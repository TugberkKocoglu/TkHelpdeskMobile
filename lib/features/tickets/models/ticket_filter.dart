import 'ticket_model.dart';

class TicketFilter {
  const TicketFilter({
    this.status,
    this.companyId,
    this.departmentId,
    this.page = 1,
    this.pageSize = 20,
  });

  final TicketStatus? status;
  final int? companyId;
  final int? departmentId;
  final int page;
  final int pageSize;

  Map<String, dynamic> toQueryParameters() {
    return {
      'status': ?status?.value,
      'companyId': ?companyId,
      'departmentId': ?departmentId,
      'page': page,
      'pageSize': pageSize,
    };
  }
}
