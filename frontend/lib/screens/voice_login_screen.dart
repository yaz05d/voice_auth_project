import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class VoiceLoginScreen extends StatefulWidget {
  const VoiceLoginScreen({super.key});

  @override
  State<VoiceLoginScreen> createState() => _VoiceLoginScreenState();
}

class _VoiceLoginScreenState extends State<VoiceLoginScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isVerifying = false;
  bool _isLoadingChallenge = true;
  int _secondsLeft = 5;
  String? _audioPath;
  String _challengePhrase = '"My voice is my password"';

  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;
  final AudioRecorder _recorder = AudioRecorder();

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _waveAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut));
    _loadChallenge();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoadingChallenge = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final response = await dio.get('/voice/challenge');

      print('=== CHALLENGE SUCCESS ===');
      print(response.data);

      if (mounted) {
        setState(() {
          _isLoadingChallenge = false;
          final data = response.data;
          if (data is Map && data.containsKey('phrase')) {
            _challengePhrase = '"${data['phrase']}"';
          } else if (data is String) {
            _challengePhrase = '"$data"';
          }
        });
      }
    } catch (e) {
      print('=== CHALLENGE FAILED ===');
      print(e);
      if (mounted) setState(() => _isLoadingChallenge = false);
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _audioPath = '${dir.path}/voice_login.wav';

    if (mounted) {
      setState(() {
        _isRecording = true;
        _secondsLeft = 5;
      });
    }

    await Future.delayed(const Duration(milliseconds: 100));

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _audioPath!,
    );

    for (int i = 4; i >= 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _secondsLeft = i);
    }

    await _recorder.stop();

    if (mounted) {
      setState(() => _isRecording = false);
      await _verifyVoice();
    }
  }

  Future<void> _verifyVoice() async {
    if (_audioPath == null) return;
    setState(() => _isVerifying = true);

    final api = ApiService();
    final result = await api.voiceLogin(
      audioPath: _audioPath!,
      passphrase: _challengePhrase.replaceAll('"', ''),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => {
        'success': false,
        'message': 'Verification timed out — please try again'
      },
    );

    print('=== VOICE LOGIN RESULT ===');
    print(result);

    if (mounted) {
      setState(() => _isVerifying = false);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice verified! Welcome back.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      } else {
        String errorMessage = result['message'] ?? 'Voice not recognized';

// Show friendly message for phrase mismatch
        if (errorMessage.toLowerCase().contains('phrase')) {
          errorMessage = 'We didn\'t catch that — please read the phrase clearly and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isRecording = false;
          _audioPath = null;
          _secondsLeft = 5;
        });
        await _loadChallenge();
      }
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
            title: 'Voice Login',
            subtitle: 'Speak the phrase below to verify your identity.',
          ),
          const SizedBox(height: 32),

          // Security info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded,
                    color: AppColors.accent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your voice will be matched against your enrolled voiceprint',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Challenge phrase card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAY THIS PHRASE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                _isLoadingChallenge
                    ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent),
                )
                    : Text(
                  _challengePhrase,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Read this phrase aloud clearly when recording',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Recording button or verifying
          Center(
            child: _isVerifying
                ? const Column(
              children: [
                CircularProgressIndicator(
                    color: AppColors.accent),
                SizedBox(height: 16),
                Text(
                  'Verifying your voice...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            )
                : _RecordButton(
              isRecording: _isRecording,
              secondsLeft: _secondsLeft,
              waveAnim: _waveAnim,
              onTap: _isRecording ? null : _startRecording,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Record Button ──────────────────────────────────────────────────
class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final int secondsLeft;
  final Animation<double> waveAnim;
  final VoidCallback? onTap;

  const _RecordButton({
    required this.isRecording,
    required this.secondsLeft,
    required this.waveAnim,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: waveAnim,
        builder: (_, __) => Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (isRecording) ...[
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent
                          .withOpacity(0.06 * waveAnim.value),
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent
                          .withOpacity(0.1 * waveAnim.value),
                    ),
                  ),
                ],
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording
                        ? AppColors.accent.withOpacity(0.15)
                        : AppColors.card,
                    border: Border.all(
                      color: isRecording
                          ? AppColors.accent
                          : AppColors.border,
                      width: 2,
                    ),
                    boxShadow: isRecording
                        ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(
                            0.3 * waveAnim.value),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ]
                        : [],
                  ),
                  child: isRecording
                      ? Center(
                    child: Text(
                      '$secondsLeft',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                      : const Icon(Icons.mic_none_rounded,
                      color: AppColors.textSecondary, size: 40),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              isRecording ? 'Recording...' : 'Tap to start',
              style: TextStyle(
                color: isRecording
                    ? AppColors.accent
                    : AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRecording)
              Text(
                '$secondsLeft seconds remaining',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}