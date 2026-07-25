import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'voice_recovery_screen.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (_phoneCtrl.text.isEmpty || _phoneCtrl.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO: call send SMS code API
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _codeSent = true;
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
          const ScreenHeader(
            title: 'Recover access',
            subtitle:
            'Verify your identity to reset your password.',
          ),
          const SizedBox(height: 32),

          const Text(
            'RECOVERY METHOD',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Voice Recovery
          _RecoveryOption(
            icon: Icons.mic_rounded,
            title: 'Voice Biometric Recovery',
            subtitle: 'Verify it\'s you using your enrolled voiceprint',
            isRecommended: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VoiceRecoveryScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Phone Recovery
          _RecoveryOption(
            icon: Icons.phone_android_rounded,
            title: 'Phone Number Verification',
            subtitle: 'Receive a reset code via SMS',
            isRecommended: false,
            onTap: () => setState(() {}),
          ),
          const SizedBox(height: 28),

          if (!_codeSent) ...[
            AppTextField(
              label: 'PHONE NUMBER',
              hint: '+962 7X XXX XXXX',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send SMS Code',
              onPressed: _handleSendCode,
              isLoading: _isLoading,
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Code sent!',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Check your phone ${_phoneCtrl.text} for the SMS code.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen(
                              method: RecoveryMethod.email),
                        ),
                      );
                    },
                    child: const Text('Enter SMS Code'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _codeSent = false),
                child: const Text('Resend code',
                    style:
                    TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Recovery Option Card ───────────────────────────────────────────
class _RecoveryOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isRecommended;
  final VoidCallback onTap;

  const _RecoveryOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRecommended
              ? AppColors.accent.withOpacity(0.06)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecommended ? AppColors.accent : AppColors.border,
            width: isRecommended ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRecommended
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isRecommended
                    ? AppColors.accent
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isRecommended
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color:
              isRecommended ? AppColors.accent : AppColors.textHint,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

enum RecoveryMethod { voice, email }