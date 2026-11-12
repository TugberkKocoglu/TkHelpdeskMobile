import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ticket_repository.dart';
import '../models/ticket_comment_model.dart';
import '../models/ticket_detail_model.dart';
import '../models/ticket_model.dart';
import 'ticket_detail_event.dart';
import 'ticket_detail_state.dart';

class TicketDetailBloc extends Bloc<TicketDetailEvent, TicketDetailState> {
  TicketDetailBloc(this._repository) : super(const TicketDetailState()) {
    on<TicketDetailStarted>(_onStarted);
    on<TicketDetailRefreshRequested>(_onRefresh);
    on<TicketClaimRequested>(_onClaim);
    on<TicketStartRequested>(_onStart);
    on<TicketCloseRequested>(_onClose);
    on<TicketPriorityChangeRequested>(_onPriorityChange);
    on<TicketCommentAddRequested>(_onAddComment);
  }

  final TicketRepository _repository;

  int? _ticketId;
  bool _busy = false;
  bool _pendingRefresh = false;

  // Bir işlem sürerken gelen Socket.IO yenilemesi kaybolmaz.
  void _finishWork() {
    _busy = false;
    if (_pendingRefresh && !isClosed) {
      _pendingRefresh = false;
      add(const TicketDetailRefreshRequested());
    }
  }

  Future<({TicketDetailModel detail, List<TicketCommentModel> comments})>
  _fetchDetail(int ticketId) async {
    final results = await Future.wait<dynamic>([
      _repository.getTicketDetail(ticketId),
      _repository.getTicketComments(ticketId),
    ]);

    return (
      detail: results[0] as TicketDetailModel,
      comments: results[1] as List<TicketCommentModel>,
    );
  }

  Future<void> _onStarted(
    TicketDetailStarted event,
    Emitter<TicketDetailState> emit,
  ) async {
    _ticketId = event.ticketId;
    if (_busy) {
      _pendingRefresh = true;
      return;
    }
    await _load(emit);
  }

  Future<void> _onRefresh(
    TicketDetailRefreshRequested event,
    Emitter<TicketDetailState> emit,
  ) async {
    if (_busy) {
      _pendingRefresh = true;
      return;
    }
    await _load(emit);
  }

  Future<void> _load(Emitter<TicketDetailState> emit) async {
    final ticketId = _ticketId;
    if (ticketId == null) return;

    _busy = true;

    emit(
      state.copyWith(
        status: TicketDetailStatus.loading,
        clearActionMessages: true,
      ),
    );

    try {
      final result = await _fetchDetail(ticketId);

      emit(
        state.copyWith(
          status: TicketDetailStatus.success,
          detail: result.detail,
          comments: result.comments,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TicketDetailStatus.failure,
          errorMessage: _errorMessage(error),
        ),
      );
    } finally {
      _finishWork();
    }
  }

  Future<void> _runAction(
    Emitter<TicketDetailState> emit, {
    required Future<void> Function(int ticketId) action,
    required String successMessage,
  }) async {
    final ticketId = _ticketId;

    if (_busy || ticketId == null) return;

    _busy = true;

    emit(state.copyWith(isProcessing: true, clearActionMessages: true));

    try {
      await action(ticketId);

      // İşlem tamamlandı. Detay ve yorumları backend'den yeniden okuyoruz.
      final result = await _fetchDetail(ticketId);

      emit(
        state.copyWith(
          status: TicketDetailStatus.success,
          detail: result.detail,
          comments: result.comments,
          isProcessing: false,
          successMessage: successMessage,
          actionVersion: state.actionVersion + 1,
          dataVersion: state.dataVersion + 1,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isProcessing: false,
          actionError: _errorMessage(error),
          actionVersion: state.actionVersion + 1,
        ),
      );
    } finally {
      _finishWork();
    }
  }

  Future<void> _onClaim(
    TicketClaimRequested event,
    Emitter<TicketDetailState> emit,
  ) async {
    await _runAction(
      emit,
      action: (ticketId) async {
        await _repository.claimTicket(ticketId);
      },
      successMessage: 'Talep başarıyla üstlenildi.',
    );
  }

  Future<void> _onStart(
    TicketStartRequested event,
    Emitter<TicketDetailState> emit,
  ) async {
    await _runAction(
      emit,
      action: (ticketId) async {
        await _repository.startTicket(ticketId);
      },
      successMessage: 'Talep işleme alındı.',
    );
  }

  Future<void> _onClose(
    TicketCloseRequested event,
    Emitter<TicketDetailState> emit,
  ) async {
    if (event.resolutionNote.trim().length < 5) {
      emit(
        state.copyWith(
          actionError: 'Çözüm notu en az 5 karakter olmalıdır.',
          actionVersion: state.actionVersion + 1,
          clearActionMessages: true,
        ),
      );
      return;
    }

    await _runAction(
      emit,
      action: (ticketId) async {
        await _repository.closeTicket(
          ticketId: ticketId,
          resolutionNote: event.resolutionNote,
        );
      },
      successMessage: 'Talep kapatıldı.',
    );
  }

  Future<void> _onPriorityChange(
    TicketPriorityChangeRequested event,
    Emitter<TicketDetailState> emit,
  ) async {
    await _runAction(
      emit,
      action: (ticketId) async {
        await _repository.updatePriority(
          ticketId: ticketId,
          priority: TicketPriority.fromValue(event.priority),
        );
      },
      successMessage: 'Talep önceliği güncellendi.',
    );
  }

  Future<void> _onAddComment(
    TicketCommentAddRequested event,
    Emitter<TicketDetailState> emit,
  ) async {
    if (event.content.trim().length < 2) {
      emit(
        state.copyWith(
          actionError: 'Yorum en az 2 karakter olmalıdır.',
          actionVersion: state.actionVersion + 1,
          clearActionMessages: true,
        ),
      );
      return;
    }

    await _runAction(
      emit,
      action: (ticketId) async {
        await _repository.addTicketComment(
          ticketId: ticketId,
          content: event.content,
        );
      },
      successMessage: 'Yorum eklendi.',
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;

      if (responseData is Map && responseData['message'] is String) {
        return responseData['message'] as String;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Sunucuya bağlanılamadı. Bağlantınızı kontrol edin.';
      }
    }

    return 'İşlem gerçekleştirilemedi. Tekrar deneyin.';
  }
}
