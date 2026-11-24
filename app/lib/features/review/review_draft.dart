import '../../ai/parsed_transaction.dart';
import '../../ai/text/category_hints.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/input_batch_repository.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';

/// `copyWith`에서 "바꾸지 않는다"를 null과 구분하는 표시.
const _keep = Object();

/// 검토함의 한 건. 읽어 낸 값에 사용자가 고친 값이 덮인다.
///
/// 값은 바꾸지 않고 [copyWith]로 새로 만든다. 검토 중인 내용이 화면이 아니라 상태
/// 제공자에 있어야 창 크기를 바꾸거나 다른 탭에 다녀와도 남는다.
class ReviewDraft {
  const ReviewDraft({
    required this.parsed,
    required this.source,
    required this.type,
    required this.date,
    required this.amount,
    required this.accountId,
    required this.counterparty,
    required this.categoryId,
    required this.accountMatched,
    required this.include,
    this.toAccountId,
    this.memo,
    this.cancelTarget,
    this.duplicates = 0,
    this.warnings = const {},
    this.transferSuggested = false,
    this.edited = false,
  });

  /// 규칙이나 모델이 읽어 낸 원래 값.
  final ParsedTransaction parsed;

  /// 어떤 경로로 들어왔는지.
  final TxSource source;

  final TxType type;
  final LocalDate date;

  /// 해외 결제처럼 금액을 모르면 null이고, 사용자가 채워야 저장된다.
  final int? amount;
  final String? accountId;

  /// 이체일 때 받는 자산.
  final String? toAccountId;
  final String counterparty;
  final String? categoryId;
  final String? memo;

  /// 저장할지(포함 · 제외).
  final bool include;

  /// 원문의 카드 · 계좌 표기가 등록한 자산과 맞았는지. 아니면 기본 자산을 제안한 것이다.
  final bool accountMatched;

  /// 취소 문자의 원 거래. 있으면 새 거래를 만들지 않고 이 거래를 취소로 표시한다.
  final TxRow? cancelTarget;

  /// 날짜 · 금액 · 상대방이 같은 거래 수(이미 저장된 것과 같은 묶음의 앞선 건).
  final int duplicates;

  /// 사용자가 눈여겨봐야 할 점. 하나라도 있으면 '확인 필요'다.
  final Set<ParseWarning> warnings;

  /// 카드대금 출금으로 보여 이체(계좌 → 카드)로 바꿔 제안했는지.
  final bool transferSuggested;

  /// 사용자가 이 건을 고쳤거나 확인했는지. 그러면 '확인 필요' 표시가 풀린다.
  final bool edited;

  /// 저장하면 새 거래를 만들지 않고 원 거래를 취소로 표시하는 건인지.
  bool get cancelsExisting => parsed.isCancel && cancelTarget != null;

  /// 경고가 남아 있는지. 이대로 저장하면 거래에 `needs_review`가 붙는다.
  /// 원 거래를 취소로 표시하기만 하는 건에는 붙일 거래가 없으므로 해당하지 않는다.
  bool get needsReview => !cancelsExisting && warnings.isNotEmpty && !edited;

  /// 저장하려면 더 채워야 하는 것. 다 찼으면 null.
  String? get missing {
    if (cancelsExisting) return null;
    if (amount == null || amount! <= 0) return '금액을 넣어야 합니다';
    if (accountId == null) return '자산을 골라야 합니다';
    if (type == TxType.transfer) {
      if (toAccountId == null) return '받는 자산을 골라야 합니다';
      if (toAccountId == accountId) return '보내는 자산과 받는 자산이 같습니다';
    }
    return null;
  }

  /// 포함했고 저장할 수 있는지.
  bool get canSave => include && missing == null;

  /// 포함했지만 채울 것이 남아 저장을 막는지.
  bool get blocksSave => include && missing != null;

  ReviewDraft copyWith({
    TxType? type,
    LocalDate? date,
    Object? amount = _keep,
    Object? accountId = _keep,
    Object? toAccountId = _keep,
    String? counterparty,
    Object? categoryId = _keep,
    Object? memo = _keep,
    bool? include,
    int? duplicates,
    bool? edited,
  }) => ReviewDraft(
    parsed: parsed,
    source: source,
    type: type ?? this.type,
    date: date ?? this.date,
    amount: identical(amount, _keep) ? this.amount : amount as int?,
    accountId: identical(accountId, _keep)
        ? this.accountId
        : accountId as String?,
    toAccountId: identical(toAccountId, _keep)
        ? this.toAccountId
        : toAccountId as String?,
    counterparty: counterparty ?? this.counterparty,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    memo: identical(memo, _keep) ? this.memo : memo as String?,
    include: include ?? this.include,
    accountMatched: accountMatched,
    cancelTarget: cancelTarget,
    duplicates: duplicates ?? this.duplicates,
    warnings: warnings,
    transferSuggested: transferSuggested,
    edited: edited ?? this.edited,
  );

  /// 같은 거래인지 가리는 키. 금액을 모르면 null.
  String? get dedupKey => amount == null
      ? null
      : LedgerRepository.dedupKeyFor(
          date,
          amount!,
          type == TxType.transfer ? null : counterparty,
        );

  /// 저장할 때 저장소에 넘기는 값. [canSave]일 때만 부른다.
  BatchEntry toEntry() {
    final target = cancelTarget;
    if (parsed.isCancel && target != null) return BatchCancel(target.id);
    final memoParts = [
      if ((memo ?? '').trim().isNotEmpty) memo!.trim(),
      if (parsed.isCancel) '취소 · 환불',
    ];
    final transfer = type == TxType.transfer;
    return BatchCreate(
      TransactionInput(
        type: type,
        occurredOn: date,
        occurredTime: parsed.time,
        // 원 거래를 찾지 못한 취소는 환불(음수 지출)로 적는다.
        amount: parsed.isCancel ? -amount! : amount!,
        accountId: accountId!,
        toAccountId: transfer ? toAccountId : null,
        counterparty: transfer ? null : counterparty,
        categoryId: transfer ? null : categoryId,
        memo: memoParts.isEmpty ? null : memoParts.join(' · '),
        installmentMonths: parsed.installmentMonths,
        balanceAfter: parsed.balanceAfter,
        currency: parsed.currency,
        originalAmount: parsed.originalAmount?.toDouble(),
        source: source,
        aiModel: parsed.modelName,
        status: needsReview ? TxStatus.needsReview : TxStatus.confirmed,
      ),
    );
  }
}

/// 거래 초안을 검토함의 처음 상태로 바꾼다(`docs/SPEC.md` 5.3).
///
/// - 자산: 원문의 카드 · 계좌 표기를 자산에 등록한 식별 문구와 맞춰 본다.
///   못 찾으면 기본 자산을 제안한다.
/// - 분류: 사용자가 쌓은 분류 규칙이 먼저고, 그다음이 모델이 고른 분류, 마지막이 기본
///   낱말 사전이다.
/// - 취소 문자는 원 거래를 찾는다. 같은 거래가 이미 있으면 기본을 제외로 둔다.
/// - 카드대금으로 보이는 출금은 그 카드의 결제 계좌에서 나간 것이면 이체로 제안한다.
Future<ReviewDraft> buildReviewDraft({
  required LedgerRepository repository,
  required String ledgerId,
  required ParsedTransaction parsed,
  required TxSource source,
  required List<AccountRow> accounts,
  required List<CategoryRow> categories,
  required String? defaultAccountId,
  required LocalDate today,
}) async {
  var type = switch (parsed.direction) {
    Direction.incoming => TxType.income,
    Direction.outgoing => TxType.expense,
    Direction.transfer => TxType.transfer,
  };

  final matched = matchAccount(parsed, accounts);
  final fallback = accounts.any((a) => a.id == defaultAccountId)
      ? defaultAccountId
      : (accounts.isEmpty ? null : accounts.first.id);
  var accountId = matched?.id ?? fallback;

  final party = parsed.counterparty ?? '';

  // 카드대금: 지출로 두면 카드로 쓴 돈과 두 번 잡힌다.
  String? toAccountId;
  var transferSuggested = false;
  if (type == TxType.expense &&
      parsed.warnings.contains(ParseWarning.possibleCardPayment)) {
    final card = _cardPaidFrom(party, accounts, fromAccountId: matched?.id);
    if (card != null) {
      type = TxType.transfer;
      toAccountId = card.id;
      accountId = matched?.id ?? card.paymentAccountId;
      transferSuggested = true;
    }
  }

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
      // 상대방만으로 짐작하고, 안 되면 메모까지 본다('버스비' + '아침'은 교통이다).
      final name =
          parsed.category ??
          suggestCategoryName(party, parsed.direction) ??
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
        counterparty: type == TxType.transfer ? null : party,
      )).length;
    }
  }

  // 대부분의 문자는 연도가 없다. 올해로 채운 흔한 경우는 경고로 치지 않고,
  // 지난해로 넘어간 경우(1월에 붙여넣은 12월 문자)만 확인을 청한다.
  final warnings = {
    for (final w in parsed.warnings)
      if (w != ParseWarning.yearInferred || parsed.date.year != today.year) w,
  };

  return ReviewDraft(
    parsed: parsed,
    source: source,
    type: type,
    date: parsed.date,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    counterparty: party,
    categoryId: categoryId,
    memo: parsed.memo,
    accountMatched: matched != null,
    cancelTarget: cancelTarget,
    duplicates: duplicates,
    warnings: warnings,
    transferSuggested: transferSuggested,
    // 중복으로 보이는 건은 기본이 제외다.
    include: duplicates == 0,
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

/// 카드사 이름 [party]로 나간 출금이 갚은 카드 자산을 찾는다(`docs/SPEC.md` 7.12).
///
/// 결제 계좌를 등록한 신용카드 가운데 이름이 카드사와 맞는 것이 하나뿐일 때만 돌려준다.
/// 출금 계좌를 알아냈으면([fromAccountId]) 그 계좌가 카드의 결제 계좌여야 한다. 출금
/// 계좌를 알아내지 못했으면 카드에 등록한 결제 계좌에서 나간 것으로 본다.
AccountRow? _cardPaidFrom(
  String party,
  List<AccountRow> accounts, {
  required String? fromAccountId,
}) {
  final company = _companyKey(party);
  if (company.isEmpty) return null;
  final cards = [
    for (final a in accounts)
      if (a.kind == AccountKind.creditCard &&
          a.paymentAccountId != null &&
          accounts.any((p) => p.id == a.paymentAccountId) &&
          (fromAccountId == null || a.paymentAccountId == fromAccountId) &&
          [a.name, a.institution, ...a.matchHints].whereType<String>().any((
            text,
          ) {
            final key = _companyKey(text);
            return key.isNotEmpty &&
                (key.contains(company) || company.contains(key));
          }))
        a,
  ];
  return cards.length == 1 ? cards.single : null;
}

/// '신한카드', '신한 카드(주)' → '신한'. 카드사 이름을 견주는 데 쓴다.
String _companyKey(String text) => text
    .replaceAll(RegExp(r'\s+|\(주\)|㈜|주식회사'), '')
    .replaceAll('카드', '')
    .toLowerCase();
