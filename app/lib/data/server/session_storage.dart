import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 로그인 세션을 둘 곳을 고른다(`docs/SPEC.md` 4.3).
///
/// Android에서는 OS 보안 저장소에 둔다. 웹과 Windows는 null을 돌려주어 `supabase_flutter`의
/// 기본값(브라우저 저장소, 앱 폴더의 파일)을 쓴다.
LocalStorage? sessionStorageFor(String serverUrl) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  return SecureSessionStorage(key: sessionKeyFor(serverUrl));
}

/// 세션을 적어 두는 이름. `supabase_flutter`가 기본 저장소에 쓰는 이름과 같게 해서, 기본
/// 저장소에 남아 있던 세션을 찾아 옮길 수 있게 한다.
String sessionKeyFor(String serverUrl) =>
    'sb-${Uri.parse(serverUrl).host.split('.').first}-auth-token';

/// 문자열 하나를 읽고 쓰고 지우는 저장소. 시험에서 바꿔 끼운다.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// OS 보안 저장소(Android Keystore로 잠근 저장소).
class OsSecretStore implements SecretStore {
  const OsSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 로그인 세션을 보안 저장소에 두는 `supabase_flutter`의 저장소.
///
/// 보안 저장소는 기기를 복원했거나 OS의 키가 바뀌면 읽지 못할 수 있다. 그때는 세션이 없는
/// 것으로 본다(다시 로그인하면 된다). 저장하지 못해도 로그인은 이어지고, 앱을 다시 켤 때
/// 로그인을 한 번 더 하게 될 뿐이다.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required this.key,
    this._store = const OsSecretStore(),
    Future<LegacySessionStore> Function()? legacy,
  }) : _legacy = legacy ?? _sharedPreferences;

  final String key;
  final SecretStore _store;
  final Future<LegacySessionStore> Function() _legacy;

  static Future<LegacySessionStore> _sharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return (read: prefs.getString, remove: prefs.remove);
  }

  @override
  Future<void> initialize() async {
    // 보안 저장소를 쓰기 전의 앱은 세션을 일반 설정 저장소에 두었다. 남아 있으면 옮기고
    // 지운다(로그인이 풀리지 않게, 그리고 평문으로 남지 않게).
    try {
      final legacy = await _legacy();
      final old = legacy.read(key);
      if (old == null) return;
      if (await _read() == null) await _store.write(key, old);
      await legacy.remove(key);
    } catch (e) {
      debugPrint('옛 세션을 옮기지 못했다: $e');
    }
  }

  Future<String?> _read() async {
    try {
      return await _store.read(key);
    } catch (e) {
      debugPrint('보안 저장소에서 세션을 읽지 못했다: $e');
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async => await _read() != null;

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<void> removePersistedSession() async {
    try {
      await _store.delete(key);
    } catch (e) {
      debugPrint('보안 저장소의 세션을 지우지 못했다: $e');
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _store.write(key, persistSessionString);
    } catch (e) {
      debugPrint('보안 저장소에 세션을 적지 못했다: $e');
    }
  }
}

/// 보안 저장소를 쓰기 전에 세션을 두던 곳(`shared_preferences`)에서 읽고 지우는 함수.
typedef LegacySessionStore = ({
  String? Function(String key) read,
  Future<bool> Function(String key) remove,
});
