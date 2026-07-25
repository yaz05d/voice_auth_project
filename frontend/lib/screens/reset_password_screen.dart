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

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isDone = false;

  // Voice verification state
  bool _voiceVerified = false;
  bool _isRecording = false;
  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _waveAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      // TODO: start voice recording
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isRecording = false;
          _voiceVerified = true;
        });
      }
    }
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

  bool get _canProceedToPassword =>
      widget.method == RecoveryMethod.voice
          ? _voiceVerified
          : _codeCtrl.text.length == 6;

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
            ScreenHeader(
              title: widget.method == RecoveryMethod.voice
                  ? 'Voice verification'
                  : 'Enter reset code',
              subtitle: widget.method == RecoveryMethod.voice
                  ? 'Speak clearly to verify your identity, then set your new password.'
                  : 'Enter the 6-digit code sent to your email.',
            ),
            const SizedBox(height: 32),

            // ── Voice Method ──
            if (widget.method == RecoveryMethod.voice) ...[
              _VoiceVerificationCard(
                isRecording: _isRecording,
                isVerified: _voiceVerified,
                waveAnim: _waveAnim,
                onTap: _voiceVerified ? null : _toggleRecording,
              ),
              const SizedBox(height: 16),

              if (_voiceVerified)
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
                        'Voice verified — identity confirmed',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // ── Email Code Method ──
            if (widget.method == RecoveryMethod.email) ...[
              _OtpInput(controller: _codeCtrl,
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Resend code',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── New Password Fields (shown when verified) ──
            if (_canProceedToPassword) ...[
              const Divider(color: AppColors.border),
              const SizedBox(height: 24),

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
            ] else if (widget.method == RecoveryMethod.voice &&
                !_voiceVerified) ...[
              const Text(
                'Your new password fields will appear here after your voice is confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Voice Verification Card ───────────────────────────────────────
class _VoiceVerificationCard extends StatelessWidget {
  final bool isRecording;
  final bool isVerified;
  final Animation<double> waveAnim;
  final VoidCallback? onTap;

  const _VoiceVerificationCard({
    required this.isRecording,
    required this.isVerified,
    required this.waveAnim,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: waveAnim,
        builder: (_, __) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isVerified
                  ? AppColors.success
                  : isRecording
                  ? AppColors.accent
                  : AppColors.border,
              width: isRecording || isVerified ? 1.5 : 1,
            ),
            boxShadow: isRecording
                ? [
              BoxShadow(
                color: AppColors.accent
                    .withOpacity(0.15 * waveAnim.value),
                blurRadius: 24,
                spreadRadius: 4,
              )
            ]
                : [],
          ),
          child: Column(
            children: [
              // Mic button
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isRecording)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent
                            .withOpacity(0.1 * waveAnim.value),
                      ),
                    ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isVerified
                          ? AppColors.success.withOpacity(0.15)
                          : isRecording
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.inputBg,
                      border: Border.all(
                        color: isVerified
                            ? AppColors.success
                            : isRecording
                            ? AppColors.accent
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isVerified
                          ? Icons.check_rounded
                          : isRecording
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: isVerified
                          ? AppColors.success
                          : isRecording
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Wave bars (shown when recording)
              if (isRecording) ...[
                _WaveBars(anim: waveAnim),
                const SizedBox(height: 12),
              ],

              Text(
                isVerified
                    ? 'Voice Verified'
                    : isRecording
                    ? 'Listening... speak now'
                    : 'Tap to verify your voice',
                style: TextStyle(
                  color: isVerified
                      ? AppColors.success
                      : isRecording
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isVerified
                    ? 'Identity confirmed via voiceprint'
                    : isRecording
                    ? 'Say: "My voice is my password"'
                    : 'We\'ll match your enrolled voiceprint',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wave Bars ─────────────────────────────────────────────────────
class _WaveBars extends StatelessWidget {
  final Animation<double> anim;
  const _WaveBars({required this.anim});

  @override
  Widget build(BuildContext context) {
    final heights = [12.0, 24.0, 16.0, 32.0, 20.0, 32.0, 16.0, 24.0, 12.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: heights.map((h) {
        return Container(
          width: 4,
          height: h * anim.value,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
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