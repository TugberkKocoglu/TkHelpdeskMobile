import 'package:equatable/equatable.dart';

sealed class TicketDetailEvent extends Equatable {
  const TicketDetailEvent();

  @override
  List<Object?> get props => [];
}

final class TicketDetailStarted extends TicketDetailEvent {
  const TicketDetailStarted(this.ticketId);

  final int ticketId;

  @override
  List<Object?> get props => [ticketId];
}

final class TicketDetailRefreshRequested extends TicketDetailEvent {
  const TicketDetailRefreshRequested();
}

final class TicketClaimRequested extends TicketDetailEvent {
  const TicketClaimRequested();
}

final class TicketStartRequested extends TicketDetailEvent {
  const TicketStartRequested();
}

final class TicketCloseRequested extends TicketDetailEvent {
  const TicketCloseRequested(this.resolutionNote);

  final String resolutionNote;

  @override
  List<Object?> get props => [resolutionNote];
}

final class TicketPriorityChangeRequested extends TicketDetailEvent {
  const TicketPriorityChangeRequested(this.priority);

  final String priority;

  @override
  List<Object?> get props => [priority];
}

final class TicketCommentAddRequested extends TicketDetailEvent {
  const TicketCommentAddRequested(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}
