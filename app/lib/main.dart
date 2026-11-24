import 'package:material_ui/material_ui.dart';

import 'app/bootstrap.dart';
import 'data/prefs/device_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  runApp(Bootstrap(prefs: await _loadPrefs()));
}

/// 기기 설정을 읽는다. 첫 화면부터 고른 테마로 그리려고 앱을 띄우기 전에 읽는다.
Future<DevicePrefs> _loadPrefs() async {
  try {
    return await SharedDevicePrefs.load();
  } catch (e) {
    // 저장소를 읽지 못해도 앱은 뜬다. 설정은 이번 실행 동안만 남는다.
    debugPrint('기기 설정을 읽지 못했다: $e');
    return MemoryDevicePrefs();
  }
}
