import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'auth_token_manager.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required SecureStorageService storage,
    required AuthTokenManager tokenManager,
  }) : _dio = dio,
       _storage = storage,
       _tokenManager = tokenManager;

  final Dio _dio;
  final SecureStorageService _storage;
  final AuthTokenManager _tokenManager;

  static const _retryKey = 'authRetried';

  bool _isPublicAuthRequest(String path) {
    final normalizedPath = Uri.parse(path).path;

    return normalizedPath.endsWith('/auth/login') ||
        normalizedPath.endsWith('/auth/refresh') ||
        normalizedPath.endsWith('/auth/logout');
  }

  String? _bearerToken(Object? authorization) {
    if (authorization is! String || !authorization.startsWith('Bearer ')) {
      return null;
    }

    return authorization.substring(7);
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicAuthRequest(options.path)) {
      handler.next(options);
      return;
    }

    try {
      final accessToken = await _storage.getAccessToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        // Repository tarafından açıkça verilen tokenı koru.
        options.headers.putIfAbsent(
          'Authorization',
          () => 'Bearer $accessToken',
        );
      }

      handler.next(options);
    } catch (error) {
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;

    if (err.response?.statusCode != 401 || _isPublicAuthRequest(request.path)) {
      handler.next(err);
      return;
    }

    if (request.extra[_retryKey] == true) {
      await _tokenManager.invalidateSession();
      handler.next(err);
      return;
    }

    try {
      final failedToken = _bearerToken(request.headers['Authorization']);

      final storedToken = await _storage.getAccessToken();

      late final String newAccessToken;

      // Başka bir istek tokenı zaten yenilemiş olabilir.
      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedToken != failedToken) {
        newAccessToken = storedToken;
      } else {
        final tokens = await _tokenManager.refreshTokens();
        newAccessToken = tokens.accessToken;
      }

      final retryOptions = request.copyWith(
        headers: {
          ...request.headers,
          'Authorization': 'Bearer $newAccessToken',
        },
        extra: {...request.extra, _retryKey: true},
      );

      final response = await _dio.fetch<dynamic>(retryOptions);

      handler.resolve(response);
    } on DioException catch (refreshError) {
      handler.next(refreshError);
    } catch (refreshError) {
      handler.next(DioException(requestOptions: request, error: refreshError));
    }
  }
}
