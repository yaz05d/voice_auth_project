import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _agreeToTerms = false;

  // Step tracking (1 = personal info, 2 = security)
  int _step = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms to continue'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final api = ApiService();
    final result = await api.register(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Go back to login
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            const ScreenHeader(
              title: 'Create account',
              subtitle:
              'Register to secure your banking access with your voice.',
            ),
            const SizedBox(height: 24),

            // Step indicator
            _StepIndicator(current: _step),
            const SizedBox(height: 28),

            if (_step == 1) ...[
              // ── Step 1: Personal Info ──
              AppTextField(
                label: 'FULL NAME',
                hint: 'As on your bank account',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().split(' ').length < 2)
                    return 'Enter your full name';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'EMAIL ADDRESS',
                hint: 'you@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'PHONE NUMBER',
                hint: '+20 1XX XXX XXXX',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone is required';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: () {
                  // Validate step 1 fields only
                  if (_nameCtrl.text.trim().isEmpty ||
                      !_emailCtrl.text.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all fields correctly'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  setState(() => _step = 2);
                },
                child: const Text('Continue'),
              ),
            ] else ...[
              // ── Step 2: Security ──
              AppTextField(
                label: 'PASSWORD',
                hint: 'Min. 8 characters',
                controller: _passwordCtrl,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'At least 8 characters required';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Password strength indicator
              _PasswordStrength(password: _passwordCtrl.text),
              const SizedBox(height: 20),

              AppTextField(
                label: 'CONFIRM PASSWORD',
                hint: 'Repeat your password',
                controller: _confirmCtrl,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) {
                  if (v != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Voice enrollment notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: AppColors.accent.withOpacity(0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mic_rounded,
                        color: AppColors.accent, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'After registration, you\'ll record your voice to create your biometric voiceprint. This is used for secure account recovery.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Terms checkbox
              GestureDetector(
                onTap: () =>
                    setState(() => _agreeToTerms = !_agreeToTerms),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _agreeToTerms
                            ? AppColors.accent
                            : AppColors.inputBg,
                        border: Border.all(
                          color: _agreeToTerms
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: _agreeToTerms
                          ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 15)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'I agree to the ',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' and ',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                label: 'Create Account',
                onPressed: _handleRegister,
                isLoading: _isLoading,
              ),
            ],

            const SizedBox(height: 24),

            // Login link
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Step Indicator ────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(1, 'Personal Info'),
        Expanded(
          child: Container(
            height: 1,
            color: current >= 2 ? AppColors.accent : AppColors.border,
          ),
        ),
        _dot(2, 'Security'),
      ],
    );
  }

  Widget _dot(int step, String label) {
    final active = current >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accent : AppColors.inputBg,
            border: Border.all(
              color: active ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Center(
            child: active && current > step
                ? const Icon(Icons.check_rounded,
                color: AppColors.primary, size: 16)
                : Text(
              '$step',
              style: TextStyle(
                color:
                active ? AppColors.primary : AppColors.textHint,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.accent : AppColors.textHint,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Password Strength ─────────────────────────────────────────────
class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  int get _strength {
    if (password.length < 4) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(password)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      Colors.transparent,
      AppColors.error,
      Colors.orange,
      Colors.yellow,
      AppColors.success,
    ];
    final s = _strength;
    return Row(
      children: [
        ...List.generate(
          4,
              (i) => Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < s ? colors[s] : AppColors.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          s > 0 ? labels[s] : '',
          style: TextStyle(
            color: s > 0 ? colors[s] : Colors.transparent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}