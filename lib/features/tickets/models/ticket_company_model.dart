import 'package:equatable/equatable.dart';

class TicketCompanyModel extends Equatable {
  const TicketCompanyModel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;

  factory TicketCompanyModel.fromJson(Map<String, dynamic> json) {
    return TicketCompanyModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, name, isActive];
}
