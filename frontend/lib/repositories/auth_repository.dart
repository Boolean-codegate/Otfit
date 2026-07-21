import '../core/network/api_client.dart';
import '../models/fitting_result.dart' show User;

/// 계약 §1: /auth/register, /auth/login, /auth/social, /auth/refresh, GET /me
abstract class AuthRepository {
  Future<User> register({
    required String email,
    required String password,
    required String nickname,
  });

  Future<User> login({required String email, required String password});

  /// 카카오/구글 SDK 토큰으로 로그인 (kakao → access_token, google → id_token).
  /// 미가입 사용자는 서버가 자동 가입 처리한다.
  Future<User> socialLogin({required String provider, required String token});

  Future<User> me();

  Future<void> logout();
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client);

  final ApiClient _client;

  Future<User> _authenticate(String path, Map<String, dynamic> body) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      final data = response.data ?? const <String, dynamic>{};
      await _client.saveSession(data);
      return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    });
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String nickname,
  }) {
    return _authenticate('/auth/register', <String, dynamic>{
      'email': email,
      'password': password,
      'nickname': nickname,
    });
  }

  @override
  Future<User> login({required String email, required String password}) {
    return _authenticate('/auth/login', <String, dynamic>{
      'email': email,
      'password': password,
    });
  }

  @override
  Future<User> socialLogin({required String provider, required String token}) {
    return _authenticate('/auth/social', <String, dynamic>{
      'provider': provider,
      'token': token,
    });
  }

  @override
  Future<User> me() {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>('/me');
      return User.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<void> logout() => _client.logout();
}

class MockAuthRepository implements AuthRepository {
  User _user = User(
    id: 'u_mock_1',
    email: 'mock@otfit.local',
    nickname: '오핏',
    creditBalance: 30,
    isPremium: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  @override
  Future<User> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    _user = User(
      id: 'u_mock_1',
      email: email,
      nickname: nickname,
      creditBalance: 30,
      isPremium: false,
      createdAt: DateTime.now().toUtc(),
    );
    return _user;
  }

  @override
  Future<User> login({required String email, required String password}) async =>
      _user;

  @override
  Future<User> socialLogin({
    required String provider,
    required String token,
  }) async => _user;

  @override
  Future<User> me() async => _user;

  @override
  Future<void> logout() async {}
}
