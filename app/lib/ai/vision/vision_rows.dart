/// 이미지에서 읽은 줄과 그 검산(`docs/SPEC.md` 5.5).
///
/// 글 해석에서는 규칙이 원문에서 금액 후보를 뽑아 두고 모델의 답을 그 안에 가둔다.
/// 이미지에는 원문 글자가 없어 그 방법을 쓸 수 없다. 대신 이미지 안의 숫자끼리 맞는지를
/// 본다: 거래내역 화면은 줄마다의 잔액이 이어지는지, 영수증은 품목의 합이 총액과 같은지.
/// 맞지 않는 줄은 화면이 "확인 필요"로 표시하고 사용자가 원본과 견주어 고친다.
library;

import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import '../text/amount_parser.dart';
import '../text/date_parser.dart';

/// 모델이 만든 초안의 [ParsedTransaction.ruleId] 머리말. 뒤에 모델 이름이 붙는다.
/// 글 해석의 `'llm:'`과 나란하다.
const vlmRulePrefix = 'vlm:';

/// 이미지의 종류.
enum VisionKind {
  /// 은행 · 카드 앱의 거래내역 화면. 한 줄이 거래 한 건이다.
  statement,

  /// 영수증. 품목이 여러 줄이어도 거래는 한 건이다.
  receipt,

  /// 거래가 보이지 않는 이미지.
  other;

  static VisionKind? fromCode(Object? code) {
    for (final k in values) {
      if (k.name == code) return k;
    }
    return null;
  }
}

/// `copyWith`에서 "바꾸지 않는다"를 null과 구분하는 표시.
const _keep = Object();

/// 거래 초안이 될 한 줄. 화면에서 고친 값이 여기에 덮인다.
class VisionRow {
  const VisionRow({
    required this.date,
    required this.direction,
    this.time,
    this.amount,
    this.counterparty = '',
    this.balance,
    this.memo,
    this.dateGuessed = false,
    this.warnings = const {},
    this.raw = '',
  });

  final LocalDate date;

  /// 'HH:mm'. 이미지에 없으면 null.
  final String? time;

  /// 원 단위 양의 정수. 읽지 못했으면 null.
  final int? amount;

  final Direction direction;

  /// 상대방 · 가맹점. 없으면 빈 글.
  final String counterparty;

  /// 그 줄에 적힌 거래 뒤 잔액(거래내역 화면).
  final int? balance;

  /// 영수증의 품목 요약('아메리카노 외 2건').
  final String? memo;

  /// 이미지에서 날짜를 읽지 못해 윗줄의 날짜나 오늘을 넣었는지.
  final bool dateGuessed;

  /// 검토함에 그대로 넘기는 경고(연도 추정, 상대방 없음 등).
  final Set<ParseWarning> warnings;

  /// 모델이 이 줄에서 읽은 글자. 화면에 보이기만 하고 저장하지 않는다.
  final String raw;

  /// 잔액 계산에 쓰는 부호 붙은 금액. 금액을 모르면 null.
  int? get signedAmount => amount == null
      ? null
      : (direction == Direction.incoming ? amount! : -amount!);

  VisionRow copyWith({
    LocalDate? date,
    Object? amount = _keep,
    Direction? direction,
    String? counterparty,
  }) {
    final dropped = <ParseWarning>{
      // 사용자가 날짜를 정했으면 추정이 아니다.
      if (date != null) ...{
        ParseWarning.yearInferred,
        ParseWarning.dateFromNow,
      },
      if (direction != null) ParseWarning.directionMismatch,
      if ((counterparty ?? '').trim().isNotEmpty) ParseWarning.noCounterparty,
    };
    return VisionRow(
      date: date ?? this.date,
      time: time,
      amount: identical(amount, _keep) ? this.amount : amount as int?,
      direction: direction ?? this.direction,
      counterparty: counterparty ?? this.counterparty,
      balance: balance,
      memo: memo,
      dateGuessed: date == null && dateGuessed,
      warnings: warnings.difference(dropped),
      raw: raw,
    );
  }
}

/// 영수증의 품목 한 줄. 검산에만 쓴다.
class VisionItem {
  const VisionItem(this.name, this.amount);

  final String name;

  /// 할인 줄은 음수다.
  final int amount;
}

/// 한 줄을 사용자가 확인해야 하는 까닭.
enum VisionIssue {
  /// 앞 줄의 잔액에 이 줄의 금액을 더하거나 뺀 값이 이 줄의 잔액과 다르다.
  balanceBreak,

  /// 입금 · 출금을 뒤집으면 잔액이 맞는다.
  directionReversed,

  /// 영수증 품목의 합이 금액과 다르다.
  sumMismatch,

  /// 영수증의 총액을 읽지 못해 품목의 합을 넣었다.
  totalMissing,

  /// 금액을 읽지 못했다.
  amountMissing,

  /// 날짜를 읽지 못해 윗줄의 날짜나 오늘을 넣었다.
  dateMissing,
}

/// 한 줄의 검산 결과.
class VisionCheck {
  const VisionCheck({
    this.verified = false,
    this.issues = const {},
    this.expected,
    this.actual,
    this.balanceSuspect = false,
  });

  /// 잔액(거래내역)이나 품목의 합(영수증)으로 금액이 확인됐는지.
  final bool verified;

  /// 비어 있지 않으면 "확인 필요"다.
  final Set<VisionIssue> issues;

  /// 검산에서 나와야 했던 값과 이미지에서 읽은 값. 잔액이 끊겼으면 잔액, 영수증이면 금액이다.
  final int? expected;
  final int? actual;

  /// 금액은 앞뒤 줄과 맞는데 이 줄의 잔액만 어긋난다. 잔액을 잘못 읽은 것으로 보고
  /// 거래에 잔액을 붙이지 않는다.
  final bool balanceSuspect;

  bool get needsCheck => issues.isNotEmpty;
}

/// 이미지 한 장에서 읽어 낸 것.
class VisionExtraction {
  const VisionExtraction({
    required this.kind,
    this.rows = const [],
    this.items = const [],
    this.receiptTotal,
  });

  final VisionKind kind;

  /// 거래 초안이 될 줄. 영수증이면 한 줄이다.
  final List<VisionRow> rows;

  /// 영수증의 품목. 거래내역 화면이면 비어 있다.
  final List<VisionItem> items;

  /// 영수증에서 읽은 총액. 읽지 못했으면 null.
  final int? receiptTotal;

  /// 품목의 합.
  int get itemSum => items.fold(0, (sum, item) => sum + item.amount);

  /// [index]번째 줄을 [row]로 바꾼 것. 고친 뒤에는 [verify]를 다시 부른다.
  VisionExtraction withRow(int index, VisionRow row) => VisionExtraction(
    kind: kind,
    rows: [...rows]..[index] = row,
    items: items,
    receiptTotal: receiptTotal,
  );

  /// 줄마다의 검산 결과. [rows]와 길이가 같다.
  List<VisionCheck> verify() {
    final checks = switch (kind) {
      VisionKind.statement => _verifyStatement(rows),
      VisionKind.receipt => [for (final row in rows) _verifyReceipt(row)],
      VisionKind.other => [for (final _ in rows) const VisionCheck()],
    };
    return [
      for (final (i, check) in checks.indexed)
        VisionCheck(
          verified: check.verified,
          issues: {
            ...check.issues,
            if (rows[i].amount == null) VisionIssue.amountMissing,
            if (rows[i].dateGuessed) VisionIssue.dateMissing,
          },
          expected: check.expected,
          actual: check.actual,
          balanceSuspect: check.balanceSuspect,
        ),
    ];
  }

  VisionCheck _verifyReceipt(VisionRow row) {
    final amount = row.amount;
    if (items.isEmpty || amount == null) return const VisionCheck();
    if (itemSum != amount) {
      return VisionCheck(
        issues: const {VisionIssue.sumMismatch},
        expected: itemSum,
        actual: amount,
      );
    }
    // 총액을 읽지 못했으면 금액이 곧 품목의 합이라 견줄 것이 없다.
    if (receiptTotal == null) {
      return const VisionCheck(issues: {VisionIssue.totalMissing});
    }
    return const VisionCheck(verified: true);
  }

  /// 거래 초안으로 바꾼다. [only]를 주면 그 번호의 줄만 바꾼다.
  ///
  /// 잔액이 의심스러운 줄([VisionCheck.balanceSuspect])에는 잔액을 붙이지 않는다.
  List<ParsedTransaction> toTransactions({
    required String modelName,
    Set<int>? only,
  }) {
    final checks = verify();
    return [
      for (final (i, row) in rows.indexed)
        if (only == null || only.contains(i))
          ParsedTransaction(
            date: row.date,
            time: row.time,
            amount: row.amount,
            direction: row.direction,
            counterparty: row.counterparty.trim().isEmpty
                ? null
                : row.counterparty.trim(),
            balanceAfter: checks[i].balanceSuspect ? null : row.balance,
            memo: row.memo,
            ruleId: '$vlmRulePrefix$modelName',
            raw: row.raw,
            warnings: row.warnings,
          ),
    ];
  }
}

/// 거래내역 화면의 검산: 잔액이 이어지는지 본다.
///
/// 앱마다 최근 거래가 위에 오기도 하고 아래에 오기도 한다. 두 방향으로 이어 보고 더 많이
/// 맞는 쪽을 그 화면의 순서로 삼는다. 가장 오래된 줄은 견줄 앞 줄이 없어 검산하지 못한다.
List<VisionCheck> _verifyStatement(List<VisionRow> rows) {
  final n = rows.length;

  /// [i]번째 줄의 잔액이 [prev]번째 줄의 잔액에서 이어지는지. 견줄 수 없으면 null.
  bool? holds(int i, int prev) {
    final before = rows[prev].balance;
    final after = rows[i].balance;
    final moved = rows[i].signedAmount;
    if (before == null || after == null || moved == null) return null;
    return before + moved == after;
  }

  int matches(int step) {
    var count = 0;
    for (var i = 0; i < n; i++) {
      final prev = i + step;
      if (prev >= 0 && prev < n && holds(i, prev) == true) count++;
    }
    return count;
  }

  // step은 시간상 앞 줄이 있는 쪽이다. +1이면 아래 줄이 더 오래된 거래(최근이 위).
  final newestFirst = matches(1);
  final oldestFirst = matches(-1);
  final int step;
  if (newestFirst != oldestFirst) {
    step = newestFirst > oldestFirst ? 1 : -1;
  } else {
    // 어느 쪽으로도 가릴 수 없으면 날짜를 본다. 그래도 모르면 흔한 쪽(최근이 위)으로 둔다.
    step = n > 1 && _stamp(rows.first).compareTo(_stamp(rows.last)) < 0
        ? -1
        : 1;
  }

  return [for (var i = 0; i < n; i++) _checkLink(rows, i, step, holds)];
}

VisionCheck _checkLink(
  List<VisionRow> rows,
  int i,
  int step,
  bool? Function(int i, int prev) holds,
) {
  final n = rows.length;
  final prev = i + step;
  final next = i - step;
  bool inRange(int index) => index >= 0 && index < n;

  // 앞 줄의 잔액을 잘못 읽었는지: 앞 줄을 건너뛰어 그 앞 줄의 잔액에서 두 금액을 이으면
  // 맞는다. 그러면 이 줄의 금액은 확인된 것이다.
  bool bridges(int from, int via, int to) {
    if (!inRange(from) || !inRange(via) || !inRange(to)) return false;
    final start = rows[from].balance;
    final end = rows[to].balance;
    final first = rows[via].signedAmount;
    final second = rows[to].signedAmount;
    if (start == null || end == null || first == null || second == null) {
      return false;
    }
    return start + first + second == end;
  }

  if (!inRange(prev)) {
    // 가장 오래된 줄. 다음 줄이 이 줄의 잔액에서 이어지면 잔액은 믿을 만하지만 금액은
    // 견줄 데가 없다.
    return const VisionCheck();
  }
  final ok = holds(i, prev);
  if (ok == null) return const VisionCheck();
  if (ok) return const VisionCheck(verified: true);

  // 앞 줄(prev)의 잔액이 틀렸고 이 줄은 맞는 경우: prev의 앞 줄에서 두 줄을 이으면 맞는다.
  if (bridges(prev + step, prev, i)) return const VisionCheck(verified: true);
  // 이 줄의 잔액만 틀린 경우: 앞 줄에서 다음 줄까지 두 금액을 이으면 맞는다.
  if (bridges(prev, i, next)) {
    return const VisionCheck(verified: true, balanceSuspect: true);
  }

  final before = rows[prev].balance!;
  final moved = rows[i].signedAmount!;
  final after = rows[i].balance!;
  return VisionCheck(
    issues: {
      before - moved == after
          ? VisionIssue.directionReversed
          : VisionIssue.balanceBreak,
    },
    expected: before + moved,
    actual: after,
  );
}

/// 줄의 순서를 가리는 데 쓰는 날짜와 시각.
String _stamp(VisionRow row) => '${row.date} ${row.time ?? ''}';

// ---------------------------------------------------------------------------
// 모델이 옮겨 적은 글자를 값으로 읽는 규칙
// ---------------------------------------------------------------------------

/// 이미지에 적힌 날짜 글자를 날짜로 읽는다. 읽지 못하면 null.
///
/// 연도가 없으면 오늘 기준 가장 가까운 과거로 채운다(글 해석과 같은 규칙,
/// [resolveMonthDay]). 그때는 `yearInferred`가 true다.
({LocalDate date, bool yearInferred})? readVisionDate(
  String text,
  LocalDate today,
) {
  final full = _fullDate.firstMatch(text);
  if (full != null) {
    final date = LocalDate.tryCreate(
      int.parse(full.group(1)!),
      int.parse(full.group(2)!),
      int.parse(full.group(3)!),
    );
    if (date != null) return (date: date, yearInferred: false);
  }
  // '26.11.15'처럼 연도를 두 자리로 적는 앱이 있다.
  final short = _shortYearDate.firstMatch(text);
  if (short != null) {
    final date = LocalDate.tryCreate(
      2000 + int.parse(short.group(1)!),
      int.parse(short.group(2)!),
      int.parse(short.group(3)!),
    );
    if (date != null) return (date: date, yearInferred: false);
  }
  final monthDay = _monthDay.firstMatch(text);
  if (monthDay != null) {
    final date = resolveMonthDay(
      int.parse(monthDay.group(1)!),
      int.parse(monthDay.group(2)!),
      today,
    );
    if (date != null) return (date: date, yearInferred: true);
  }
  // '오늘', '어제', '3일 전'. 요일만 적힌 머리('15일 금요일')는 어느 주인지 알 수 없어 읽지 않는다.
  final relative = findDateExpression(text, today);
  if (relative != null && !relative.text.contains('요일')) {
    return (date: relative.date, yearInferred: false);
  }
  return null;
}

/// 이미지에 적힌 시각 글자를 'HH:mm'으로 읽는다. 읽지 못하면 null.
String? readVisionTime(String text) {
  final m = _clock.firstMatch(text);
  if (m == null) return null;
  var hour = int.parse(m.group(2)!);
  final minute = int.parse(m.group(3)!);
  final half = m.group(1)?.toLowerCase();
  if (half != null) {
    if (hour < 1 || hour > 12) return null;
    final afternoon = half == '오후' || half == 'pm';
    hour = hour % 12 + (afternoon ? 12 : 0);
  }
  return formatTime(hour, minute);
}

/// 이미지에 적힌 숫자 글자를 원 단위 정수로 읽는다.
///
/// `value`는 양수이고, 앞에 부호가 보였으면 `sign`이 +1이나 -1이다. 엔진이 문법을 쓰지 못해
/// JSON 숫자로 답한 경우도 받는다.
({int value, int? sign})? readVisionAmount(Object? raw) {
  if (raw is num) {
    if (raw != raw.roundToDouble()) return null;
    final value = raw.toInt();
    return (value: value.abs(), sign: value < 0 ? -1 : null);
  }
  if (raw is! String) return null;
  var text = raw.replaceAll(RegExp(r'\s'), '');
  int? sign;
  if (text.startsWith(_minus)) {
    sign = -1;
    text = text.substring(1);
  } else if (text.startsWith('+')) {
    sign = 1;
    text = text.substring(1);
  }
  final value =
      parseDigits(text.replaceAll(RegExp('[원₩]'), '')) ??
      parseKoreanAmount(text);
  if (value == null) return null;
  return (value: value, sign: sign);
}

final _fullDate = RegExp(
  r'(?<!\d)(\d{4})\s?[-./년]\s?(\d{1,2})\s?[-./월]\s?(\d{1,2})(?!\d)',
);
final _shortYearDate = RegExp(
  r'(?<![\d.])(\d{2})[-./](\d{1,2})[-./](\d{1,2})(?!\d)',
);
final _monthDay = RegExp(
  r'(?<![\d:])(\d{1,2})\s?(?:[-./]|월)\s?(\d{1,2})(?![\d:])',
);
final _clock = RegExp(
  r'(?:(오전|오후|am|pm)\s?)?(?<![\d:])(\d{1,2}):(\d{2})',
  caseSensitive: false,
);

/// 빼기 부호. 화면에서는 긴 줄표(−, –)로 그리기도 한다.
final _minus = RegExp('^[-−–]');
