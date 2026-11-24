import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/query/ledger_query.dart';
import '../../ai/query/llm_query_parser.dart';
import '../../ai/query/query_parser.dart';
import '../../app/providers.dart';
import '../../data/repositories/query_repository.dart';

/// 물음 하나를 처리한 결과.
sealed class QueryOutcome {
  const QueryOutcome();
}

/// 조건을 읽어 답을 냈다.
class QueryAnswered extends QueryOutcome {
  const QueryAnswered(this.result);

  final QueryResult result;
}

/// 조건을 읽지 못했다. 화면은 그렇게 말하고 예시를 보여 준다.
class QueryUnreadable extends QueryOutcome {
  const QueryUnreadable();
}

/// [question]의 조건을 읽고 답을 낸다(`docs/SPEC.md` 7.15).
///
/// 규칙이 먼저 읽는다. 규칙이 못 읽고 기기 안의 모델이 있으면 모델이 조건을 고른다.
/// 어느 쪽이든 숫자는 `runQuery`의 SQL이 센다.
final queryOutcomeProvider = FutureProvider.autoDispose
    .family<QueryOutcome, String>((ref, question) async {
      final repository = ref.watch(repositoryProvider);
      final ledgerId = ref.watch(ledgerIdProvider);
      final today = ref.watch(todayProvider);
      final rows = await ref.watch(categoriesProvider.future);
      // 월 시작일은 프로필에서 바로 읽는다. 제공자의 값은 프로필이 오기 전에 1이라
      // 주소로 곧장 들어온 조회의 기간이 어긋날 수 있다.
      final startDay = (await repository.profile(ledgerId))?.monthStartDay ?? 1;
      final categories = [
        for (final row in rows) QueryCategory(row.name, row.kind),
      ];

      var query = parseQuery(
        question,
        today: today,
        categories: categories,
        startDay: startDay,
      );
      if (query == null && question.trim().isNotEmpty) {
        final engine = ref.watch(llmEngineProvider);
        if (engine != null) {
          try {
            query = await LlmQueryParser(engine).parse(
              question,
              today: today,
              categories: categories,
              startDay: startDay,
            );
          } on Object {
            // 모델이 답하지 못하면(내려갔거나 시간이 넘었으면) 읽지 못한 것으로 둔다.
            query = null;
          }
        }
      }
      if (query == null) return const QueryUnreadable();
      return QueryAnswered(
        await runQuery(repository, ledgerId, query, today: today),
      );
    });
