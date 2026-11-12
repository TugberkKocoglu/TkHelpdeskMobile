import 'package:equatable/equatable.dart';

import '../models/dashboard_ticket.dart';
import '../models/report_summary.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.helpdeskSummary,
    this.employeeSummary,
    this.errorMessage,
  });

  final DashboardStatus status;
  final ReportSummary? helpdeskSummary;
  final EmployeeDashboardSummary? employeeSummary;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    helpdeskSummary,
    employeeSummary,
    errorMessage,
  ];
}
