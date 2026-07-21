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
}
