import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 밖에서 입력창에 채워 넣을 글(공유로 받은 글 등). 입력창이 가져가면 비운다.
class IncomingText extends Notifier<String?> {
  @override
  String? build() => null;

  /// 입력창에 채울 글을 올려 둔다.
  void offer(String text) => state = text;

  /// 올려 둔 글을 가져가고 비운다.
  String? take() {
    final text = state;
    state = null;
    return text;
  }
}

final incomingTextProvider = NotifierProvider<IncomingText, String?>(
  IncomingText.new,
);
