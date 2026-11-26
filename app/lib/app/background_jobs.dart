import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/llm/llama_server.dart';
import '../ai/llm/llm_engine.dart';

import '../data/repositories/conflict_repository.dart';
import '../data/server/realtime.dart';
import '../features/recurring/recurring_runner.dart';
import 'engine_providers.dart';

/// 화면이 떠 있는 동안 뒤에서 도는 일을 켠다. 뼈대가 본다.
///
/// 일을 더하려면 그 일을 하는 제공자를 만들고 여기서 켠다.
final backgroundJobsProvider = Provider<void>((ref) {
  ref.watch(recurringRunnerProvider);
  ref.watch(realtimeSyncProvider);
  // Windows: 받아 둔 모델이 있으면 앱을 켤 때 모델 서버를 미리 띄운다. 사용자가 할 일은 없다.
  ref.listen<LlmEngine?>(llmEngineProvider, (_, engine) {
    if (engine is LlamaServerEngine) unawaited(engine.warmUp());
  }, fireImmediately: true);
  // 오래된 충돌 기록은 켤 때 한 번 치운다. 못 치워도 다음에 켤 때 다시 한다.
  Future.microtask(() async {
    try {
      await ref.read(conflictRepositoryProvider).pruneConflicts();
    } catch (_) {}
  });
});
