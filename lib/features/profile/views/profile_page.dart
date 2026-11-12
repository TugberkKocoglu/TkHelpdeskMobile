import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../viewmodel/profile_bloc.dart';
import '../viewmodel/profile_event.dart';
import '../viewmodel/profile_state.dart';
import 'change_password_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color _primary = Color(0xFF1B2B45);

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final profileBloc = context.read<ProfileBloc>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: profileBloc,
          child: const ChangePasswordPage(),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Icon(icon, color: _primary, size: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<ProfileBloc>().add(const ProfileRefreshRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.initial ||
              (state.isLoading && state.user == null)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ProfileStatus.failure && state.user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: _primary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'Profil bilgileri alınamadı.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: _buttonStyle(),
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                          const ProfileRefreshRequested(),
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

          final user = state.user;
          if (user == null) {
            return const Center(child: Text('Kullanıcı bilgisi bulunamadı.'));
          }

          final roleText = user.isHelpdesk
              ? 'Helpdesk'
              : user.isEmployee
              ? 'Çalışan'
              : user.role;

          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<ProfileBloc>();

              bloc.add(const ProfileRefreshRequested());

              await bloc.stream.firstWhere(
                (value) =>
                    value.status == ProfileStatus.success ||
                    value.status == ProfileStatus.failure,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: Color(0xFF34445E),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        roleText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hesap Bilgileri',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _infoRow(
                          icon: Icons.badge_outlined,
                          label: 'Ad Soyad',
                          value: user.fullName,
                        ),
                        const Divider(height: 1),
                        _infoRow(
                          icon: Icons.mail_outline_rounded,
                          label: 'E-posta',
                          value: user.email,
                        ),
                        const Divider(height: 1),
                        _infoRow(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Rol',
                          value: roleText,
                        ),
                        const Divider(height: 1),

                        _infoRow(
                          icon: Icons.groups_outlined,
                          label: 'Departman',
                          value: state.departmentName ?? 'Belirtilmemiş',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: _buttonStyle(),
                  onPressed: () => _openChangePassword(context),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Şifre Değiştir'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
