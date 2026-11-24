import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/repositories/input_batch_repository.dart';

/// 되돌린 결과를 알리는 문장(`docs/SPEC.md` 7.7).
String undoResultMessage(UndoResult result) {
  if (result.kept == 0) {
    return result.undone == 0
        ? '되돌릴 거래가 남아 있지 않습니다'
        : '${result.undone}건을 되돌렸습니다';
  }
  if (result.undone == 0) {
    return '되돌린 건이 없습니다. 고친 ${result.kept}건은 남겼습니다';
  }
  return '${result.undone}건을 되돌리고, 고친 ${result.kept}건은 남겼습니다';
}

/// 묶음을 되돌리고 결과를 알린다. 되돌렸으면 결과를, 못 했으면 null을 준다.
///
/// 저장 직후의 알림, 작업 기록 화면, 명령창이 함께 쓴다. 알림의 단추는 그 알림을 띄운
/// 화면이 사라진 뒤에도 눌릴 수 있어서 `ref` 대신 [container]를 받는다.
Future<UndoResult?> undoBatchAndNotify(
  ScaffoldMessengerState messenger,
  ProviderContainer container,
  String batchId,
) async {
  String message;
  UndoResult? result;
  try {
    result = await container.read(inputBatchRepositoryProvider).undo(batchId);
    message = undoResultMessage(result);
  } on BatchAlreadyUndone {
    message = '이미 되돌린 묶음입니다';
  } catch (_) {
    message = '되돌리지 못했습니다. 작업 기록에서 다시 해 보세요';
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return result;
}

/// 마지막으로 저장한 묶음을 되돌린다(명령창과 Ctrl/⌘+Z). 되돌릴 묶음이 없으면 그렇게 알린다.
Future<UndoResult?> undoLastBatch(
  ScaffoldMessengerState messenger,
  ProviderContainer container,
) async {
  final last = await container
      .read(inputBatchRepositoryProvider)
      .lastUndoable(container.read(ledgerIdProvider));
  if (last == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('되돌릴 입력이 없습니다')));
    return null;
  }
  return undoBatchAndNotify(messenger, container, last.id);
}

/// 묶음을 저장한 직후에 "되돌리기"가 달린 알림을 띄운다.
void showBatchSavedNotice(
  ScaffoldMessengerState messenger,
  ProviderContainer container, {
  required String batchId,
  required int count,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('batch-saved'),
        content: Text('$count건을 저장했습니다'),
        // 단추가 달린 알림은 기본이 계속 떠 있는 것이다. 되돌릴 틈만 주고 물러나게 한다.
        persist: false,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          key: const ValueKey('batch-undo'),
          label: '되돌리기',
          onPressed: () => undoBatchAndNotify(messenger, container, batchId),
        ),
      ),
    );
}
