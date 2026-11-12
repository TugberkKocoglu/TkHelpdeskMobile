import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/viewmodel/auth_bloc.dart';
import '../../auth/viewmodel/auth_event.dart';
import '../viewmodel/profile_bloc.dart';
import '../viewmodel/profile_event.dart';
import '../viewmodel/profile_state.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const Color _primary = Color(0xFF1B2B45);

  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
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

  InputDecoration _passwordDecoration({
    required String label,
    required bool hidden,
    required VoidCallback toggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: IconButton(
        tooltip: hidden ? 'Şifreyi göster' : 'Şifreyi gizle',
        onPressed: toggle,
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<ProfileBloc>().add(
      ProfilePasswordChangeRequested(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      ),
    );
  }

  Future<void> _handleSuccess(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şifre Değiştirildi'),
        content: Text(
          '$message\n\nYeni şifrenizle tekrar giriş yapabilirsiniz.',
        ),
        actions: [
          ElevatedButton(
            style: _buttonStyle(),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    // Backend şifre değişikliği sonrası yeniden giriş istiyor.
    // Mevcut AuthBloc üzerinden normal çıkış akışını kullanıyoruz.
    final authBloc = context.read<AuthBloc>();

    authBloc.add(const AuthLogoutRequested());

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre Değiştir')),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listenWhen: (previous, current) =>
            previous.passwordChangeStatus != current.passwordChangeStatus,
        listener: (context, state) {
          if (state.passwordChangeStatus == PasswordChangeStatus.success) {
            _handleSuccess(
              state.passwordMessage ?? 'Şifreniz başarıyla değiştirildi.',
            );
          } else if (state.passwordChangeStatus ==
              PasswordChangeStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.passwordMessage ?? 'Şifre değiştirilemedi.',
                  ),
                ),
              );
          }
        },
        builder: (context, state) {
          final submitting = state.isChangingPassword;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Hesap Güvenliği',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Şifrenizi değiştirmek için mevcut şifrenizi '
                  've kullanmak istediğiniz yeni şifreyi girin.',
                ),
                const SizedBox(height: 24),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _currentController,
                          obscureText: _hideCurrent,
                          enabled: !submitting,
                          autofillHints: const [AutofillHints.password],
                          decoration: _passwordDecoration(
                            label: 'Mevcut Şifre',
                            hidden: _hideCurrent,
                            toggle: () {
                              setState(() {
                                _hideCurrent = !_hideCurrent;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Mevcut şifrenizi girin.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _newController,
                          obscureText: _hideNew,
                          enabled: !submitting,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: _passwordDecoration(
                            label: 'Yeni Şifre',
                            hidden: _hideNew,
                            toggle: () {
                              setState(() {
                                _hideNew = !_hideNew;
                              });
                            },
                          ),
                          validator: (value) {
                            if ((value?.length ?? 0) < 8) {
                              return 'Yeni şifre en az 8 karakter olmalıdır.';
                            }

                            if (value == _currentController.text) {
                              return 'Yeni şifre mevcut şifreden farklı olmalıdır.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _hideConfirm,
                          enabled: !submitting,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: _passwordDecoration(
                            label: 'Yeni Şifre Tekrar',
                            hidden: _hideConfirm,
                            toggle: () {
                              setState(() {
                                _hideConfirm = !_hideConfirm;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value != _newController.text) {
                              return 'Yeni şifreler eşleşmiyor.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Yeni şifreniz en az 8 karakter olmalıdır. '
                  'Şifre değişikliğinden sonra yeniden giriş yapmanız gerekir.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: _buttonStyle(),
                  onPressed: submitting ? null : _submit,
                  icon: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(
                    submitting ? 'Şifre Değiştiriliyor...' : 'Şifremi Değiştir',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
