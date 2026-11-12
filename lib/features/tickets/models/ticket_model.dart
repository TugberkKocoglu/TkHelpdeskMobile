import 'package:equatable/equatable.dart';

enum TicketStatus {
  inPool('InPool', 'Havuzda'),
  claimed('Claimed', 'Üstlenildi'),
  inProgress('InProgress', 'İşlemde'),
  closed('Closed', 'Kapatıldı');

  const TicketStatus(this.value, this.label);

  final String value;
  final String label;

  static TicketStatus fromValue(String value) {
    return TicketStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw FormatException('Bilinmeyen talep durumu: $value'),
    );
  }
}

enum TicketPriority {
  low('Low', 'Düşük'),
  normal('Normal', 'Normal'),
  high('High', 'Yüksek'),
  critical('Critical', 'Kritik');

  const TicketPriority(this.value, this.label);

  final String value;
  final String label;

  static TicketPriority fromValue(String value) {
    return TicketPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => throw FormatException('Bilinmeyen öncelik: $value'),
    );
  }
}

class TicketModel extends Equatable {
  const TicketModel({
    required this.id,
    required this.ticketNumber,
    required this.companyId,
    required this.departmentId,
    required this.createdByUserId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.assignedUserId,
    this.claimedAt,
    this.closedAt,
    this.resolutionNote,
  });

  final int id;
  final String ticketNumber;
  final int companyId;
  final int departmentId;
  final int createdByUserId;
  final int? assignedUserId;

  final String title;
  final String description;

  final TicketStatus status;
  final TicketPriority priority;

  final DateTime createdAt;
  final DateTime? claimedAt;
  final DateTime? closedAt;

  final String? resolutionNote;

  bool get isInPool => status == TicketStatus.inPool;
  bool get isClosed => status == TicketStatus.closed;

  bool isAssignedTo(int userId) => assignedUserId == userId;

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: (json['id'] as num).toInt(),
      ticketNumber: json['ticket_number'] as String,
      companyId: (json['company_id'] as num).toInt(),
      departmentId: (json['department_id'] as num).toInt(),
      createdByUserId: (json['created_by_user_id'] as num).toInt(),
      assignedUserId: (json['assigned_user_id'] as num?)?.toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      status: TicketStatus.fromValue(json['status'] as String),
      priority: TicketPriority.fromValue(json['priority'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      claimedAt: _parseDate(json['claimed_at']),
      closedAt: _parseDate(json['closed_at']),
      resolutionNote: json['resolution_note'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  @override
  List<Object?> get props => [
    id,
    ticketNumber,
    companyId,
    departmentId,
    createdByUserId,
    assignedUserId,
    title,
    description,
    status,
    priority,
    createdAt,
    claimedAt,
    closedAt,
    resolutionNote,
  ];
}
