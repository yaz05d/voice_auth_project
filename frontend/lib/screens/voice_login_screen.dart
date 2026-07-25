import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
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
  bool _isDone = false;
  bool _isVerifying = false;
  bool _verifySuccess = false;
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
    _waveAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut));
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    final api = ApiService();
    final result = await api.getVoiceChallenge();
    if (mounted) {
      setState(() {
        _isLoadingChallenge = false;
        if (result['success']) {
          final data = result['data'];
          if (data is Map && data.containsKey('phrase')) {
            _challengePhrase = '"${data['phrase']}"';
          } else if (data is String) {
            _challengePhrase = '"$data"';
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _recorder.dispose();
    super.dispose();
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
    _audioPath = '${dir.path}/voice_verify.wav';

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
      setState(() {
        _isRecording = false;
        _isDone = true;
      });
      await _verifyVoice();
    }
  }

  Future<void> _verifyVoice() async {
    if (_audioPath == null) return;
    setState(() => _isVerifying = true);

    final api = ApiService();
    final result = await api.verifyVoice(
      audioPath: _audioPath!,
      passphrase: _challengePhrase.replaceAll('"', ''),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => {
        'success': false,
        'message': 'Verification timed out — please try again'
      },
    );

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _verifySuccess = result['success'];
      });

      if (result['success']) {
        // Navigate to home screen
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _resetRecording() {
    setState(() {
      _isRecording = false;
      _isDone = false;
      _isVerifying = false;
      _verifySuccess = false;
      _audioPath = null;
      _secondsLeft = 5;
    });
    _loadChallenge();
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

          // Security info card
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
                    'Your voice will be compared against your enrolled voiceprint',
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
                  'Speak clearly in a quiet environment',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Recording button or states
          Center(
            child: _isVerifying
                ? const Column(
              children: [
                CircularProgressIndicator(color: AppColors.accent),
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
                : _isDone && !_verifySuccess
                ? _FailedState(onRetry: _resetRecording)
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
                        color: AppColors.accent
                            .withOpacity(0.3 * waveAnim.value),
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

// ── Failed State ───────────────────────────────────────────────────
class _FailedState extends StatelessWidget {
  final VoidCallback onRetry;
  const _FailedState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withOpacity(0.1),
            border: Border.all(color: AppColors.error, width: 2),
          ),
          child: const Icon(Icons.close_rounded,
              color: AppColors.error, size: 48),
        ),
        const SizedBox(height: 20),
        const Text(
          'Voice not recognized',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your voice did not match.\nPlease try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}