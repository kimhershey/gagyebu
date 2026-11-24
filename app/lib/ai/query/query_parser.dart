/// 묻는 문장에서 조건을 읽는 규칙(`docs/SPEC.md` 7.15).
///
/// 모델 없이 돈다(웹 앱에서도 쓴다). 읽는 것은 기간 낱말, 분류 이름, 집계 낱말, 종류
/// 낱말이고, 남은 말은 상대방으로 본다. 읽지 못한 문장은 null로 돌려 모델에 넘기거나
/// "읽지 못했습니다"로 안내하게 한다. 틀린 조건으로 답하는 것보다 그쪽이 낫다.
library;

import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../../domain/month_period.dart';
import 'ledger_query.dart';

/// [text]에서 조회 조건을 읽는다. 읽지 못하면 null.
///
/// [categories]는 가계부에 있는 분류다. [startDay]는 월 시작일(1–28)이다.
LedgerQuery? parseQuery(
  String text, {
  required LocalDate today,
  List<QueryCategory> categories = const [],
  int startDay = 1,
}) {
  final cleaned = text
      .replaceAll(_punctuation, ' ')
      .replaceAll(_spaces, ' ')
      .trim();
  if (cleaned.isEmpty) return null;

  final found = _findPeriod(cleaned, today: today, startDay: startDay);
  final rest = found == null
      ? cleaned
      : '${cleaned.substring(0, found.start)} ${cleaned.substring(found.end)}';

  final aggregation = _aggregationOf(cleaned);
  final typeWord = _typeOf(rest);

  QueryCategory? category;
  final leftovers = <String>[];
  for (final token in rest.split(' ')) {
    if (token.isEmpty) continue;
    if (category == null) {
      final hit = _matchCategory(token, categories, typeWord);
      if (hit != null) {
        category = hit;
        continue;
      }
    }
    if (_isFiller(token)) continue;
    // 조사만 띄어 쓴 것('스타벅스 에서')은 버린다.
    final bare = token.replaceFirst(_particle, '');
    if (bare.isEmpty || _isFiller(bare)) continue;
    leftovers.add(bare);
  }

  // 풀지 못한 말이 많으면 조건을 제대로 읽은 것이 아니다.
  if (leftovers.length > _maxPartyWords) return null;
  final party = leftovers.isEmpty ? null : leftovers.join(' ');

  if (found == null && category == null && party == null && typeWord == null) {
    return null;
  }

  final TxType? type;
  if (category != null) {
    type = category.kind == CategoryKind.income
        ? TxType.income
        : TxType.expense;
  } else if (typeWord != null) {
    type = typeWord;
  } else {
    // 종류를 말하지 않은 물음은 대개 쓴 돈을 묻는다. 목록은 가리지 않고 보여 준다.
    type = aggregation == QueryAggregation.list ? null : TxType.expense;
  }

  final period = found?.period ?? const QueryPeriod.thisMonth();
  return LedgerQuery(
    period: period,
    range: period.resolve(today: today, startDay: startDay),
    category: category?.name,
    party: party,
    type: type,
    aggregation: aggregation,
    perDay:
        aggregation == QueryAggregation.average && _perDay.hasMatch(cleaned),
    periodAssumed: found == null,
  );
}

/// 상대방으로 볼 수 있는 낱말 수의 한도.
const _maxPartyWords = 2;

final _punctuation = RegExp(r'''[?？!！.,。~…"'“”‘’]''');
final _spaces = RegExp(r'\s+');

// ---------------------------------------------------------------- 기간

class _PeriodFind {
  const _PeriodFind(this.period, this.start, this.end);

  final QueryPeriod period;
  final int start;
  final int end;
}

typedef _PeriodBuilder = QueryPeriod? Function(Match m, LocalDate today, int y);

class _PeriodRule {
  _PeriodRule(String pattern, this.build)
    : pattern = RegExp('(?<![0-9가-힣A-Za-z])(?:$pattern)');

  final RegExp pattern;
  final _PeriodBuilder build;
}

QueryPeriod? _monthOf(String text, {int? year}) {
  final month = int.parse(text);
  if (month < 1 || month > 12) return null;
  return QueryPeriod.month(month, year: year);
}

/// 구체적인 것부터 본다. '작년 3월'을 '작년'으로 읽지 않기 위해서다.
final _periodRules = <_PeriodRule>[
  _PeriodRule(
    r'(\d{4})년 ?(\d{1,2})월',
    (m, today, y) => _monthOf(m.group(2)!, year: int.parse(m.group(1)!)),
  ),
  _PeriodRule(
    r'(?:작년|지난해) ?(\d{1,2})월',
    (m, today, y) => _monthOf(m.group(1)!, year: y - 1),
  ),
  _PeriodRule(
    r'(?:올해|금년) ?(\d{1,2})월',
    (m, today, y) => _monthOf(m.group(1)!, year: y),
  ),
  _PeriodRule(r'(\d{1,2})월 ?(\d{1,2})일', (m, today, y) {
    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    // 아직 오지 않은 날짜면 작년의 그날이다.
    var date = LocalDate.tryCreate(today.year, month, day);
    if (date != null && date > today) {
      date = LocalDate.tryCreate(today.year - 1, month, day);
    }
    return date == null ? null : QueryPeriod.day(date);
  }),
  _PeriodRule(r'(?:최근|지난) ?(\d{1,3})일', (m, today, y) {
    final days = int.parse(m.group(1)!);
    return days < 1 ? null : QueryPeriod.recentDays(days);
  }),
  _PeriodRule(r'(?:최근|지난) ?(\d{1,2})주(?:일)?', (m, today, y) {
    final weeks = int.parse(m.group(1)!);
    return weeks < 1 ? null : QueryPeriod.recentDays(weeks * 7);
  }),
  _PeriodRule(r'(?:최근|지난) ?(\d{1,2})(?:개월|달)', (m, today, y) {
    final months = int.parse(m.group(1)!);
    return months < 1 ? null : QueryPeriod.recentMonths(months);
  }),
  _PeriodRule(
    r'(?:최근 ?)?(?:일주일|한 ?주)',
    (m, today, y) => const QueryPeriod.recentDays(7),
  ),
  _PeriodRule(
    r'(?:최근|지난) ?한 ?달',
    (m, today, y) => const QueryPeriod.recentMonths(1),
  ),
  _PeriodRule(r'(\d{1,2})월', (m, today, y) => _monthOf(m.group(1)!)),
  _PeriodRule(r'오늘', (m, today, y) => const QueryPeriod.today()),
  _PeriodRule(r'어제', (m, today, y) => const QueryPeriod.yesterday()),
  _PeriodRule(r'그저께|그제', (m, today, y) => QueryPeriod.day(today.addDays(-2))),
  _PeriodRule(r'이번 ?주', (m, today, y) => const QueryPeriod.thisWeek()),
  _PeriodRule(r'(?:지난|저번) ?주', (m, today, y) => const QueryPeriod.lastWeek()),
  _PeriodRule(r'이번 ?달|이달', (m, today, y) => const QueryPeriod.thisMonth()),
  _PeriodRule(
    r'(?:지난|저번) ?달|전달',
    (m, today, y) => const QueryPeriod.lastMonth(),
  ),
  _PeriodRule(r'올해|금년', (m, today, y) => const QueryPeriod.thisYear()),
  _PeriodRule(r'작년|지난해', (m, today, y) => const QueryPeriod.lastYear()),
];

/// 기간 낱말 뒤에 붙어도 되는 말. 이것 말고 다른 글자가 붙어 있으면 기간이 아니다
/// ('오늘의집'의 '오늘').
final _periodTail = RegExp(r'^(?:달)?(?:에는|에도|에만|엔|에|은|는|의|도|만|동안|간|치|분|부터)?$');

_PeriodFind? _findPeriod(
  String text, {
  required LocalDate today,
  required int startDay,
}) {
  final year = MonthPeriod.containing(today, startDay: startDay).year;
  for (final rule in _periodRules) {
    for (final m in rule.pattern.allMatches(text)) {
      // 낱말의 끝까지를 기간으로 지운다. 뒤에 붙은 것이 조사가 아니면 다른 낱말이다.
      var end = text.indexOf(' ', m.end);
      if (end < 0) end = text.length;
      if (!_periodTail.hasMatch(text.substring(m.end, end))) continue;
      final period = rule.build(m, today, year);
      if (period == null) continue;
      return _PeriodFind(period, m.start, end);
    }
  }
  return null;
}

// ---------------------------------------------------------------- 집계 · 종류

final _average = RegExp('평균');
final _perDay = RegExp('하루|일 ?평균|매일');
final _count = RegExp('몇 ?(?:번|건|회|차례)|횟수|건수');
final _sum = RegExp('얼마|합계|총액|총합|합쳐');
final _list = RegExp('보여|목록|내역|리스트|뭐|뭘|무엇|무슨|어디|언제');

/// 집계 방식. '얼마 썼는지 보여 줘'는 합계다(금액을 묻는 말이 먼저다).
QueryAggregation _aggregationOf(String text) {
  if (_average.hasMatch(text)) return QueryAggregation.average;
  if (_count.hasMatch(text)) return QueryAggregation.count;
  if (_sum.hasMatch(text)) return QueryAggregation.sum;
  if (_list.hasMatch(text)) return QueryAggregation.list;
  return QueryAggregation.sum;
}

final _transferWord = RegExp('이체|옮긴|옮겼');
final _incomeWord = RegExp('수입|벌었|벌어|번 돈|받은|받았|들어온|들어왔|입금');
final _expenseWord = RegExp('지출|썼|쓴|소비|나간|나갔|결제|샀|먹었|먹은|구매|출금|긁');

TxType? _typeOf(String text) {
  if (_transferWord.hasMatch(text)) return TxType.transfer;
  if (_incomeWord.hasMatch(text)) return TxType.income;
  if (_expenseWord.hasMatch(text)) return TxType.expense;
  return null;
}

// ---------------------------------------------------------------- 분류

/// 분류 이름을 나누는 글자('카페·간식' → 카페, 간식).
final _nameSeparator = RegExp(r'[·/,&\s]+');

/// 분류 이름이 아니어도 그 분류를 가리키는 말. 기본 분류에만 쓴다.
const _categoryAliases = <String, String>{'월급': '급여', '병원': '의료·건강'};

/// [token]이 가리키는 분류. 이름 전체, 가운뎃점을 뺀 이름, 나눈 조각 순서로 긴 것부터
/// 맞춘다('교통비'는 '교통', '카페'는 '카페·간식').
QueryCategory? _matchCategory(
  String token,
  List<QueryCategory> categories,
  TxType? typeWord,
) {
  QueryCategory? best;
  var bestLength = 0;
  var bestAt = 0;
  void consider(String key, QueryCategory category) {
    if (key.length < 2) return;
    final at = token.indexOf(key);
    if (at < 0) return;
    // 긴 이름이 먼저고, 길이가 같으면 앞에 나온 말이 먼저다('문화생활'은 '문화').
    // 이름이 같은 분류가 지출과 수입에 다 있으면 문장의 종류 낱말을 따른다.
    final preferred =
        typeWord == TxType.income && category.kind == CategoryKind.income;
    final better =
        key.length > bestLength ||
        (key.length == bestLength &&
            (at < bestAt || (at == bestAt && preferred)));
    if (better) {
      best = category;
      bestLength = key.length;
      bestAt = at;
    }
  }

  for (final category in categories) {
    final name = category.name.trim();
    consider(name, category);
    final parts = name.split(_nameSeparator);
    if (parts.length > 1) {
      consider(parts.join(), category);
      for (final part in parts) {
        consider(part, category);
      }
    }
  }
  if (best != null) return best;
  for (final alias in _categoryAliases.entries) {
    if (!token.contains(alias.key)) continue;
    for (final category in categories) {
      if (category.name == alias.value) return category;
    }
  }
  return null;
}

// ---------------------------------------------------------------- 남은 말

/// 상대방에 붙은 조사. 떼고 난 말이 내역의 상대방 · 내용에 들어 있는지를 본다.
/// '도' · '만'은 떼지 않는다. 이름의 끝 글자일 때가 더 많다('제주도').
final _particle = RegExp(r'(?:에서는|에서도|에서|에게서|한테서|에게|한테|으로|에는|에도|에|은|는|을|를|의)$');

/// 조건이 아닌 말: 묻는 말, 집계 · 종류 낱말로 시작하는 말.
final _fillerPrefix = RegExp(
  '^(?:얼마|몇|어느|어떤|어떻게|어디|언제|누구|뭐|뭘|무엇|무슨|왜|'
  '합계|평균|총액|총합|합쳐|내역|목록|리스트|횟수|건수|'
  '지출|수입|소비|이체|결제|입금|출금|사용|이용|구매|'
  '보여|알려|찾아|말해|조회|검색|줘|주세|줄래|봐)',
);

/// 조건이 아닌 말: 그 자체로 뜻이 없는 낱말.
const _fillerWords = <String>{
  '돈', '총', '전부', '모두', '다', '좀', '내가', '나', '난', '제가', '우리',
  '건', '거', '것', '게', '걸', '정도', '쯤', '대략', '하루', '하루에', '매일',
  '일', '건당', '한', '번', '중', '중에', '동안', '간', '원', '값', '비용',
  '가장', '제일', '많이', '전체', '그리고', '또', '그럼', '혹시', '이번',
  '지난', '최근', '달', '주', '요', '야', '이야', '지', '까', //
};

/// 조건이 아닌 말: 쓰다 · 사다 · 먹다 · 가다 · 받다 · 벌다 · 하다 같은 풀이말.
/// 줄기와 어미가 낱말 전체를 채울 때만 풀이말로 본다('하나로마트'는 가게 이름이다).
/// '가' · '사' · '내' · '하'처럼 한 글자뿐인 줄기는 넣지 않는다. '가게' · '사고' ·
/// '하나'가 풀이말로 읽힌다.
final _verb = RegExp(
  '^(?:썼|쓴|쓰는|쓰|샀|산|먹었|먹은|먹|갔|간|받았|받은|받|벌었|번|벌|'
  '나갔|나간|나가|들어왔|들어온|들어오|했|한|해|하는|됐|된|돼|되|있|없|냈|낸|'
  '긁었|긁은|긁|줬|준|보냈|보낸|넣었|넣은|나왔|나온|나오|시켰|시킨|시켜|들었|든)'
  '(?:어|아|지|니|냐|나|까|요|다|음|네|게|고|서|죠|는지|은지|는데|을까|던가|더라|'
  '어요|아요|나요|습니다|습니까|었어|았어|었지|았지|었나|았나|'
  '거|거야|거지|건지|건가|건데|걸까)*\$',
);

/// 조건이 아닌 말: 횟수를 세는 말('몇 번이야'의 '번이야').
final _counter = RegExp(r'^(?:번|건|회|차례)(?:이야|이나|이지|인지|이니|야|쯤|정도)?$');

bool _isFiller(String token) =>
    _fillerWords.contains(token) ||
    _counter.hasMatch(token) ||
    _fillerPrefix.hasMatch(token) ||
    _verb.hasMatch(token);
