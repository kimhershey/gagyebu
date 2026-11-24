import 'dart:typed_data';

/// 클립보드의 이미지를 읽을 수 없는 환경(웹)의 자리.
bool get clipboardImageSupported => false;

Uint8List? readClipboardBitmap() => null;
