import 'package:equatable/equatable.dart';

import 'ticket_model.dart';

class TicketHistoryModel extends Equatable {
  const TicketHistoryModel({
    required this.id,
    required this.action,
    required this.createdAt,
    this.description,
    this.performedByName,
    this.oldValue,
    this.newValue,
  });

  final int id;
  final String action;
  final DateTime createdAt;
  final String? description;
  final String? performedByName;
  final String? oldValue;
  final String? newValue;

  factory TicketHistoryModel.fromJson(Map<String, dynamic> json) {
    return TicketHistoryModel(
      id: (json['id'] as num).toInt(),
      action: json['action'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String?,
      performedByName: json['performedByName'] as String?,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    action,
    createdAt,
    description,
    performedByName,
    oldValue,
    newValue,
  ];
}

class TicketDetailModel extends Equatable {
  const TicketDetailModel({
    required this.ticket,
    required this.history,
    this.assignedUserName,
  });

  final TicketModel ticket;
  final List<TicketHistoryModel> history;
  final String? assignedUserName;

  factory TicketDetailModel.fromJson(Map<String, dynamic> json) {
    final historyData = json['history'] as List;

    return TicketDetailModel(
      ticket: TicketModel.fromJson(json),
      history: historyData.map((item) {
        return TicketHistoryModel.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList(),
      assignedUserName: json['assignedUserName'] as String?,
    );
  }

  @override
  List<Object?> get props => [ticket, history, assignedUserName];
}
