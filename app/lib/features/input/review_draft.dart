import '../../ai/parsed_transaction.dart';
import '../../ai/text/category_hints.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';

/// 검토 카드 한 장의 상태. 사용자가 고친 값이 여기에 담긴다.
class ReviewDraft {
  ReviewDraft({
    required this.parsed,
    required this.type,
    required this.date,
    required this.amount,
    required this.accountId,
    required this.counterparty,
    required this.categoryId,
    required this.accountMatched,
    this.cancelTarget,
    this.duplicates = 0,
  });

  /// 규칙이나 모델이 읽어 낸 원래 값.
  final ParsedTransaction parsed;

  TxType type;
  LocalDate date;

  /// 해외 결제처럼 금액을 모르면 null이고, 사용자가 채워야 저장된다.
  int? amount;
  String? accountId;
  String counterparty;
  String? categoryId;

  /// 저장할지.
  bool include = true;

  /// 원문의 카드 · 계좌 표기가 등록한 자산과 맞았는지. 아니면 기본 자산을 제안한 것이다.
  final bool accountMatched;

  /// 취소 문자의 원 거래. 있으면 새 거래를 만들지 않고 이 거래를 취소로 표시한다.
  final TxRow? cancelTarget;

  /// 날짜 · 금액 · 상대방이 같은 기존 거래 수.
  final int duplicates;

  bool get canSave =>
      include && accountId != null && amount != null && amount! > 0;
}

/// 거래 초안을 검토 카드의 처음 상태로 바꾼다.
///
/// - 자산: 원문의 카드 · 계좌 표기를 자산에 등록한 식별 문구와 맞춰 본다.
///   못 찾으면 기본 자산을 제안한다.
/// - 분류: 사용자가 쌓은 분류 규칙이 먼저고, 그다음이 모델이 고른 분류, 마지막이 기본
///   낱말 사전이다.
/// - 취소 문자는 원 거래를 찾는다. 같은 거래가 이미 있으면 알린다.
Future<ReviewDraft> buildReviewDraft({
  required LedgerRepository repository,
  required String ledgerId,
  required ParsedTransaction parsed,
  required List<AccountRow> accounts,
  required List<CategoryRow> categories,
  required String? defaultAccountId,
}) async {
  final type = switch (parsed.direction) {
    Direction.incoming => TxType.income,
    Direction.outgoing => TxType.expense,
    Direction.transfer => TxType.transfer,
  };

  final matched = matchAccount(parsed, accounts);
  final fallback = accounts.any((a) => a.id == defaultAccountId)
      ? defaultAccountId
      : (accounts.isEmpty ? null : accounts.first.id);

  final party = parsed.counterparty ?? '';
  String? categoryId;
  if (type != TxType.transfer && party.isNotEmpty) {
    final byRule = await repository.categoryForCounterparty(ledgerId, party);
    final kind = type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    if (byRule != null &&
        categories.any((c) => c.id == byRule && c.kind == kind)) {
      categoryId = byRule;
    } else {
      // 모델이 고른 분류가 있으면 그것을, 없으면 기본 낱말 사전을 쓴다.
      final name =
          parsed.category ??
          suggestCategoryName('$party ${parsed.memo ?? ''}', parsed.direction);
      for (final c in categories) {
        if (c.kind == kind && c.name == name) categoryId = c.id;
      }
    }
  } else if (type != TxType.transfer && parsed.category != null) {
    final kind = type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    for (final c in categories) {
      if (c.kind == kind && c.name == parsed.category) categoryId = c.id;
    }
  }

  TxRow? cancelTarget;
  var duplicates = 0;
  final amount = parsed.amount;
  if (amount != null) {
    if (parsed.isCancel) {
      cancelTarget = await repository.findCancelTarget(
        ledgerId,
        amount: amount,
        onOrBefore: parsed.date,
        counterparty: party,
      );
    } else {
      duplicates = (await repository.findPossibleDuplicates(
        ledgerId,
        date: parsed.date,
        amount: amount,
        counterparty: party,
      )).length;
    }
  }

  return ReviewDraft(
    parsed: parsed,
    type: type,
    date: parsed.date,
    amount: amount,
    accountId: matched?.id ?? fallback,
    counterparty: party,
    categoryId: categoryId,
    accountMatched: matched != null,
    cancelTarget: cancelTarget,
    duplicates: duplicates,
  );
}

/// 원문의 카드 · 계좌 표기에 맞는 자산을 찾는다.
///
/// 자산의 식별 문구가 모두 원문 표기에 들어 있어야 맞은 것으로 본다. 여러 자산이 맞으면
/// 식별 문구가 많은 쪽을 고른다.
AccountRow? matchAccount(ParsedTransaction parsed, List<AccountRow> accounts) {
  final haystack = [
    parsed.institution,
    parsed.accountText,
    parsed.accountHint,
  ].whereType<String>().join(' ').replaceAll(' ', '').toLowerCase();
  if (haystack.isEmpty) return null;

  AccountRow? best;
  var bestScore = 0;
  for (final account in accounts) {
    final hints = [
      for (final h in account.matchHints)
        if (h.trim().isNotEmpty) h.replaceAll(' ', '').toLowerCase(),
    ];
    if (hints.isEmpty) continue;
    if (hints.every(haystack.contains) && hints.length > bestScore) {
      best = account;
      bestScore = hints.length;
    }
  }
  return best;
}

/// 검토를 마친 초안을 저장한다. 저장한 건수를 돌려준다.
Future<int> saveReviewDrafts({
  required LedgerRepository repository,
  required String ledgerId,
  required List<ReviewDraft> drafts,
  required TxSource source,
}) async {
  var saved = 0;
  for (final draft in drafts) {
    if (!draft.canSave) continue;
    final parsed = draft.parsed;
    final target = draft.cancelTarget;
    if (parsed.isCancel && target != null) {
      // 취소 문자: 원 거래를 취소로 표시한다.
      await repository.setCanceled(target.id, canceled: true);
      saved++;
      continue;
    }
    final memoParts = [
      if (parsed.memo != null) parsed.memo!,
      if (parsed.isCancel) '취소 · 환불',
    ];
    await repository.addTransaction(
      ledgerId,
      TransactionInput(
        type: draft.type,
        occurredOn: draft.date,
        occurredTime: parsed.time,
        // 원 거래를 찾지 못한 취소는 환불(음수 지출)로 적는다.
        amount: parsed.isCancel ? -draft.amount! : draft.amount!,
        accountId: draft.accountId!,
        counterparty: draft.counterparty,
        categoryId: draft.categoryId,
        memo: memoParts.isEmpty ? null : memoParts.join(' · '),
        installmentMonths: parsed.installmentMonths,
        balanceAfter: parsed.balanceAfter,
        currency: parsed.currency,
        originalAmount: parsed.originalAmount?.toDouble(),
        source: source,
        aiModel: parsed.modelName,
      ),
    );
    final categoryId = draft.categoryId;
    if (draft.counterparty.trim().isNotEmpty && categoryId != null) {
      await repository.rememberCategory(
        ledgerId,
        draft.counterparty,
        categoryId,
      );
    }
    saved++;
  }
  return saved;
}
