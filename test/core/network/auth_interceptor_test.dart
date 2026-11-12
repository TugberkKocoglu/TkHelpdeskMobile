import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkhelpdesk_mobile/core/network/auth_token_manager.dart';
import 'package:tkhelpdesk_mobile/core/network/dio_client.dart';
import 'package:tkhelpdesk_mobile/core/storage/secure_storage_service.dart';

class FakeStorage extends SecureStorageService {
  String? accessToken = 'old-access-token';
  String? refreshToken = 'old-refresh-token';

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

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Map<String, dynamic> data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('401 sonrasi token yenilenir ve orijinal istek tekrar edilir', () async {
    final storage = FakeStorage();

    var refreshCount = 0;
    var meRequestCount = 0;

    // Refresh isteği için ayrı Dio.
    final refreshDio = Dio();

    refreshDio.httpClientAdapter = FakeHttpAdapter((options) async {
      expect(options.method, 'POST');
      expect(options.path, '/auth/refresh');
      expect(options.data['refreshToken'], 'old-refresh-token');

      refreshCount++;

      return jsonResponse({
        'success': true,
        'data': {
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'tokenType': 'Bearer',
          'expiresIn': 900,
        },
      }, 200);
    });

    final tokenManager = AuthTokenManager(storage, refreshDio: refreshDio);

    final dioClient = DioClient(storage: storage, tokenManager: tokenManager);

    // /auth/me endpoint'ini taklit ediyoruz.
    dioClient.dio.httpClientAdapter = FakeHttpAdapter((options) async {
      expect(options.method, 'GET');
      expect(options.path, '/auth/me');

      meRequestCount++;

      final authorization = options.headers['Authorization'];

      if (authorization == 'Bearer old-access-token') {
        return jsonResponse({
          'success': false,
          'message': 'Token süresi dolmuş.',
        }, 401);
      }

      if (authorization == 'Bearer new-access-token') {
        return jsonResponse({
          'success': true,
          'data': {
            'id': 1,
            'firstName': 'Test',
            'lastName': 'Kullanıcı',
            'email': 'test@example.com',
            'role': 'Helpdesk',
            'departmentId': 1,
          },
        }, 200);
      }

      return jsonResponse({
        'success': false,
        'message': 'Geçersiz Authorization.',
      }, 401);
    });

    try {
      final response = await dioClient.dio.get('/auth/me');

      // İlk istek 401, ikinci istek 200.
      expect(meRequestCount, 2);

      // Refresh yalnızca bir kez çağrıldı.
      expect(refreshCount, 1);

      // İstek sonunda başarılı.
      expect(response.statusCode, 200);
      expect(response.data['success'], true);

      // Kullanıcı bilgileri geldi.
      expect(response.data['data']['firstName'], 'Test');

      // Yeni tokenlar güvenli depolamaya yazıldı.
      expect(await storage.getAccessToken(), 'new-access-token');

      expect(await storage.getRefreshToken(), 'new-refresh-token');
    } finally {
      dioClient.dio.close();
      await tokenManager.dispose();
    }
  });
}
