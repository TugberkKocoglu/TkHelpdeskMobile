import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../models/notification_page_model.dart';

class NotificationRepository {
  NotificationRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  dynamic _readData(dynamic responseData) {
    final envelope = Map<String, dynamic>.from(responseData as Map);

    if (envelope['success'] != true) {
      throw StateError('Bildirim işlemi başarısız.');
    }

    return envelope['data'];
  }

  Future<NotificationPageModel> getNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/notifications',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );

    return NotificationPageModel.fromJson(
      Map<String, dynamic>.from(_readData(response.data) as Map),
    );
  }

  Future<void> markAsRead(int notificationId) async {
    final response = await _dio.patch('/notifications/$notificationId/read');

    final envelope = Map<String, dynamic>.from(response.data as Map);

    if (envelope['success'] != true) {
      throw StateError('Bildirim okundu olarak işaretlenemedi.');
    }
  }

  Future<int> markAllAsRead() async {
    final response = await _dio.patch('/notifications/read-all');

    final data = Map<String, dynamic>.from(_readData(response.data) as Map);

    return (data['updatedCount'] as num).toInt();
  }
}
