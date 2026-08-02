import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final RecoveryMethod method;
  const ResetPasswordScreen({super.key, required this.method});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isDone = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_newPasswordCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_newPasswordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO: call reset password API when Mahmoud builds it
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          if (_isDone) ...[
            _SuccessView(
              onGoToLogin: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
            ),
          ] else ...[
            const ScreenHeader(
              title: 'Reset Password',
              subtitle: 'Set your new password below.',
            ),
            const SizedBox(height: 24),

            // ── Voice method — show confirmed badge ──
            if (widget.method == RecoveryMethod.voice) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Identity confirmed via voice biometrics',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── SMS code method ──
            if (widget.method == RecoveryMethod.email) ...[
              _OtpInput(
                controller: _codeCtrl,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Resend code',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── New password fields ──
            const Text(
              'SET NEW PASSWORD',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),

            AppTextField(
              label: 'NEW PASSWORD',
              hint: 'Min. 8 characters',
              controller: _newPasswordCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 20),

            AppTextField(
              label: 'CONFIRM PASSWORD',
              hint: 'Repeat your new password',
              controller: _confirmCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Reset Password',
              onPressed: _handleReset,
              isLoading: _isLoading,
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── OTP Input ─────────────────────────────────────────────────────
class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _OtpInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '6-DIGIT CODE',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
          ),
          decoration: const InputDecoration(
            hintText: '······',
            counterText: '',
            hintStyle: TextStyle(
              color: AppColors.textHint,
              fontSize: 24,
              letterSpacing: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Success View ──────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onGoToLogin;
  const _SuccessView({required this.onGoToLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withOpacity(0.1),
              border: Border.all(color: AppColors.success, width: 1.5),
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 42),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Password updated',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password has been reset successfully.\nYou can now sign in with your new credentials.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Back to Sign In',
          onPressed: onGoToLogin,
        ),
      ],
    );
  }
}