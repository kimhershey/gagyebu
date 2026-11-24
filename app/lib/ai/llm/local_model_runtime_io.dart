import 'llamadart_runtime.dart';
import 'local_model_runtime.dart';

/// 네이티브 플랫폼에는 llama.cpp 런타임이 있다. 실제로 쓸지는 앱이 플랫폼(Windows ·
/// Android)과 기기 메모리를 보고 정한다.
const bool localModelRuntimeAvailable = true;

/// llama.cpp로 [spec]의 모델을 돌리는 런타임.
LocalModelRuntime createLocalModelRuntime(LocalModelSpec spec) =>
    LlamadartRuntime(spec);
