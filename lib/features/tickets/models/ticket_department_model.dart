import 'package:equatable/equatable.dart';

class TicketDepartmentModel extends Equatable {
  const TicketDepartmentModel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;

  factory TicketDepartmentModel.fromJson(Map<String, dynamic> json) {
    return TicketDepartmentModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      isActive: json['is_active'] == null ? true : json['is_active'] as bool,
    );
  }

  bool get canReceiveTickets =>
      isActive && (name == 'Yazılım' || name == 'Yazılım Destek');

  @override
  List<Object?> get props => [id, name, isActive];
}
