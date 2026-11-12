import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/lifecycle/app_resume_service.dart';
import '../core/socket/socket_service.dart';
import '../core/theme/app_theme.dart';

import '../features/auth/viewmodel/auth_bloc.dart';
import '../features/auth/viewmodel/auth_event.dart';
import '../features/auth/viewmodel/auth_state.dart';

import 'di/injection.dart';
import 'router/app_router.dart';

class TkHelpdeskApp extends StatelessWidget {
  const TkHelpdeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(const AuthStarted()),
      child: _AppLifecycleHandler(
        child: MaterialApp.router(
          title: 'TK Helpdesk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}

class _AppLifecycleHandler extends StatefulWidget {
  const _AppLifecycleHandler({required this.child});

  final Widget child;

  @override
  State<_AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<_AppLifecycleHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final authState = context.read<AuthBloc>().state;

    if (authState.status != AuthStatus.authenticated) {
      return;
    }

    // Arka plandayken kaçırılan Socket.IO olaylarına
    // güvenmek yerine açık ekranlara yenileme bildir.
    getIt<AppResumeService>().notifyResumed();

    // Bağlantı kesilmişse mevcut SocketService
    // güncel JWT ile yeniden bağlanmayı dener.
    final socketService = getIt<SocketService>();

    if (!socketService.isConnected) {
      unawaited(socketService.connect());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
