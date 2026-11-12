import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';
import 'auth_token_manager.dart';

class DioClient {
  DioClient({
    required SecureStorageService storage,
    required AuthTokenManager tokenManager,
  }) : dio = Dio(
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
       ) {
    dio.interceptors.add(
      AuthInterceptor(dio: dio, storage: storage, tokenManager: tokenManager),
    );
  }

  final Dio dio;
}
