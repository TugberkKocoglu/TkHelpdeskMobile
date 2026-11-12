import 'package:equatable/equatable.dart';

import '../../auth/models/auth_user.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

final class DashboardStarted extends DashboardEvent {
  const DashboardStarted(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class DashboardRefreshRequested extends DashboardEvent {
  const DashboardRefreshRequested(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}
