import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱을 켤 때와 동기화가 끝난 뒤에 밀린 반복 거래를 만든다(`docs/SPEC.md` 7.13).
/// 뼈대가 이 제공자를 켜 둔다(`app/background_jobs.dart`).
final recurringRunnerProvider = Provider<void>((ref) {});
