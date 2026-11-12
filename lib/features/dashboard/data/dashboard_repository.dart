import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../models/dashboard_ticket.dart';
import '../models/report_summary.dart';

class DashboardRepository {
  DashboardRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  Map<String, dynamic> _readData(dynamic responseData) {
    final envelope = Map<String, dynamic>.from(responseData as Map);

    if (envelope['success'] != true) {
      throw StateError('API işlemi başarısız.');
    }

    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  Future<ReportSummary> getHelpdeskSummary({
    required int year,
    int? month,
  }) async {
    final response = await _dio.get(
      '/reports/summary',
      queryParameters: {'year': year, 'month': ?month},
    );

    return ReportSummary.fromJson(_readData(response.data));
  }

  Future<EmployeeDashboardSummary> getEmployeeSummary({
    required int currentUserId,
  }) async {
    const pageSize = 100;

    final tickets = <DashboardTicket>[];
    var page = 1;
    var totalPages = 1;

    // API sayfalı çalıştığı için bütün departman
    // taleplerini okuyup doğru sayıları hesaplıyoruz.
    do {
      final response = await _dio.get(
        '/tickets',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );

      final data = _readData(response.data);

      final items = data['items'] as List;

      tickets.addAll(
        items.map(
          (item) =>
              DashboardTicket.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );

      totalPages = (data['totalPages'] as num).toInt();
      page++;
    } while (page <= totalPages);

    return EmployeeDashboardSummary.fromTickets(tickets, currentUserId);
  }
}
