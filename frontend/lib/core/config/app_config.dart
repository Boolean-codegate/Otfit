/// Runtime configuration shared by mock and future HTTP repositories.
///
/// Run with `--dart-define=API_BASE_URL=https://api.example.com` when a real
/// backend implementation is added. The MVP defaults to local mock data.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'mock://local',
  );

  static bool get usesMockApi => apiBaseUrl.startsWith('mock://');

  /// 개발용 자동 로그인 (아직 로그인 UI가 없어 통합 테스트에 사용).
  /// `--dart-define=DEV_LOGIN_EMAIL=... --dart-define=DEV_LOGIN_PASSWORD=...`
  /// 를 넘기면 HTTP 모드에서 토큰이 없을 때 자동으로 로그인/가입한다.
  /// 로그인 UI가 생기면 이 값 없이 실행하면 된다.
  static const String devLoginEmail = String.fromEnvironment('DEV_LOGIN_EMAIL');
  static const String devLoginPassword = String.fromEnvironment(
    'DEV_LOGIN_PASSWORD',
  );

  static bool get hasDevLogin =>
      devLoginEmail.isNotEmpty && devLoginPassword.isNotEmpty;

  /// 소셜 로그인 키 (미설정 시 버튼은 안내만 표시 — web-login-demo와 동일한 정책).
  static const String kakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY');
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
}
