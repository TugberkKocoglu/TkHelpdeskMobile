import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../core/lifecycle/app_resume_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../auth/viewmodel/auth_bloc.dart';
import '../../tickets/viewmodel/ticket_detail_bloc.dart';
import '../../tickets/viewmodel/ticket_detail_event.dart';
import '../../tickets/views/ticket_detail_page.dart';
import '../models/notification_model.dart';
import '../viewmodel/notification_bloc.dart';
import '../viewmodel/notification_event.dart';
import '../viewmodel/notification_state.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color _primary = Color(0xFF1B2B45);

  StreamSubscription<void>? _notificationSubscription;
  StreamSubscription<void>? _resumeSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _refreshDebounce;
  Timer? _retryRefresh;
  bool _pendingSocketRefresh = false;

  @override
  void initState() {
    super.initState();

    _resumeSubscription = getIt<AppResumeService>().onResume.listen((_) {
      _scheduleRefresh();
    });

    final socketService = getIt<SocketService>();
    _notificationSubscription = socketService.notificationRefresh.listen((_) {
      _scheduleRefresh();
    });
    _connectionSubscription = socketService.connectionChanged.listen((
      connected,
    ) {
      if (connected) _scheduleRefresh();
    });
  }

  void _scheduleRefresh() {
    if (!mounted) return;
    _pendingSocketRefresh = true;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 350),
      _trySocketRefresh,
    );
  }

  void _trySocketRefresh() {
    if (!mounted || !_pendingSocketRefresh) return;

    final bloc = context.read<NotificationBloc>();
    final state = bloc.state;
    final busy =
        state.status == NotificationListStatus.loading ||
        state.isLoadingMore ||
        state.isProcessing;

    if (busy || state.status == NotificationListStatus.initial) {
      _retryRefresh?.cancel();
      _retryRefresh = Timer(
        const Duration(milliseconds: 500),
        _trySocketRefresh,
      );
      return;
    }

    _pendingSocketRefresh = false;
    bloc.add(const NotificationRefreshRequested());
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _retryRefresh?.cancel();
    _notificationSubscription?.cancel();
    _resumeSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: _primary.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white70,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(date.day)}.${two(date.month)}.${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _openNotification(NotificationModel notification) async {
    final notificationBloc = context.read<NotificationBloc>();
    final user = context.read<AuthBloc>().state.user;

    if (!notification.isRead) {
      notificationBloc.add(NotificationMarkAsReadRequested(notification.id));
    }

    final ticketId = notification.ticketId;
    if (ticketId == null || user == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              getIt<TicketDetailBloc>()..add(TicketDetailStarted(ticketId)),
          child: TicketDetailPage(ticketId: ticketId, user: user),
        ),
      ),
    );

    if (mounted) {
      notificationBloc.add(const NotificationRefreshRequested());
    }
  }

  void _showActionMessage(BuildContext context, NotificationState state) {
    final message = state.actionMessage ?? state.errorMessage;
    if (message == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              return IconButton(
                tooltip: 'Yenile',
                onPressed:
                    state.isProcessing ||
                        state.isLoadingMore ||
                        state.status == NotificationListStatus.loading
                    ? null
                    : () => context.read<NotificationBloc>().add(
                        const NotificationRefreshRequested(),
                      ),
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listenWhen: (previous, current) =>
            previous.actionVersion != current.actionVersion,
        listener: _showActionMessage,
        builder: (context, state) {
          if (state.status == NotificationListStatus.initial ||
              state.status == NotificationListStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == NotificationListStatus.failure &&
              state.items.isEmpty) {
            return _buildError(context, state);
          }

          return Stack(
            children: [
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Bildirimlerim',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${state.total} bildirim • ${state.unreadCount} okunmamış',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  if (state.unreadCount > 0) ...[
                    ElevatedButton.icon(
                      style: _buttonStyle(),
                      onPressed: state.isProcessing || state.isLoadingMore
                          ? null
                          : () => context.read<NotificationBloc>().add(
                              const NotificationMarkAllAsReadRequested(),
                            ),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Tümünü Okundu İşaretle'),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (state.items.isEmpty)
                    _buildEmpty(context)
                  else
                    ...state.items.map(
                      (notification) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NotificationCard(
                          notification: notification,
                          dateText: _formatDate(notification.createdAt),
                          onTap: state.isProcessing
                              ? null
                              : () => _openNotification(notification),
                        ),
                      ),
                    ),
                  if (state.errorMessage != null && state.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.hasNextPage) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: _buttonStyle(),
                      onPressed: state.isLoadingMore || state.isProcessing
                          ? null
                          : () => context.read<NotificationBloc>().add(
                              const NotificationNextPageRequested(),
                            ),
                      icon: state.isLoadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        state.isLoadingMore
                            ? 'Yükleniyor...'
                            : 'Daha Fazla Yükle',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                ],
              ),
              if (state.isProcessing)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x22000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 58,
            color: _primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz bildiriminiz bulunmuyor.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, NotificationState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _primary),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Bildirimler yüklenemedi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: _buttonStyle(),
              onPressed: () => context.read<NotificationBloc>().add(
                const NotificationRefreshRequested(),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.dateText,
    required this.onTap,
  });

  final NotificationModel notification;
  final String dateText;
  final VoidCallback? onTap;

  static const Color _primary = Color(0xFF1B2B45);

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Card(
      margin: EdgeInsets.zero,
      color: isUnread ? const Color(0xFFF0F5FC) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isUnread
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                    color: _primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        color: _primary,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isUnread)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(notification.message),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      dateText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (notification.hasTicket) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: _primary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
