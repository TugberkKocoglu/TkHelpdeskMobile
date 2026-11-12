import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tkhelpdesk_mobile/core/network/auth_token_manager.dart';
import 'package:tkhelpdesk_mobile/core/storage/secure_storage_service.dart';

class FakeSessionStorage extends SecureStorageService {
  String? accessToken = 'old-access';
  String? refreshToken = 'old-refresh';

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refreshToken = token;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Logout devam eden refresh tamamlandiktan '
      'sonra guncel tokeni iptal eder', () async {
    final storage = FakeSessionStorage();

    final refreshStarted = Completer<void>();
    final completeRefresh = Completer<void>();

    final refreshDio = Dio();

    refreshDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          expect(options.path, '/auth/refresh');

          refreshStarted.complete();

          // Sunucunun yanıtını test kontrol ediyor.
          await completeRefresh.future;

          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                  'tokenType': 'Bearer',
                  'expiresIn': 900,
                },
              },
            ),
          );
        },
      ),
    );

    final manager = AuthTokenManager(storage, refreshDio: refreshDio);

    try {
      // 1. Refresh başlar fakat yanıt bekler.
      final refreshFuture = manager.refreshTokens();

      await refreshStarted.future;

      // 2. Refresh bitmeden Logout başlatılır.
      String? revokedToken;

      final logoutFuture = manager.logout(
        revokeToken: (token) async {
          revokedToken = token;
        },
      );

      // 3. Logout devam ederken yeni refresh engellenir.
      await expectLater(manager.refreshTokens(), throwsStateError);

      // 4. Bekleyen refresh yanıtı gelir.
      completeRefresh.complete();

      await refreshFuture;
      await logoutFuture;

      // 5. Logout eski değil, yeni tokenı iptal eder.
      expect(revokedToken, 'new-refresh');

      // 6. Yerel oturum tamamen temizlenir.
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    } finally {
      if (!completeRefresh.isCompleted) {
        completeRefresh.complete();
      }

      await manager.dispose();
    }
  });

  test('Gecersiz refresh token oturumu temizler', () async {
    final storage = FakeSessionStorage();
    final refreshDio = Dio();

    refreshDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'success': false, 'message': 'Refresh token geçersiz.'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final manager = AuthTokenManager(storage, refreshDio: refreshDio);

    try {
      final expiredEvent = manager.sessionExpired.first;

      await expectLater(manager.refreshTokens(), throwsA(isA<DioException>()));

      // AuthBloc'un dinlediği olay gönderilmeli.
      await expiredEvent;

      // Geçersiz oturumun tokenları silinmeli.
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);

      // Yeni bir Login yapılana kadar refresh kapalı.
      await expectLater(manager.refreshTokens(), throwsStateError);
    } finally {
      await manager.dispose();
    }
  });
}
