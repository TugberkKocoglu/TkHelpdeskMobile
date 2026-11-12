import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ticket_repository.dart';
import '../models/ticket_filter.dart';
import '../models/ticket_model.dart';
import 'ticket_event.dart';
import 'ticket_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  TicketBloc(this._repository) : super(const TicketState()) {
    on<TicketListStarted>(_onStarted);
    on<TicketListRefreshRequested>(_onRefresh);
    on<TicketStatusChanged>(_onStatusChanged);
    on<TicketNextPageRequested>(_onNextPage);
  }

  final TicketRepository _repository;

  static const int _pageSize = 20;
  static const int _fetchPageSize = 100;

  bool _busy = false;
  bool _pendingRefresh = false;
  List<TicketModel>? _myTicketsCache;

  // A refresh received during a page load should not be silently discarded.
  void _finishRequest() {
    _busy = false;
    if (_pendingRefresh && !isClosed) {
      _pendingRefresh = false;
      add(const TicketListRefreshRequested());
    }
  }

  Future<void> _onStarted(
    TicketListStarted event,
    Emitter<TicketState> emit,
  ) async {
    await _loadFirstPage(
      emit,
      mode: event.mode,
      currentUserId: event.currentUserId,
      statusFilter: null,
    );
  }

  Future<void> _onRefresh(
    TicketListRefreshRequested event,
    Emitter<TicketState> emit,
  ) async {
    if (_busy) {
      _pendingRefresh = true;
      return;
    }
    if (state.status == TicketListStatus.initial) return;

    await _loadFirstPage(
      emit,
      mode: state.mode,
      currentUserId: state.currentUserId,
      statusFilter: state.selectedStatus,
    );
  }

  Future<void> _onStatusChanged(
    TicketStatusChanged event,
    Emitter<TicketState> emit,
  ) async {
    if (state.mode == TicketListMode.pool) return;
    if (state.selectedStatus == event.status) return;

    await _loadFirstPage(
      emit,
      mode: state.mode,
      currentUserId: state.currentUserId,
      statusFilter: event.status,
    );
  }

  Future<List<TicketModel>> _fetchAllMyTickets(int userId) async {
    final result = <TicketModel>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await _repository.getTickets(
        filter: TicketFilter(page: page, pageSize: _fetchPageSize),
      );

      result.addAll(
        response.items.where((ticket) => ticket.assignedUserId == userId),
      );

      totalPages = response.totalPages;
      page++;
    } while (page <= totalPages);

    return result;
  }

  List<TicketModel> _filterMyTickets(
    List<TicketModel> tickets,
    String? status,
  ) {
    if (status == null) return tickets;
    return tickets.where((ticket) => ticket.status.value == status).toList();
  }

  Future<void> _loadFirstPage(
    Emitter<TicketState> emit, {
    required TicketListMode mode,
    required int currentUserId,
    required String? statusFilter,
  }) async {
    if (_busy) return;
    _busy = true;

    emit(
      TicketState(
        status: TicketListStatus.loading,
        mode: mode,
        currentUserId: currentUserId,
        selectedStatus: statusFilter,
      ),
    );

    try {
      if (mode == TicketListMode.mine) {
        _myTicketsCache = null;
        final mine = await _fetchAllMyTickets(currentUserId);
        _myTicketsCache = mine;
        final filtered = _filterMyTickets(mine, statusFilter);

        emit(
          state.copyWith(
            status: TicketListStatus.success,
            items: filtered.take(_pageSize).toList(),
            total: filtered.length,
            page: 1,
            hasNextPage: filtered.length > _pageSize,
            clearError: true,
          ),
        );
        return;
      }

      final TicketStatus? effectiveStatus = mode == TicketListMode.pool
          ? TicketStatus.inPool
          : statusFilter == null
          ? null
          : TicketStatus.fromValue(statusFilter);

      final result = await _repository.getTickets(
        filter: TicketFilter(
          status: effectiveStatus,
          page: 1,
          pageSize: _pageSize,
        ),
      );

      emit(
        state.copyWith(
          status: TicketListStatus.success,
          items: result.items,
          total: result.total,
          page: result.page,
          hasNextPage: result.hasNextPage,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TicketListStatus.failure,
          errorMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _finishRequest();
    }
  }

  Future<void> _onNextPage(
    TicketNextPageRequested event,
    Emitter<TicketState> emit,
  ) async {
    if (_busy ||
        state.status != TicketListStatus.success ||
        !state.hasNextPage) {
      return;
    }

    _busy = true;
    emit(state.copyWith(isLoadingMore: true, clearError: true));

    try {
      final nextPage = state.page + 1;

      if (state.mode == TicketListMode.mine) {
        final filtered = _filterMyTickets(
          _myTicketsCache ?? [],
          state.selectedStatus,
        );

        final nextItems = filtered
            .skip((nextPage - 1) * _pageSize)
            .take(_pageSize)
            .toList();

        emit(
          state.copyWith(
            items: [...state.items, ...nextItems],
            page: nextPage,
            hasNextPage: nextPage * _pageSize < filtered.length,
            isLoadingMore: false,
          ),
        );
        return;
      }

      final TicketStatus? effectiveStatus = state.mode == TicketListMode.pool
          ? TicketStatus.inPool
          : state.selectedStatus == null
          ? null
          : TicketStatus.fromValue(state.selectedStatus!);

      final result = await _repository.getTickets(
        filter: TicketFilter(
          status: effectiveStatus,
          page: nextPage,
          pageSize: _pageSize,
        ),
      );

      final existingIds = state.items.map((ticket) => ticket.id).toSet();
      final newItems = result.items.where(
        (ticket) => !existingIds.contains(ticket.id),
      );

      emit(
        state.copyWith(
          items: [...state.items, ...newItems],
          total: result.total,
          page: result.page,
          hasNextPage: result.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _finishRequest();
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
            'İnternet ve API bağlantısını kontrol edin.';
      }
    }

    return 'Talepler yüklenemedi. Tekrar deneyin.';
  }
}
