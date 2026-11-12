import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/models/auth_user.dart';
import '../../tickets/data/ticket_reference_repository.dart';

class ProfileRepository {
  ProfileRepository({
    required DioClient dioClient,
    required TicketReferenceRepository referenceRepository,
  }) : _dio = dioClient.dio,
       _referenceRepository = referenceRepository;

  final Dio _dio;
  final TicketReferenceRepository _referenceRepository;

  Future<AuthUser> getProfile() async {
    final response = await _dio.get('/auth/me');

    final envelope = Map<String, dynamic>.from(response.data as Map);

    if (envelope['success'] != true) {
      throw StateError('Profil bilgileri alınamadı.');
    }

    return AuthUser.fromJson(
      Map<String, dynamic>.from(envelope['data'] as Map),
    );
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.patch(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );

    final envelope = Map<String, dynamic>.from(response.data as Map);

    if (envelope['success'] != true) {
      throw StateError('Şifre değiştirilemedi.');
    }

    return envelope['message'] as String? ?? 'Şifreniz başarıyla değiştirildi.';
  }

  Future<String?> getDepartmentName(int? departmentId) async {
    if (departmentId == null) return null;

    final departments = await _referenceRepository.getAllDepartments();

    for (final department in departments) {
      if (department.id == departmentId) {
        return department.name;
      }
    }

    return null;
  }
}
