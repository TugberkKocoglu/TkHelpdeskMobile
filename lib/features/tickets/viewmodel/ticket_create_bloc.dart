import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ticket_reference_repository.dart';
import '../data/ticket_repository.dart';
import '../models/ticket_company_model.dart';
import '../models/ticket_department_model.dart';
import 'ticket_create_event.dart';
import 'ticket_create_state.dart';
import 'package:flutter/foundation.dart';

class TicketCreateBloc extends Bloc<TicketCreateEvent, TicketCreateState> {
  TicketCreateBloc({
    required TicketRepository ticketRepository,
    required TicketReferenceRepository referenceRepository,
  }) : _ticketRepository = ticketRepository,
       _referenceRepository = referenceRepository,
       super(const TicketCreateState()) {
    on<TicketCreateStarted>(_onStarted);
    on<TicketCreateRefreshRequested>(_onRefresh);
    on<TicketCreateSubmitted>(_onSubmitted);
  }

  final TicketRepository _ticketRepository;
  final TicketReferenceRepository _referenceRepository;

  bool _busy = false;

  Future<void> _onStarted(
    TicketCreateStarted event,
    Emitter<TicketCreateState> emit,
  ) async {
    if (_busy || state.status != TicketCreateStatus.initial) {
      return;
    }

    await _loadReferenceData(emit);
  }

  Future<void> _onRefresh(
    TicketCreateRefreshRequested event,
    Emitter<TicketCreateState> emit,
  ) async {
    if (_busy || state.status == TicketCreateStatus.success) {
      return;
    }

    await _loadReferenceData(emit);
  }

  Future<void> _loadReferenceData(Emitter<TicketCreateState> emit) async {
    _busy = true;

    emit(state.copyWith(status: TicketCreateStatus.loading, clearError: true));

    try {
      final results = await Future.wait<dynamic>([
        _referenceRepository.getActiveCompanies(),
        _referenceRepository.getAvailableDepartments(),
      ]);

      final companies = results[0] as List<TicketCompanyModel>;
      final departments = results[1] as List<TicketDepartmentModel>;

      emit(
        state.copyWith(
          status: TicketCreateStatus.ready,
          companies: companies,
          departments: departments,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('TicketCreate referans veri hatası: $error');
      debugPrintStack(stackTrace: stackTrace);

      emit(
        state.copyWith(
          status: TicketCreateStatus.failure,
          errorMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _onSubmitted(
    TicketCreateSubmitted event,
    Emitter<TicketCreateState> emit,
  ) async {
    if (_busy || !state.canSubmit) return;

    final title = event.title.trim();
    final description = event.description.trim();

    if (title.length < 3) {
      emit(
        state.copyWith(
          errorMessage: 'Talep başlığı en az 3 karakter olmalıdır.',
        ),
      );
      return;
    }

    if (description.length < 5) {
      emit(
        state.copyWith(errorMessage: 'Açıklama en az 5 karakter olmalıdır.'),
      );
      return;
    }

    final companyExists = state.companies.any(
      (company) => company.id == event.companyId,
    );

    final departmentExists = state.departments.any(
      (department) => department.id == event.departmentId,
    );

    if (!companyExists || !departmentExists) {
      emit(
        state.copyWith(
          errorMessage: 'Geçerli bir şirket ve departman seçmelisiniz.',
        ),
      );
      return;
    }

    _busy = true;

    emit(
      state.copyWith(status: TicketCreateStatus.submitting, clearError: true),
    );

    try {
      final ticket = await _ticketRepository.createTicket(
        companyId: event.companyId,
        departmentId: event.departmentId,
        title: title,
        description: description,
        priority: event.priority,
      );

      emit(
        state.copyWith(
          status: TicketCreateStatus.success,
          createdTicket: ticket,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TicketCreateStatus.ready,
          errorMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;

      if (responseData is Map && responseData['message'] is String) {
        return responseData['message'] as String;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Sunucuya bağlanılamadı. '
            'API bağlantısını kontrol edin.';
      }
    }

    return 'İşlem gerçekleştirilemedi. Tekrar deneyin.';
  }
}
