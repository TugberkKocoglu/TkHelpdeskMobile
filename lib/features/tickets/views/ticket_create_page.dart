import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/ticket_model.dart';
import '../viewmodel/ticket_create_bloc.dart';
import '../viewmodel/ticket_create_event.dart';
import '../viewmodel/ticket_create_state.dart';

class TicketCreatePage extends StatefulWidget {
  const TicketCreatePage({super.key});

  @override
  State<TicketCreatePage> createState() => _TicketCreatePageState();
}

class _TicketCreatePageState extends State<TicketCreatePage> {
  static const Color _primary = Color(0xFF1B2B45);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedCompanyId;
  int? _selectedDepartmentId;
  TicketPriority _selectedPriority = TicketPriority.normal;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: _primary.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white70,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _submit(TicketCreateState state) {
    if (!state.canSubmit) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompanyId == null || _selectedDepartmentId == null) {
      return;
    }

    context.read<TicketCreateBloc>().add(
      TicketCreateSubmitted(
        companyId: _selectedCompanyId!,
        departmentId: _selectedDepartmentId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Talep Oluştur'),
        actions: [
          BlocBuilder<TicketCreateBloc, TicketCreateState>(
            builder: (context, state) {
              return IconButton(
                tooltip: 'Seçenekleri Yenile',
                onPressed: state.isLoading || state.isSubmitting
                    ? null
                    : () {
                        context.read<TicketCreateBloc>().add(
                          const TicketCreateRefreshRequested(),
                        );
                      },
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<TicketCreateBloc, TicketCreateState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.status != current.status,
        listener: (context, state) {
          if (state.status == TicketCreateStatus.success) {
            final ticket = state.createdTicket;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ticket == null
                      ? 'Talep başarıyla oluşturuldu.'
                      : '${ticket.ticketNumber} numaralı talep oluşturuldu.',
                ),
              ),
            );

            Navigator.of(context).pop(true);
            return;
          }

          if (state.errorMessage != null) {
            _showMessage(state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading || state.status == TicketCreateStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == TicketCreateStatus.failure) {
            return _buildErrorState(state);
          }

          return _buildForm(state);
        },
      ),
    );
  }

  Widget _buildErrorState(TicketCreateState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: _primary),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ??
                  'Şirket ve departman bilgileri yüklenemedi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: _primaryButtonStyle(),
              onPressed: () {
                context.read<TicketCreateBloc>().add(
                  const TicketCreateRefreshRequested(),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(TicketCreateState state) {
    final companyIds = state.companies.map((company) => company.id).toSet();

    final departmentIds = state.departments
        .map((department) => department.id)
        .toSet();

    // API'den seçenekler güncellendiyse eski seçimi
    // Dropdown'a geçersiz değer olarak göndermeyelim.
    final companyValue = companyIds.contains(_selectedCompanyId)
        ? _selectedCompanyId
        : null;

    final departmentValue = departmentIds.contains(_selectedDepartmentId)
        ? _selectedDepartmentId
        : null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Talep Bilgileri',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni talebin gönderileceği şirketi ve '
            'departmanı seçerek bilgileri doldurun.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'company-${state.companies.length}-$companyValue',
                    ),
                    initialValue: companyValue,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      label: 'Şirket',
                      icon: Icons.business_outlined,
                    ),
                    items: state.companies.map((company) {
                      return DropdownMenuItem<int>(
                        value: company.id,
                        child: Text(
                          company.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: state.isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCompanyId = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Şirket seçmelisiniz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'department-${state.departments.length}-$departmentValue',
                    ),
                    initialValue: departmentValue,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      label: 'Departman',
                      icon: Icons.groups_outlined,
                    ),
                    items: state.departments.map((department) {
                      return DropdownMenuItem<int>(
                        value: department.id,
                        child: Text(
                          department.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: state.isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedDepartmentId = value;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Departman seçmelisiniz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _titleController,
                    enabled: !state.isSubmitting,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      label: 'Talep Başlığı',
                      icon: Icons.title_rounded,
                      hint: 'Talebin konusunu yazın',
                    ),
                    validator: (value) {
                      if ((value?.trim().length ?? 0) < 3) {
                        return 'Başlık en az 3 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _descriptionController,
                    enabled: !state.isSubmitting,
                    minLines: 4,
                    maxLines: 7,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      label: 'Açıklama',
                      icon: Icons.description_outlined,
                      hint: 'Talebin detaylarını yazın',
                    ),
                    validator: (value) {
                      if ((value?.trim().length ?? 0) < 5) {
                        return 'Açıklama en az 5 karakter olmalıdır.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  DropdownButtonFormField<TicketPriority>(
                    initialValue: _selectedPriority,
                    decoration: _inputDecoration(
                      label: 'Öncelik',
                      icon: Icons.flag_outlined,
                    ),
                    items: TicketPriority.values.map((priority) {
                      return DropdownMenuItem<TicketPriority>(
                        value: priority,
                        child: Text(priority.label),
                      );
                    }).toList(),
                    onChanged: state.isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _selectedPriority = value;
                              });
                            }
                          },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: _primaryButtonStyle(),
            onPressed: state.canSubmit ? () => _submit(state) : null,
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add_task_rounded),
            label: Text(
              state.isSubmitting ? 'Talep Oluşturuluyor...' : 'Talep Oluştur',
            ),
          ),

          if (state.companies.isEmpty || state.departments.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Talep oluşturmak için en az bir aktif şirket '
              've uygun departman bulunmalıdır.',
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
