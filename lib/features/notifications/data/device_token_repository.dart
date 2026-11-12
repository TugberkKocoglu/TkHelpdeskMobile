import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class DeviceTokenRepository {
  DeviceTokenRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Future<void> register({
    required String token,
    required String platform,
  }) async {
    await _dio.post(
      '/device-tokens',
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> deactivate(String token) async {
    await _dio.delete('/device-tokens', data: {'token': token});
  }
}
