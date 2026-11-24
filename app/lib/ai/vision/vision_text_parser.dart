import 'dart:convert';
import 'dart:typed_data';

import '../../core/local_date.dart';
import '../parsed_transaction.dart';
import 'vision_engine.dart';
import 'vision_prompt.dart';
import 'vision_rows.dart';

/// 이미지 한 장을 읽은 결과.
class VisionParseResult {
  const VisionParseResult({
    required this.modelName,
    required this.attempts,
    this.extraction,
    this.failure,
  });

  final String modelName;

  /// 모델을 부른 횟수.
  final int attempts;

  /// 읽어 낸 줄과 검산에 쓸 값. 읽지 못했으면 null이다.
  final VisionExtraction? extraction;

  /// 두 번 모두 검증에 실패했을 때의 이유.
  final String? failure;

  bool get failed => failure != null;

  /// 거래 초안. 화면에서 고치지 않고 그대로 넘길 때 쓴다.
  List<ParsedTransaction> get transactions =>
      extraction?.toTransactions(modelName: modelName) ?? const [];
}

/// 영수증 · 거래내역 화면 캡처를 이미지 모델로 읽어 거래 초안으로 만든다.
///
/// 모델은 보이는 글자를 옮겨 적기만 하고, 날짜 · 금액 · 방향은 여기서 규칙으로 다시 읽는다.
/// - 거래내역 화면은 한 줄이 거래 한 건이다. 날짜를 읽지 못한 줄은 윗줄의 날짜를 잇는다
///   (날짜가 묶음의 머리에만 있는 화면).
/// - 영수증은 품목이 여러 줄이어도 거래 한 건(가게 이름, 총액)이다. 품목은 검산에만 쓴다.
/// - JSON이 깨졌거나 잘렸으면 이유를 붙여 한 번 다시 부르고, 또 실패하면 포기한다.
/// 읽은 숫자가 서로 맞는지는 [VisionExtraction.verify]가 본다.
class VisionTextParser {
  VisionTextParser(this.engine);

  final VisionEngine engine;

  /// 줄이 많은 화면도 끊기지 않게 넉넉히 둔다(한 줄에 토큰 40–50개).
  static const _maxTokens = 2048;

  Future<VisionParseResult> parse(
    Uint8List image, {
    required LocalDate today,
  }) async {
    String? feedback;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final request = buildVisionRequest(feedback: feedback);
      final raw = await engine.generateJsonFromImage(
        image: image,
        system: request.system,
        user: request.user,
        schema: request.schema,
        grammar: request.grammar,
        maxTokens: _maxTokens,
      );
      final outcome = _validate(raw, today);
      final extraction = outcome.extraction;
      if (extraction != null) {
        return VisionParseResult(
          modelName: engine.modelName,
          attempts: attempt,
          extraction: extraction,
        );
      }
      feedback = outcome.problem;
    }
    return VisionParseResult(
      modelName: engine.modelName,
      attempts: 2,
      failure: feedback,
    );
  }

  _Outcome _validate(String raw, LocalDate today) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // 토큰 한도에서 잘린 출력도 여기로 온다.
      return const _Outcome.problem('JSON이 아니다. 끝까지 적어야 한다.');
    }
    if (decoded is! Map) return const _Outcome.problem('JSON 객체가 아니다.');

    final kind = VisionKind.fromCode(decoded['kind']);
    if (kind == null) {
      return const _Outcome.problem(
        '"kind"는 "statement", "receipt", "other" 가운데 하나여야 한다.',
      );
    }
    final list = decoded['rows'];
    if (list is! List) return const _Outcome.problem('"rows" 배열이 없다.');
    final lines = <Map<Object?, Object?>>[];
    for (final item in list) {
      if (item is! Map) return const _Outcome.problem('줄이 객체가 아니다.');
      lines.add(item);
    }

    return _Outcome(switch (kind) {
      VisionKind.other => const VisionExtraction(kind: VisionKind.other),
      VisionKind.statement => VisionExtraction(
        kind: kind,
        rows: _statementRows(lines, today),
      ),
      VisionKind.receipt => _receipt(decoded, lines, today),
    });
  }

  List<VisionRow> _statementRows(
    List<Map<Object?, Object?>> lines,
    LocalDate today,
  ) {
    final rows = <VisionRow>[];
    // 날짜가 묶음의 머리에만 있는 화면에서는 모델이 줄마다 날짜를 적지 못할 수 있다.
    LocalDate? carried;
    for (final line in lines) {
      final dateText = _text(line['d']);
      final timeText = _text(line['t']);
      final amount = readVisionAmount(line['a']);
      final who = _text(line['who']) ?? '';
      // 금액도 이름도 없는 줄은 거래가 아니다(머리줄, 빈 줄).
      if (amount == null && who.isEmpty) continue;

      final warnings = <ParseWarning>{};
      final read = dateText == null ? null : readVisionDate(dateText, today);
      if (read == null && carried == null) {
        warnings.add(ParseWarning.dateFromNow);
      }
      if (read != null && read.yearInferred) {
        warnings.add(ParseWarning.yearInferred);
      }
      final date = read?.date ?? carried ?? today;
      if (read != null) carried = date;

      // 방향은 모델의 판단(io)을 쓰고, 금액 앞의 부호와 어긋나면 경고한다. 잔액이 보이는
      // 화면이면 검산이 한 번 더 가려 준다.
      final answered = switch (line['io']) {
        'in' => Direction.incoming,
        'out' => Direction.outgoing,
        _ => null,
      };
      final bySign = switch (amount?.sign) {
        1 => Direction.incoming,
        -1 => Direction.outgoing,
        _ => null,
      };
      if (answered != null && bySign != null && answered != bySign) {
        warnings.add(ParseWarning.directionMismatch);
      }
      if (who.isEmpty) warnings.add(ParseWarning.noCounterparty);

      final balance = readVisionAmount(line['bal']);
      rows.add(
        VisionRow(
          date: date,
          time:
              (timeText == null ? null : readVisionTime(timeText)) ??
              (dateText == null ? null : readVisionTime(dateText)),
          amount: (amount == null || amount.value == 0) ? null : amount.value,
          direction: answered ?? bySign ?? Direction.outgoing,
          counterparty: who,
          // 마이너스 통장의 잔액은 음수다.
          balance: balance == null
              ? null
              : (balance.sign == -1 ? -balance.value : balance.value),
          dateGuessed: read == null,
          warnings: warnings,
          raw: [
            dateText,
            timeText,
            _text(line['a']),
            who.isEmpty ? null : who,
            if (_text(line['bal']) != null) '잔액 ${_text(line['bal'])}',
          ].whereType<String>().join(' '),
        ),
      );
    }
    return rows;
  }

  VisionExtraction _receipt(
    Map<Object?, Object?> decoded,
    List<Map<Object?, Object?>> lines,
    LocalDate today,
  ) {
    final items = <VisionItem>[];
    ({LocalDate date, bool yearInferred})? read;
    String? time;
    for (final line in lines) {
      final dateText = _text(line['d']);
      final timeText = _text(line['t']);
      if (dateText != null) read ??= readVisionDate(dateText, today);
      time ??=
          (timeText == null ? null : readVisionTime(timeText)) ??
          (dateText == null ? null : readVisionTime(dateText));
      final amount = readVisionAmount(line['a']);
      if (amount == null) continue;
      items.add(
        VisionItem(
          _text(line['who']) ?? '',
          amount.sign == -1 ? -amount.value : amount.value,
        ),
      );
    }

    final shop = _text(decoded['shop']) ?? '';
    final total = readVisionAmount(decoded['total'])?.value;
    final sum = items.fold(0, (sum, item) => sum + item.amount);
    // 총액을 읽지 못했으면 품목의 합을 넣는다. 검산이 "확인 필요"로 표시한다.
    final amount = total ?? (items.isEmpty ? null : sum);
    if (amount == null && shop.isEmpty) {
      return const VisionExtraction(kind: VisionKind.receipt);
    }

    final bought = [
      for (final item in items)
        if (item.amount > 0 && item.name.isNotEmpty) item.name,
    ];
    return VisionExtraction(
      kind: VisionKind.receipt,
      items: items,
      receiptTotal: total,
      rows: [
        VisionRow(
          date: read?.date ?? today,
          time: time,
          amount: (amount == null || amount <= 0) ? null : amount,
          direction: Direction.outgoing,
          counterparty: shop,
          memo: switch (bought.length) {
            0 => null,
            1 => bought.single,
            _ => '${bought.first} 외 ${bought.length - 1}건',
          },
          dateGuessed: read == null,
          warnings: {
            if (read == null) ParseWarning.dateFromNow,
            if (read != null && read.yearInferred) ParseWarning.yearInferred,
            if (shop.isEmpty) ParseWarning.noCounterparty,
          },
          raw: [
            if (shop.isNotEmpty) shop,
            if (_text(decoded['total']) != null)
              '합계 ${_text(decoded['total'])}',
          ].join(' '),
        ),
      ],
    );
  }
}

class _Outcome {
  const _Outcome(VisionExtraction this.extraction) : problem = null;

  const _Outcome.problem(String this.problem) : extraction = null;

  final VisionExtraction? extraction;
  final String? problem;
}

/// 비어 있지 않은 글자. 숫자로 답한 값도 글자로 바꿔 받는다.
String? _text(Object? value) {
  final text = switch (value) {
    final String s => s.trim(),
    final num n => '$n',
    _ => '',
  };
  return text.isEmpty ? null : text;
}
