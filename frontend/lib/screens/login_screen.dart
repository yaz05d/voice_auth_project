import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../services/api_service.dart';
import 'voice_recording_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
// TEMPORARY: bypass API for UI testing
Navigator.of(context).pushAndRemoveUntil(
MaterialPageRoute(builder: (_) => const HomeScreen()),
(route) => false,
);
return;
// rest of code below...
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final api = ApiService();
    final result = await api.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),

            // Logo
            const Center(child: VoiceLogo(size: 64)),
            const SizedBox(height: 28),

            // Header
            const Center(
              child: Column(
                children: [
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Sign in to your secure account',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Security badge
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your voice is your password. AI-protected login.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Email
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

            // Password
            AppTextField(
              label: 'PASSWORD',
              hint: 'Enter your password',
              controller: _passwordCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Password too short';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen()),
                  );
                },
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Login button
            PrimaryButton(
              label: 'Sign In',
              onPressed: _handleLogin,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),

            const OrDivider(),
            const SizedBox(height: 24),

            // Voice login button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VoiceRecordingScreen(mode: 'enroll'),
                  ),
                );              },
              icon: const Icon(Icons.mic_none_rounded,
                  color: AppColors.accent, size: 20),
              label: const Text(
                'Sign in with Voice',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: AppColors.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 36),

            // Register link
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text(
                      'Create account',
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