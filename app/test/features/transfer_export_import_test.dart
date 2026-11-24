import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/transfer/csv_codec.dart';
import 'package:gagyebu/features/transfer/export.dart';
import 'package:gagyebu/features/transfer/export_queries.dart';
import 'package:gagyebu/features/transfer/import_mapping.dart';

/// 압축하지 않은 ZIP에서 파일 이름 → 내용을 꺼낸다(시험용).
Map<String, Uint8List> unzipStored(Uint8List zip) {
  final data = ByteData.sublistView(zip);
  final end = zip.length - 22;
  expect(data.getUint32(end, Endian.little), 0x06054b50, reason: 'ZIP의 끝 표시');
  final count = data.getUint16(end + 10, Endian.little);
  var offset = data.getUint32(end + 16, Endian.little);
  final files = <String, Uint8List>{};
  for (var i = 0; i < count; i++) {
    expect(data.getUint32(offset, Endian.little), 0x02014b50);
    expect(data.getUint16(offset + 10, Endian.little), 0, reason: '압축 안 함');
    final size = data.getUint32(offset + 24, Endian.little);
    final nameLength = data.getUint16(offset + 28, Endian.little);
    final local = data.getUint32(offset + 42, Endian.little);
    final name = utf8.decode(
      zip.sublist(offset + 46, offset + 46 + nameLength),
    );
    expect(data.getUint32(local, Endian.little), 0x04034b50);
    final localNameLength = data.getUint16(local + 26, Endian.little);
    final start = local + 30 + localNameLength;
    files[name] = zip.sublist(start, start + size);
    offset += 46 + nameLength;
  }
  return files;
}

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String ledgerId;
  late String cash;
  late String card;
  late String food;
  late String salary;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LedgerRepository(db, clock: () => DateTime(2026, 11, 17, 12));
    ledgerId = await repo.ensureLocalLedger();
    cash = (await repo.accounts(ledgerId)).single.id;
    card = await repo.addAccount(
      ledgerId: ledgerId,
      name: '신한, 체크카드',
      kind: AccountKind.checkCard,
    );
    final categories = await repo.categories(ledgerId);
    food = categories.firstWhere((c) => c.name == '식비').id;
    salary = categories.firstWhere((c) => c.name == '급여').id;
  });
  tearDown(() => db.close());

  Future<List<TransactionView>> allRows() => repo.transactionsBetween(
    ledgerId,
    from: LocalDate(2000, 1, 1),
    toExclusive: LocalDate(2100, 1, 1),
  );

  /// 종류 · 취소 · 할부 · 까다로운 글자를 고루 넣는다.
  Future<void> addVariety() async {
    Future<void> add(TransactionInput input) =>
        repo.addTransaction(ledgerId, input);
    await add(
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 1),
        occurredTime: '08:05',
        amount: 4500,
        accountId: card,
        counterparty: '스타벅스, 강남점',
        categoryId: food,
        memo: '그가 "좋다"고 했다',
      ),
    );
    await add(
      TransactionInput(
        type: TxType.income,
        occurredOn: LocalDate(2026, 11, 2),
        amount: 2500000,
        accountId: cash,
        counterparty: '(주)회사',
        categoryId: salary,
      ),
    );
    await add(
      TransactionInput(
        type: TxType.transfer,
        occurredOn: LocalDate(2026, 11, 3),
        amount: 100000,
        accountId: cash,
        toAccountId: card,
        memo: '카드값\n두 줄 메모',
      ),
    );
    await add(
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 4),
        occurredTime: '23:59',
        amount: 1200000,
        accountId: card,
        counterparty: '=HYPERLINK("http://x")',
        memo: "'작은따옴표로 시작",
        installmentMonths: 12,
      ),
    );
    await add(
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 5),
        amount: 30000,
        accountId: cash,
        counterparty: '-할인마트',
        memo: '+1 행사, @집',
        canceled: true,
      ),
    );
    await add(
      TransactionInput(
        type: TxType.expense,
        occurredOn: LocalDate(2026, 11, 6),
        amount: 800,
        accountId: cash,
      ),
    );
  }

  ImportedRow expected(TransactionView view) => ImportedRow(
    date: view.row.occurredOn,
    time: view.row.occurredTime,
    type: view.row.type,
    amount: view.row.amount,
    accountName: view.accountName,
    toAccountName: view.toAccountName,
    counterparty: view.counterparty,
    categoryName: view.categoryName,
    memo: view.row.memo,
    installmentMonths: view.row.installmentMonths,
    canceled: view.isCanceled,
  );

  group('내보내기', () {
    test('CSV는 BOM으로 시작하고 열이 설계서의 순서다', () async {
      await addVariety();
      final bytes = exportTransactions(await allRows(), ExportFormat.csv);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final lines = parseCsvText(utf8.decode(bytes.sublist(3)));
      expect(lines.first, [
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
      ]);
      expect(lines, hasLength(7));
      expect(lines[1], [
        '2026-11-01',
        '08:05',
        '지출',
        '4500',
        '신한, 체크카드',
        '',
        '스타벅스, 강남점',
        '식비',
        '그가 "좋다"고 했다',
        '',
        '',
      ]);
      expect(lines[3].sublist(2, 6), ['이체', '100000', '현금', '신한, 체크카드']);
      expect(lines[4][9], '12');
      expect(lines[5][10], '취소');
    });

    test('수식으로 읽힐 글 앞에는 작은따옴표를 붙인다', () async {
      await addVariety();
      final bytes = exportTransactions(await allRows(), ExportFormat.csv);
      final lines = parseCsvText(utf8.decode(bytes.sublist(3)));
      expect(lines[4][6], '\'=HYPERLINK("http://x")');
      expect(lines[4][8], "''작은따옴표로 시작");
      expect(lines[5][6], "'-할인마트");
      expect(lines[5][8], "'+1 행사, @집");
      expect(guardCell('@집'), "'@집");
      expect(guardCell('보통 글'), '보통 글');
      expect(unguardCell(guardCell("'x")), "'x");
    });

    test('거래가 없으면 제목 줄만 있다', () {
      final bytes = exportTransactions(const [], ExportFormat.csv);
      expect(parseCsv(bytes).header, exportHeader);
      expect(parseCsv(bytes).rows, isEmpty);
    });

    test('Excel 파일은 시트 하나에 금액을 숫자로, 나머지를 글자로 담는다', () async {
      await addVariety();
      final bytes = exportTransactions(await allRows(), ExportFormat.xlsx);
      // ZIP 파일이다.
      expect(bytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
      final files = unzipStored(bytes);
      expect(files.keys, [
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/worksheets/sheet1.xml',
      ]);
      expect(utf8.decode(files['xl/workbook.xml']!), contains('name="거래"'));
      final sheet = utf8.decode(files['xl/worksheets/sheet1.xml']!);
      expect(sheet, contains('<c r="A1" t="inlineStr">'));
      expect(sheet, contains('>취소 여부</t>'));
      expect(sheet, contains('<c r="D2"><v>4500</v></c>'));
      expect(sheet, contains('<c r="J5"><v>12</v></c>'));
      // XML에서 뜻이 있는 글자는 바꿔 적는다. 수식을 막는 작은따옴표는 붙이지 않는다.
      expect(sheet, contains('>그가 &quot;좋다&quot;고 했다</t>'));
      expect(sheet, contains('>=HYPERLINK(&quot;http://x&quot;)</t>'));
      expect(sheet, contains('>카드값\n두 줄 메모</t>'));
      expect(sheet, isNot(contains('<f>')));
      // 빈 칸은 적지 않는다.
      expect(sheet, isNot(contains('r="B3"')));
    });
  });

  group('내보낸 CSV 다시 가져오기', () {
    test('같은 거래가 된다', () async {
      await addVariety();
      final rows = await allRows();
      final table = parseCsv(exportTransactions(rows, ExportFormat.csv));
      final mapping = guessMapping(table.header);
      expect(mapping.ownFormat, isTrue);
      expect(mapping.isComplete, isTrue);

      final result = mapRows(table, mapping);
      expect(result.skipped, isEmpty);
      expect(result.overLimit, 0);
      expect(result.rows, [for (final view in rows) expected(view)]);
      // 까다로운 값이 그대로 돌아왔는지 몇 개를 직접 본다.
      expect(result.rows[0].counterparty, '스타벅스, 강남점');
      expect(result.rows[0].memo, '그가 "좋다"고 했다');
      expect(result.rows[2].type, TxType.transfer);
      expect(result.rows[2].toAccountName, '신한, 체크카드');
      expect(result.rows[2].memo, '카드값\n두 줄 메모');
      expect(result.rows[3].counterparty, '=HYPERLINK("http://x")');
      expect(result.rows[3].memo, "'작은따옴표로 시작");
      expect(result.rows[3].installmentMonths, 12);
      expect(result.rows[4].canceled, isTrue);
      expect(result.rows[4].counterparty, '-할인마트');
      expect(result.rows[5].counterparty, isNull);
    });

    test('CP949로 다시 저장한 파일도 같은 거래가 된다', () async {
      await addVariety();
      final rows = await allRows();
      final utf8Bytes = exportTransactions(rows, ExportFormat.csv);
      // Excel에서 열어 'CSV(쉼표로 분리)'로 저장하면 CP949가 된다.
      final text = utf8.decode(utf8Bytes.sublist(3));
      final table = parseCsv(cp949.encode(text));
      expect(table.encoding, 'CP949');
      final result = mapRows(table, guessMapping(table.header));
      expect(result.rows, [for (final view in rows) expected(view)]);
    });
  });

  group('열 맞추기', () {
    test('은행 파일: 출금 · 입금이 다른 열이면 둘 다 맞춘다', () {
      final mapping = guessMapping(['거래일시', '적요', '출금금액', '입금금액', '잔액', '메모']);
      expect(mapping.ownFormat, isFalse);
      expect(mapping[ImportField.date], 0);
      expect(mapping[ImportField.counterparty], 1);
      expect(mapping[ImportField.expense], 2);
      expect(mapping[ImportField.income], 3);
      expect(mapping[ImportField.amount], isNull);
      expect(mapping[ImportField.memo], 5);
      expect(mapping.isComplete, isTrue);
    });

    test('카드 파일: 금액 열 하나', () {
      final mapping = guessMapping([
        '이용일',
        '이용시간',
        '가맹점명',
        '이용금액',
        '할부개월',
        '취소여부',
      ]);
      expect(mapping[ImportField.date], 0);
      expect(mapping[ImportField.time], 1);
      expect(mapping[ImportField.counterparty], 2);
      expect(mapping[ImportField.amount], 3);
      expect(mapping[ImportField.expense], isNull);
      expect(mapping[ImportField.installment], 4);
      expect(mapping[ImportField.canceled], 5);
      expect(mapping.isComplete, isTrue);
    });

    test("'입금/출금 구분' 열은 금액이 아니라 종류다", () {
      final mapping = guessMapping(['날짜', '내용', '금액', '입금/출금 구분']);
      expect(mapping[ImportField.amount], 2);
      expect(mapping[ImportField.type], 3);
      expect(mapping[ImportField.expense], isNull);
      expect(mapping[ImportField.income], isNull);
    });

    test('모르는 제목이면 맞추지 않고, 무엇이 빠졌는지 알린다', () {
      final mapping = guessMapping(['A', 'B', 'C']);
      expect(mapping.columns, isEmpty);
      expect(mapping.isComplete, isFalse);
      expect(mapping.missing, ['날짜', '금액(또는 출금 · 입금 두 열)', '내용']);

      final withDate = mapping
          .withField(ImportField.date, 0)
          .withField(ImportField.counterparty, 1)
          .withField(ImportField.expense, 2);
      // 출금만 맞추면 모자란다. 입금까지 맞추거나 금액 한 열을 맞춰야 한다.
      expect(withDate.missing, ['금액(또는 출금 · 입금 두 열)']);
      expect(withDate.withField(ImportField.income, 2).isComplete, isTrue);
      expect(
        withDate
            .withField(ImportField.expense, null)
            .withField(ImportField.amount, 2)
            .isComplete,
        isTrue,
      );
    });

    test('덜 맞춘 채로는 읽지 않는다', () {
      const table = CsvTable(header: ['a'], rows: [], encoding: 'UTF-8');
      expect(
        () => mapRows(table, const ColumnMapping({})),
        throwsArgumentError,
      );
    });

    test('은행 파일의 줄을 수입과 지출로 가른다', () {
      const table = CsvTable(
        header: ['거래일시', '적요', '출금금액', '입금금액', '잔액'],
        rows: [
          ['2026.11.16 12:30:45', '체크카드 김밥천국', '8,000', '0', '1,234,000'],
          ['2026.11.17 09:00:00', '급여', '', '2,500,000원', '3,734,000'],
          ['2026/11/18', '이자', '0', '12', ''],
          ['합계', '', '8,000', '2,500,012', ''],
          ['2026-11-19', '둘 다', '100', '200', ''],
          ['2026-11-20', '금액 없음', '', '', ''],
          ['2026-02-30', '없는 날짜', '100', '', ''],
        ],
        encoding: 'CP949',
      );
      final result = mapRows(table, guessMapping(table.header));
      expect(result.rows, [
        ImportedRow(
          date: LocalDate(2026, 11, 16),
          time: '12:30',
          type: TxType.expense,
          amount: 8000,
          counterparty: '체크카드 김밥천국',
        ),
        ImportedRow(
          date: LocalDate(2026, 11, 17),
          time: '09:00',
          type: TxType.income,
          amount: 2500000,
          counterparty: '급여',
        ),
        ImportedRow(
          date: LocalDate(2026, 11, 18),
          type: TxType.income,
          amount: 12,
          counterparty: '이자',
        ),
      ]);
      expect(
        [for (final s in result.skipped) (s.line, s.reason)],
        [
          (4, '날짜를 읽지 못했습니다'),
          (5, '출금과 입금이 함께 적혀 있습니다'),
          (6, '금액을 읽지 못했습니다'),
          (7, '날짜를 읽지 못했습니다'),
        ],
      );
    });

    test('금액 열이 하나면 종류 열이나 부호로 가른다', () {
      const table = CsvTable(
        header: ['이용일', '가맹점명', '이용금액', '할부', '구분'],
        rows: [
          ['26.11.16', '김밥천국', '8,000', '일시불', ''],
          ['2026년 11월 17일', '가전', '1200000', '12개월', '승인'],
          ['20261118', '환불', '-5,000', '', ''],
          ['2026-11-19', '급여', '(3,000)', '', '입금'],
          ['2026-11-20', '저축', '50000', '', '이체'],
          ['2026-11-21', '0원', '0', '', ''],
        ],
        encoding: 'UTF-8',
      );
      final rows = mapRows(table, guessMapping(table.header)).rows;
      expect(
        [for (final r in rows) (r.date.toString(), r.type, r.amount)],
        [
          ('2026-11-16', TxType.expense, 8000),
          ('2026-11-17', TxType.expense, 1200000),
          // 음수는 취소 · 환불이다. 수입으로 적는다.
          ('2026-11-18', TxType.income, 5000),
          ('2026-11-19', TxType.income, 3000),
          ('2026-11-20', TxType.transfer, 50000),
        ],
      );
      expect(rows[0].installmentMonths, isNull);
      expect(rows[1].installmentMonths, 12);
    });

    test('한 번에 2,000건까지만 읽고 남은 줄 수를 알린다', () {
      final table = CsvTable(
        header: const ['날짜', '내용', '금액'],
        rows: [
          for (var i = 0; i < 2105; i++) ['2026-11-16', '가게 $i', '${i + 1}'],
        ],
        encoding: 'UTF-8',
      );
      final result = mapRows(table, guessMapping(table.header));
      expect(importLimit, 2000);
      expect(result.rows, hasLength(2000));
      expect(result.rows.last.counterparty, '가게 1999');
      expect(result.overLimit, 105);
    });
  });

  group('값 읽기', () {
    test('날짜', () {
      LocalDate? date(String text) => parseImportDate(text).$1;
      expect(date('2026-11-16'), LocalDate(2026, 11, 16));
      expect(date('2026.11.6'), LocalDate(2026, 11, 6));
      expect(date('2026. 11. 16.'), LocalDate(2026, 11, 16));
      expect(date('2026/1/2'), LocalDate(2026, 1, 2));
      expect(date('20261116'), LocalDate(2026, 11, 16));
      expect(date('2026년 11월 16일'), LocalDate(2026, 11, 16));
      expect(date('26-11-16'), LocalDate(2026, 11, 16));
      expect(date('11/16/2026'), isNull);
      expect(date('합계'), isNull);
      expect(date(''), isNull);
      expect(parseImportDate('2026-11-16 오후 3:07'), (
        LocalDate(2026, 11, 16),
        '15:07',
      ));
    });

    test('시각', () {
      expect(parseImportTime('9:05'), '09:05');
      expect(parseImportTime('23:59:59'), '23:59');
      expect(parseImportTime('오전 12:10'), '00:10');
      expect(parseImportTime('25:00'), isNull);
      expect(parseImportTime(''), isNull);
    });

    test('금액', () {
      expect(parseImportAmount('8,000'), 8000);
      expect(parseImportAmount('8,000원'), 8000);
      expect(parseImportAmount('₩ 1,234'), 1234);
      expect(parseImportAmount(r'\1,234'), 1234);
      expect(parseImportAmount('-500'), -500);
      expect(parseImportAmount('(500)'), -500);
      expect(parseImportAmount('+500'), 500);
      expect(parseImportAmount('1000.00'), 1000);
      expect(parseImportAmount(''), isNull);
      expect(parseImportAmount('USD 12'), isNull);
      expect(parseImportAmount('없음'), isNull);
    });

    test('종류와 취소 여부', () {
      expect(parseImportType('지출'), TxType.expense);
      expect(parseImportType('입금'), TxType.income);
      expect(parseImportType('계좌이체'), TxType.transfer);
      expect(parseImportType('Income'), TxType.income);
      expect(parseImportType('기타'), isNull);
      expect(parseImportCanceled('취소'), isTrue);
      expect(parseImportCanceled('승인취소'), isTrue);
      expect(parseImportCanceled('Y'), isTrue);
      expect(parseImportCanceled(''), isFalse);
      expect(parseImportCanceled('N'), isFalse);
    });
  });

  test('가계부에 없는 자산 · 분류 이름을 처음 나온 순서대로 모은다', () {
    ImportedRow row(
      TxType type, {
      String? account,
      String? to,
      String? category,
    }) => ImportedRow(
      date: LocalDate(2026, 11, 16),
      type: type,
      amount: 1,
      accountName: account,
      toAccountName: to,
      categoryName: category,
    );
    final missing = findMissingNames(
      [
        row(TxType.expense, account: '현금', category: '식비'),
        row(TxType.expense, account: '새 카드', category: '반려동물'),
        row(TxType.income, account: '월급 통장', category: '부수입'),
        row(TxType.income, account: '월급 통장', category: '반려동물'),
        row(TxType.transfer, account: '현금', to: '적금', category: '이체 분류'),
        row(TxType.expense),
      ],
      accountNames: ['현금'],
      categoryNames: ['식비', '급여'],
    );
    expect(missing.accounts, ['새 카드', '월급 통장', '적금']);
    expect(missing.categories, {
      '반려동물': CategoryKind.expense,
      '부수입': CategoryKind.income,
    });
    expect(missing.isEmpty, isFalse);
    expect(
      findMissingNames(
        [row(TxType.expense, account: '현금')],
        accountNames: ['현금'],
        categoryNames: const [],
      ).isEmpty,
      isTrue,
    );
  });
}
