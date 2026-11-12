import 'package:equatable/equatable.dart';

enum TicketListMode { all, pool, mine }

sealed class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

final class TicketListStarted extends TicketEvent {
  const TicketListStarted({required this.mode, required this.currentUserId});

  final TicketListMode mode;
  final int currentUserId;

  @override
  List<Object?> get props => [mode, currentUserId];
}

final class TicketListRefreshRequested extends TicketEvent {
  const TicketListRefreshRequested();
}

final class TicketNextPageRequested extends TicketEvent {
  const TicketNextPageRequested();
}

final class TicketStatusChanged extends TicketEvent {
  const TicketStatusChanged(this.status);

  final String? status;

  @override
  List<Object?> get props => [status];
}
