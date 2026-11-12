import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkhelpdesk_mobile/core/network/auth_token_manager.dart';
import 'package:tkhelpdesk_mobile/core/storage/secure_storage_service.dart';

class FakeSecureStorageService extends SecureStorageService {
  String? accessToken;
  String? refreshToken;

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

  test('Eşzamanlı refresh istekleri tek API çağrısı yapar', () async {
    final storage = FakeSecureStorageService()
      ..accessToken = 'old-access-token'
      ..refreshToken = 'old-refresh-token';

    final fakeDio = Dio();
    var refreshRequestCount = 0;

    fakeDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          refreshRequestCount++;

          expect(options.path, '/auth/refresh');

          expect(options.data['refreshToken'], 'old-refresh-token');

          await Future<void>.delayed(const Duration(milliseconds: 50));

          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'accessToken': 'new-access-token',
                  'refreshToken': 'new-refresh-token',
                  'tokenType': 'Bearer',
                  'expiresIn': 900,
                },
              },
            ),
          );
        },
      ),
    );

    final manager = AuthTokenManager(storage, refreshDio: fakeDio);

    try {
      final results = await Future.wait([
        manager.refreshTokens(),
        manager.refreshTokens(),
        manager.refreshTokens(),
      ]);

      expect(refreshRequestCount, 1);

      expect(results.length, 3);

      for (final tokens in results) {
        expect(tokens.accessToken, 'new-access-token');
        expect(tokens.refreshToken, 'new-refresh-token');
      }

      expect(await storage.getAccessToken(), 'new-access-token');

      expect(await storage.getRefreshToken(), 'new-refresh-token');
    } finally {
      await manager.dispose();
    }
  });
}
