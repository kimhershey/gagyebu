import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/llm/llm_engine.dart';
import '../ai/vision/vision_engine.dart';

/// 기기 내 LLM. 모델이 없는 기기(웹 앱, 저사양 폰)와 모델을 내려받기 전에는 null이고,
/// 그때는 규칙만으로 해석한다.
final llmEngineProvider = Provider<LlmEngine?>((ref) => null);

/// 이미지를 읽는 모델. 없으면 null이고 이미지 입력을 쓸 수 없다.
final visionEngineProvider = Provider<VisionEngine?>((ref) => null);
