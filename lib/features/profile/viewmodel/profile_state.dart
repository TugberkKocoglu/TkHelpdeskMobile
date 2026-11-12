import 'package:equatable/equatable.dart';

import '../../auth/models/auth_user.dart';

enum ProfileStatus { initial, loading, success, failure }

enum PasswordChangeStatus { initial, submitting, success, failure }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.departmentName,
    this.errorMessage,
    this.passwordChangeStatus = PasswordChangeStatus.initial,
    this.passwordMessage,
  });

  final ProfileStatus status;
  final AuthUser? user;

  // API'den alınan departman adı.
  final String? departmentName;

  final String? errorMessage;

  final PasswordChangeStatus passwordChangeStatus;
  final String? passwordMessage;

  bool get isLoading => status == ProfileStatus.loading;

  bool get isChangingPassword =>
      passwordChangeStatus == PasswordChangeStatus.submitting;

  ProfileState copyWith({
    ProfileStatus? status,
    AuthUser? user,
    String? departmentName,
    bool clearDepartmentName = false,
    String? errorMessage,
    bool clearError = false,
    PasswordChangeStatus? passwordChangeStatus,
    String? passwordMessage,
    bool clearPasswordMessage = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      departmentName: clearDepartmentName
          ? null
          : departmentName ?? this.departmentName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      passwordChangeStatus: passwordChangeStatus ?? this.passwordChangeStatus,
      passwordMessage: clearPasswordMessage
          ? null
          : passwordMessage ?? this.passwordMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    departmentName,
    errorMessage,
    passwordChangeStatus,
    passwordMessage,
  ];
}
