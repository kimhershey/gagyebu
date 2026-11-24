import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 입력창에 초점을 달라는 신호. 숫자가 오를 때마다 입력창이 초점을 잡는다.
///
/// 입력창은 다른 폴더의 것이라 직접 부르지 않고, 입력창이 이 값을 듣게 한다
/// (`ref.listen(composerFocusRequestProvider, (_, _) => focusNode.requestFocus())`).
class ComposerFocusRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final composerFocusRequestProvider =
    NotifierProvider<ComposerFocusRequest, int>(ComposerFocusRequest.new);

/// 내역 화면의 검색 칸에 초점을 달라는 신호.
///
/// 내역 화면은 신호를 올린 뒤에야 처음 그려질 수 있다. 그래서 숫자를 올리지 않고
/// "아직 가져가지 않은 요청"으로 둔다: 내역 화면이 그려질 때와 값이 바뀔 때 [take]로
/// 가져가고, true면 검색 칸에 초점을 준다.
class TransactionSearchFocusRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  /// 요청이 있었는지 돌려주고 비운다.
  bool take() {
    final requested = state;
    if (requested) state = false;
    return requested;
  }
}

final transactionSearchFocusRequestProvider =
    NotifierProvider<TransactionSearchFocusRequest, bool>(
      TransactionSearchFocusRequest.new,
    );

/// 마지막 입력 묶음을 되돌린다. 사용자에게 알릴 말을 돌려준다
/// ("3건을 되돌리고, 고친 1건은 남겼습니다"). 알릴 말이 없으면 null.
typedef UndoLastBatch = Future<String?> Function();

/// 마지막 입력 묶음 되돌리기(`docs/SPEC.md` 7.7). 되돌리기 저장소가 생기면 그 구현으로
/// 덮어쓴다. null인 동안에는 명령과 단축키(Ctrl/⌘+Z)를 숨긴다.
final undoLastBatchProvider = Provider<UndoLastBatch?>((ref) => null);
