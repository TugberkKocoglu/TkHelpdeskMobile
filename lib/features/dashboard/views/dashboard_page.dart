import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/models/auth_user.dart';
import '../../auth/viewmodel/auth_bloc.dart';
import '../../auth/viewmodel/auth_event.dart';
import '../viewmodel/dashboard_bloc.dart';
import '../viewmodel/dashboard_event.dart';
import '../viewmodel/dashboard_state.dart';
import '../models/dashboard_ticket.dart';
import '../models/report_summary.dart';

import '../../../app/di/injection.dart';
import '../../../core/lifecycle/app_resume_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../tickets/viewmodel/ticket_create_bloc.dart';
import '../../tickets/viewmodel/ticket_create_event.dart';
import '../../tickets/views/ticket_create_page.dart';
import '../../tickets/viewmodel/ticket_bloc.dart';
import '../../tickets/viewmodel/ticket_event.dart';
import '../../tickets/views/ticket_list_page.dart';

import '../../profile/viewmodel/profile_bloc.dart';
import '../../profile/viewmodel/profile_event.dart';
import '../../profile/views/profile_page.dart';

import '../../notifications/data/notification_repository.dart';
import '../../notifications/viewmodel/notification_bloc.dart';
import '../../notifications/viewmodel/notification_event.dart';
import '../../notifications/views/notification_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.user, super.key});

  final AuthUser user;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int? _unreadCount;
  int _badgeRequestVersion = 0;
  StreamSubscription<void>? _notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _ticketSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<void>? _resumeSubscription;
  Timer? _notificationDebounce;
  Timer? _reportsDebounce;

  AuthUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    final socketService = getIt<SocketService>();
    _notificationSubscription = socketService.notificationRefresh.listen((_) {
      _scheduleUnreadRefresh();
    });
    _ticketSubscription = socketService.ticketChanged.listen((_) {
      _scheduleReportsRefresh();
    });
    _connectionSubscription = socketService.connectionChanged.listen((
      connected,
    ) {
      if (connected) {
        _scheduleUnreadRefresh();
        _scheduleReportsRefresh();
      }
    });
    _resumeSubscription = getIt<AppResumeService>().onResume.listen((_) {
      // Arka planda kaçırılmış Socket.IO olaylarından bağımsız yenile.
      _scheduleUnreadRefresh();
      _scheduleReportsRefresh();
    });
    _refreshUnreadCount();
  }

  void _scheduleUnreadRefresh() {
    _notificationDebounce?.cancel();
    _notificationDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(_refreshUnreadCount());
    });
  }

  void _scheduleReportsRefresh() {
    _reportsDebounce?.cancel();
    _reportsDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<DashboardBloc>().add(DashboardRefreshRequested(user));
    });
  }

  @override
  void dispose() {
    _notificationDebounce?.cancel();
    _reportsDebounce?.cancel();
    _notificationSubscription?.cancel();
    _ticketSubscription?.cancel();
    _connectionSubscription?.cancel();
    _resumeSubscription?.cancel();
    _badgeRequestVersion++;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _unreadCount = null;
      _refreshUnreadCount();
      _scheduleReportsRefresh();
    }
  }

  Future<void> _refreshUnreadCount() async {
    final requestVersion = ++_badgeRequestVersion;
    try {
      final result = await getIt<NotificationRepository>().getNotifications(
        page: 1,
        pageSize: 1,
      );
      if (!mounted || requestVersion != _badgeRequestVersion) return;
      setState(() => _unreadCount = result.unreadCount);
    } catch (_) {
      // Bildirim sayacı yüklenemese de Dashboard çalışmaya devam etsin.
      if (!mounted || requestVersion != _badgeRequestVersion) return;
      // Önceden alınan son başarılı değeri koru.
    }
  }

  Widget _notificationIcon() {
    final unreadCount = _unreadCount ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (unreadCount > 0)
          Positioned(
            right: -11,
            top: -10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1B2B45), width: 1),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _refresh(BuildContext context) {
    context.read<DashboardBloc>().add(DashboardRefreshRequested(user));
    _refreshUnreadCount();
  }

  ButtonStyle _ticketButtonStyle() {
    return OutlinedButton.styleFrom(
      backgroundColor: const Color(0xFF1B2B45),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF1B2B45)),
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) =>
              getIt<NotificationBloc>()..add(const NotificationListStarted()),
          child: const NotificationPage(),
        ),
      ),
    );
    if (mounted) {
      _refreshUnreadCount();
    }
  }

  void _openTicketList(BuildContext context, TicketListMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) =>
              getIt<TicketBloc>()
                ..add(TicketListStarted(mode: mode, currentUserId: user.id)),
          child: TicketListPage(mode: mode),
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => getIt<ProfileBloc>()..add(const ProfileStarted()),
          child: const ProfilePage(),
        ),
      ),
    );
  }

  Future<void> _openTicketCreate(BuildContext context) async {
    if (!user.isHelpdesk) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BlocProvider(
          create: (_) =>
              getIt<TicketCreateBloc>()..add(const TicketCreateStarted()),
          child: const TicketCreatePage(),
        ),
      ),
    );

    if (created == true && context.mounted) {
      _refresh(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TK Helpdesk'),

        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => _refresh(context),
            icon: const Icon(Icons.refresh_rounded),
          ),

          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () => _openNotifications(context),
            icon: _notificationIcon(),
          ),

          IconButton(
            tooltip: 'Profilim',
            onPressed: () => _openProfile(context),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.initial ||
              state.status == DashboardStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == DashboardStatus.failure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'Bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _refresh(context),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<DashboardBloc>();

              _refreshUnreadCount();
              bloc.add(DashboardRefreshRequested(user));

              await bloc.stream.firstWhere(
                (state) =>
                    state.status == DashboardStatus.success ||
                    state.status == DashboardStatus.failure,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Merhaba, ${user.firstName} 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.isHelpdesk
                      ? 'Helpdesk genel görünüm'
                      : 'Departmanınızın güncel talep durumu',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rol: ${user.role}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                if (user.isHelpdesk && state.helpdeskSummary != null)
                  _HelpdeskDashboard(summary: state.helpdeskSummary!),
                if (user.isEmployee && state.employeeSummary != null)
                  _EmployeeDashboard(summary: state.employeeSummary!),

                const SizedBox(height: 28),

                Text(
                  'Talep Yönetimi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                if (user.isHelpdesk) ...[
                  OutlinedButton.icon(
                    style: _ticketButtonStyle(),
                    onPressed: () => _openTicketCreate(context),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Yeni Talep Oluştur'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: _ticketButtonStyle(),
                    onPressed: () =>
                        _openTicketList(context, TicketListMode.all),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Tüm Talepler'),
                  ),
                ],

                if (user.isEmployee) ...[
                  OutlinedButton.icon(
                    style: _ticketButtonStyle(),
                    onPressed: () =>
                        _openTicketList(context, TicketListMode.pool),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Departman Havuzu'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: _ticketButtonStyle(),
                    onPressed: () =>
                        _openTicketList(context, TicketListMode.mine),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('Taleplerim'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HelpdeskDashboard extends StatelessWidget {
  const _HelpdeskDashboard({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final overview = summary.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${summary.year} Yılı Talep Özeti',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        _StatsGrid(
          items: [
            _StatItem(
              title: 'Toplam Talep',
              value: '${overview.totalTickets}',
              icon: Icons.confirmation_number_outlined,
              color: const Color(0xFF2563EB),
            ),
            _StatItem(
              title: 'Açık Talep',
              value: '${overview.openTickets}',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _StatItem(
              title: 'Kapatılan',
              value: '${overview.closedTickets}',
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF16A34A),
            ),
            _StatItem(
              title: 'Kapanma Oranı',
              value: '%${overview.closureRate.toStringAsFixed(1)}',
              icon: Icons.pie_chart_outline_rounded,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Talep Durumları', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _DistributionCard(values: summary.statusDistribution),
        const SizedBox(height: 24),
        Text('Öncelik Dağılımı', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _DistributionCard(values: summary.priorityDistribution),
      ],
    );
  }
}

class _EmployeeDashboard extends StatelessWidget {
  const _EmployeeDashboard({required this.summary});

  final EmployeeDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Departman Özeti', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _StatsGrid(
          items: [
            _StatItem(
              title: 'Toplam Talep',
              value: '${summary.totalTickets}',
              icon: Icons.confirmation_number_outlined,
              color: const Color(0xFF2563EB),
            ),
            _StatItem(
              title: 'Havuzdaki',
              value: '${summary.poolTickets}',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _StatItem(
              title: 'Üstlendiğim Açık',
              value: '${summary.myOpenTickets}',
              icon: Icons.person_outline_rounded,
              color: const Color(0xFF7C3AED),
            ),
            _StatItem(
              title: 'İşlemdeki',
              value: '${summary.inProgressTickets}',
              icon: Icons.sync_rounded,
              color: const Color(0xFF0891B2),
            ),
            _StatItem(
              title: 'Kapatılan',
              value: '${summary.closedTickets}',
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF16A34A),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 148,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return Card(
              margin: EdgeInsets.zero,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, color: item.color, size: 28),
                    const Spacer(),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.values});

  final Map<String, int> values;

  String _label(String key) {
    return switch (key) {
      'InPool' => 'Havuzda',
      'Claimed' => 'Üstlenildi',
      'InProgress' => 'İşlemde',
      'Closed' => 'Kapatıldı',
      'Low' => 'Düşük',
      'Normal' => 'Normal',
      'High' => 'Yüksek',
      'Critical' => 'Kritik',
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: values.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(_label(entry.key))),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
