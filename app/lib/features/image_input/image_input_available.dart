import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 이 기기에서 이미지 입력을 쓸 수 있는지(Windows 앱이고 이미지 모델이 준비됐을 때).
/// 입력창이 이미지 단추를 보일지 정하는 데 쓴다.
final imageInputAvailableProvider = Provider<bool>((ref) => false);
