import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/models/auth_user.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._repository) : super(const DashboardState()) {
    on<DashboardStarted>(_onStarted);
    on<DashboardRefreshRequested>(_onRefresh);
  }

  final DashboardRepository _repository;

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    await _load(event.user, emit);
  }

  Future<void> _onRefresh(
    DashboardRefreshRequested event,
    Emitter<DashboardState> emit,
  ) async {
    await _load(event.user, emit);
  }

  Future<void> _load(AuthUser user, Emitter<DashboardState> emit) async {
    emit(const DashboardState(status: DashboardStatus.loading));

    try {
      if (user.isHelpdesk) {
        final summary = await _repository.getHelpdeskSummary(
          year: DateTime.now().toUtc().year,
        );

        emit(
          DashboardState(
            status: DashboardStatus.success,
            helpdeskSummary: summary,
          ),
        );

        return;
      }

      if (user.isEmployee) {
        final summary = await _repository.getEmployeeSummary(
          currentUserId: user.id,
        );

        emit(
          DashboardState(
            status: DashboardStatus.success,
            employeeSummary: summary,
          ),
        );

        return;
      }

      emit(
        const DashboardState(
          status: DashboardStatus.failure,
          errorMessage: 'Geçersiz kullanıcı rolü.',
        ),
      );
    } catch (error) {
      emit(
        DashboardState(
          status: DashboardStatus.failure,
          errorMessage: _getErrorMessage(error),
        ),
      );
    }
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Sunucuya bağlanılamadı. '
            'API bağlantınızı kontrol edin.';
      }
    }

    return 'Dashboard verileri alınamadı. '
        'Lütfen tekrar deneyin.';
  }
}
