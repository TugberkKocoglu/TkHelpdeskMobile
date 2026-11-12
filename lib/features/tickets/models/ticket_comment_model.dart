import 'package:equatable/equatable.dart';

class TicketCommentModel extends Equatable {
  const TicketCommentModel({
    required this.id,
    required this.ticketId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userName,
  });

  final int id;
  final int ticketId;
  final int userId;
  final String content;
  final DateTime createdAt;
  final String? userName;

  factory TicketCommentModel.fromJson(Map<String, dynamic> json) {
    return TicketCommentModel(
      id: (json['id'] as num).toInt(),
      ticketId: (json['ticket_id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['userName'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ticketId,
    userId,
    content,
    createdAt,
    userName,
  ];
}
