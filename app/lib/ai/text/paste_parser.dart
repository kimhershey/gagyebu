/// 붙여넣은 원문을 건별로 나눠 판정한다.
///
/// 순서: 표기 정리 → 덩어리 나누기 → 거래 아님 판별 → 형식 규칙.
/// 규칙에 맞지 않는 덩어리는 [UnrecognizedItem]으로 돌려준다. 기기 내 LLM이 있으면
/// 그쪽으로 넘기고, 없으면 원문을 옆에 둔 직접 입력으로 넘긴다.
library;

import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import 'non_transaction.dart';
import 'sms_parser.dart';
import 'sms_rules.dart';
import 'text_normalizer.dart';

class PasteParser {
  PasteParser({List<SmsRule>? rules}) : _rules = rules ?? builtinSmsRules;

  final List<SmsRule> _rules;

  /// 문자 한 건이 차지할 수 있는 최대 줄 수.
  static const _maxLinesPerMessage = 12;

  /// [text]에서 거래 초안과 그 밖의 판정을 원문 순서대로 돌려준다.
  ///
  /// [today]는 연도 없는 날짜를 풀 때의 기준일이다.
  List<ParsedItem> parse(String text, {required LocalDate today}) {
    final normalized = normalizeText(text);
    if (normalized.isEmpty) return const [];

    final items = <ParsedItem>[];
    for (final block in _splitBlocks(normalized)) {
      items.addAll(_parseBlock(block, today));
    }
    return items;
  }

  /// 빈 줄과 '[Web발신]' 머리말을 경계로 덩어리를 나눈다.
  List<List<String>> _splitBlocks(String normalized) {
    final blocks = <List<String>>[];
    var current = <String>[];

    void flush() {
      if (current.isNotEmpty) {
        blocks.add(current);
        current = <String>[];
      }
    }

    for (final rawLine in normalized.split('\n')) {
      var line = rawLine;
      final header = _carrierHeader.matchAsPrefix(line);
      if (header != null) {
        flush();
        line = line.substring(header.end).trim();
      }
      if (line.isEmpty) {
        flush();
        continue;
      }
      current.add(line);
    }
    flush();
    return blocks;
  }

  List<ParsedItem> _parseBlock(List<String> lines, LocalDate today) {
    final items = <ParsedItem>[];
    final pending = <String>[];
    final startsCache = <int, bool>{};

    void flushPending() {
      if (pending.isEmpty) return;
      items.add(UnrecognizedItem(pending.join('\n')));
      pending.clear();
    }

    ParsedItem? classify(int from, int to) =>
        _classify(lines.sublist(from, to), today);

    // from에서 시작하는 문자가 있는지. 어느 길이로든 판정이 나오면 시작으로 본다.
    bool startsMessage(int from) => startsCache.putIfAbsent(from, () {
      final maxTo = _min(lines.length, from + _maxLinesPerMessage);
      for (var to = from + 1; to <= maxTo; to++) {
        if (classify(from, to) != null) return true;
      }
      return false;
    });

    var i = 0;
    while (i < lines.length) {
      // 다음 문자가 시작되는 줄을 경계로 삼는다. 경계를 넘지 않는 범위에서 가장 긴 판정을
      // 고르고, 거기서 판정이 안 나올 때만 경계를 하나씩 넘어 본다. 제목 줄이 따로 오는
      // 앱 알림('입출금 알림' 다음 줄에 본문)은 경계를 넘어야 한 건으로 읽힌다.
      final maxEnd = _min(lines.length, i + _maxLinesPerMessage);
      final boundaries = <int>[
        for (var j = i + 1; j < maxEnd; j++)
          if (startsMessage(j)) j,
        maxEnd,
      ];
      ParsedItem? best;
      var bestEnd = i;
      var floor = i;
      for (final boundary in boundaries) {
        for (var to = boundary; to > floor; to--) {
          final item = classify(i, to);
          if (item != null) {
            best = item;
            bestEnd = to;
            break;
          }
        }
        if (best != null) break;
        floor = boundary;
      }
      if (best == null) {
        pending.add(lines[i]);
        i++;
        continue;
      }
      ParsedItem chosen = best;
      if (chosen is NonTransactionItem &&
          chosen.reason != NonTransactionReason.advertisement) {
        // 안내문은 낱말 하나로 판정하므로 줄을 더해도 계속 맞는다. 뒤따르는 줄을
        // 삼키지 않게 가장 짧은 범위를 쓴다. 광고는 본문 전체를 한 건으로 둔다.
        for (var to = i + 1; to < bestEnd; to++) {
          final item = classify(i, to);
          if (item is NonTransactionItem) {
            chosen = item;
            bestEnd = to;
            break;
          }
        }
      }
      flushPending();
      final last = items.isEmpty ? null : items.last;
      if (chosen is NonTransactionItem &&
          last is NonTransactionItem &&
          last.reason == chosen.reason) {
        // 안내문 한 건이 여러 줄에 걸쳐 판정되면 하나로 합친다.
        items[items.length - 1] = NonTransactionItem(
          '${last.raw}\n${chosen.raw}',
          chosen.reason,
        );
      } else {
        items.add(chosen);
      }
      i = bestEnd;
    }
    flushPending();
    return items;
  }

  ParsedItem? _classify(List<String> window, LocalDate today) {
    final text = window.join('\n');
    final collapsed = foldWhitespace(text);
    if (collapsed.isEmpty) return null;

    final reason = detectNonTransaction(collapsed);
    if (reason != null) return NonTransactionItem(text, reason);

    final parsed = parseWithRules(
      collapsed,
      today: today,
      rules: _rules,
      raw: text,
      lines: window,
    );
    if (parsed != null) return TransactionItem(parsed);
    return null;
  }
}

int _min(int a, int b) => a < b ? a : b;

/// 통신사가 붙이는 머리말. 문자의 시작을 뜻한다.
final _carrierHeader = RegExp(r'\[(?:Web발신|국제발신|국외발신|WEB발신)\]\s*');
