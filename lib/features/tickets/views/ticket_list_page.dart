import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/app_resume_service.dart';
import '../../../core/socket/socket_service.dart';

import '../models/ticket_model.dart';
import '../viewmodel/ticket_bloc.dart';
import '../viewmodel/ticket_event.dart';
import '../viewmodel/ticket_state.dart';
import '../../../app/di/injection.dart';
import '../../auth/viewmodel/auth_bloc.dart';
import '../viewmodel/ticket_detail_bloc.dart';
import '../viewmodel/ticket_detail_event.dart';
import 'ticket_detail_page.dart';

class TicketListPage extends StatefulWidget {
  const TicketListPage({required this.mode, super.key});

  final TicketListMode mode;

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  StreamSubscription<Map<String, dynamic>>? _ticketSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<void>? _resumeSubscription;
  Timer? _refreshTimer;

  TicketListMode get mode => widget.mode;

  @override
  void initState() {
    super.initState();
    final socket = getIt<SocketService>();

    _ticketSubscription = socket.ticketChanged.listen((_) {
      _scheduleRefresh();
    });

    _connectionSubscription = socket.connectionChanged.listen((connected) {
      if (connected) _scheduleRefresh();
    });

    _resumeSubscription = getIt<AppResumeService>().onResume.listen((_) {
      _scheduleRefresh();
    });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<TicketBloc>().add(const TicketListRefreshRequested());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ticketSubscription?.cancel();
    _connectionSubscription?.cancel();
    _resumeSubscription?.cancel();
    super.dispose();
  }

  String get _pageTitle {
    return switch (mode) {
      TicketListMode.all => 'Tüm Talepler',
      TicketListMode.pool => 'Departman Havuzu',
      TicketListMode.mine => 'Taleplerim',
    };
  }

  Future<void> _openTicketDetail(
    BuildContext context,
    TicketModel ticket,
  ) async {
    final user = context.read<AuthBloc>().state.user;

    if (user == null) return;

    final ticketBloc = context.read<TicketBloc>();

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              getIt<TicketDetailBloc>()..add(TicketDetailStarted(ticket.id)),
          child: TicketDetailPage(ticketId: ticket.id, user: user),
        ),
      ),
    );

    // Detayda durum veya öncelik değişmiş olabilir.
    // Geri dönüldüğünde listeyi güncelle.
    if (context.mounted) {
      ticketBloc.add(const TicketListRefreshRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () {
              context.read<TicketBloc>().add(
                const TicketListRefreshRequested(),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketListStatus.initial ||
              state.status == TicketListStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == TicketListStatus.failure) {
            return _ErrorView(
              message: state.errorMessage ?? 'Talepler yüklenemedi.',
              onRetry: () {
                context.read<TicketBloc>().add(
                  const TicketListRefreshRequested(),
                );
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _pageTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toplam ${state.total} talep',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),

              if (mode != TicketListMode.pool) ...[
                _StatusFilter(
                  selectedStatus: state.selectedStatus,
                  onChanged: (status) {
                    context.read<TicketBloc>().add(TicketStatusChanged(status));
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (state.items.isEmpty)
                const _EmptyView()
              else
                ...state.items.map(
                  (ticket) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TicketCard(
                      ticket: ticket,
                      onTap: () => _openTicketDetail(context, ticket),
                    ),
                  ),
                ),

              if (state.errorMessage != null && state.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              if (state.hasNextPage) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: state.isLoadingMore
                      ? null
                      : () {
                          context.read<TicketBloc>().add(
                            const TicketNextPageRequested(),
                          );
                        },
                  child: state.isLoadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Daha Fazla Yükle'),
                ),
              ],

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selectedStatus, required this.onChanged});

  final String? selectedStatus;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Durum',
        prefixIcon: Icon(Icons.filter_list_rounded),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedStatus,
          isExpanded: true,
          isDense: true,
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('Tüm Durumlar')),
            DropdownMenuItem<String?>(value: 'InPool', child: Text('Havuzda')),
            DropdownMenuItem<String?>(
              value: 'Claimed',
              child: Text('Üstlenildi'),
            ),
            DropdownMenuItem<String?>(
              value: 'InProgress',
              child: Text('İşlemde'),
            ),
            DropdownMenuItem<String?>(
              value: 'Closed',
              child: Text('Kapatıldı'),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final TicketModel ticket;
  final VoidCallback onTap;

  String _statusText(String status) {
    return switch (status) {
      'InPool' => 'Havuzda',
      'Claimed' => 'Üstlenildi',
      'InProgress' => 'İşlemde',
      'Closed' => 'Kapatıldı',
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'InPool' => const Color(0xFFF59E0B),
      'Claimed' => const Color(0xFF2563EB),
      'InProgress' => const Color(0xFF0891B2),
      'Closed' => const Color(0xFF16A34A),
      _ => Colors.grey,
    };
  }

  String _priorityText(String priority) {
    return switch (priority) {
      'Low' => 'Düşük',
      'Normal' => 'Normal',
      'High' => 'Yüksek',
      'Critical' => 'Kritik',
      _ => priority,
    };
  }

  String _dateText(DateTime value) {
    final local = value.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}.'
        '${twoDigits(local.month)}.'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status.value);

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.ticketNumber,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(ticket.status.value),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 17),
                  const SizedBox(width: 5),
                  Text(_priorityText(ticket.priority.value)),
                  const Spacer(),
                  const Icon(Icons.calendar_today_outlined, size: 15),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _dateText(ticket.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text('Gösterilecek talep bulunamadı.'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
