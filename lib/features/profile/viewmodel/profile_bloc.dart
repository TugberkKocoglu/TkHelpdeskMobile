import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._repository) : super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileRefreshRequested>(_onRefresh);
    on<ProfilePasswordChangeRequested>(_onChangePassword);
  }

  final ProfileRepository _repository;

  bool _loading = false;
  bool _changingPassword = false;

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.status != ProfileStatus.initial) return;

    await _loadProfile(emit);
  }

  Future<void> _onRefresh(
    ProfileRefreshRequested event,
    Emitter<ProfileState> emit,
  ) async {
    await _loadProfile(emit);
  }

  Future<void> _loadProfile(Emitter<ProfileState> emit) async {
    if (_loading || _changingPassword) return;

    _loading = true;

    emit(
      state.copyWith(
        status: ProfileStatus.loading,
        clearDepartmentName: true,
        clearError: true,
      ),
    );

    try {
      // Kullanıcı bilgilerini API'den al.
      final user = await _repository.getProfile();

      String? departmentName;

      // Departman bilgilerini ayrı endpoint üzerinden al.
      // Bu istek başarısız olursa profil ekranını
      // tamamen hataya düşürmeyelim.
      try {
        departmentName = await _repository.getDepartmentName(user.departmentId);
      } catch (_) {
        departmentName = null;
      }

      emit(
        state.copyWith(
          status: ProfileStatus.success,
          user: user,
          departmentName: departmentName,
          clearDepartmentName: departmentName == null,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _loading = false;
    }
  }

  Future<void> _onChangePassword(
    ProfilePasswordChangeRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (_changingPassword || _loading) return;

    if (event.currentPassword.isEmpty) {
      emit(
        state.copyWith(
          passwordChangeStatus: PasswordChangeStatus.failure,
          passwordMessage: 'Mevcut şifrenizi girin.',
        ),
      );
      return;
    }

    if (event.newPassword.length < 8) {
      emit(
        state.copyWith(
          passwordChangeStatus: PasswordChangeStatus.failure,
          passwordMessage: 'Yeni şifre en az 8 karakter olmalıdır.',
        ),
      );
      return;
    }

    if (event.currentPassword == event.newPassword) {
      emit(
        state.copyWith(
          passwordChangeStatus: PasswordChangeStatus.failure,
          passwordMessage: 'Yeni şifre mevcut şifreden farklı olmalıdır.',
        ),
      );
      return;
    }

    _changingPassword = true;

    emit(
      state.copyWith(
        passwordChangeStatus: PasswordChangeStatus.submitting,
        clearPasswordMessage: true,
      ),
    );

    try {
      final message = await _repository.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      emit(
        state.copyWith(
          passwordChangeStatus: PasswordChangeStatus.success,
          passwordMessage: message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          passwordChangeStatus: PasswordChangeStatus.failure,
          passwordMessage: _getErrorMessage(error),
        ),
      );
    } finally {
      _changingPassword = false;
    }
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Sunucuya bağlanılamadı. '
            'Bağlantınızı kontrol edin.';
      }
    }

    return 'İşlem gerçekleştirilemedi. Tekrar deneyin.';
  }
}
