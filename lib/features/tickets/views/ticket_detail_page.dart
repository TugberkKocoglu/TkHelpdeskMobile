import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../core/lifecycle/app_resume_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../auth/models/auth_user.dart';
import '../models/ticket_comment_model.dart';
import '../models/ticket_detail_model.dart';
import '../models/ticket_model.dart';
import '../viewmodel/ticket_detail_bloc.dart';
import '../viewmodel/ticket_detail_event.dart';
import '../viewmodel/ticket_detail_state.dart';

class TicketDetailPage extends StatefulWidget {
  const TicketDetailPage({
    required this.ticketId,
    required this.user,
    super.key,
  });

  final int ticketId;
  final AuthUser user;

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final _commentController = TextEditingController();
  bool _dataChanged = false;

  StreamSubscription<Map<String, dynamic>>? _ticketSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<void>? _resumeSubscription;
  Timer? _socketRefreshTimer;

  @override
  void initState() {
    super.initState();

    final socketService = getIt<SocketService>();

    _ticketSubscription = socketService.ticketChanged.listen((payload) {
      final rawId = payload['ticketId'];
      final changedId = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');

      if (changedId == widget.ticketId) {
        _scheduleSocketRefresh();
      }
    });

    _connectionSubscription = socketService.connectionChanged.listen((
      connected,
    ) {
      if (connected) {
        _scheduleSocketRefresh();
      }
    });

    _resumeSubscription = getIt<AppResumeService>().onResume.listen((_) {
      _scheduleSocketRefresh();
    });
  }

  void _scheduleSocketRefresh() {
    if (!mounted) return;

    _socketRefreshTimer?.cancel();
    _socketRefreshTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<TicketDetailBloc>().add(
        const TicketDetailRefreshRequested(),
      );
    });
  }

  static const _primary = Color(0xFF1B2B45);

  @override
  void dispose() {
    _socketRefreshTimer?.cancel();
    _ticketSubscription?.cancel();
    _connectionSubscription?.cancel();
    _resumeSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: _primary.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white70,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _goBack() {
    Navigator.of(context).pop(_dataChanged);
  }

  Future<void> _refresh() async {
    final bloc = context.read<TicketDetailBloc>();

    bloc.add(const TicketDetailRefreshRequested());

    await bloc.stream.firstWhere(
      (state) =>
          state.status == TicketDetailStatus.success ||
          state.status == TicketDetailStatus.failure,
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(date.day)}.${two(date.month)}.${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _confirmClaim() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Talebi Üstlen'),
        content: const Text('Bu talebi üzerinize almak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: _buttonStyle(),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Üstlen'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<TicketDetailBloc>().add(const TicketClaimRequested());
    }
  }

  Future<void> _confirmStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İşleme Al'),
        content: const Text(
          'Talep üzerinde çalışmaya başlamak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: _buttonStyle(),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İşleme Al'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<TicketDetailBloc>().add(const TicketStartRequested());
    }
  }

  Future<void> _showCloseDialog() async {
    final controller = TextEditingController();
    String? validationMessage;

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Talebi Kapat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Talebi kapatmak için çözüm notunu girin.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: 'Çözüm Notu',
                  alignLabelWithHint: true,
                  errorText: validationMessage,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: _buttonStyle(),
              onPressed: () {
                final value = controller.text.trim();

                if (value.length < 5) {
                  setDialogState(() {
                    validationMessage =
                        'Çözüm notu en az 5 karakter olmalıdır.';
                  });
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Talebi Kapat'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    if (note != null && mounted) {
      context.read<TicketDetailBloc>().add(TicketCloseRequested(note));
    }
  }

  Future<void> _showPriorityDialog(TicketPriority current) async {
    final selected = await showDialog<TicketPriority>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Öncelik Değiştir'),
        children: TicketPriority.values.map((priority) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, priority),
            child: Row(
              children: [
                Icon(
                  current == priority
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _primary,
                ),
                const SizedBox(width: 12),
                Text(priority.label),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null && selected != current && mounted) {
      context.read<TicketDetailBloc>().add(
        TicketPriorityChangeRequested(selected.value),
      );
    }
  }

  void _addComment() {
    final content = _commentController.text.trim();

    if (content.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum en az 2 karakter olmalıdır.')),
      );
      return;
    }

    context.read<TicketDetailBloc>().add(TicketCommentAddRequested(content));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Talep Detayı'),
          leading: IconButton(
            tooltip: 'Geri',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goBack,
          ),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                context.read<TicketDetailBloc>().add(
                  const TicketDetailRefreshRequested(),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<TicketDetailBloc, TicketDetailState>(
          listenWhen: (previous, current) =>
              previous.actionVersion != current.actionVersion ||
              previous.dataVersion != current.dataVersion,
          listener: (context, state) {
            if (state.dataVersion > 0) {
              _dataChanged = true;
            }

            if (state.successMessage == 'Yorum eklendi.') {
              _commentController.clear();
            }

            final message = state.actionError ?? state.successMessage;

            if (message != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          },
          builder: (context, state) {
            if (state.status == TicketDetailStatus.initial ||
                (state.status == TicketDetailStatus.loading &&
                    state.detail == null)) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == TicketDetailStatus.failure &&
                state.detail == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? 'Talep detayı yüklenemedi.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: _buttonStyle(),
                        onPressed: () {
                          context.read<TicketDetailBloc>().add(
                            const TicketDetailRefreshRequested(),
                          );
                        },
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final detail = state.detail;

            if (detail == null) {
              return const Center(child: Text('Talep bulunamadı.'));
            }

            final ticket = detail.ticket;

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ticketInformation(detail),
                      const SizedBox(height: 16),
                      _ticketActions(ticket, state.isProcessing),
                      const SizedBox(height: 16),
                      _historySection(detail.history),
                      const SizedBox(height: 16),
                      _commentsSection(
                        state.comments,
                        ticket,
                        state.isProcessing,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                if (state.isProcessing)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x44000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _ticketInformation(TicketDetailModel detail) {
    final ticket = detail.ticket;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket.ticketNumber,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ticket.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(ticket.description),
            const Divider(height: 32),
            _infoRow('Durum', ticket.status.label),
            _infoRow('Öncelik', ticket.priority.label),
            _infoRow('Oluşturulma', _formatDate(ticket.createdAt)),
            _infoRow(
              'Atanan Personel',
              detail.assignedUserName ?? 'Henüz atanmadı',
            ),
            if (ticket.claimedAt != null)
              _infoRow('Üstlenilme', _formatDate(ticket.claimedAt!)),
            if (ticket.closedAt != null)
              _infoRow('Kapatılma', _formatDate(ticket.closedAt!)),
            if (ticket.resolutionNote != null &&
                ticket.resolutionNote!.isNotEmpty)
              _infoRow('Çözüm Notu', ticket.resolutionNote!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(title, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketActions(TicketModel ticket, bool processing) {
    Widget? action;

    if (widget.user.isEmployee) {
      if (ticket.isInPool) {
        action = ElevatedButton.icon(
          style: _buttonStyle(),
          onPressed: processing ? null : _confirmClaim,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Talebi Üstlen'),
        );
      } else if (ticket.isAssignedTo(widget.user.id) &&
          ticket.status == TicketStatus.claimed) {
        action = ElevatedButton.icon(
          style: _buttonStyle(),
          onPressed: processing ? null : _confirmStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('İşleme Al'),
        );
      } else if (ticket.isAssignedTo(widget.user.id) &&
          ticket.status == TicketStatus.inProgress) {
        action = ElevatedButton.icon(
          style: _buttonStyle(),
          onPressed: processing ? null : _showCloseDialog,
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Çözüm Notuyla Kapat'),
        );
      }
    }

    if (widget.user.isHelpdesk && !ticket.isClosed) {
      action = ElevatedButton.icon(
        style: _buttonStyle(),
        onPressed: processing
            ? null
            : () => _showPriorityDialog(ticket.priority),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Öncelik Değiştir'),
      );
    }

    if (action == null) {
      return const SizedBox.shrink();
    }

    return action;
  }

  Widget _historySection(List<TicketHistoryModel> history) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İşlem Geçmişi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (history.isEmpty) const Text('Henüz işlem geçmişi bulunmuyor.'),
            for (final item in history) ...[
              Text(
                item.description ?? item.action,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.performedByName ?? 'Bilinmeyen Kullanıcı'}'
                ' • ${_formatDate(item.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commentsSection(
    List<TicketCommentModel> comments,
    TicketModel ticket,
    bool processing,
  ) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yorumlar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (comments.isEmpty) const Text('Henüz yorum yapılmamış.'),
            for (final comment in comments) ...[
              Text(
                comment.userName ?? 'Bilinmeyen Kullanıcı',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(comment.content),
              const SizedBox(height: 6),
              Text(
                _formatDate(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 24),
            ],
            if (!ticket.isClosed) ...[
              TextField(
                controller: _commentController,
                minLines: 2,
                maxLines: 5,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Yorum Yaz',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: _buttonStyle(),
                onPressed: processing ? null : _addComment,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Yorum Ekle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
