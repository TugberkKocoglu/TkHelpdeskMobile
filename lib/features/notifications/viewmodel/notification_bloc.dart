import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notification_repository.dart';
import '../models/notification_model.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc(this._repository) : super(const NotificationState()) {
    on<NotificationListStarted>(_onStarted);
    on<NotificationRefreshRequested>(_onRefresh);
    on<NotificationNextPageRequested>(_onNextPage);
    on<NotificationMarkAsReadRequested>(_onMarkAsRead);
    on<NotificationMarkAllAsReadRequested>(_onMarkAllAsRead);
  }

  final NotificationRepository _repository;

  static const int _pageSize = 20;

  bool _busy = false;

  Future<void> _onStarted(
    NotificationListStarted event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.status != NotificationListStatus.initial) {
      return;
    }

    await _loadFirstPage(emit);
  }

  Future<void> _onRefresh(
    NotificationRefreshRequested event,
    Emitter<NotificationState> emit,
  ) async {
    await _loadFirstPage(emit);
  }

  Future<void> _loadFirstPage(Emitter<NotificationState> emit) async {
    if (_busy) return;

    _busy = true;

    emit(
      state.copyWith(
        status: NotificationListStatus.loading,
        clearError: true,
        clearActionMessage: true,
      ),
    );

    try {
      final result = await _repository.getNotifications(
        page: 1,
        pageSize: _pageSize,
      );

      emit(
        state.copyWith(
          status: NotificationListStatus.success,
          items: result.items,
          total: result.total,
          unreadCount: result.unreadCount,
          page: result.page,
          hasNextPage: result.hasNextPage,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: NotificationListStatus.failure,
          errorMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _onNextPage(
    NotificationNextPageRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (_busy ||
        state.status != NotificationListStatus.success ||
        !state.hasNextPage) {
      return;
    }

    _busy = true;

    emit(state.copyWith(isLoadingMore: true, clearError: true));

    try {
      final result = await _repository.getNotifications(
        page: state.page + 1,
        pageSize: _pageSize,
      );

      final existingIds = state.items
          .map((notification) => notification.id)
          .toSet();

      final newItems = result.items.where(
        (notification) => !existingIds.contains(notification.id),
      );

      emit(
        state.copyWith(
          items: [...state.items, ...newItems],
          total: result.total,
          unreadCount: result.unreadCount,
          page: result.page,
          hasNextPage: result.hasNextPage,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: _getErrorMessage(error),
          actionVersion: state.actionVersion + 1,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _onMarkAsRead(
    NotificationMarkAsReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (_busy || state.status != NotificationListStatus.success) {
      return;
    }

    NotificationModel? selected;

    for (final notification in state.items) {
      if (notification.id == event.notificationId) {
        selected = notification;
        break;
      }
    }

    if (selected == null || selected.isRead) {
      return;
    }

    _busy = true;

    emit(
      state.copyWith(
        isProcessing: true,
        clearError: true,
        clearActionMessage: true,
      ),
    );

    try {
      await _repository.markAsRead(event.notificationId);

      final result = await _repository.getNotifications(
        page: 1,
        pageSize: _pageSize,
      );

      emit(
        state.copyWith(
          status: NotificationListStatus.success,
          items: result.items,
          total: result.total,
          unreadCount: result.unreadCount,
          page: result.page,
          hasNextPage: result.hasNextPage,
          isProcessing: false,
          actionMessage: 'Bildirim okundu olarak işaretlendi.',
          actionVersion: state.actionVersion + 1,
          clearError: true,
        ),
      );
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 404) {
        try {
          final result = await _repository.getNotifications(
            page: 1,
            pageSize: _pageSize,
          );

          emit(
            state.copyWith(
              items: result.items,
              total: result.total,
              unreadCount: result.unreadCount,
              page: result.page,
              hasNextPage: result.hasNextPage,
              isProcessing: false,
              clearError: true,
            ),
          );
          return;
        } catch (_) {
          // Senkronizasyon da başarısız olursa
          // hata mesajını aşağıda göstereceğiz.
        }
      }

      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: _getErrorMessage(error),
          actionVersion: state.actionVersion + 1,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _onMarkAllAsRead(
    NotificationMarkAllAsReadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (_busy ||
        state.status != NotificationListStatus.success ||
        state.unreadCount == 0) {
      return;
    }

    _busy = true;

    emit(
      state.copyWith(
        isProcessing: true,
        clearError: true,
        clearActionMessage: true,
      ),
    );

    try {
      await _repository.markAllAsRead();

      final result = await _repository.getNotifications(
        page: 1,
        pageSize: _pageSize,
      );

      emit(
        state.copyWith(
          items: result.items,
          total: result.total,
          unreadCount: result.unreadCount,
          page: result.page,
          hasNextPage: result.hasNextPage,
          isProcessing: false,
          actionMessage: 'Tüm bildirimler okundu olarak işaretlendi.',
          actionVersion: state.actionVersion + 1,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isProcessing: false,
          errorMessage: _getErrorMessage(error),
          actionVersion: state.actionVersion + 1,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Sunucuya bağlanılamadı. '
            'İnternet ve API bağlantısını kontrol edin.';
      }
    }

    return 'Bildirim işlemi gerçekleştirilemedi. '
        'Tekrar deneyin.';
  }
}
