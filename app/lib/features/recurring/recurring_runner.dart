import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../core/local_date.dart';
import '../../data/repositories/recurring_repository.dart';

/// 앱을 켤 때와 동기화가 끝난 뒤에 밀린 반복 거래를 만든다(`docs/SPEC.md` 7.13).
/// 뼈대가 이 제공자를 켜 둔다(`app/background_jobs.dart`).
///
/// 동기화 뒤에 다시 도는 까닭: 다른 기기에서 만든 규칙을 방금 받았을 수 있고, 다른 기기가
/// 이미 만든 거래를 받은 뒤에 돌아야 같은 거래를 또 올리지 않는다(올려도 ID가 같아 한
/// 건만 남지만, 쓸데없는 충돌 기록이 생긴다).
final recurringRunnerProvider = Provider<void>((ref) {
  final repository = ref.watch(recurringRepositoryProvider);
  final ledgerId = ref.watch(ledgerIdProvider);
  var running = false;
  var disposed = false;
  ref.onDispose(() => disposed = true);

  Future<void> run() async {
    // 도는 중에 또 부르면 건너뛴다. 못 만든 것은 다음 차례에 만든다.
    if (running || disposed) return;
    running = true;
    try {
      final today = LocalDate.fromDateTime(ref.read(clockProvider)());
      await repository.runDue(ledgerId, today);
    } catch (_) {
      // 뒤에서 도는 일이라 화면을 멈추지 않는다. 다음에 켜거나 동기화한 뒤에 다시 한다.
    } finally {
      running = false;
    }
  }

  // 앱을 켤 때 한 번. 제공자를 만드는 중에는 다른 상태를 바꾸지 않게 뒤로 미룬다.
  unawaited(Future.microtask(run));
  ref.listen(syncControllerProvider, (previous, next) {
    if (next.phase == SyncPhase.idle && previous?.phase != SyncPhase.idle) {
      unawaited(run());
    }
  });
});
