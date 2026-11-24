/// CSV를 읽고 쓴다(RFC 4180). 따옴표로 감싼 칸 안의 쉼표 · 따옴표 · 줄바꿈을 지킨다.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';

/// 읽은 CSV: 제목 줄과 그 아래의 줄들.
class CsvTable {
  const CsvTable({
    required this.header,
    required this.rows,
    required this.encoding,
    this.headerLine = 1,
  });

  /// 제목 줄의 칸들.
  final List<String> header;

  /// 제목 줄 아래의 줄들. 빈 줄은 뺐다. 칸 수가 제목 줄과 다를 수 있다.
  final List<List<String>> rows;

  /// 읽을 때 쓴 인코딩의 이름('UTF-8' · 'CP949').
  final String encoding;

  /// 제목 줄이 빈 줄을 뺀 줄들 가운데 몇 번째였는지(1부터). 은행 파일은 표 위에 안내 줄이
  /// 붙기도 한다.
  final int headerLine;

  /// [row]의 [column]번째 칸. 그 칸이 없으면 빈 글이다.
  static String cell(List<String> row, int column) =>
      column < row.length ? row[column] : '';
}

const _bom = [0xEF, 0xBB, 0xBF];

/// 바이트를 글로 바꾼다. UTF-8을 먼저 해 보고, 맞지 않으면 CP949(EUC-KR)로 읽는다.
/// 은행 · 카드사가 주는 CSV는 CP949가 많다. 돌려주는 것은 (글, 인코딩 이름)이다.
(String, String) decodeCsvBytes(Uint8List bytes) {
  var data = bytes;
  if (data.length >= 3 &&
      data[0] == _bom[0] &&
      data[1] == _bom[1] &&
      data[2] == _bom[2]) {
    data = Uint8List.sublistView(data, 3);
  }
  try {
    return (utf8.decode(data), 'UTF-8');
  } on FormatException {
    // 읽지 못하는 글자가 섞여 있어도 나머지는 읽는다.
    return (cp949.decode(data, allowInvalid: true), 'CP949');
  }
}

/// CSV 파일의 바이트를 표로 읽는다. 읽을 줄이 하나도 없으면 [FormatException].
CsvTable parseCsv(Uint8List bytes) {
  final (text, encoding) = decodeCsvBytes(bytes);
  final lines = parseCsvText(text);
  if (lines.isEmpty) throw const FormatException('빈 파일이다');
  final headerIndex = _findHeader(lines);
  return CsvTable(
    header: [for (final cell in lines[headerIndex]) cell.trim()],
    rows: lines.sublist(headerIndex + 1),
    encoding: encoding,
    headerLine: headerIndex + 1,
  );
}

/// 제목 줄을 찾는다.
///
/// 은행 파일은 표 위에 계좌번호 · 조회 기간 같은 안내 줄이 붙는다. 그런 줄은 칸이 적다.
/// 앞쪽 줄들 가운데 채워진 칸이 가장 많은 줄의 70% 이상을 채운 첫 줄을 제목으로 본다.
int _findHeader(List<List<String>> lines) {
  int filled(List<String> line) =>
      line.where((cell) => cell.trim().isNotEmpty).length;
  final head = lines.take(30).toList();
  var widest = 0;
  for (final line in head) {
    final n = filled(line);
    if (n > widest) widest = n;
  }
  final enough = (widest * 0.7).ceil();
  for (var i = 0; i < head.length; i++) {
    if (filled(head[i]) >= enough) return i;
  }
  return 0;
}

/// CSV 글을 줄과 칸으로 나눈다. 칸이 모두 빈 줄은 뺀다.
///
/// 구분자는 첫 줄을 보고 쉼표와 탭 가운데 고른다. 따옴표 안의 줄바꿈은 칸의 내용이다.
List<List<String>> parseCsvText(String text) {
  final delimiter = _detectDelimiter(text);
  final lines = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  // 따옴표로 시작한 칸인지. 닫힌 뒤에 붙은 글자는 그대로 잇는다.
  var wasQuoted = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
    wasQuoted = false;
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) lines.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && cell.isEmpty && !wasQuoted) {
      quoted = true;
      wasQuoted = true;
    } else if (ch == delimiter) {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch == '\r') {
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(ch);
    }
  }
  // 마지막 줄이 줄바꿈 없이 끝났다.
  if (cell.isNotEmpty || row.isNotEmpty || wasQuoted) endRow();
  return lines;
}

/// 첫 줄(따옴표 밖)에 탭이 쉼표보다 많으면 탭으로 나눈다.
String _detectDelimiter(String text) {
  var commas = 0, tabs = 0;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '"') {
      quoted = !quoted;
    } else if (!quoted) {
      if (ch == '\n' || ch == '\r') break;
      if (ch == ',') commas++;
      if (ch == '\t') tabs++;
    }
  }
  return tabs > commas ? '\t' : ',';
}

/// 줄들을 CSV 글로 쓴다. 줄 끝은 CRLF다(Excel과 RFC 4180의 기본).
String encodeCsv(List<List<String>> rows) {
  final buffer = StringBuffer();
  for (final row in rows) {
    buffer
      ..write(row.map(_quote).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}

final _needsQuote = RegExp('[",\r\n\t]|^\\s|\\s\$');

String _quote(String cell) =>
    _needsQuote.hasMatch(cell) ? '"${cell.replaceAll('"', '""')}"' : cell;

/// CSV 글을 Excel이 한글을 바로 여는 바이트로 바꾼다(UTF-8, 앞에 BOM).
Uint8List csvBytes(String csv) =>
    Uint8List.fromList([..._bom, ...utf8.encode(csv)]);
