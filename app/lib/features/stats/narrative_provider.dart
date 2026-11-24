import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/month_period.dart';

/// 그 달의 총평 문장(`docs/SPEC.md` 7.10). 아직 만들지 않았거나 만들 수 없으면 null.
final monthNarrativeProvider = FutureProvider.family<String?, MonthPeriod>(
  (ref, period) async => null,
);
