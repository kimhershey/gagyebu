import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 다른 앱의 "공유"로 받은 글(`docs/SPEC.md` 7.18).
///
/// Android에서만 받는다. 매니페스트의 `text/plain` SEND 인텐트 필터가 가계부를 공유 대상에
/// 올리고, `MainActivity`가 받은 글을 들고 있다가 이 채널로 넘긴다. 웹과 Windows에서는 아무
/// 일도 하지 않는다.
///
/// 주고받는 말은 둘뿐이다: 기기 쪽이 새 글을 받았다고 `changed`로 알리면, 이쪽이 `take`로
/// 가져간다. 앱을 띄운 공유는 듣기 시작할 때 `take`로 가져간다.
class ShareReceiver {
  ShareReceiver({
    this._channel = const MethodChannel(channelName),
    bool? enabled,
  }) : _enabled = enabled ?? supported;

  static const channelName = 'io.github.kimhershey.gagyebu/share';

  /// 이 플랫폼에서 공유를 받는지.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final MethodChannel _channel;
  final bool _enabled;

  late final StreamController<String> _texts = StreamController<String>(
    onListen: _start,
    onCancel: _stop,
  );

  /// 받은 글. 듣기 시작하면 앱을 띄운 공유(있으면)부터 준다. 한 곳에서만 듣는다.
  Stream<String> get texts => _texts.stream;

  void _start() {
    if (!_enabled) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await _take();
    });
    unawaited(_take());
  }

  void _stop() {
    if (_enabled) _channel.setMethodCallHandler(null);
  }

  Future<void> _take() async {
    try {
      final text = await _channel.invokeMethod<String>('take');
      if (text == null || text.trim().isEmpty || _texts.isClosed) return;
      _texts.add(text);
    } on MissingPluginException {
      // 기기 쪽 코드가 없는 환경(시험, 개발용 실행)이다. 받을 글이 없는 것과 같다.
    } on PlatformException catch (e) {
      debugPrint('공유로 받은 글을 가져오지 못했다: $e');
    }
  }

  /// 더 받지 않는다.
  void dispose() {
    _stop();
    // 듣는 곳이 없으면 닫힘이 끝났다는 알림도 오지 않는다. 기다리지 않는다.
    unawaited(_texts.close());
  }
}
