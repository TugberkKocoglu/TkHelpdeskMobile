import 'package:equatable/equatable.dart';

import '../models/ticket_company_model.dart';
import '../models/ticket_department_model.dart';
import '../models/ticket_model.dart';

enum TicketCreateStatus {
  initial,
  loading,
  ready,
  submitting,
  success,
  failure,
}

class TicketCreateState extends Equatable {
  const TicketCreateState({
    this.status = TicketCreateStatus.initial,
    this.companies = const [],
    this.departments = const [],
    this.createdTicket,
    this.errorMessage,
  });

  final TicketCreateStatus status;

  final List<TicketCompanyModel> companies;
  final List<TicketDepartmentModel> departments;

  final TicketModel? createdTicket;
  final String? errorMessage;

  bool get isLoading => status == TicketCreateStatus.loading;

  bool get isSubmitting => status == TicketCreateStatus.submitting;

  bool get canSubmit =>
      status == TicketCreateStatus.ready &&
      companies.isNotEmpty &&
      departments.isNotEmpty;

  TicketCreateState copyWith({
    TicketCreateStatus? status,
    List<TicketCompanyModel>? companies,
    List<TicketDepartmentModel>? departments,
    TicketModel? createdTicket,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TicketCreateState(
      status: status ?? this.status,
      companies: companies ?? this.companies,
      departments: departments ?? this.departments,
      createdTicket: createdTicket ?? this.createdTicket,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    companies,
    departments,
    createdTicket,
    errorMessage,
  ];
}
