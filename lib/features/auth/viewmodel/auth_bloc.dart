import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/auth_token_manager.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/notifications/push_notification_service.dart';

import '../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._repository,
    AuthTokenManager tokenManager,
    this._socketService,
    this._pushService,
  ) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);

    _sessionSubscription = tokenManager.sessionExpired.listen((_) {
      _socketService.disconnect();

      // Oturum zaten geçersiz olduğundan DELETE isteği
      // göndermiyoruz. Yerel token kaydını durduruyoruz.
      unawaited(_pushService.stop(deactivate: false));

      if (!isClosed) {
        add(const AuthSessionExpired());
      }
    });
  }

  final AuthRepository _repository;
  final SocketService _socketService;
  final PushNotificationService _pushService;

  late final StreamSubscription<void> _sessionSubscription;

  void _connectSocket() {
    unawaited(_socketService.connect());
  }

  void _startPush() {
    // Firebase hatası login işlemini engellemez.
    _pushService.start();
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(const AuthState(status: AuthStatus.loading));

    try {
      final user = await _repository.restoreSession();

      if (user == null) {
        _socketService.disconnect();
        await _pushService.stop(deactivate: false);

        emit(const AuthState(status: AuthStatus.unauthenticated));
        return;
      }

      emit(AuthState(status: AuthStatus.authenticated, user: user));

      _connectSocket();
      _startPush();
    } catch (_) {
      _socketService.disconnect();
      await _pushService.stop(deactivate: false);

      emit(
        const AuthState(
          status: AuthStatus.sessionCheckFailed,
          errorMessage:
              'Oturum kontrol edilemedi. İnternet bağlantınızı '
              'kontrol edip tekrar deneyin.',
        ),
      );
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _socketService.disconnect();
    await _pushService.stop(deactivate: false);

    emit(const AuthState(status: AuthStatus.loading));

    try {
      final user = await _repository.login(
        email: event.email.trim(),
        password: event.password,
      );

      emit(AuthState(status: AuthStatus.authenticated, user: user));

      _connectSocket();
      _startPush();
    } catch (error) {
      _socketService.disconnect();
      await _pushService.stop(deactivate: false);

      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: _getErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _socketService.disconnect();

    emit(AuthState(status: AuthStatus.loading, user: state.user));

    // JWT temizlenmeden önce backend'deki
    // FCM cihaz kaydını pasifleştir.
    await _pushService.stop(deactivate: true);

    try {
      await _repository.logout();
    } catch (_) {
      // Repository yerel tokenları her durumda temizler.
    }

    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    _socketService.disconnect();
    unawaited(_pushService.stop(deactivate: false));

    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage:
            'Oturumunuzun süresi doldu. '
            'Lütfen tekrar giriş yapın.',
      ),
    );
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Sunucuya bağlanılamadı. '
            'İnternet ve API bağlantısını kontrol edin.';
      }
    }

    return 'İşlem gerçekleştirilemedi. Tekrar deneyin.';
  }

  @override
  Future<void> close() async {
    _socketService.disconnect();

    await _sessionSubscription.cancel();
    await super.close();
  }
}
