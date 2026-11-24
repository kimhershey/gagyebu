/// 시트 하나짜리 Excel 파일(.xlsx)을 만든다.
///
/// xlsx는 XML 파일 몇 개를 ZIP으로 묶은 것이다. 내보내기에 필요한 것은 글자와 숫자가 든 표
/// 하나뿐이라, 스프레드시트 패키지를 들이지 않고 여기서 직접 쓴다(검토한 패키지는 웹에서
/// `dart:html`에 기대고 있었다). 압축하지 않고 담는다. 가계부 몇 해치도 몇 MB를 넘지 않는다.
library;

import 'dart:convert';
import 'dart:typed_data';

/// [rows]를 시트 [sheetName]에 담은 xlsx 파일의 바이트.
///
/// 칸의 값이 [num]이면 숫자로, 그 밖에는 글자로 쓴다. null은 빈 칸이다.
/// [columnWidths]는 열의 너비(글자 수)다.
Uint8List buildXlsx(
  List<List<Object?>> rows, {
  String sheetName = 'Sheet1',
  List<double> columnWidths = const [],
}) {
  final sheet = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
  if (columnWidths.isNotEmpty) {
    sheet.write('<cols>');
    for (var i = 0; i < columnWidths.length; i++) {
      sheet.write(
        '<col min="${i + 1}" max="${i + 1}" width="${columnWidths[i]}" '
        'customWidth="1"/>',
      );
    }
    sheet.write('</cols>');
  }
  sheet.write('<sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final value = row[c];
      if (value == null || value == '') continue;
      final ref = '${_columnName(c)}${r + 1}';
      if (value is num && value.isFinite) {
        sheet.write('<c r="$ref"><v>$value</v></c>');
      } else {
        // 글자는 그 칸에 바로 적는다(공유 문자열 표를 따로 두지 않는다).
        sheet.write(
          '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
          '${_escapeXml('$value')}</t></is></c>',
        );
      }
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  const xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  final files = <String, String>{
    '[Content_Types].xml':
        '$xmlHead'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '</Types>',
    '_rels/.rels':
        '$xmlHead'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml':
        '$xmlHead'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="${_escapeXml(_sheetName(sheetName))}" sheetId="1" r:id="rId1"/></sheets>'
        '</workbook>',
    'xl/_rels/workbook.xml.rels':
        '$xmlHead'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '</Relationships>',
    'xl/worksheets/sheet1.xml': sheet.toString(),
  };
  return _zipStored({
    for (final entry in files.entries) entry.key: utf8.encode(entry.value),
  });
}

/// 0 → 'A', 25 → 'Z', 26 → 'AA'
String _columnName(int index) {
  var n = index + 1;
  final letters = <int>[];
  while (n > 0) {
    final rem = (n - 1) % 26;
    letters.insert(0, 0x41 + rem);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(letters);
}

/// 시트 이름에 쓸 수 없는 글자를 빼고 31자로 자른다.
String _sheetName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  if (cleaned.isEmpty) return 'Sheet1';
  return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
}

/// XML에 쓸 수 없는 제어 문자를 빼고 `& < > "`를 바꿔 적는다.
String _escapeXml(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    switch (rune) {
      case 0x26:
        buffer.write('&amp;');
      case 0x3C:
        buffer.write('&lt;');
      case 0x3E:
        buffer.write('&gt;');
      case 0x22:
        buffer.write('&quot;');
      case 0x09 || 0x0A || 0x0D:
        buffer.writeCharCode(rune);
      default:
        final allowed =
            (rune >= 0x20 && rune <= 0xD7FF) ||
            (rune >= 0xE000 && rune <= 0xFFFD) ||
            rune >= 0x10000;
        if (allowed) buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// 파일들을 압축 없이(stored) ZIP으로 묶는다.
Uint8List _zipStored(Map<String, List<int>> files) {
  final out = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  var count = 0;
  // 날짜는 고정한다(1980-01-01). 같은 내용이면 같은 파일이 나온다.
  const dosTime = 0, dosDate = 0x21;

  files.forEach((name, data) {
    final nameBytes = utf8.encode(name);
    final crc = _crc32(data);
    final offset = out.length;

    final local = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little) // 풀 때 필요한 버전 2.0
      ..setUint16(6, 0x0800, Endian.little) // 이름은 UTF-8
      ..setUint16(8, 0, Endian.little) // 압축 안 함
      ..setUint16(10, dosTime, Endian.little)
      ..setUint16(12, dosDate, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, data.length, Endian.little)
      ..setUint32(22, data.length, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    out
      ..add(local.buffer.asUint8List())
      ..add(nameBytes)
      ..add(data);

    final entry = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, dosTime, Endian.little)
      ..setUint16(14, dosDate, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(entry.buffer.asUint8List())
      ..add(nameBytes);
    count++;
  });

  final centralBytes = central.takeBytes();
  final centralOffset = out.length;
  final end = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, count, Endian.little)
    ..setUint16(10, count, Endian.little)
    ..setUint32(12, centralBytes.length, Endian.little)
    ..setUint32(16, centralOffset, Endian.little);
  out
    ..add(centralBytes)
    ..add(end.buffer.asUint8List());
  return out.takeBytes();
}

final List<int> _crcTable = () {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
}();

/// ZIP이 쓰는 CRC-32.
int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
