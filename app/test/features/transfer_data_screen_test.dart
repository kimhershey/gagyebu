import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/core/local_date.dart';
import 'package:gagyebu/data/repositories/ledger_repository.dart';
import 'package:gagyebu/domain/enums.dart';
import 'package:gagyebu/features/transfer/csv_codec.dart';
import 'package:gagyebu/features/transfer/export.dart';
import 'package:gagyebu/features/transfer/export_queries.dart';
import 'package:gagyebu/features/transfer/file_access.dart';
import 'package:gagyebu/features/transfer/import_mapping.dart';

import 'settings_harness.dart';

/// 저장하라고 받은 파일.
typedef Saved = ({String fileName, String mimeType, Uint8List bytes});

void main() {
  late List<Saved> saved;

  setUp(() => saved = []);

  Override saver({String? result = '/내려받기'}) =>
      fileSaverProvider.overrideWithValue(({
        required fileName,
        required mimeType,
        required bytes,
      }) async {
        saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes));
        return result;
      });

  Override picker(String name, List<int> bytes) =>
      filePickerProvider.overrideWithValue(
        () async => PickedFile(name: name, bytes: Uint8List.fromList(bytes)),
      );

  Future<void> open(
    WidgetTester tester,
    AppServices services, {
    Size size = desktop,
    double textScale = 1,
    List<Override> overrides = const [],
  }) => pumpAppWith(
    tester,
    services,
    size: size,
    textScale: textScale,
    location: '/settings/data',
    overrides: overrides,
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await scrollSubScreenTo(tester, target);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> addTx(
    AppServices services, {
    required LocalDate date,
    required int amount,
    String party = '김밥천국',
    TxType type = TxType.expense,
  }) async {
    final repo = services.repository;
    final cash = (await repo.accounts(services.ledgerId)).first.id;
    await repo.addTransaction(
      services.ledgerId,
      TransactionInput(
        type: type,
        occurredOn: date,
        amount: amount,
        accountId: cash,
        counterparty: party,
      ),
    );
  }

  List<int> csv(List<List<String>> rows) => utf8.encode(encodeCsv(rows));

  group('내보내기', () {
    testWidgets('보고 있는 달의 거래를 오래된 것부터 CSV로 저장한다', (tester) async {
      final services = await createTestServices();
      await addTx(services, date: LocalDate(2026, 11, 16), amount: 8000);
      await addTx(
        services,
        date: LocalDate(2026, 11, 3),
        amount: 4500,
        party: '카페',
      );
      // 다른 달의 거래는 들어가지 않는다.
      await addTx(services, date: LocalDate(2026, 10, 30), amount: 999);
      await open(tester, services, overrides: [saver()]);

      await tapKey(tester, 'export-run');
      final file = saved.single;
      expect(file.fileName, '가계부_2026-11-01_2026-11-30.csv');
      expect(file.mimeType, 'text/csv');
      final table = parseCsv(file.bytes);
      expect(table.header, exportHeader);
      expect([for (final row in table.rows) row[6]], ['카페', '김밥천국']);
      expect(find.text('거래 2건을 저장했습니다: /내려받기'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('전체 기간을 Excel 파일로 저장한다', (tester) async {
      final services = await createTestServices();
      await addTx(services, date: LocalDate(2026, 11, 16), amount: 8000);
      await addTx(services, date: LocalDate(2025, 3, 1), amount: 999);
      await open(tester, services, overrides: [saver()]);

      await tapKey(tester, 'export-range-all');
      await tapKey(tester, 'export-format-xlsx');
      await tapKey(tester, 'export-run');
      final file = saved.single;
      expect(file.fileName, '가계부_전체.xlsx');
      expect(file.mimeType, ExportFormat.xlsx.mimeType);
      expect(file.bytes.sublist(0, 2), [0x50, 0x4B]);
      expect(find.textContaining('거래 2건을 저장했습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('올해만 고를 수 있다', (tester) async {
      final services = await createTestServices();
      await addTx(services, date: LocalDate(2026, 1, 2), amount: 100);
      await addTx(services, date: LocalDate(2025, 12, 31), amount: 200);
      await open(tester, services, overrides: [saver()]);
      await tapKey(tester, 'export-range-year');
      await tapKey(tester, 'export-run');
      expect(saved.single.fileName, '가계부_2026.csv');
      expect(parseCsv(saved.single.bytes).rows.single[3], '100');
      await disposeApp(tester, services);
    });

    testWidgets('거래가 없는 기간이면 파일을 만들지 않고 알린다', (tester) async {
      final services = await createTestServices();
      await open(tester, services, overrides: [saver()]);
      await tapKey(tester, 'export-run');
      expect(saved, isEmpty);
      expect(find.text('이 기간에는 내보낼 거래가 없습니다.'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('저장할 곳을 고르다 그만두면 저장하지 않았다고 알린다', (tester) async {
      final services = await createTestServices();
      await addTx(services, date: LocalDate(2026, 11, 16), amount: 8000);
      await open(tester, services, overrides: [saver(result: null)]);
      await tapKey(tester, 'export-run');
      expect(find.text('저장하지 않았습니다.'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('저장에 실패하면 예외 문구 대신 할 일을 알린다', (tester) async {
      final services = await createTestServices();
      await addTx(services, date: LocalDate(2026, 11, 16), amount: 8000);
      await open(
        tester,
        services,
        overrides: [
          fileSaverProvider.overrideWithValue(
            ({required fileName, required mimeType, required bytes}) async =>
                throw StateError('FileSystemException: 권한 없음'),
          ),
        ],
      );
      await tapKey(tester, 'export-run');
      expect(find.textContaining('파일을 저장하지 못했습니다'), findsOneWidget);
      expect(find.textContaining('FileSystemException'), findsNothing);
      await disposeApp(tester, services);
    });
  });

  group('가져오기', () {
    /// 이 앱이 내보낸 파일: 거래 세 건.
    Future<Uint8List> ownFile() async {
      final services = await createTestServices();
      final repo = services.repository;
      final card = await repo.addAccount(
        ledgerId: services.ledgerId,
        name: '새 카드',
        kind: AccountKind.creditCard,
      );
      final pets = await repo.addCategory(
        ledgerId: services.ledgerId,
        kind: CategoryKind.expense,
        name: '반려동물',
      );
      await repo.addTransaction(
        services.ledgerId,
        TransactionInput(
          type: TxType.expense,
          occurredOn: LocalDate(2026, 11, 3),
          amount: 32000,
          accountId: card,
          counterparty: '동물병원',
          categoryId: pets,
        ),
      );
      await addTx(services, date: LocalDate(2026, 11, 16), amount: 8000);
      await addTx(
        services,
        date: LocalDate(2026, 11, 17),
        amount: 2500000,
        party: '회사',
        type: TxType.income,
      );
      final rows = await repo.transactionsBetween(
        services.ledgerId,
        from: LocalDate(2026, 1, 1),
        toExclusive: LocalDate(2027, 1, 1),
      );
      // 화면이 쓸 DB를 열기 전에 닫는다.
      await services.db.close();
      return exportTransactions(rows, ExportFormat.csv);
    }

    testWidgets('이 앱이 내보낸 파일은 열을 맞추지 않고 바로 읽는다', (tester) async {
      final bytes = await ownFile();
      final services = await createTestServices();
      await open(
        tester,
        services,
        overrides: [
          picker('가계부_11월.csv', bytes),
          importSinkProvider.overrideWithValue(null),
        ],
      );

      await tapKey(tester, 'import-pick');
      expect(find.text('가계부_11월.csv · UTF-8 · 3줄'), findsOneWidget);
      expect(find.byKey(const ValueKey('import-own-format')), findsOneWidget);
      expect(find.byKey(const ValueKey('import-map-date')), findsNothing);
      expect(find.text('3건을 읽었습니다'), findsOneWidget);
      // 미리보기: 금액에 부호가 붙는다.
      expect(find.text('동물병원'), findsOneWidget);
      expect(find.text('-32,000원'), findsOneWidget);
      expect(find.text('+2,500,000원'), findsOneWidget);
      // 가계부에 없는 이름을 알려 준다.
      expect(find.textContaining('자산 새 카드 · 분류 반려동물'), findsOneWidget);
      // 검토함이 이어지기 전에는 보내는 단추가 없다.
      expect(find.byKey(const ValueKey('import-send')), findsNothing);
      expect(
        await services.db.select(services.db.ledgerTransactions).get(),
        isEmpty,
      );
      await disposeApp(tester, services);
    });

    testWidgets('검토함이 이어져 있으면 읽은 건을 그대로 넘긴다', (tester) async {
      final bytes = await ownFile();
      final services = await createTestServices();
      final received = <List<ImportedRow>>[];
      await open(
        tester,
        services,
        overrides: [
          picker('a.csv', bytes),
          importSinkProvider.overrideWithValue(
            (rows) async => received.add(rows),
          ),
        ],
      );

      await tapKey(tester, 'import-pick');
      await tapKey(tester, 'import-send');
      expect(received.single, hasLength(3));
      expect(received.single.first.counterparty, '동물병원');
      expect(received.single.first.accountName, '새 카드');
      expect(received.single.last.type, TxType.income);
      expect(find.text('3건을 검토함으로 보냈습니다'), findsOneWidget);
      // 보내고 나면 처음으로 돌아간다.
      expect(find.byKey(const ValueKey('import-count')), findsNothing);
      // 만들라고 하지 않았으므로 자산과 분류는 그대로다.
      final accounts = await services.repository.accounts(services.ledgerId);
      expect(accounts.map((a) => a.name), ['현금']);
      await disposeApp(tester, services);
    });

    testWidgets('없는 자산과 분류를 새로 만들겠다고 하면 만들고 보낸다', (tester) async {
      final bytes = await ownFile();
      final services = await createTestServices();
      var sent = 0;
      await open(
        tester,
        services,
        overrides: [
          picker('a.csv', bytes),
          importSinkProvider.overrideWithValue((rows) async => sent++),
        ],
      );

      await tapKey(tester, 'import-pick');
      await tapKey(tester, 'import-create-missing');
      await tapKey(tester, 'import-send');
      expect(sent, 1);
      final repo = services.repository;
      final accounts = await repo.accounts(services.ledgerId);
      expect(accounts.map((a) => a.name), ['현금', '새 카드']);
      expect(accounts.last.kind, AccountKind.other);
      final pets = (await repo.categories(services.ledgerId))
          .singleWhere((c) => c.name == '반려동물');
      expect(pets.kind, CategoryKind.expense);
      await disposeApp(tester, services);
    });

    testWidgets('다른 파일은 열을 맞춰야 읽는다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        overrides: [
          picker(
            'bank.csv',
            csv([
              ['A', 'B', 'C', 'D'],
              ['2026-11-16', '김밥천국', '8,000', ''],
              ['2026-11-17', '급여', '', '2,500,000'],
              ['합계', '', '8,000', '2,500,000'],
            ]),
          ),
        ],
      );

      await tapKey(tester, 'import-pick');
      expect(find.textContaining('제목 줄: A | B | C | D'), findsOneWidget);
      expect(
        find.text('아직 맞추지 않은 열: 날짜, 금액(또는 출금 · 입금 두 열), 내용'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('import-count')), findsNothing);

      Future<void> choose(String field, String column) async {
        await tapKey(tester, 'import-map-$field');
        await tester.tap(find.text(column).last);
        await tester.pumpAndSettle();
      }

      await choose('date', 'A');
      await choose('counterparty', 'B');
      await choose('expense', 'C');
      expect(find.text('아직 맞추지 않은 열: 금액(또는 출금 · 입금 두 열)'), findsOneWidget);
      await choose('income', 'D');

      await scrollSubScreenTo(
        tester,
        find.byKey(const ValueKey('import-count')),
      );
      expect(find.text('2건을 읽었습니다'), findsOneWidget);
      expect(find.text('1줄은 건너뛰었습니다. 3번째 줄: 날짜를 읽지 못했습니다'), findsOneWidget);
      expect(find.text('-8,000원'), findsOneWidget);
      expect(find.text('+2,500,000원'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('은행 파일의 제목을 보고 열을 미리 맞춰 둔다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        overrides: [
          picker(
            'bank.csv',
            csv([
              ['계좌번호', '110-123'],
              ['거래일시', '적요', '출금금액', '입금금액', '잔액'],
              ['2026.11.16 12:30:00', '김밥천국', '8,000', '0', '100'],
            ]),
          ),
        ],
      );
      await tapKey(tester, 'import-pick');
      expect(find.textContaining('표 위의 안내 1줄은 건너뛰었습니다'), findsOneWidget);
      expect(find.byKey(const ValueKey('import-map-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('import-missing')), findsNothing);
      await scrollSubScreenTo(
        tester,
        find.byKey(const ValueKey('import-count')),
      );
      expect(find.text('1건을 읽었습니다'), findsOneWidget);
      await disposeApp(tester, services);
    });

    testWidgets('2,000건을 넘으면 앞의 2,000건만 읽었다고 알린다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        overrides: [
          picker(
            'big.csv',
            csv([
              ['날짜', '내용', '금액'],
              for (var i = 0; i < 2003; i++) ['2026-11-16', '가게', '${i + 1}'],
            ]),
          ),
        ],
      );
      await tapKey(tester, 'import-pick');
      await scrollSubScreenTo(
        tester,
        find.byKey(const ValueKey('import-count')),
      );
      expect(find.text('2,000건을 읽었습니다'), findsOneWidget);
      expect(
        find.textContaining('한 번에 2,000건까지 가져옵니다. 뒤의 3줄은 읽지 않았습니다'),
        findsOneWidget,
      );
      await disposeApp(tester, services);
    });

    testWidgets('표가 아닌 파일, 너무 큰 파일, 고르지 않은 경우', (tester) async {
      final services = await createTestServices();
      var mode = 'empty';
      await open(
        tester,
        services,
        overrides: [
          filePickerProvider.overrideWithValue(() async {
            switch (mode) {
              case 'empty':
                return PickedFile(name: 'x.csv', bytes: Uint8List(0));
              case 'large':
                throw const FileTooLargeException();
              case 'broken':
                throw StateError('PlatformException(…)');
              default:
                return null;
            }
          }),
        ],
      );

      await tapKey(tester, 'import-pick');
      expect(find.textContaining('파일에서 표를 읽지 못했습니다'), findsOneWidget);

      mode = 'large';
      await tapKey(tester, 'import-pick');
      expect(find.textContaining('파일이 너무 큽니다'), findsOneWidget);

      mode = 'broken';
      await tapKey(tester, 'import-pick');
      expect(find.textContaining('파일을 열지 못했습니다'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);

      // 고르지 않고 닫으면 아무 일도 없다.
      mode = 'cancel';
      await tapKey(tester, 'import-pick');
      expect(find.byKey(const ValueKey('import-error')), findsNothing);
      expect(find.byKey(const ValueKey('import-file')), findsNothing);
      await disposeApp(tester, services);
    });

    testWidgets('닫기를 누르면 읽은 파일을 내려놓는다', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        overrides: [
          picker(
            'a.csv',
            csv([
              ['날짜', '내용', '금액'],
              ['2026-11-16', '가게', '100'],
            ]),
          ),
        ],
      );
      await tapKey(tester, 'import-pick');
      expect(find.byKey(const ValueKey('import-file')), findsOneWidget);
      await tapKey(tester, 'import-clear');
      expect(find.byKey(const ValueKey('import-file')), findsNothing);
      expect(find.text('파일 고르기'), findsOneWidget);
      await disposeApp(tester, services);
    });
  });

  group('넘치지 않는다', () {
    final file = csv([
      ['거래일시(년-월-일 시:분:초)', '적요와 아주 긴 제목의 열 이름입니다', '출금금액', '입금금액', '잔액'],
      ['2026-11-16 12:30:00', '아주 긴 가맹점 이름입니다 ' * 6, '123,456,789', '', '1'],
      ['2026-11-17', '급여', '', '2,500,000', '2'],
      ['합계', '', '', '', ''],
    ]);

    for (final (name, size) in fourSizes) {
      testWidgets(name, (tester) async {
        final services = await createTestServices();
        await addTx(services, date: LocalDate(2026, 11, 16), amount: 8000);
        await open(
          tester,
          services,
          size: size,
          overrides: [
            saver(result: '/아주/긴/경로/${'폴더/' * 12}가계부.csv'),
            picker('은행에서 받은 아주 긴 이름의 거래 내역 파일 (2026년 11월).csv', file),
            importSinkProvider.overrideWithValue((rows) async {}),
          ],
        );
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'export-run');
        expect(tester.takeException(), isNull);
        await tapKey(tester, 'import-pick');
        expect(tester.takeException(), isNull);
        await scrollSubScreenTo(
          tester,
          find.byKey(const ValueKey('import-send')),
        );
        expect(tester.takeException(), isNull);
        // 드롭다운을 펼쳐도 넘치지 않는다.
        await tapKey(tester, 'import-map-memo');
        expect(tester.takeException(), isNull);
        await disposeApp(tester, services);
      });
    }

    testWidgets('소형 폰에서 글자를 200%로 키워도', (tester) async {
      final services = await createTestServices();
      await open(
        tester,
        services,
        size: phone,
        textScale: 2,
        overrides: [saver(), picker('bank.csv', file)],
      );
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'import-pick');
      expect(tester.takeException(), isNull);
      await scrollSubScreenTo(
        tester,
        find.byKey(const ValueKey('import-count')),
      );
      expect(tester.takeException(), isNull);
      await disposeApp(tester, services);
    });
  });
}
