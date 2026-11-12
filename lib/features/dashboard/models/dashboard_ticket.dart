import 'package:equatable/equatable.dart';

class DashboardTicket extends Equatable {
  const DashboardTicket({
    required this.id,
    required this.status,
    required this.assignedUserId,
  });

  final int id;
  final String status;
  final int? assignedUserId;

  factory DashboardTicket.fromJson(Map<String, dynamic> json) {
    return DashboardTicket(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String,
      assignedUserId: (json['assigned_user_id'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [id, status, assignedUserId];
}

class EmployeeDashboardSummary extends Equatable {
  const EmployeeDashboardSummary({
    required this.totalTickets,
    required this.poolTickets,
    required this.inProgressTickets,
    required this.closedTickets,
    required this.myOpenTickets,
  });

  final int totalTickets;
  final int poolTickets;
  final int inProgressTickets;
  final int closedTickets;
  final int myOpenTickets;

  factory EmployeeDashboardSummary.fromTickets(
    List<DashboardTicket> tickets,
    int currentUserId,
  ) {
    return EmployeeDashboardSummary(
      totalTickets: tickets.length,
      poolTickets: tickets.where((ticket) => ticket.status == 'InPool').length,
      inProgressTickets: tickets
          .where((ticket) => ticket.status == 'InProgress')
          .length,
      closedTickets: tickets
          .where((ticket) => ticket.status == 'Closed')
          .length,
      myOpenTickets: tickets
          .where(
            (ticket) =>
                ticket.assignedUserId == currentUserId &&
                ticket.status != 'Closed',
          )
          .length,
    );
  }

  @override
  List<Object?> get props => [
    totalTickets,
    poolTickets,
    inProgressTickets,
    closedTickets,
    myOpenTickets,
  ];
}
