import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/llm/narrative_writer.dart';
import '../../app/providers.dart';
import '../../data/repositories/monthly_summary_repository.dart';
import '../../data/repositories/summary_repository.dart';
import '../../domain/month_period.dart';

/// [period]의 집계에 드는 것이 바뀌면 달라지는 표지. 총평이 이것을 보고 다시 만든다.
final _monthDataStampProvider = StreamProvider.family<String, MonthPeriod>(
  (ref, period) => ref
      .watch(monthlySummaryRepositoryProvider)
      .watchDataStamp(ref.watch(ledgerIdProvider), period),
);

/// 그 달의 총평 문장(`docs/SPEC.md` 7.10). 아직 만들지 않았거나 만들 수 없으면 null.
///
/// 끝난 달만 만든다(이번 달은 숫자가 아직 움직인다). 처음 읽을 때 집계를 계산해
/// `monthly_summaries`에 보관하고, 다음부터는 집계의 해시가 같은 동안 보관한 글을 쓴다.
/// 기기 안의 모델이 있으면 모델이 쓰고, 없거나 검증에서 떨어지면 문장 틀로 쓴다.
final monthNarrativeProvider = FutureProvider.family<String?, MonthPeriod>((
  ref,
  period,
) async {
  final today = ref.watch(todayProvider);
  if (today < period.endExclusive) return null;
  final ledgerId = ref.watch(ledgerIdProvider);
  final summaries = ref.watch(summaryRepositoryProvider);
  final repository = ref.watch(monthlySummaryRepositoryProvider);
  final engine = ref.watch(llmEngineProvider);
  // 지난달의 거래를 고치면 총평도 다시 맞춘다. 표지의 첫 값을 기다리지는 않는다:
  // 듣는 화면이 없으면 표지의 흐름이 멈춰 있어서, 기다리면 이 값도 끝나지 않는다.
  ref.listen(_monthDataStampProvider(period), (previous, next) {
    final before = previous?.value;
    final after = next.value;
    if (before != null && after != null && before != after) {
      ref.invalidateSelf();
    }
  });

  final summary = await summaries.monthSummary(ledgerId, period, today: today);
  // 적은 것이 없는 달에는 할 말이 없다.
  if (summary.income == 0 && summary.expense == 0) return null;
  return repository.narrativeFor(
    ledgerId,
    month: period.key,
    stats: summary.toStatsJson(),
    write: NarrativeWriter(engine).write,
  );
});
