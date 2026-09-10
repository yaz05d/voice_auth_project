import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'forgot_password_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String resetToken;
  const NewPasswordScreen({super.key, required this.resetToken});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isDone = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
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

    final api = ApiService();
    final result = await api.resetPasswordConfirm(
      resetToken: widget.resetToken,
      newPassword: _newPasswordCtrl.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success']) {
        setState(() => _isDone = true);
      } else {
        final message = result['message'] ?? '';

        // Token expired — send back to start of flow
        if (message.toLowerCase().contains('expired') ||
            message.toLowerCase().contains('invalid')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Reset link expired. Please start the process again.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 4),
            ),
          );
          // Navigate back to forgot password
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen()),
                (route) => route.isFirst,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.isNotEmpty
                  ? message
                  : 'Password reset failed. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          if (_isDone) ...[
            // Success state
            const SizedBox(height: 48),
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(0.1),
                  border:
                  Border.all(color: AppColors.success, width: 1.5),
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 42),
              ),
            ),
            const SizedBox(height: 28),
            const Center(
              child: Text(
                'Password updated!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Your password has been reset successfully.\nYou can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              label: 'Back to Sign In',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
            ),
          ] else ...[
            const ScreenHeader(
              title: 'Set new password',
              subtitle: 'Your identity has been confirmed. Create a new password.',
            ),
            const SizedBox(height: 16),

            // Token expiry warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accent.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: AppColors.accent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'This link expires in 10 minutes',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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