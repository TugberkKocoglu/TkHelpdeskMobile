import 'package:equatable/equatable.dart';

import '../models/notification_model.dart';

enum NotificationListStatus { initial, loading, success, failure }

class NotificationState extends Equatable {
  const NotificationState({
    this.status = NotificationListStatus.initial,
    this.items = const [],
    this.total = 0,
    this.unreadCount = 0,
    this.page = 1,
    this.hasNextPage = false,
    this.isLoadingMore = false,
    this.isProcessing = false,
    this.errorMessage,
    this.actionMessage,
    this.actionVersion = 0,
  });

  final NotificationListStatus status;
  final List<NotificationModel> items;

  final int total;
  final int unreadCount;
  final int page;
  final bool hasNextPage;

  final bool isLoadingMore;
  final bool isProcessing;

  final String? errorMessage;
  final String? actionMessage;
  final int actionVersion;

  NotificationState copyWith({
    NotificationListStatus? status,
    List<NotificationModel>? items,
    int? total,
    int? unreadCount,
    int? page,
    bool? hasNextPage,
    bool? isLoadingMore,
    bool? isProcessing,
    String? errorMessage,
    String? actionMessage,
    bool clearError = false,
    bool clearActionMessage = false,
    int? actionVersion,
  }) {
    return NotificationState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      unreadCount: unreadCount ?? this.unreadCount,
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      actionMessage: clearActionMessage
          ? null
          : actionMessage ?? this.actionMessage,
      actionVersion: actionVersion ?? this.actionVersion,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    total,
    unreadCount,
    page,
    hasNextPage,
    isLoadingMore,
    isProcessing,
    errorMessage,
    actionMessage,
    actionVersion,
  ];
}
