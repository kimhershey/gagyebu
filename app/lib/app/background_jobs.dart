import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/server/realtime.dart';
import '../features/recurring/recurring_runner.dart';

/// 화면이 떠 있는 동안 뒤에서 도는 일을 켠다. 뼈대가 본다.
///
/// 일을 더하려면 그 일을 하는 제공자를 만들고 여기서 켠다.
final backgroundJobsProvider = Provider<void>((ref) {
  ref.watch(recurringRunnerProvider);
  ref.watch(realtimeSyncProvider);
});
