import 'package:equatable/equatable.dart';

class ReportOverview extends Equatable {
  const ReportOverview({
    required this.totalTickets,
    required this.openTickets,
    required this.closedTickets,
    required this.closureRate,
    required this.averageResolutionMinutes,
  });

  final int totalTickets;
  final int openTickets;
  final int closedTickets;
  final double closureRate;
  final int? averageResolutionMinutes;

  factory ReportOverview.fromJson(Map<String, dynamic> json) {
    return ReportOverview(
      totalTickets: (json['totalTickets'] as num).toInt(),
      openTickets: (json['openTickets'] as num).toInt(),
      closedTickets: (json['closedTickets'] as num).toInt(),
      closureRate: (json['closureRate'] as num).toDouble(),
      averageResolutionMinutes: (json['averageResolutionMinutes'] as num?)
          ?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    totalTickets,
    openTickets,
    closedTickets,
    closureRate,
    averageResolutionMinutes,
  ];
}

class ReportSummary extends Equatable {
  const ReportSummary({
    required this.year,
    required this.month,
    required this.overview,
    required this.statusDistribution,
    required this.priorityDistribution,
  });

  final int year;
  final int? month;
  final ReportOverview overview;
  final Map<String, int> statusDistribution;
  final Map<String, int> priorityDistribution;

  static Map<String, int> _readDistribution(dynamic value) {
    final data = Map<String, dynamic>.from(value as Map);

    return data.map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final period = Map<String, dynamic>.from(json['period'] as Map);

    return ReportSummary(
      year: (period['year'] as num).toInt(),
      month: (period['month'] as num?)?.toInt(),
      overview: ReportOverview.fromJson(
        Map<String, dynamic>.from(json['overview'] as Map),
      ),
      statusDistribution: _readDistribution(json['statusDistribution']),
      priorityDistribution: _readDistribution(json['priorityDistribution']),
    );
  }

  @override
  List<Object?> get props => [
    year,
    month,
    overview,
    statusDistribution,
    priorityDistribution,
  ];
}
