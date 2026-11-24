import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clipboard_image_stub.dart'
    if (dart.library.io) 'clipboard_image_native.dart'
    as clipboard;

/// 화면에 들어온 이미지 한 장. 바이트는 메모리에만 둔다.
class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  /// 대기열에 보이는 이름(파일 이름, '붙여넣은 이미지').
  final String name;
  final Uint8List bytes;
}

/// 이미지를 들여오는 길: 파일 고르기와 클립보드.
///
/// 운영체제에 닿는 부분이라 시험에서는 가짜로 바꾼다. 창에 끌어놓은 파일은 화면이 받아
/// 바로 대기열에 넣는다.
abstract interface class ImageIntake {
  /// 클립보드의 이미지를 읽을 수 있는 기기인지. 아니면 붙여넣기 단추를 숨긴다.
  bool get canReadClipboard;

  /// 파일 고르기 창을 띄운다. 그냥 닫으면 빈 목록이다.
  Future<List<PickedImage>> pickFiles();

  /// 클립보드에 있는 이미지. 없으면 null.
  Future<PickedImage?> readClipboard();
}

/// 고를 수 있는 파일의 확장자.
const imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'bmp'];

class PlatformImageIntake implements ImageIntake {
  const PlatformImageIntake();

  @override
  bool get canReadClipboard => clipboard.clipboardImageSupported;

  @override
  Future<List<PickedImage>> pickFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '이미지',
          extensions: imageExtensions,
          mimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/bmp'],
        ),
      ],
    );
    return [
      for (final file in files)
        PickedImage(name: file.name, bytes: await file.readAsBytes()),
    ];
  }

  @override
  Future<PickedImage?> readClipboard() async {
    final bitmap = clipboard.readClipboardBitmap();
    if (bitmap == null) return null;
    // 클립보드의 그림은 BMP 꼴이다. 엔진이 어떤 형식을 받는지 알 수 없어 PNG로 바꿔 넘긴다.
    final png = await _encodePng(bitmap);
    return png == null ? null : PickedImage(name: '붙여넣은 이미지', bytes: png);
  }
}

Future<Uint8List?> _encodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

final imageIntakeProvider = Provider<ImageIntake>(
  (ref) => const PlatformImageIntake(),
);
