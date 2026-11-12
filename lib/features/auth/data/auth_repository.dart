import 'package:dio/dio.dart';

import '../../../core/network/auth_token_manager.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/auth_tokens.dart';
import '../models/auth_user.dart';
import '../models/login_result.dart';

class AuthRepository {
  AuthRepository({
    required DioClient dioClient,
    required SecureStorageService storage,
    required AuthTokenManager tokenManager,
  }) : _dio = dioClient.dio,
       _storage = storage,
       _tokenManager = tokenManager;

  final Dio _dio;
  final SecureStorageService _storage;
  final AuthTokenManager _tokenManager;

  Map<String, dynamic> _responseData(dynamic responseData) {
    final envelope = Map<String, dynamic>.from(responseData as Map);

    if (envelope['success'] != true) {
      throw StateError('API işlemi başarısız.');
    }

    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final result = LoginResult.fromJson(_responseData(response.data));

    await _storage.saveAccessToken(result.tokens.accessToken);

    await _storage.saveRefreshToken(result.tokens.refreshToken);
    _tokenManager.activateSession();

    return result.user;
  }

  Future<AuthUser> getCurrentUser(String accessToken) async {
    final response = await _dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    return AuthUser.fromJson(_responseData(response.data));
  }

  Future<AuthTokens> refresh() {
    return _tokenManager.refreshTokens();
  }

  Future<AuthUser?> restoreSession() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearTokens();
      return null;
    }

    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        // Access token süresi dolmuşsa interceptor
        // yeniler ve /auth/me isteğini tekrarlar.
        return await getCurrentUser(accessToken);
      }

      // Access token yok, ancak refresh token varsa
      // yeniden access token üret.
      final tokens = await refresh();

      return await getCurrentUser(tokens.accessToken);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;

      if (statusCode == 401 || statusCode == 403) {
        await _tokenManager.invalidateSession();
        return null;
      }

      // İnternet kesilirse tokenları koru.
      rethrow;
    }
  }

  Future<void> logout() {
    return _tokenManager.logout(
      revokeToken: (refreshToken) async {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      },
    );
  }
}
