/// 서버 주소와 공개 키. 빌드할 때 넣는다.
///
///   flutter build web --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///                     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx
///
/// 둘 다 공개해도 되는 값이다(앱에 그대로 들어간다). 데이터는 서버의 행 단위 보안 정책이
/// 지킨다. service_role 키와 DB 비밀번호는 앱이나 저장소에 넣지 않는다.
class ServerConfig {
  const ServerConfig({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// 빌드 설정에서 읽는다. 넣지 않았으면 null이고, 앱은 로그인 없이 동작한다.
  static ServerConfig? fromEnvironment() => (_url.isEmpty || _key.isEmpty)
      ? null
      : const ServerConfig(url: _url, publishableKey: _key);
}
