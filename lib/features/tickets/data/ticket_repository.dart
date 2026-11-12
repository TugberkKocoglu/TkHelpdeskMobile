import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../models/ticket_filter.dart';
import '../models/ticket_model.dart';
import '../models/ticket_page.dart';
import '../models/ticket_detail_model.dart';
import '../models/ticket_comment_model.dart';

class TicketRepository {
  TicketRepository({required DioClient dioClient}) : _dio = dioClient.dio;

  final Dio _dio;

  dynamic _readData(dynamic responseData) {
    final envelope = Map<String, dynamic>.from(responseData as Map);

    if (envelope['success'] != true) {
      throw StateError('Talep işlemi başarısız.');
    }

    return envelope['data'];
  }

  Future<TicketPage> getTickets({
    TicketFilter filter = const TicketFilter(),
  }) async {
    final response = await _dio.get(
      '/tickets',
      queryParameters: filter.toQueryParameters(),
    );

    return TicketPage.fromJson(
      Map<String, dynamic>.from(_readData(response.data) as Map),
    );
  }

  Future<TicketModel> getTicketById(int ticketId) async {
    final response = await _dio.get('/tickets/$ticketId');

    return TicketModel.fromJson(
      Map<String, dynamic>.from(_readData(response.data) as Map),
    );
  }

  Future<TicketModel> createTicket({
    required int companyId,
    required int departmentId,
    required String title,
    required String description,
    TicketPriority priority = TicketPriority.normal,
  }) async {
    final response = await _dio.post(
      '/tickets',
      data: {
        'companyId': companyId,
        'departmentId': departmentId,
        'title': title.trim(),
        'description': description.trim(),
        'priority': priority.value,
      },
    );

    return TicketModel.fromJson(
      Map<String, dynamic>.from(_readData(response.data) as Map),
    );
  }

  Future<TicketModel> claimTicket(int ticketId) async {
    final response = await _dio.post('/tickets/$ticketId/claim');

    return _readTicket(response.data);
  }

  Future<TicketModel> startTicket(int ticketId) async {
    final response = await _dio.patch('/tickets/$ticketId/start');

    return _readTicket(response.data);
  }

  Future<TicketModel> closeTicket({
    required int ticketId,
    required String resolutionNote,
  }) async {
    final response = await _dio.patch(
      '/tickets/$ticketId/close',
      data: {'resolutionNote': resolutionNote.trim()},
    );

    return _readTicket(response.data);
  }

  Future<TicketModel> updatePriority({
    required int ticketId,
    required TicketPriority priority,
  }) async {
    final response = await _dio.patch(
      '/tickets/$ticketId/priority',
      data: {'priority': priority.value},
    );

    return _readTicket(response.data);
  }

  TicketModel _readTicket(dynamic responseData) {
    return TicketModel.fromJson(
      Map<String, dynamic>.from(_readData(responseData) as Map),
    );
  }

  Future<TicketDetailModel> getTicketDetail(int ticketId) async {
    final response = await _dio.get('/tickets/$ticketId');

    return TicketDetailModel.fromJson(
      Map<String, dynamic>.from(_readData(response.data) as Map),
    );
  }

  Future<List<TicketCommentModel>> getTicketComments(int ticketId) async {
    final response = await _dio.get('/tickets/$ticketId/comments');

    final data = _readData(response.data) as List;

    return data.map((item) {
      return TicketCommentModel.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();
  }

  Future<void> addTicketComment({
    required int ticketId,
    required String content,
  }) async {
    await _dio.post(
      '/tickets/$ticketId/comments',
      data: {'content': content.trim()},
    );
  }
}
