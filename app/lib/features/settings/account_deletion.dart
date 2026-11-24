import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/db/database.dart';

/// 서버에서 로그인한 계정을 지우는 함수(`delete_my_account()`를 부른다).
///
/// 로그인하지 않았거나 서버가 없는 빌드면 null이다. null이면 계정 화면이 "계정 삭제"를
/// 숨긴다. 지우지 못하면 예외를 던진다. 그래야 기기의 가계부를 지우지 않는다.
final accountDeleterProvider = Provider<Future<void> Function()?>((ref) {
  final signedIn = ref.watch(
    syncControllerProvider.select((status) => status.signedIn),
  );
  if (!signedIn) return null;
  return ref.read(syncControllerProvider.notifier).deleteAccount;
});

/// 기기의 가계부 · 대기열 · 충돌 기록 · 작업 기록 · 동기화 상태를 모두 지운다.
///
/// 기기 ID(`sync_state`의 `device_id`)와 내려받은 모델 파일의 기록은 남긴다. 계정이 아니라
/// 기기에 딸린 것이기 때문이다. 지운 뒤에는 앱을 다시 열어 화면 상태를 새로 잡아야 한다.
Future<void> wipeLocalData(AppDatabase db) async {
  await db.transaction(() async {
    for (final table in const [
      // 동기화하는 표 9개
      'monthly_summaries',
      'category_rules',
      'recurring_rules',
      'budgets',
      'transactions',
      'categories',
      'accounts',
      'profiles',
      'ledgers',
      // 기기에만 있는 표
      'outbox',
      'sync_conflicts',
      'input_batch_items',
      'input_batches',
    ]) {
      await db.customStatement('DELETE FROM $table');
    }
    await db.customStatement("DELETE FROM sync_state WHERE key <> 'device_id'");
  });
  // 직접 지운 것을 보고 있던 화면에 알린다(앱을 다시 열기 전까지 옛 내용이 남지 않게).
  db.markTablesUpdated(db.allTables);
}

/// 탈퇴: 서버의 계정을 지우고, 기기의 가계부를 지우고, 로그아웃한 뒤 앱을 다시 연다
/// (`docs/SPEC.md` 4.5).
///
/// [deleteOnServer]가 실패하면 그 예외를 그대로 던지고 아무것도 지우지 않는다. 서버에서
/// 지운 뒤의 단계는 실패해도 끝까지 간다. 계정이 이미 없으므로 되돌릴 수 없고, 남은 것은
/// 다음에 로그인할 때 "지우고 받기"로 정리된다.
Future<void> deleteAccountAndLocalData({
  required Future<void> Function() deleteOnServer,
  required AppDatabase db,
  required Future<void> Function() signOut,
  required void Function() restart,
}) async {
  await deleteOnServer();
  try {
    await wipeLocalData(db);
  } on Object {
    // 아래에서 로그아웃하고 다시 연다.
  }
  try {
    // 계정이 이미 지워져 서버가 로그아웃 요청을 거절할 수 있다.
    await signOut();
  } on Object {
    // 다시 열면 세션이 없는 상태로 시작한다.
  }
  restart();
}
