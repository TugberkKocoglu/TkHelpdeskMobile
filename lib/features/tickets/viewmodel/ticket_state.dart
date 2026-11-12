import 'package:equatable/equatable.dart';

import '../models/ticket_model.dart';
import 'ticket_event.dart';

enum TicketListStatus { initial, loading, success, failure }

class TicketState extends Equatable {
  const TicketState({
    this.status = TicketListStatus.initial,
    this.mode = TicketListMode.all,
    this.currentUserId = 0,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasNextPage = false,
    this.isLoadingMore = false,
    this.selectedStatus,
    this.errorMessage,
  });

  final TicketListStatus status;
  final TicketListMode mode;
  final int currentUserId;
  final List<TicketModel> items;
  final int total;
  final int page;
  final bool hasNextPage;
  final bool isLoadingMore;
  final String? selectedStatus;
  final String? errorMessage;

  TicketState copyWith({
    TicketListStatus? status,
    TicketListMode? mode,
    int? currentUserId,
    List<TicketModel>? items,
    int? total,
    int? page,
    bool? hasNextPage,
    bool? isLoadingMore,
    String? selectedStatus,
    bool clearSelectedStatus = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TicketState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      currentUserId: currentUserId ?? this.currentUserId,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedStatus: clearSelectedStatus
          ? null
          : selectedStatus ?? this.selectedStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    mode,
    currentUserId,
    items,
    total,
    page,
    hasNextPage,
    isLoadingMore,
    selectedStatus,
    errorMessage,
  ];
}
