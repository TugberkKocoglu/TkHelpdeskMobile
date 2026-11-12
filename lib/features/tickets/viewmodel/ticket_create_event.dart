import 'package:equatable/equatable.dart';

import '../models/ticket_model.dart';

sealed class TicketCreateEvent extends Equatable {
  const TicketCreateEvent();

  @override
  List<Object?> get props => [];
}

final class TicketCreateStarted extends TicketCreateEvent {
  const TicketCreateStarted();
}

final class TicketCreateRefreshRequested extends TicketCreateEvent {
  const TicketCreateRefreshRequested();
}

final class TicketCreateSubmitted extends TicketCreateEvent {
  const TicketCreateSubmitted({
    required this.companyId,
    required this.departmentId,
    required this.title,
    required this.description,
    required this.priority,
  });

  final int companyId;
  final int departmentId;
  final String title;
  final String description;
  final TicketPriority priority;

  @override
  List<Object?> get props => [
    companyId,
    departmentId,
    title,
    description,
    priority,
  ];
}
