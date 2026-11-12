import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/models/auth_tokens.dart';
import '../storage/secure_storage_service.dart';
import 'api_config.dart';

class AuthTokenManager {
  AuthTokenManager(this._storage, {Dio? refreshDio})
    : _refreshDio =
          refreshDio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'x-client-platform': 'mobile',
              },
            ),
          );

  final SecureStorageService _storage;
  final Dio _refreshDio;

  final _sessionExpiredController = StreamController<void>.broadcast();

  Future<AuthTokens>? _refreshFuture;

  bool _sessionClosed = false;
  int _sessionGeneration = 0;

  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  Future<AuthTokens> refreshTokens() async {
    if (_sessionClosed) {
      throw StateError('Oturum kapalı.');
    }

    final existingRefresh = _refreshFuture;

    if (existingRefresh != null) {
      return existingRefresh;
    }

    final generation = _sessionGeneration;
    final future = _performRefresh(generation);

    _refreshFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<AuthTokens> _performRefresh(int generation) async {
    final refreshToken = await _storage.getRefreshToken();

    if (_sessionClosed || generation != _sessionGeneration) {
      throw StateError('Oturum değişti.');
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      await invalidateSession();
      throw StateError('Refresh token bulunamadı.');
    }

    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final envelope = Map<String, dynamic>.from(response.data as Map);

      if (envelope['success'] != true) {
        throw StateError('Token yenileme başarısız.');
      }

      final data = Map<String, dynamic>.from(envelope['data'] as Map);

      final tokens = AuthTokens.fromJson(data);

      // Logout devam eden bu isteğin bitmesini bekler.
      // Böylece dönen en yeni refresh token iptal edilir.
      await _storage.saveAccessToken(tokens.accessToken);
      await _storage.saveRefreshToken(tokens.refreshToken);

      return tokens;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;

      if ((statusCode == 401 || statusCode == 403) &&
          generation == _sessionGeneration &&
          !_sessionClosed) {
        await invalidateSession();
      }

      // Bağlantı hatası ve 5xx durumlarında
      // yerel tokenlar korunur.
      rethrow;
    }
  }

  Future<void> invalidateSession() async {
    if (_sessionClosed) {
      return;
    }

    _sessionClosed = true;
    _sessionGeneration++;

    await _storage.clearTokens();

    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  Future<void> logout({
    required Future<void> Function(String refreshToken) revokeToken,
  }) async {
    // Yeni refresh işlemlerini hemen engelle.
    _sessionClosed = true;
    _sessionGeneration++;

    try {
      final pendingRefresh = _refreshFuture;

      if (pendingRefresh != null) {
        try {
          await pendingRefresh;
        } catch (_) {
          // Logout yine de tamamlanacak.
        }
      }

      // Başarılı bir refresh gerçekleştiyse
      // artık depoda en yeni refresh token bulunur.
      final refreshToken = await _storage.getRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await revokeToken(refreshToken);
      }
    } finally {
      await _storage.clearTokens();
    }
  }

  void activateSession() {
    _sessionGeneration++;
    _sessionClosed = false;
  }

  Future<void> dispose() async {
    await _sessionExpiredController.close();
    _refreshDio.close();
  }
}
