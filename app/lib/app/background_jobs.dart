import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/conflict_repository.dart';
import '../data/server/realtime.dart';
import '../features/recurring/recurring_runner.dart';

/// 화면이 떠 있는 동안 뒤에서 도는 일을 켠다. 뼈대가 본다.
///
/// 일을 더하려면 그 일을 하는 제공자를 만들고 여기서 켠다.
final backgroundJobsProvider = Provider<void>((ref) {
  ref.watch(recurringRunnerProvider);
  ref.watch(realtimeSyncProvider);
  // 오래된 충돌 기록은 켤 때 한 번 치운다. 못 치워도 다음에 켤 때 다시 한다.
  Future.microtask(() async {
    try {
      await ref.read(conflictRepositoryProvider).pruneConflicts();
    } catch (_) {}
  });
});
