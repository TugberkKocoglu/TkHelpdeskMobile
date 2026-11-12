import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../../features/auth/models/auth_user.dart';
import '../../features/auth/viewmodel/auth_bloc.dart';
import '../../features/auth/viewmodel/auth_event.dart';
import '../../features/auth/viewmodel/auth_state.dart';
import '../../features/auth/views/login_page.dart';
import '../../features/dashboard/viewmodel/dashboard_bloc.dart';
import '../../features/dashboard/viewmodel/dashboard_event.dart';
import '../../features/dashboard/views/dashboard_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => const _AuthGate())],
);

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          case AuthStatus.unauthenticated:
            return const LoginPage();

          case AuthStatus.sessionCheckFailed:
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 54),
                        const SizedBox(height: 20),
                        Text(
                          'Bağlantı kurulamadı',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage ?? 'Oturum kontrol edilemedi.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.read<AuthBloc>().add(const AuthStarted());
                          },
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

          case AuthStatus.authenticated:
            final user = state.user;

            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('Kullanıcı bilgileri bulunamadı.')),
              );
            }

            return _DashboardHost(key: ValueKey(user.id), user: user);
        }
      },
    );
  }
}

class _DashboardHost extends StatelessWidget {
  const _DashboardHost({required this.user, super.key});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardBloc>()..add(DashboardStarted(user)),
      child: DashboardPage(user: user),
    );
  }
}
