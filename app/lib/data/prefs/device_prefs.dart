import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 이 기기에만 두는 설정. 서버로 올라가지 않고, 계정을 바꿔도 남는다.
///
/// 로컬 DB가 아니라 여기에 두는 까닭은 DB를 열기 전에(첫 화면을 그리기 전에) 읽어야
/// 하는 값이 있기 때문이다. 키는 `docs/SPEC.md` 3.1에 적는다.
abstract interface class DevicePrefs {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// 기기의 설정 저장소(`shared_preferences`)에 둔다.
class SharedDevicePrefs implements DevicePrefs {
  SharedDevicePrefs(this._prefs);

  final SharedPreferences _prefs;

  /// 저장소를 읽어 온다. 앱이 뜨기 전에 한 번 부른다.
  static Future<SharedDevicePrefs> load() async =>
      SharedDevicePrefs(await SharedPreferences.getInstance());

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// 메모리에만 두는 설정. 시험과, 저장소를 읽지 못했을 때 쓴다.
class MemoryDevicePrefs implements DevicePrefs {
  MemoryDevicePrefs([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// 기기 설정. 앱이 시작할 때 읽어 온 것으로 덮어쓴다(`app/bootstrap.dart`).
final devicePrefsProvider = Provider<DevicePrefs>((ref) => MemoryDevicePrefs());
