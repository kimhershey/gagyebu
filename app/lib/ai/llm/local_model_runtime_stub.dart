import 'local_model_runtime.dart';

/// 이 플랫폼(웹)에는 기기 안의 모델을 돌릴 런타임이 없다.
const bool localModelRuntimeAvailable = false;

/// 런타임이 없으므로 부르면 안 된다. [localModelRuntimeAvailable]을 먼저 본다.
LocalModelRuntime createLocalModelRuntime(LocalModelSpec spec) =>
    throw UnsupportedError('이 플랫폼에는 기기 안의 모델이 없다');
