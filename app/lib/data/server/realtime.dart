import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 서버의 실시간 신호를 듣고 있다가 변경이 생기면 받기를 돌린다(`docs/SPEC.md` 4.4).
/// 뼈대가 이 제공자를 켜 둔다(`app/background_jobs.dart`).
final realtimeSyncProvider = Provider<void>((ref) {});
