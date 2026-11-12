import 'package:equatable/equatable.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

final class NotificationListStarted extends NotificationEvent {
  const NotificationListStarted();
}

final class NotificationRefreshRequested extends NotificationEvent {
  const NotificationRefreshRequested();
}

final class NotificationNextPageRequested extends NotificationEvent {
  const NotificationNextPageRequested();
}

final class NotificationMarkAsReadRequested extends NotificationEvent {
  const NotificationMarkAsReadRequested(this.notificationId);

  final int notificationId;

  @override
  List<Object?> get props => [notificationId];
}

final class NotificationMarkAllAsReadRequested extends NotificationEvent {
  const NotificationMarkAllAsReadRequested();
}
