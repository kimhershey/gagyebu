/// 거래를 파일로 내보낸다(`docs/SPEC.md` 7.16).
library;

import 'dart:typed_data';

import '../../data/repositories/ledger_repository.dart';
import '../../domain/enums.dart';
import 'csv_codec.dart';
import 'xlsx_writer.dart';

/// 내보내는 파일의 형식.
enum ExportFormat {
  csv('CSV', 'csv', 'text/csv'),
  xlsx(
    'Excel',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const ExportFormat(this.label, this.extension, this.mimeType);

  /// 화면에 보이는 이름.
  final String label;

  /// 파일 이름의 확장자(점 없이).
  final String extension;
  final String mimeType;
}

/// 내보내는 파일의 열. 가져오기는 첫 줄이 이것과 같으면 이 앱이 내보낸 파일로 본다.
const exportHeader = [
  '날짜',
  '시각',
  '종류',
  '금액',
  '자산',
  '받는 자산',
  '상대방',
  '분류',
  '메모',
  '할부',
  '취소 여부',
];

/// 취소한 거래의 '취소 여부' 칸에 적는 말.
const canceledMark = '취소';

/// 거래 종류를 파일에 적는 말.
String txTypeLabel(TxType type) => switch (type) {
  TxType.expense => '지출',
  TxType.income => '수입',
  TxType.transfer => '이체',
};

/// 스프레드시트가 수식으로 읽을 수 있는 글 앞에 작은따옴표를 붙인다.
///
/// 결제 문자에서 온 상대방 · 메모가 `=` `+` `-` `@`로 시작하면 Excel이 수식으로 풀어 버린다.
/// 작은따옴표로 시작하는 글에도 하나를 더 붙여서, 가져올 때 맨 앞의 하나만 떼면 원래 글이
/// 되게 한다([unguardCell]).
String guardCell(String text) {
  if (text.isEmpty) return text;
  const risky = ['=', '+', '-', '@', '\t', '\r', "'"];
  return risky.contains(text[0]) ? "'$text" : text;
}

/// [guardCell]이 붙인 작은따옴표를 뗀다.
String unguardCell(String text) =>
    text.startsWith("'") ? text.substring(1) : text;

/// 거래 한 건의 칸들([exportHeader]의 순서). 금액은 숫자, 나머지는 글자다.
List<Object> _cells(TransactionView view, {required bool guard}) {
  final row = view.row;
  String text(String? value) {
    final v = value ?? '';
    return guard ? guardCell(v) : v;
  }

  return [
    row.occurredOn.toString(),
    row.occurredTime ?? '',
    txTypeLabel(row.type),
    row.amount,
    text(view.accountName),
    text(row.type == TxType.transfer ? view.toAccountName : null),
    text(view.counterparty),
    text(view.categoryName),
    text(row.memo),
    row.installmentMonths ?? '',
    view.isCanceled ? canceledMark : '',
  ];
}

/// [rows]를 [format] 파일의 바이트로 만든다. 줄의 순서는 받은 그대로다.
///
/// CSV는 UTF-8에 BOM을 붙여 Excel이 한글을 바로 열게 한다. 수식으로 읽힐 글은 CSV에서만
/// 막는다(xlsx는 글자 칸으로 적혀 수식이 되지 않는다).
Uint8List exportTransactions(List<TransactionView> rows, ExportFormat format) {
  switch (format) {
    case ExportFormat.csv:
      return csvBytes(
        encodeCsv([
          exportHeader,
          for (final view in rows)
            [for (final cell in _cells(view, guard: true)) '$cell'],
        ]),
      );
    case ExportFormat.xlsx:
      return buildXlsx(
        [exportHeader, for (final view in rows) _cells(view, guard: false)],
        sheetName: '거래',
        columnWidths: const [12, 8, 8, 12, 16, 16, 24, 14, 30, 8, 10],
      );
  }
}
