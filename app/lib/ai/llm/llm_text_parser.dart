import 'dart:convert';

import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import '../text/date_parser.dart';
import '../text/direction_rules.dart';
import '../text/text_normalizer.dart';
import 'extraction_prompt.dart';
import 'llm_engine.dart';

/// 모델이 만든 초안의 [ParsedTransaction.ruleId] 머리말. 뒤에 모델 이름이 붙는다.
const llmRulePrefix = 'llm:';

/// 모델로 해석한 결과.
class LlmParseResult {
  const LlmParseResult({
    required this.transactions,
    required this.isTransaction,
    required this.attempts,
    this.failure,
  });

  /// 거래 초안. 검증을 통과한 것만 들어 있다.
  final List<ParsedTransaction> transactions;

  /// 모델이 거래가 있는 글로 봤는지. false면 안내문 · 광고로 본 것이다.
  final bool isTransaction;

  /// 모델을 부른 횟수.
  final int attempts;

  /// 두 번 모두 검증에 실패했을 때의 이유. 이때는 원문을 붙인 직접 입력으로 넘긴다.
  final String? failure;

  bool get failed => failure != null;
}

/// 형식 규칙이 읽지 못한 글과 한 줄 문장을 기기 안의 LLM으로 해석한다.
///
/// 모델은 규칙이 뽑은 후보 가운데에서 고르고, 돈이 실제로 움직인 글인지 판정한다.
/// 출력은 여기서 다시 검증한다(문법을 쓰지 못하는 엔진도 있기 때문이다).
/// - 날짜와 금액은 규칙이 뽑은 후보 안에 있어야 한다.
/// - 방향은 원문의 낱말로 정해지면 그것을 쓴다.
/// - 상대와 내용은 원문에 있는 글자여야 한다. 없으면 버린다.
/// - 시각 · 잔액 · 할부 개월 · 취소 여부는 모델에 묻지 않고 규칙이 원문에서 읽는다.
/// 검증에 실패하면 이유를 붙여 한 번 다시 묻고, 또 실패하면 포기한다.
class LlmTextParser {
  LlmTextParser(this.engine);

  final LlmEngine engine;

  Future<LlmParseResult> parse(
    String text, {
    required LocalDate today,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
  }) async {
    final input = normalizeText(text);
    String? feedback;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final request = buildExtractionRequest(
        text: input,
        today: today,
        expenseCategories: expenseCategories,
        incomeCategories: incomeCategories,
        feedback: feedback,
      );
      final raw = await engine.generateJson(
        system: request.system,
        user: request.user,
        schema: request.schema,
        grammar: request.grammar,
        maxTokens: 400,
      );
      final outcome = _validate(
        raw,
        request: request,
        input: input,
        original: text,
        today: today,
        categories: {...expenseCategories, ...incomeCategories},
      );
      if (outcome.problem == null) {
        return LlmParseResult(
          transactions: outcome.transactions,
          isTransaction: outcome.isTransaction,
          attempts: attempt,
        );
      }
      feedback = outcome.problem;
    }
    return LlmParseResult(
      transactions: const [],
      isTransaction: true,
      attempts: 2,
      failure: feedback,
    );
  }

  _Outcome _validate(
    String raw, {
    required ExtractionRequest request,
    required String input,
    required String original,
    required LocalDate today,
    required Set<String> categories,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // 토큰 한도에서 잘린 출력도 여기로 온다.
      return const _Outcome.problem('JSON이 아니다.');
    }
    if (decoded is! Map) return const _Outcome.problem('JSON 객체가 아니다.');

    final list = decoded['tx'];
    if (list is! List) return const _Outcome.problem('"tx" 배열이 없다.');
    if (request.certainlyTransaction) {
      // 규칙만으로 거래가 분명한 글이다. 모델의 real은 보지 않는다.
      if (list.isEmpty) return const _Outcome.problem('거래를 한 건 이상 적어야 한다.');
    } else if (list.isEmpty || decoded['real'] == false) {
      // 모델이 돈이 움직이지 않은 글로 봤다. 적어 둔 거래는 버린다.
      return const _Outcome([], isTransaction: false);
    }

    final squeezed = _squeeze(input);
    // 거래가 한 건일 때만 규칙으로 읽은 시각 · 잔액 · 할부 · 취소를 붙인다. 여러 건이면
    // 어느 거래의 것인지 알 수 없다.
    final single = list.length == 1;
    final transactions = <ParsedTransaction>[];
    for (final item in list) {
      if (item is! Map) return const _Outcome.problem('거래가 객체가 아니다.');
      final warnings = <ParseWarning>{};

      // 날짜: 규칙이 뽑은 후보 안에 있어야 한다.
      final dateText = item['d'];
      final date = dateText is String ? LocalDate.tryParse(dateText) : null;
      if (date == null || !request.dateCandidates.contains(date)) {
        return _Outcome.problem('d "$dateText"는 [날짜 후보]에 없다.');
      }
      if (date.year != today.year && !input.contains('${date.year}')) {
        warnings.add(ParseWarning.yearInferred);
      }

      // 금액: 규칙이 찾은 후보만 쓴다. 후보가 없으면(해외 결제 등) 모델이 적은 숫자를
      // 버리고 비워 둔다.
      final amountValue = item['a'];
      int? amount;
      if (request.amountCandidates.isEmpty) {
        warnings.add(ParseWarning.needsKrwAmount);
      } else {
        if (amountValue is! num) {
          return const _Outcome.problem('a가 비어 있다. [금액 후보]에서 골라야 한다.');
        }
        amount = amountValue.toInt().abs();
        if (!request.amountCandidates.contains(amount)) {
          return _Outcome.problem('a $amount은 [금액 후보]의 금액에 없다.');
        }
      }

      // 방향: 원문의 낱말로 정해졌으면 그것을 쓴다.
      final answered = Direction.fromCode(item['io'] as String?);
      if (answered == null || answered == Direction.transfer) {
        return const _Outcome.problem('io는 "in"이나 "out"이어야 한다.');
      }
      final direction = request.direction ?? answered;
      if (answered != direction) warnings.add(ParseWarning.directionMismatch);

      // 상대와 내용: 원문에 있는 글자여야 한다. 지어낸 말은 버린다.
      String? grounded(Object? value) {
        if (value is! String || value.trim().isEmpty) return null;
        return squeezed.contains(_squeeze(value)) ? value.trim() : null;
      }

      var counterparty = grounded(item['who']);
      // 가린 이름(홍*동)은 카드 명의자다.
      if (counterparty != null && _maskedName.hasMatch(counterparty)) {
        counterparty = null;
      }
      if (counterparty == null) warnings.add(ParseWarning.noCounterparty);

      // 같은 말을 상대와 내용에 모두 골랐으면 상대로만 둔다.
      var memo = grounded(item['memo']);
      if (memo == counterparty) memo = null;

      final category = item['cat'];
      transactions.add(
        ParsedTransaction(
          date: date,
          time: single ? _onlyTime(input) : null,
          amount: amount,
          direction: direction,
          counterparty: counterparty,
          memo: memo,
          installmentMonths: single ? _installmentMonths(input) : null,
          balanceAfter: (single && request.balanceCandidates.length == 1)
              ? request.balanceCandidates.single
              : null,
          isCancel: single && mentionsCancel(input),
          category: (category is String && categories.contains(category))
              ? category
              : null,
          ruleId: '$llmRulePrefix${engine.modelName}',
          raw: original,
          warnings: warnings,
        ),
      );
    }
    return _Outcome(transactions, isTransaction: true);
  }
}

class _Outcome {
  const _Outcome(this.transactions, {required this.isTransaction})
    : problem = null;

  const _Outcome.problem(String this.problem)
    : transactions = const [],
      isTransaction = true;

  final List<ParsedTransaction> transactions;
  final bool isTransaction;
  final String? problem;
}

/// 공백을 없애고 소문자로 바꾼다. 원문에 있는 말인지 견줄 때 쓴다.
String _squeeze(String text) =>
    text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// 원문에 시각이 하나만 있으면 그 시각('HH:mm').
String? _onlyTime(String text) {
  final matches = _clock.allMatches(text).toList();
  if (matches.length != 1) return null;
  return formatTime(
    int.parse(matches.single.group(1)!),
    int.parse(matches.single.group(2)!),
  );
}

/// 원문의 할부 개월 수. '할부'라는 말이 있거나 금액 바로 뒤에 'N개월'이 올 때만 읽는다.
/// ('헬스장 3개월 27만원'의 3개월은 할부가 아니다.)
int? _installmentMonths(String text) {
  final afterAmount = _monthsAfterAmount.firstMatch(text);
  final withWord = _monthsWithWord.firstMatch(text);
  final found =
      afterAmount?.group(1) ?? withWord?.group(1) ?? withWord?.group(2);
  final months = found == null ? null : int.tryParse(found);
  return (months != null && months >= 2 && months <= 60) ? months : null;
}

final _clock = RegExp(r'(?<![\d:])(\d{1,2}):(\d{2})(?![\d:])');
final _monthsAfterAmount = RegExp(r'[\d,]+원\s?\(?(\d{1,2})개월');
final _monthsWithWord = RegExp(r'(\d{1,2})개월\s?할부|할부\s?(\d{1,2})개월');
final _maskedName = RegExp(r'^[가-힣A-Za-z]{0,3}\*[가-힣A-Za-z*]{0,4}님?$');
