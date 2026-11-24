import 'package:flutter/services.dart';

import '../../core/formatters.dart';

/// 금액 입력란에 천 단위 쉼표를 넣는다.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final amount = parseAmountInput(newValue.text);
    if (amount == null) return const TextEditingValue();
    final text = formatNumber(amount);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 좁은 칸에 적는 줄인 금액. 12,500 → '1.3만', 125,000 → '12.5만', 1억 2천만 → '1.2억'.
///
/// 만 원 미만은 그대로 적는다. 부호는 붙이지 않는다([value]의 크기만 쓴다).
String compactAmount(int value) {
  final v = value.abs();
  if (v < 10000) return formatNumber(v);
  // 소수 첫째 자리까지 반올림하고, 세 자리가 넘으면 소수를 버린다.
  String scaled(int unit, String suffix) {
    final tenths = (v * 10 + unit ~/ 2) ~/ unit;
    if (tenths >= 1000) {
      return '${formatNumber((v + unit ~/ 2) ~/ unit)}$suffix';
    }
    final whole = tenths ~/ 10;
    final fraction = tenths % 10;
    return fraction == 0 ? '$whole$suffix' : '$whole.$fraction$suffix';
  }

  // 9,999.5만은 만으로 적으면 '10,000만'이 되므로 억으로 넘긴다.
  if (v < 99995000) return scaled(10000, '만');
  return scaled(100000000, '억');
}

/// 부호를 붙인 줄인 금액. 0보다 크면 '+', 작으면 '-'.
String signedCompactAmount(int value) =>
    '${value < 0 ? '-' : '+'}${compactAmount(value)}';
