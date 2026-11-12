import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.departmentId,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final int departmentId;

  String get fullName => '$firstName $lastName'.trim();

  bool get isHelpdesk => role == 'Helpdesk';
  bool get isEmployee => role == 'Employee';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      departmentId: json['departmentId'] as int,
    );
  }

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    email,
    role,
    departmentId,
  ];
}
