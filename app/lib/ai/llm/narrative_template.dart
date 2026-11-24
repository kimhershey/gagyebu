/// 월별 총평의 문장 틀(`docs/SPEC.md` 7.10).
///
/// 모델이 없는 기기(웹 앱, 저사양 폰)와 모델의 글이 검증에서 두 번 떨어졌을 때 쓴다.
/// 집계 JSON(`MonthSummary.toStatsJson()`)의 값만 문장에 끼워 넣는다.
library;

import '../../core/formatters.dart';

/// 금액을 읽기 쉬운 말로. 값은 줄이지 않는다.
///
/// 1860250 → '186만 250원', 120000 → '12만 원', 4500 → '4,500원',
/// 123456789 → '1억 2,345만 6,789원'
String koreanWon(int value) {
  final n = value.abs();
  final eok = n ~/ 100000000;
  final man = (n % 100000000) ~/ 10000;
  final rest = n % 10000;
  final parts = [
    if (eok > 0) '${formatNumber(eok)}억',
    if (man > 0) '${formatNumber(man)}만',
    if (rest > 0 || n == 0) formatNumber(rest),
  ];
  // '12만 원'처럼 단위로 끝나면 띄우고, '250원'처럼 숫자로 끝나면 붙인다.
  final unitLast = rest == 0 && n != 0;
  return '${value < 0 ? '-' : ''}${parts.join(' ')}${unitLast ? ' 원' : '원'}';
}

/// 집계의 정수 값. 없거나 정수가 아니면 0.
int statInt(Object? value) => value is num ? value.round() : 0;

/// 집계의 목록 값. 없으면 빈 목록.
List<Map<String, Object?>> statList(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map) item.cast<String, Object?>(),
];

/// 집계가 가리키는 달의 이름(1–12). 읽지 못하면 null.
int? statMonth(Map<String, Object?> stats) {
  final key = stats['month'];
  if (key is! String) return null;
  final parts = key.split('-');
  if (parts.length != 2) return null;
  final month = int.tryParse(parts[1]);
  return month != null && month >= 1 && month <= 12 ? month : null;
}

/// 분류가 없는 지출을 묶은 줄의 이름(`LedgerRepository.monthSummary`가 붙인다).
const _uncategorized = '분류 없음';

/// 집계 [stats]를 3–5문장의 총평으로 옮긴다. 모델을 쓰지 않는다.
///
/// 차례: 쓴 돈과 번 돈 → 전달과 견준 것 → 가장 많이 쓴 분류 → 예산(없으면 고정 지출,
/// 그것도 없으면 가장 큰 지출) → 하루 평균과 지출이 없던 날.
String templateNarrative(Map<String, Object?> stats) {
  final month = statMonth(stats);
  final head = month == null ? '이 달에는' : '$month월에는';
  final income = statInt(stats['income']);
  final expense = statInt(stats['expense']);
  final previous = statInt(stats['previous_expense']);
  final sentences = <String>[];

  if (expense <= 0) {
    // 지출이 없던 달. 말할 것이 적다.
    sentences.add(
      income > 0
          ? '$head ${koreanWon(income)}을 벌었고 지출은 없었습니다.'
          : '$head 적어 둔 수입과 지출이 없습니다.',
    );
    if (previous > 0) sentences.add('전달에는 ${koreanWon(previous)}을 썼습니다.');
    final noSpend = statInt(stats['no_spend_days']);
    if (noSpend > 0) sentences.add('지출이 없던 날은 $noSpend일입니다.');
    return sentences.join(' ');
  }

  sentences.add(
    income > 0
        ? '$head ${koreanWon(income)}을 벌고 ${koreanWon(expense)}을 썼습니다.'
        : '$head ${koreanWon(expense)}을 썼습니다.',
  );

  if (previous > 0) {
    final change = expense - previous;
    sentences.add(switch (change) {
      < 0 => '전달보다 ${koreanWon(-change)} 덜 썼습니다.',
      > 0 => '전달보다 ${koreanWon(change)} 더 썼습니다.',
      _ => '전달과 똑같이 썼습니다.',
    });
  }

  final categories = statList(stats['by_category']);
  if (categories.isNotEmpty) {
    final top = categories.first;
    final name = top['name'];
    final amount = statInt(top['amount']);
    final ratio = top['ratio'];
    final share = ratio is num ? '${(ratio * 100).round()}%, ' : '';
    sentences.add(
      name == _uncategorized || name is! String
          ? '분류를 정하지 않은 지출이 ${koreanWon(amount)}으로 가장 많았습니다.'
          : '가장 많이 쓴 분류는 $name($share${koreanWon(amount)})입니다.',
    );
  }

  final budget = stats['budget'];
  final fixed = statInt(stats['fixed_expense']);
  final largest = statList(stats['largest']);
  if (budget is Map) {
    final amount = statInt(budget['amount']);
    final spent = statInt(budget['spent']);
    sentences.add(
      spent > amount
          ? '예산 ${koreanWon(amount)}을 ${koreanWon(spent - amount)} 넘겼습니다.'
          : '예산 ${koreanWon(amount)} 가운데 ${koreanWon(spent)}을 써서 '
                '${koreanWon(amount - spent)}이 남았습니다.',
    );
  } else if (fixed > 0) {
    sentences.add('반복 거래로 나간 고정 지출은 ${koreanWon(fixed)}입니다.');
  } else if (largest.isNotEmpty) {
    final name = largest.first['name'];
    final amount = koreanWon(statInt(largest.first['amount']));
    sentences.add(
      name is String && name.isNotEmpty
          ? '가장 큰 지출은 $name $amount입니다.'
          : '가장 큰 지출은 $amount입니다.',
    );
  }

  final average = koreanWon(statInt(stats['daily_average']));
  final noSpend = statInt(stats['no_spend_days']);
  sentences.add(
    noSpend > 0
        ? '하루 평균 $average을 썼고, 지출이 없던 날은 $noSpend일입니다.'
        : '하루 평균 $average을 썼습니다.',
  );

  return sentences.join(' ');
}
