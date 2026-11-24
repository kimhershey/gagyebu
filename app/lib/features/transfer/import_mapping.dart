/// 읽은 CSV의 열을 거래의 칸에 맞추고 가져올 건으로 바꾼다(`docs/SPEC.md` 7.16).
library;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/parsed_transaction.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../review/review_state.dart';
import 'csv_codec.dart';
import 'export.dart';

/// 한 번에 가져오는 건수의 한도.
const importLimit = 2000;

/// 파일에서 읽어 온 거래 한 건. 자산과 분류는 아직 이름이다(검토함이 가계부의 것과 잇는다).
class ImportedRow {
  const ImportedRow({
    required this.date,
    required this.type,
    required this.amount,
    this.time,
    this.accountName,
    this.toAccountName,
    this.counterparty,
    this.categoryName,
    this.memo,
    this.installmentMonths,
    this.canceled = false,
  });

  final LocalDate date;

  /// 'HH:mm'. 파일에 없으면 null.
  final String? time;
  final TxType type;

  /// 원 단위의 양수.
  final int amount;
  final String? accountName;

  /// 이체일 때 받는 자산의 이름.
  final String? toAccountName;
  final String? counterparty;
  final String? categoryName;
  final String? memo;
  final int? installmentMonths;
  final bool canceled;

  @override
  bool operator ==(Object other) =>
      other is ImportedRow &&
      other.date == date &&
      other.time == time &&
      other.type == type &&
      other.amount == amount &&
      other.accountName == accountName &&
      other.toAccountName == toAccountName &&
      other.counterparty == counterparty &&
      other.categoryName == categoryName &&
      other.memo == memo &&
      other.installmentMonths == installmentMonths &&
      other.canceled == canceled;

  @override
  int get hashCode => Object.hash(
    date,
    time,
    type,
    amount,
    accountName,
    toAccountName,
    counterparty,
    categoryName,
    memo,
    installmentMonths,
    canceled,
  );

  @override
  String toString() =>
      'ImportedRow($date ${time ?? ''} ${type.code} $amount '
      '$accountName→$toAccountName $counterparty $categoryName $memo '
      '$installmentMonths ${canceled ? 'canceled' : ''})';
}

/// 가져올 건을 받아 검토함으로 보내는 함수(출처 `import`). null이면 가져오기 화면은
/// 미리보기까지만 보여 준다(시험에서 덮어쓴다).
///
/// 자산과 분류는 이름으로 넘긴다. ID로 잇고, 중복으로 보이는 건을 빼 두는 일은 검토함이
/// 한다.
final importSinkProvider = Provider<Future<void> Function(List<ImportedRow>)?>(
  (ref) =>
      (rows) => ref
          .read(reviewSessionProvider.notifier)
          .open(
            transactions: [for (final row in rows) row.toParsed()],
            source: TxSource.import,
          ),
);

extension on ImportedRow {
  /// 검토함이 받는 거래 초안으로 바꾼다.
  ParsedTransaction toParsed() => ParsedTransaction(
    date: date,
    time: time,
    amount: amount,
    direction: switch (type) {
      TxType.income => Direction.incoming,
      TxType.expense => Direction.outgoing,
      TxType.transfer => Direction.transfer,
    },
    accountText: accountName,
    counterparty: type == TxType.transfer ? toAccountName : counterparty,
    category: categoryName,
    memo: memo,
    installmentMonths: installmentMonths,
    isCancel: canceled,
    ruleId: 'import',
    raw: '',
  );
}

/// 열을 맞출 수 있는 칸.
enum ImportField {
  date('날짜'),
  time('시각'),
  type('종류'),
  amount('금액'),
  expense('출금(지출) 금액'),
  income('입금(수입) 금액'),
  counterparty('내용(상대방)'),
  account('자산'),
  toAccount('받는 자산'),
  category('분류'),
  memo('메모'),
  installment('할부'),
  canceled('취소 여부');

  const ImportField(this.label);

  /// 화면에 보이는 이름.
  final String label;
}

/// 어느 칸을 파일의 몇 번째 열에서 읽을지.
class ColumnMapping {
  const ColumnMapping(this.columns, {this.ownFormat = false});

  /// 칸 → 열 번호(0부터).
  final Map<ImportField, int> columns;

  /// 이 앱이 내보낸 파일인지. 그러면 내보낼 때 붙인 작은따옴표를 뗀다.
  final bool ownFormat;

  int? operator [](ImportField field) => columns[field];

  /// [field]를 [column]열에 맞춘다. [column]이 null이면 푼다.
  ColumnMapping withField(ImportField field, int? column) {
    final next = {...columns}..remove(field);
    if (column != null) next[field] = column;
    return ColumnMapping(next, ownFormat: ownFormat);
  }

  /// 꼭 맞춰야 하는데 아직 맞추지 않은 것. 날짜 · 금액 · 내용이 있어야 하고, 금액은 한 열이거나
  /// 출금 · 입금 두 열이어야 한다.
  List<String> get missing => [
    if (!columns.containsKey(ImportField.date)) '날짜',
    if (!columns.containsKey(ImportField.amount) &&
        !(columns.containsKey(ImportField.expense) &&
            columns.containsKey(ImportField.income)))
      '금액(또는 출금 · 입금 두 열)',
    if (!columns.containsKey(ImportField.counterparty)) '내용',
  ];

  bool get isComplete => missing.isEmpty;
}

/// 제목 줄을 보고 열을 짐작한다. 이 앱이 내보낸 파일이면 모두 맞춰진다.
ColumnMapping guessMapping(List<String> header) {
  final names = [for (final h in header) h.trim()];
  if (const ListEquality<String>().equals(names, exportHeader)) {
    return const ColumnMapping({
      ImportField.date: 0,
      ImportField.time: 1,
      ImportField.type: 2,
      ImportField.amount: 3,
      ImportField.account: 4,
      ImportField.toAccount: 5,
      ImportField.counterparty: 6,
      ImportField.category: 7,
      ImportField.memo: 8,
      ImportField.installment: 9,
      ImportField.canceled: 10,
    }, ownFormat: true);
  }

  // 앞에 적은 칸부터 열을 고른다. 한 열은 한 칸에만 쓴다.
  const hints = <ImportField, List<String>>{
    // '입금/출금 구분' 같은 열을 금액 열로 잡지 않게 종류를 먼저 고른다.
    ImportField.type: ['종류', '구분', 'type'],
    ImportField.expense: ['출금', '지출', '찾으신', '사용금액', '이용금액', '결제금액'],
    ImportField.income: ['입금', '수입', '맡기신'],
    ImportField.date: ['거래일', '이용일', '승인일', '날짜', '일자', '일시', 'date'],
    ImportField.time: ['시각', '시간', 'time'],
    ImportField.amount: ['금액', 'amount'],
    ImportField.counterparty: [
      '가맹점',
      '내용',
      '적요',
      '상대',
      '거래처',
      '상호',
      '받는분',
      '보낸분',
      '사용처',
      'description',
    ],
    ImportField.memo: ['메모', '비고', 'memo'],
    ImportField.category: ['분류', '카테고리', '업종', 'category'],
    ImportField.toAccount: ['받는 자산', '입금계좌'],
    ImportField.account: ['자산', '결제수단', '카드명', '계좌'],
    ImportField.installment: ['할부'],
    ImportField.canceled: ['취소'],
  };
  final lower = [for (final n in names) n.toLowerCase().replaceAll(' ', '')];
  final taken = <int>{};
  final columns = <ImportField, int>{};
  hints.forEach((field, words) {
    for (final word in words) {
      final needle = word.toLowerCase().replaceAll(' ', '');
      final index = lower.indexed
          .where((e) => !taken.contains(e.$1) && e.$2.contains(needle))
          // 잔액 열은 금액이 아니다.
          .where((e) => !e.$2.contains('잔액'))
          .map((e) => e.$1)
          .firstOrNull;
      if (index != null) {
        columns[field] = index;
        taken.add(index);
        return;
      }
    }
  });
  // 출금 · 입금 가운데 하나만 찾았으면 그 열이 금액이다(카드 명세서의 '이용금액').
  final hasExpense = columns.containsKey(ImportField.expense);
  final hasIncome = columns.containsKey(ImportField.income);
  if (hasExpense != hasIncome && !columns.containsKey(ImportField.amount)) {
    final only = hasExpense ? ImportField.expense : ImportField.income;
    columns[ImportField.amount] = columns.remove(only)!;
  } else if (hasExpense != hasIncome) {
    columns
      ..remove(ImportField.expense)
      ..remove(ImportField.income);
  }
  return ColumnMapping(columns);
}

/// 읽지 못해 건너뛴 줄.
class SkippedRow {
  const SkippedRow(this.line, this.reason);

  /// 제목 줄 아래에서 몇 번째 줄인지(1부터).
  final int line;

  /// 사용자에게 보일 까닭.
  final String reason;
}

/// [mapRows]의 결과.
class ImportResult {
  const ImportResult({
    required this.rows,
    required this.skipped,
    required this.overLimit,
  });

  /// 가져올 건.
  final List<ImportedRow> rows;

  /// 읽지 못한 줄.
  final List<SkippedRow> skipped;

  /// 한도를 넘어 읽지 않은 줄 수.
  final int overLimit;
}

/// [table]의 줄들을 [mapping]대로 가져올 건으로 바꾼다. 한 번에 [limit]건까지다.
///
/// 날짜나 금액을 읽지 못한 줄(합계 줄, 안내 줄)은 건너뛰고 까닭을 남긴다.
/// [mapping]이 덜 맞춰졌으면 [ArgumentError].
ImportResult mapRows(
  CsvTable table,
  ColumnMapping mapping, {
  int limit = importLimit,
}) {
  if (!mapping.isComplete) {
    throw ArgumentError('열을 덜 맞췄다: ${mapping.missing.join(', ')}');
  }
  final rows = <ImportedRow>[];
  final skipped = <SkippedRow>[];
  var overLimit = 0;

  for (var i = 0; i < table.rows.length; i++) {
    if (rows.length >= limit) {
      overLimit = table.rows.length - i;
      break;
    }
    final line = table.rows[i];
    String raw(ImportField field) {
      final column = mapping[field];
      return column == null ? '' : CsvTable.cell(line, column).trim();
    }

    String? text(ImportField field) {
      var value = raw(field);
      if (mapping.ownFormat) value = unguardCell(value).trim();
      return value.isEmpty ? null : value;
    }

    final (date, timeInDate) = parseImportDate(raw(ImportField.date));
    if (date == null) {
      skipped.add(SkippedRow(i + 1, '날짜를 읽지 못했습니다'));
      continue;
    }

    final typeText = raw(ImportField.type);
    TxType? type = typeText.isEmpty ? null : parseImportType(typeText);
    int? amount;
    if (mapping[ImportField.amount] != null) {
      final signed = parseImportAmount(raw(ImportField.amount));
      if (signed != null && signed != 0) {
        amount = signed.abs();
        // 종류 열이 없으면 부호로 가른다. 카드 명세서에서 음수는 취소 · 환불이다.
        type ??= signed < 0 ? TxType.income : TxType.expense;
      }
    } else {
      final out = parseImportAmount(raw(ImportField.expense))?.abs() ?? 0;
      final into = parseImportAmount(raw(ImportField.income))?.abs() ?? 0;
      if (out > 0 && into > 0) {
        skipped.add(SkippedRow(i + 1, '출금과 입금이 함께 적혀 있습니다'));
        continue;
      }
      if (out > 0) {
        amount = out;
        type = type == TxType.transfer ? type : TxType.expense;
      } else if (into > 0) {
        amount = into;
        type = type == TxType.transfer ? type : TxType.income;
      }
    }
    if (amount == null) {
      skipped.add(SkippedRow(i + 1, '금액을 읽지 못했습니다'));
      continue;
    }

    final time = parseImportTime(raw(ImportField.time)) ?? timeInDate;
    final installment = RegExp(r'\d+')
        .firstMatch(raw(ImportField.installment))
        ?.group(0);
    final months = installment == null ? null : int.tryParse(installment);
    rows.add(
      ImportedRow(
        date: date,
        time: time,
        type: type ?? TxType.expense,
        amount: amount,
        accountName: text(ImportField.account),
        toAccountName: text(ImportField.toAccount),
        counterparty: text(ImportField.counterparty),
        categoryName: text(ImportField.category),
        memo: text(ImportField.memo),
        // 1개월 이하는 일시불이다.
        installmentMonths: months != null && months > 1 ? months : null,
        canceled: parseImportCanceled(raw(ImportField.canceled)),
      ),
    );
  }
  return ImportResult(rows: rows, skipped: skipped, overLimit: overLimit);
}

final _dateSeparated = RegExp(
  r'^(\d{4}|\d{2})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})\s*일?\.?',
);
final _dateCompact = RegExp(r'^(\d{4})(\d{2})(\d{2})(?!\d)');
final _timePattern = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?');

/// 날짜 칸을 읽는다. '2026-11-16', '2026.11.16', '2026/11/16', '20261116',
/// '2026년 11월 16일', '26.11.16'을 받는다. 뒤에 시각이 붙어 있으면 함께 돌려준다.
(LocalDate?, String?) parseImportDate(String text) {
  final value = text.trim();
  final match =
      _dateSeparated.firstMatch(value) ?? _dateCompact.firstMatch(value);
  if (match == null) return (null, null);
  var year = int.parse(match.group(1)!);
  // 두 자리 해는 2000년대로 본다.
  if (match.group(1)!.length == 2) year += 2000;
  final date = LocalDate.tryCreate(
    year,
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (date == null) return (null, null);
  return (date, parseImportTime(value.substring(match.end)));
}

/// 시각 칸을 'HH:mm'으로 읽는다. 읽지 못하면 null.
String? parseImportTime(String text) {
  final match = _timePattern.firstMatch(text);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (text.contains('오후') && hour < 12) hour += 12;
  if (text.contains('오전') && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 금액 칸을 읽는다. 쉼표 · '원' · 통화 기호를 떼고, 앞의 '-'나 괄호는 음수로 읽는다.
/// 소수점 아래는 버린다. 숫자가 없으면 null.
int? parseImportAmount(String text) {
  var value = text.replaceAll(RegExp(r'[,\s원₩\\]'), '');
  if (value.isEmpty) return null;
  var negative = false;
  if (value.startsWith('(') && value.endsWith(')')) {
    negative = true;
    value = value.substring(1, value.length - 1);
  }
  if (value.startsWith('-') || value.startsWith('−')) {
    negative = true;
    value = value.substring(1);
  } else if (value.startsWith('+')) {
    value = value.substring(1);
  }
  final match = RegExp(r'^(\d+)(?:\.\d+)?$').firstMatch(value);
  if (match == null) return null;
  final amount = int.tryParse(match.group(1)!);
  if (amount == null) return null;
  return negative ? -amount : amount;
}

/// 종류 칸을 읽는다. 모르는 말이면 null(금액의 부호나 열로 가른다).
TxType? parseImportType(String text) {
  final value = text.trim().toLowerCase();
  if (value.contains('이체') || value == 'transfer') return TxType.transfer;
  if (value.contains('수입') || value.contains('입금') || value == 'income') {
    return TxType.income;
  }
  if (value.contains('지출') ||
      value.contains('출금') ||
      value.contains('결제') ||
      value.contains('승인') ||
      value == 'expense') {
    return TxType.expense;
  }
  return null;
}

/// 취소 여부 칸을 읽는다.
bool parseImportCanceled(String text) {
  final value = text.trim().toLowerCase();
  return value.contains('취소') ||
      const {'y', 'yes', 'true', '1', 'o', '예'}.contains(value);
}

/// 가져올 건에 나오지만 가계부에 없는 자산 · 분류의 이름.
class MissingNames {
  const MissingNames({required this.accounts, required this.categories});

  /// 없는 자산의 이름.
  final List<String> accounts;

  /// 없는 분류의 이름과 종류. 수입 거래에만 나온 이름은 수입 분류로 본다.
  final Map<String, CategoryKind> categories;

  bool get isEmpty => accounts.isEmpty && categories.isEmpty;
}

/// [rows]에 나오는 자산 · 분류 이름 가운데 [accountNames] · [categoryNames]에 없는 것을
/// 처음 나온 순서대로 모은다.
MissingNames findMissingNames(
  List<ImportedRow> rows, {
  required Iterable<String> accountNames,
  required Iterable<String> categoryNames,
}) {
  final knownAccounts = accountNames.toSet();
  final knownCategories = categoryNames.toSet();
  final accounts = <String>{};
  final categories = <String, CategoryKind>{};
  for (final row in rows) {
    for (final name in [row.accountName, row.toAccountName]) {
      if (name != null && !knownAccounts.contains(name)) accounts.add(name);
    }
    final category = row.categoryName;
    if (category != null &&
        row.type != TxType.transfer &&
        !knownCategories.contains(category)) {
      final kind = row.type == TxType.income
          ? CategoryKind.income
          : CategoryKind.expense;
      // 지출에 한 번이라도 쓰였으면 지출 분류다.
      categories.update(
        category,
        (old) => old == CategoryKind.expense ? old : kind,
        ifAbsent: () => kind,
      );
    }
  }
  return MissingNames(accounts: accounts.toList(), categories: categories);
}
