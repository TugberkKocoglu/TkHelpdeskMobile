import 'package:equatable/equatable.dart';

import 'notification_model.dart';

class NotificationPageModel extends Equatable {
  const NotificationPageModel({
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<NotificationModel> items;

  final int total;
  final int unreadCount;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasNextPage => page < totalPages;

  factory NotificationPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List;

    return NotificationPageModel(
      items: rawItems.map((item) {
        return NotificationModel.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList(),
      total: (json['total'] as num).toInt(),
      unreadCount: (json['unreadCount'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [
    items,
    total,
    unreadCount,
    page,
    pageSize,
    totalPages,
  ];
}
