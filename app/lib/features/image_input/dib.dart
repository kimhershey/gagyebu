import 'dart:typed_data';

/// 클립보드에서 받는 이미지의 크기 한도. 4K 화면 캡처(약 33MB)는 들어간다.
const maxClipboardImageBytes = 64 * 1024 * 1024;

/// 클립보드의 그림(DIB: 머리 정보 + 색상표 + 화소)을 BMP 파일 꼴로 만든다.
///
/// BMP 파일은 DIB 앞에 14바이트의 파일 머리가 붙은 것이다. 머리에는 화소가 시작하는 자리를
/// 적어야 해서 머리 정보의 크기, 색 가리개, 색상표의 길이를 읽는다. 꼴이 맞지 않으면 null.
Uint8List? dibToBmp(Uint8List dib) {
  if (dib.length < 40) return null;
  final data = ByteData.sublistView(dib);
  final headerSize = data.getUint32(0, Endian.little);
  if (headerSize < 40 || headerSize > dib.length) return null;
  final bitCount = data.getUint16(14, Endian.little);
  final compression = data.getUint32(16, Endian.little);
  var colorsUsed = data.getUint32(32, Endian.little);
  if (colorsUsed == 0 && bitCount <= 8) colorsUsed = 1 << bitCount;

  // 옛 머리(40바이트)에서는 색 가리개가 머리 뒤에 따로 온다.
  const biBitfields = 3;
  const biAlphaBitfields = 6;
  final masks = headerSize == 40
      ? switch (compression) {
          biBitfields => 12,
          biAlphaBitfields => 16,
          _ => 0,
        }
      : 0;
  const fileHeader = 14;
  final pixels = fileHeader + headerSize + masks + colorsUsed * 4;
  if (pixels > fileHeader + dib.length) return null;

  final bmp = Uint8List(fileHeader + dib.length);
  ByteData.sublistView(bmp)
    ..setUint8(0, 0x42) // 'B'
    ..setUint8(1, 0x4D) // 'M'
    ..setUint32(2, bmp.length, Endian.little)
    ..setUint32(10, pixels, Endian.little);
  bmp.setRange(fileHeader, bmp.length, dib);
  return bmp;
}

/// 바이트의 머리로 알아본 이미지 형식. 이미지가 아니면 null.
String? sniffImageFormat(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) {
    if (bytes.length < at + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[at + i] != magic[i]) return false;
    }
    return true;
  }

  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (starts(const [0xFF, 0xD8, 0xFF])) return 'jpeg';
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'webp';
  }
  if (starts(const [0x42, 0x4D])) return 'bmp';
  if (starts(const [0x47, 0x49, 0x46, 0x38])) return 'gif';
  return null;
}
