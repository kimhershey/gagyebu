import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/engine_providers.dart';

/// 이 기기에서 이미지 입력을 쓸 수 있는지(Windows 앱이고 이미지 모델이 준비됐을 때).
/// 입력창이 이미지 단추를 보일지 정하는 데 쓴다.
///
/// 이미지 모델은 Windows에서만 돌린다(`docs/SPEC.md` 5.4). 메모리가 모자란 PC에서는 엔진
/// 쪽이 모델을 올리지 않아 [visionEngineProvider]가 null로 남는다.
final imageInputAvailableProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      ref.watch(visionEngineProvider) != null,
);
