import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/llm/llm_engine.dart';
import '../core/local_date.dart';
import '../data/db/database.dart';
import '../data/repositories/ledger_repository.dart';
import '../domain/month_period.dart';
import '../domain/month_summary.dart';

/// 앱이 시작할 때 한 번 준비하는 것들.
class AppServices {
  const AppServices({
    required this.db,
    required this.repository,
    required this.ledgerId,
    required this.storage,
    required this.persistent,
  });

  final AppDatabase db;
  final LedgerRepository repository;

  /// 지금 쓰는 가계부.
  final String ledgerId;

  /// 로컬 DB의 저장 방식(설정 화면에 보여 준다).
  final String storage;

  /// 앱을 닫아도 데이터가 남는지.
  final bool persistent;
}

/// [Bootstrap]이 준비가 끝난 값으로 덮어쓴다.
final appServicesProvider = Provider<AppServices>(
  (ref) => throw StateError('appServicesProvider를 덮어써야 한다'),
);

final repositoryProvider = Provider<LedgerRepository>(
  (ref) => ref.watch(appServicesProvider).repository,
);

final ledgerIdProvider = Provider<String>(
  (ref) => ref.watch(appServicesProvider).ledgerId,
);

/// 기기 안의 언어 모델. 없으면 규칙만으로 동작한다.
///
/// 웹 앱에는 모델이 없다(v1). Windows와 Android는 모델을 내려받은 뒤에 채운다.
final llmEngineProvider = Provider<LlmEngine?>((ref) => null);

/// 현재 시각. 시험에서 덮어쓴다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final todayProvider = Provider<LocalDate>(
  (ref) => LocalDate.fromDateTime(ref.watch(clockProvider)()),
);

final profileProvider = StreamProvider<ProfileRow?>(
  (ref) =>
      ref.watch(repositoryProvider).watchProfile(ref.watch(ledgerIdProvider)),
);

/// 월 시작일(1–28).
final monthStartDayProvider = Provider<int>(
  (ref) => ref.watch(profileProvider).value?.monthStartDay ?? 1,
);

/// 화면에 보고 있는 달.
class SelectedPeriod extends Notifier<MonthPeriod> {
  @override
  MonthPeriod build() => MonthPeriod.containing(
    ref.watch(todayProvider),
    startDay: ref.watch(monthStartDayProvider),
  );

  void previous() => state = state.previous;
  void next() => state = state.next;

  void showToday() => state = MonthPeriod.containing(
    ref.read(todayProvider),
    startDay: ref.read(monthStartDayProvider),
  );

  /// [date]가 속한 달을 보여 준다.
  void show(LocalDate date) => state = MonthPeriod.containing(
    date,
    startDay: ref.read(monthStartDayProvider),
  );
}

final selectedPeriodProvider = NotifierProvider<SelectedPeriod, MonthPeriod>(
  SelectedPeriod.new,
);

/// 내역 화면의 검색어.
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

final monthSummaryProvider = StreamProvider<MonthSummary>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(repositoryProvider)
      .watchMonthSummary(
        ref.watch(ledgerIdProvider),
        period,
        today: ref.watch(todayProvider),
      );
});

/// 보고 있는 달의 거래(검색어 적용).
final transactionsProvider = StreamProvider<List<TransactionView>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(repositoryProvider)
      .watchTransactions(
        ref.watch(ledgerIdProvider),
        from: period.start,
        toExclusive: period.endExclusive,
        search: ref.watch(searchQueryProvider),
      );
});

/// 보고 있는 달의 거래(검색어 없이). 홈 화면의 최근 내역에 쓴다.
final monthTransactionsProvider = StreamProvider<List<TransactionView>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  return ref
      .watch(repositoryProvider)
      .watchTransactions(
        ref.watch(ledgerIdProvider),
        from: period.start,
        toExclusive: period.endExclusive,
      );
});

final accountsProvider = StreamProvider<List<AccountRow>>(
  (ref) =>
      ref.watch(repositoryProvider).watchAccounts(ref.watch(ledgerIdProvider)),
);

final accountBalancesProvider = StreamProvider<List<AccountBalance>>(
  (ref) => ref
      .watch(repositoryProvider)
      .watchAccountBalances(ref.watch(ledgerIdProvider)),
);

final categoriesProvider = StreamProvider<List<CategoryRow>>(
  (ref) => ref
      .watch(repositoryProvider)
      .watchCategories(ref.watch(ledgerIdProvider)),
);

/// 아직 서버로 보내지 않은 변경 수.
final pendingChangesProvider = StreamProvider<int>(
  (ref) => ref.watch(repositoryProvider).watchPendingChangeCount(),
);
