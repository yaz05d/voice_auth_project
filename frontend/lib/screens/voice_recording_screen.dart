import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/api_service.dart';

class VoiceRecordingScreen extends StatefulWidget {
  final String mode;
  const VoiceRecordingScreen({super.key, required this.mode});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isDone = false;
  bool _isUploading = false;
  bool _uploadSuccess = false;
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
          } else {
            _challengePhrase = '"My voice is my password"';
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
    _audioPath = '${dir.path}/voice_sample.wav';

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
      await _uploadVoice();
    }
  }

  Future<void> _uploadVoice() async {
    if (_audioPath == null) return;
    setState(() => _isUploading = true);

    final api = ApiService();
    final result = await api.uploadVoiceProfile(
      audioPath: _audioPath!,
      passphrase: _challengePhrase.replaceAll('"', ''),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => {
        'success': false,
        'message': 'Upload timed out — please try again'
      },
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadSuccess = result['success'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success']
                ? 'Voice enrolled successfully!'
                : result['message'],
          ),
          backgroundColor:
          result['success'] ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _resetRecording() {
    setState(() {
      _isRecording = false;
      _isDone = false;
      _isUploading = false;
      _uploadSuccess = false;
      _audioPath = null;
      _secondsLeft = 5;
    });
    _loadChallenge();
  }

  @override
  Widget build(BuildContext context) {
    final isEnroll = widget.mode == 'enroll';

    return AuthScreen(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ScreenHeader(
            title: isEnroll ? 'Voice Enrollment' : 'Voice Verification',
            subtitle: isEnroll
                ? 'Record your voice to create your biometric voiceprint.'
                : 'Speak to verify your identity.',
          ),
          const SizedBox(height: 40),

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
                    fontSize: 20,
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
            child: _isUploading
                ? const Column(
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 16),
                Text(
                  'Saving your voiceprint...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            )
                : _isDone
                ? _DoneState(
              isEnroll: isEnroll,
              uploadSuccess: _uploadSuccess,
              onRetry: _resetRecording,
            )
                : _RecordButton(
              isRecording: _isRecording,
              secondsLeft: _secondsLeft,
              waveAnim: _waveAnim,
              onTap: _isRecording ? null : _startRecording,
            ),
          ),
          const SizedBox(height: 32),

          if (!_isRecording && !_isDone && !_isUploading) ...[
            const Text(
              'TIPS FOR BEST RESULTS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            _tip(Icons.volume_up_outlined, 'Speak at normal volume'),
            _tip(Icons.noise_aware_outlined, 'Find a quiet place'),
            _tip(Icons.phone_android_outlined,
                'Hold phone 15-20cm from mouth'),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint, size: 18),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
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
              isRecording ? 'Recording...' : 'Tap to start recording',
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

// ── Done State ─────────────────────────────────────────────────────
class _DoneState extends StatelessWidget {
  final bool isEnroll;
  final bool uploadSuccess;
  final VoidCallback onRetry;

  const _DoneState({
    required this.isEnroll,
    required this.uploadSuccess,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: uploadSuccess
                ? AppColors.success.withOpacity(0.1)
                : AppColors.error.withOpacity(0.1),
            border: Border.all(
              color: uploadSuccess ? AppColors.success : AppColors.error,
              width: 2,
            ),
          ),
          child: Icon(
            uploadSuccess ? Icons.check_rounded : Icons.close_rounded,
            color: uploadSuccess ? AppColors.success : AppColors.error,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          uploadSuccess
              ? isEnroll ? 'Voice enrolled!' : 'Voice verified!'
              : 'Upload failed',
          style: TextStyle(
            color: uploadSuccess ? AppColors.success : AppColors.error,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          uploadSuccess
              ? isEnroll
              ? 'Your voiceprint has been saved'
              : 'Identity confirmed successfully'
              : 'Please try again',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 28),
        if (uploadSuccess)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnroll ? 'Continue' : 'Done'),
          )
        else
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
      ],
    );
  }
}