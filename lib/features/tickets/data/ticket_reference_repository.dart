import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../models/ticket_company_model.dart';
import '../models/ticket_department_model.dart';

class TicketReferenceRepository {
  TicketReferenceRepository({required DioClient dioClient})
    : _dio = dioClient.dio;

  final Dio _dio;

  dynamic _readData(dynamic responseData) {
    final envelope = Map<String, dynamic>.from(responseData as Map);

    if (envelope['success'] != true) {
      throw StateError('Veriler alınamadı.');
    }

    return envelope['data'];
  }

  Future<List<TicketCompanyModel>> getActiveCompanies() async {
    final response = await _dio.get('/companies');

    final data = _readData(response.data) as List;

    return data
        .map(
          (item) => TicketCompanyModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where((company) => company.isActive)
        .toList();
  }

  Future<List<TicketDepartmentModel>> getAvailableDepartments() async {
    final response = await _dio.get('/departments');

    final data = _readData(response.data) as List;

    return data
        .map(
          (item) => TicketDepartmentModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where((department) => department.canReceiveTickets)
        .toList();
  }

  Future<List<TicketDepartmentModel>> getAllDepartments() async {
    final response = await _dio.get('/departments');

    final data = _readData(response.data) as List;

    return data.map((item) {
      return TicketDepartmentModel.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();
  }
}
