import 'package:equatable/equatable.dart';

import 'ticket_model.dart';

class TicketPage extends Equatable {
  const TicketPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<TicketModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasNextPage => page < totalPages;

  factory TicketPage.fromJson(Map<String, dynamic> json) {
    return TicketPage(
      items: (json['items'] as List)
          .map(
            (item) =>
                TicketModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [items, total, page, pageSize, totalPages];
}
