import 'package:flutter_test/flutter_test.dart';

import 'package:tkhelpdesk_mobile/features/tickets/models/ticket_filter.dart';
import 'package:tkhelpdesk_mobile/features/tickets/models/ticket_model.dart';
import 'package:tkhelpdesk_mobile/features/tickets/models/ticket_page.dart';

void main() {
  test('TicketModel backend JSON verisini okur', () {
    final ticket = TicketModel.fromJson({
      'id': 12,
      'ticket_number': 'TK-TEST001',
      'company_id': 1,
      'department_id': 2,
      'created_by_user_id': 3,
      'assigned_user_id': null,
      'title': 'Test talebi',
      'description': 'Test açıklaması',
      'status': 'InPool',
      'priority': 'High',
      'created_at': '2026-11-10T12:00:00.000Z',
      'claimed_at': null,
      'closed_at': null,
      'resolution_note': null,
    });

    expect(ticket.id, 12);
    expect(ticket.ticketNumber, 'TK-TEST001');
    expect(ticket.status, TicketStatus.inPool);
    expect(ticket.priority, TicketPriority.high);
    expect(ticket.isInPool, isTrue);
    expect(ticket.assignedUserId, isNull);
  });

  test('TicketPage sayfalama bilgilerini okur', () {
    final page = TicketPage.fromJson({
      'items': [],
      'total': 45,
      'page': 1,
      'pageSize': 20,
      'totalPages': 3,
    });

    expect(page.total, 45);
    expect(page.hasNextPage, isTrue);
    expect(page.totalPages, 3);
  });

  test('TicketFilter API parametrelerini oluşturur', () {
    const filter = TicketFilter(
      status: TicketStatus.inPool,
      page: 2,
      pageSize: 20,
    );

    final query = filter.toQueryParameters();

    expect(query['status'], 'InPool');
    expect(query['page'], 2);
    expect(query.containsKey('companyId'), isFalse);
    expect(query.containsKey('departmentId'), isFalse);
  });
}
