/// 입력 창의 글을 거래 초안으로 바꾸는 순서. 화면과 평가 도구가 같은 코드를 쓴다.
library;

import '../core/local_date.dart';
import 'llm/llm_engine.dart';
import 'llm/llm_text_parser.dart';
import 'llm/local_model_engine.dart';
import 'parsed_transaction.dart';
import 'text/name_candidates.dart';
import 'text/paste_parser.dart';
import 'text/quick_entry_parser.dart';

/// 해석 결과.
class InterpretedInput {
  const InterpretedInput(this.items, {required this.fromSentence});

  /// 덩어리마다의 판정: 거래 초안, 안내문, 읽지 못한 글.
  final List<ParsedItem> items;

  /// 형식 규칙이 하나도 읽지 못한 한 줄 글이었는지. 자연어 입력으로 기록한다.
  final bool fromSentence;

  Iterable<ParsedTransaction> get transactions =>
      items.whereType<TransactionItem>().map((i) => i.transaction);
}

/// [input]을 해석한다.
///
/// 1. 형식 규칙이 아는 결제 문자 · 입출금 알림을 읽고, 안내문을 걸러 낸다.
/// 2. 사람이 쓴 한 줄 문장은 규칙으로 읽는다. 홀드아웃 실측에서 문장은 규칙이 소형 모델보다
///    정확하고(금액 · 날짜 · 방향 85% 대 75%) 바로 끝났다(`eval/README.md`).
/// 3. 규칙이 읽지 못한 덩어리(모르는 형식의 문자)는 [engine]이 있으면 기기 안의 모델에
///    넘긴다. 이쪽은 모델이 상대방을 훨씬 잘 가려낸다.
/// 4. 모델이 없거나 모델도 읽지 못한 한 줄 글은 규칙으로 읽어 본다.
Future<InterpretedInput> interpretInput(
  String input, {
  required LocalDate today,
  required List<String> expenseCategories,
  required List<String> incomeCategories,
  LlmEngine? engine,
  PasteParser? parser,
}) async {
  var items = (parser ?? PasteParser()).parse(input, today: today);
  final oneLine = !input.trim().contains('\n');
  final fromSentence = oneLine && items.every((i) => i is UnrecognizedItem);

  if (fromSentence && !looksLikeMessage(input)) {
    final quick = parseQuickEntry(input, today: today);
    if (quick != null) {
      return InterpretedInput([TransactionItem(quick)], fromSentence: true);
    }
  }

  if (engine != null) {
    final llm = LlmTextParser(engine);
    final resolved = <ParsedItem>[];
    for (final item in items) {
      if (item is! UnrecognizedItem) {
        resolved.add(item);
        continue;
      }
      final LlmParseResult result;
      try {
        result = await llm.parse(
          item.raw,
          today: today,
          expenseCategories: expenseCategories,
          incomeCategories: incomeCategories,
        );
      } on GenerationCancelled {
        // 사용자가 멈췄다. 남은 덩어리도 모델에 넘기지 않게 부르는 쪽에 알린다.
        rethrow;
      } on Object {
        // 모델을 올리지 못했거나 추론이 실패했다. 이 덩어리는 읽지 못한 것으로 두고
        // 나머지는 계속 읽는다. 모델이 고장 나도 규칙으로 읽은 것은 잃지 않는다.
        resolved.add(item);
        continue;
      }
      if (result.failed) {
        resolved.add(item);
      } else if (!result.isTransaction) {
        resolved.add(
          NonTransactionItem(item.raw, NonTransactionReason.judgedByModel),
        );
      } else {
        resolved.addAll(result.transactions.map(TransactionItem.new));
      }
    }
    items = resolved;
  }

  if (oneLine && items.every((i) => i is UnrecognizedItem)) {
    final quick = parseQuickEntry(input, today: today);
    if (quick != null) items = [TransactionItem(quick)];
  }

  return InterpretedInput(items, fromSentence: fromSentence);
}
