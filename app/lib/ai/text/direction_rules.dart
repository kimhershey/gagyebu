/// 원문의 낱말로 돈의 방향을 정하는 규칙.
library;

import '../parsed_transaction.dart';

/// 들어온 돈을 뜻하는 낱말.
final incomingWords = RegExp(
  r'월급|급여|상여|보너스|성과급|용돈\s?받|입금|받음|받았|환급|이자\s?(?:입금|받)|배당|수입|들어옴|들어왔'
  r'|보내\s?(?:줌|줬|주셨|주심)',
);

/// 나간 돈을 뜻하는 낱말.
final outgoingWords = RegExp(r'출금|승인|결제|사용|보냄|보냈|납부|구매|지출|이체|냄(?![가-힣])|냈');

/// 낱말로 방향을 정할 수 있으면 그 방향, 양쪽 낱말이 다 있거나 없으면 null.
Direction? directionFromKeywords(String text) {
  final incoming = incomingWords.hasMatch(text);
  final outgoing = outgoingWords.hasMatch(text);
  if (incoming == outgoing) return null;
  return incoming ? Direction.incoming : Direction.outgoing;
}

/// 취소 · 환불을 뜻하는 낱말이 있는지.
bool mentionsCancel(String text) => _cancelWords.hasMatch(text);

final _cancelWords = RegExp(r'취소|환불');
