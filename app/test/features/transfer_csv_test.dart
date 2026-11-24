import 'dart:convert';
import 'dart:typed_data';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/features/transfer/csv_codec.dart';

Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('CSV 읽기', () {
    test('쉼표로 나눈 줄을 읽는다', () {
      expect(parseCsvText('a,b,c\n1,2,3\n'), [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('따옴표로 감싼 칸의 쉼표 · 따옴표 · 줄바꿈을 지킨다', () {
      const text =
          '날짜,내용,메모\r\n'
          '2026-11-16,"스타벅스, 강남점","그가 ""좋다""고 했다"\r\n'
          '2026-11-17,"첫 줄\n둘째 줄\r\n셋째 줄",끝\r\n';
      expect(parseCsvText(text), [
        ['날짜', '내용', '메모'],
        ['2026-11-16', '스타벅스, 강남점', '그가 "좋다"고 했다'],
        ['2026-11-17', '첫 줄\n둘째 줄\r\n셋째 줄', '끝'],
      ]);
    });

    test('빈 칸, 따옴표만 있는 칸, 끝의 빈 칸을 지킨다', () {
      expect(parseCsvText('a,,c\n"",x,\n,,z'), [
        ['a', '', 'c'],
        ['', 'x', ''],
        ['', '', 'z'],
      ]);
    });

    test('칸 가운데의 따옴표는 글자로 읽는다', () {
      expect(parseCsvText('5" 피자,"큰" 것\n'), [
        ['5" 피자', '큰 것'],
      ]);
    });

    test('빈 줄은 빼고, 줄 끝이 CR · LF · CRLF 어느 것이든 읽는다', () {
      expect(parseCsvText('a,b\r\r\n\n1,2\r3,4\n,\n'), [
        ['a', 'b'],
        ['1', '2'],
        ['3', '4'],
      ]);
    });

    test('마지막 줄에 줄바꿈이 없어도 읽는다', () {
      expect(parseCsvText('a,b\n1,"2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('탭으로 나눈 파일도 읽는다', () {
      expect(parseCsvText('날짜\t내용\t금액\n2026-11-16\t김밥, 라면\t8,000\n'), [
        ['날짜', '내용', '금액'],
        ['2026-11-16', '김밥, 라면', '8,000'],
      ]);
    });

    test('UTF-8의 BOM을 떼고 첫 줄을 제목으로 읽는다', () {
      final table = parseCsv(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('날짜,금액\n1,2\n')]),
      );
      expect(table.encoding, 'UTF-8');
      expect(table.header, ['날짜', '금액']);
      expect(table.rows, [
        ['1', '2'],
      ]);
      expect(table.headerLine, 1);
    });

    test('UTF-8이 아니면 CP949로 읽는다', () {
      // '한글,가\n똠방각하,1' — 똠은 EUC-KR에는 없고 CP949에만 있는 글자다.
      final bytes = Uint8List.fromList([
        0xC7, 0xD1, 0xB1, 0xDB, 0x2C, 0xB0, 0xA1, 0x0A, //
        0x8C, 0x63, 0xB9, 0xE6, 0xB0, 0xA2, 0xC7, 0xCF, 0x2C, 0x31,
      ]);
      final table = parseCsv(bytes);
      expect(table.encoding, 'CP949');
      expect(table.header, ['한글', '가']);
      expect(table.rows, [
        ['똠방각하', '1'],
      ]);
    });

    test('은행이 주는 CP949 파일(따옴표와 쉼표가 든 금액)을 읽는다', () {
      const text =
          '거래일시,적요,출금금액,입금금액,잔액\r\n'
          '2026.11.16 12:30:45,체크카드 김밥천국,"8,000",0,"1,234,000"\r\n'
          '2026.11.17 09:00:00,급여,0,"2,500,000","3,734,000"\r\n';
      final table = parseCsv(cp949.encode(text));
      expect(table.encoding, 'CP949');
      expect(table.header, ['거래일시', '적요', '출금금액', '입금금액', '잔액']);
      expect(table.rows.first, [
        '2026.11.16 12:30:45',
        '체크카드 김밥천국',
        '8,000',
        '0',
        '1,234,000',
      ]);
      expect(table.rows, hasLength(2));
    });

    test('표 위에 붙은 안내 줄을 건너뛰고 제목 줄을 찾는다', () {
      final table = parseCsv(
        _utf8(
          '계좌번호,110-123-456789\n'
          '조회기간,2026-11-01 ~ 2026-11-30\n'
          '\n'
          '거래일,적요,출금,입금,잔액\n'
          '2026-11-16,김밥천국,8000,,100000\n',
        ),
      );
      expect(table.headerLine, 3);
      expect(table.header, ['거래일', '적요', '출금', '입금', '잔액']);
      expect(table.rows.single.first, '2026-11-16');
    });

    test('줄이 하나도 없으면 읽지 못한다고 알린다', () {
      expect(() => parseCsv(_utf8('\n\n')), throwsFormatException);
      expect(() => parseCsv(Uint8List(0)), throwsFormatException);
    });

    test('칸 수가 모자란 줄의 없는 칸은 빈 글이다', () {
      expect(CsvTable.cell(['a'], 0), 'a');
      expect(CsvTable.cell(['a'], 3), '');
    });
  });

  group('CSV 쓰기', () {
    test('쉼표 · 따옴표 · 줄바꿈 · 앞뒤 공백이 든 칸만 따옴표로 감싼다', () {
      expect(
        encodeCsv([
          ['a', 'b c', '1,000'],
          ['그가 "좋다"고', '첫 줄\n둘째 줄', ' 앞 공백'],
        ]),
        'a,b c,"1,000"\r\n'
        '"그가 ""좋다""고","첫 줄\n둘째 줄"," 앞 공백"\r\n',
      );
    });

    test('쓴 것을 다시 읽으면 같은 칸들이다', () {
      final rows = [
        ['날짜', '내용', '메모'],
        ['2026-11-16', '스타벅스, 강남점', '"따옴표"'],
        ['2026-11-17', '줄\r\n바꿈', ''],
        ['2026-11-18', '\t탭으로 시작', '끝 공백 '],
        ['2026-11-19', "'작은따옴표", '=1+2'],
      ];
      expect(parseCsvText(encodeCsv(rows)), rows);
    });

    test('바이트 앞에 BOM을 붙인다(Excel이 한글을 바로 연다)', () {
      final bytes = csvBytes('가\r\n');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), '가\r\n');
    });
  });
}
