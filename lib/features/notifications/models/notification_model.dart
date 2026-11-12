import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.ticketId,
    this.readAt,
  });

  final int id;
  final int userId;
  final int? ticketId;

  final String title;
  final String message;
  final String type;

  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get hasTicket => ticketId != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      ticketId: (json['ticket_id'] as num?)?.toInt(),
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    ticketId,
    title,
    message,
    type,
    isRead,
    createdAt,
    readAt,
  ];
}
