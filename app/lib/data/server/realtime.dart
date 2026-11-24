import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';

/// 신호를 받은 뒤 받기를 돌리기까지 모으는 시간. 묶음 하나가 신호 여러 개를 낼 수 있고,
/// 자기가 올린 변경의 신호도 온다.
const realtimeDebounce = Duration(milliseconds: 500);

/// 서버의 실시간 신호를 듣고 있다가 변경이 생기면 받기를 돌린다(`docs/SPEC.md` 4.4).
/// 뼈대가 이 제공자를 켜 둔다(`app/background_jobs.dart`).
///
/// - 로그인해 기기의 가계부를 계정의 가계부에 맞춘 뒤에 구독한다. 그 전의 가계부 ID는 서버에
///   없는 것이라 들을 채널이 없다.
/// - 신호를 받으면 [realtimeDebounce]만큼 모았다가 받기를 한 번 돌린다.
/// - 로그아웃하면 구독을 끊는다. 가계부가 바뀌면 앱이 다시 열리면서 이 제공자도 새로 만들어진다.
/// - 동기화가 잠깐 실패한 동안에는 구독을 그대로 둔다(연결은 라이브러리가 다시 붙인다).
final realtimeSyncProvider = Provider<void>((ref) {
  final services = ref.watch(appServicesProvider);
  final changes = services.server?.changes;
  if (changes == null) return;

  StreamSubscription<void>? subscription;
  Timer? debounce;

  void stop() {
    debounce?.cancel();
    debounce = null;
    subscription?.cancel();
    subscription = null;
  }

  void onSignal() {
    // 이미 기다리는 중이면 그 한 번에 묻어 간다.
    debounce ??= Timer(realtimeDebounce, () {
      debounce = null;
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    });
  }

  void follow(SyncStatus status) {
    switch (status.phase) {
      case SyncPhase.idle || SyncPhase.syncing:
        if (subscription != null || status.user == null) return;
        if (!ref.read(syncControllerProvider.notifier).ledgerReady) return;
        subscription = changes(services.ledgerId)
            .listen((_) => onSignal(), onError: (Object _) {});
      case SyncPhase.failed:
        // 다음 차례에 다시 해 본다. 듣고 있었으면 계속 듣는다.
        break;
      case SyncPhase.signedOut ||
          SyncPhase.differentAccount ||
          SyncPhase.unavailable:
        stop();
    }
  }

  ref.listen(
    syncControllerProvider,
    (_, status) => follow(status),
    fireImmediately: true,
  );
  ref.onDispose(stop);
});
