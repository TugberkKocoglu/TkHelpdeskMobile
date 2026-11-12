import 'dart:async';
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

  test('Uc eszamanli 401 yaniti tek refresh yapar', () async {
    final storage = FakeStorage();

    var refreshCount = 0;
    var oldRequestCount = 0;
    var successfulRequestCount = 0;

    final allOldRequestsStarted = Completer<void>();
    final releaseRefresh = Completer<void>();

    final refreshDio = Dio();

    refreshDio.httpClientAdapter = FakeHttpAdapter((options) async {
      expect(options.path, '/auth/refresh');
      expect(options.method, 'POST');

      refreshCount++;

      expect(options.data['refreshToken'], 'old-refresh-token');

      // Refresh yanitini test kontrol edecek.
      await releaseRefresh.future;

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

    final manager = AuthTokenManager(storage, refreshDio: refreshDio);

    final dioClient = DioClient(storage: storage, tokenManager: manager);

    final endpoints = {'/reports/summary', '/tickets', '/notifications'};

    dioClient.dio.httpClientAdapter = FakeHttpAdapter((options) async {
      expect(endpoints.contains(options.path), isTrue);
      expect(options.method, 'GET');

      final authorization = options.headers['Authorization'];

      if (authorization == 'Bearer old-access-token') {
        oldRequestCount++;

        if (oldRequestCount == 3 && !allOldRequestsStarted.isCompleted) {
          allOldRequestsStarted.complete();
        }

        // Uc istegin de eski tokenla baslamasini bekle.
        await allOldRequestsStarted.future;

        return jsonResponse({
          'success': false,
          'message': 'Access token suresi doldu.',
        }, 401);
      }

      if (authorization == 'Bearer new-access-token') {
        successfulRequestCount++;

        return jsonResponse({
          'success': true,
          'data': {'endpoint': options.path, 'result': 'ok'},
        }, 200);
      }

      return jsonResponse({
        'success': false,
        'message': 'Authorization gecersiz.',
      }, 401);
    });

    try {
      final requests = Future.wait([
        dioClient.dio.get('/reports/summary'),
        dioClient.dio.get('/tickets'),
        dioClient.dio.get('/notifications'),
      ]);

      // Refresh yanitini serbest birak.
      // Future.wait'in hata vermemesi icin hemen beklemiyoruz.
      await allOldRequestsStarted.future;
      releaseRefresh.complete();

      final responses = await requests;

      // Uc istegin tamamı eski tokenla 401 aldi.
      expect(oldRequestCount, 3);

      // Backend'e tek refresh gonderildi.
      expect(refreshCount, 1);

      // Uc istek yeni tokenla tekrar edildi.
      expect(successfulRequestCount, 3);

      // Hepsi basarili dondu.
      expect(responses.length, 3);

      for (final response in responses) {
        expect(response.statusCode, 200);
        expect(response.data['success'], true);
        expect(response.data['data']['result'], 'ok');
      }

      // Yeni tokenlar saklandi.
      expect(await storage.getAccessToken(), 'new-access-token');

      expect(await storage.getRefreshToken(), 'new-refresh-token');
    } finally {
      if (!releaseRefresh.isCompleted) {
        releaseRefresh.complete();
      }

      dioClient.dio.close();
      await manager.dispose();
    }
  });
}
