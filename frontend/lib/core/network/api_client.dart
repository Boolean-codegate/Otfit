import 'package:dio/dio.dart';

import '../../models/fitting_result.dart' show ApiError, ApiErrorCodes, ApiException;
import 'token_storage.dart';

/// dio 기반 공용 API 클라이언트.
///
/// - 모든 인증 요청에 `Authorization: Bearer` 자동 첨부
/// - 401 → `/auth/refresh` 로 갱신 후 원요청 1회 재시도, 실패 시 토큰 폐기(로그아웃)
/// - 에러 응답 `{error:{code,message,detail}}` → [ApiException] 매핑
/// - (개발용) 토큰이 없고 DEV_LOGIN_* define이 있으면 자동 로그인/가입
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokens,
    this.onLoggedOut,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           // live 모드에서 analyze(Sol 비전)가 30초를 넘길 수 있어 넉넉히 잡는다
           receiveTimeout: const Duration(seconds: 180),
         ),
       ) {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const Set<String> _publicPaths = <String>{
    '/auth/register',
    '/auth/login',
    '/auth/refresh',
    '/health',
  };

  final Dio dio;
  final TokenStorage tokens;
  final void Function()? onLoggedOut;

  Future<void>? _refreshing;

  bool _isPublic(String path) => _publicPaths.contains(path);

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final access = await tokens.readAccessToken();
      if (access != null) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException exception,
    ErrorInterceptorHandler handler,
  ) async {
    final response = exception.response;
    final path = exception.requestOptions.path;

    // 401 → refresh 후 원요청 1회 재시도
    if (response?.statusCode == 401 &&
        !_isPublic(path) &&
        exception.requestOptions.extra['retried'] != true) {
      try {
        await _refreshTokens();
        final retried = await _retry(exception.requestOptions);
        return handler.resolve(retried);
      } on Object {
        await logout();
      }
    }
    handler.reject(exception);
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    options.extra['retried'] = true;
    final access = await tokens.readAccessToken();
    if (access != null) options.headers['Authorization'] = 'Bearer $access';
    return dio.fetch<dynamic>(options);
  }

  /// refresh 동시 호출 방지(single-flight).
  Future<void> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    final refresh = await tokens.readRefreshToken();
    if (refresh == null) {
      throw const ApiException(
        ApiError(code: ApiErrorCodes.unauthorized, message: '로그인이 필요해요.'),
        statusCode: 401,
      );
    }
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: <String, dynamic>{'refresh_token': refresh},
    );
    final data = response.data ?? const <String, dynamic>{};
    await tokens.saveTokens(
      accessToken: data['access_token'].toString(),
      refreshToken: data['refresh_token'].toString(),
    );
    // 재시도 요청에 새 토큰이 붙도록 갱신
  }

  Future<void> saveSession(Map<String, dynamic> authResponse) async {
    await tokens.saveTokens(
      accessToken: authResponse['access_token'].toString(),
      refreshToken: authResponse['refresh_token'].toString(),
    );
  }

  Future<void> logout() async {
    await tokens.clear();
    onLoggedOut?.call();
  }

  /// dio 예외 → 계약 에러 포맷의 [ApiException].
  static ApiException mapError(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;
      if (data is Map) {
        return ApiException(
          ApiError.fromJson(Map<String, dynamic>.from(data)),
          statusCode: response?.statusCode,
        );
      }
      return ApiException(
        ApiError(
          code: 'NETWORK_ERROR',
          message: '서버에 연결할 수 없어요. 네트워크를 확인해 주세요.',
          detail: <String, dynamic>{'type': error.type.name},
        ),
        statusCode: response?.statusCode,
      );
    }
    return ApiException(
      ApiError(code: 'UNKNOWN', message: error.toString()),
    );
  }
}

/// 리포지토리 공용 헬퍼: dio 호출을 [ApiException]으로 감싼다.
Future<T> guardApi<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on Object catch (error) {
    throw ApiClient.mapError(error);
  }
}
