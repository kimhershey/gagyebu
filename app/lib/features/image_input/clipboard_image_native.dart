import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'dib.dart';

/// 클립보드의 이미지를 읽을 수 있는지. Windows에서만 읽는다.
bool get clipboardImageSupported => Platform.isWindows;

/// 클립보드에 있는 이미지를 BMP 파일 꼴의 바이트로 돌려준다. 이미지가 없으면 null.
///
/// Windows API를 직접 부른다. 클립보드를 읽는 패키지(pasteboard)는 이미지를 임시 파일로
/// 적었다가 읽는데, 원본 이미지를 기기의 저장소에 남기지 않는다는 원칙(`docs/SPEC.md` 1.2)에
/// 어긋나 쓰지 않았다. 여기서는 클립보드의 메모리를 그대로 베낀다.
Uint8List? readClipboardBitmap() {
  if (!Platform.isWindows) return null;
  final user32 = DynamicLibrary.open('user32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final openClipboard = user32
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'OpenClipboard',
      );
  final closeClipboard = user32
      .lookupFunction<Int32 Function(), int Function()>('CloseClipboard');
  final isFormatAvailable = user32
      .lookupFunction<Int32 Function(Uint32), int Function(int)>(
        'IsClipboardFormatAvailable',
      );
  final getClipboardData = user32
      .lookupFunction<
        Pointer<Void> Function(Uint32),
        Pointer<Void> Function(int)
      >('GetClipboardData');
  final globalLock = kernel32
      .lookupFunction<
        Pointer<Uint8> Function(Pointer<Void>),
        Pointer<Uint8> Function(Pointer<Void>)
      >('GlobalLock');
  final globalUnlock = kernel32
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('GlobalUnlock');
  final globalSize = kernel32
      .lookupFunction<
        IntPtr Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('GlobalSize');

  // CF_DIB. 화면 캡처든 복사한 그림이든 Windows가 이 형식으로 바꿔 준다.
  const cfDib = 8;
  if (isFormatAvailable(cfDib) == 0) return null;
  // 다른 프로그램이 클립보드를 쥐고 있으면 열리지 않는다. 그때는 없는 것으로 본다.
  if (openClipboard(0) == 0) return null;
  try {
    // 이 손잡이는 클립보드의 것이라 풀어 주지 않는다.
    final handle = getClipboardData(cfDib);
    if (handle == nullptr) return null;
    final size = globalSize(handle);
    if (size <= 0 || size > maxClipboardImageBytes) return null;
    final locked = globalLock(handle);
    if (locked == nullptr) return null;
    try {
      // 클립보드를 닫으면 메모리가 사라지므로 베껴 둔다.
      return dibToBmp(Uint8List.fromList(locked.asTypedList(size)));
    } finally {
      globalUnlock(handle);
    }
  } finally {
    closeClipboard();
  }
}
