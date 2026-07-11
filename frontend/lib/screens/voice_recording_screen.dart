import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class VoiceRecordingScreen extends StatefulWidget {
  final String mode; // 'enroll' or 'verify'
  const VoiceRecordingScreen({super.key, required this.mode});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isDone = false;
  int _secondsLeft = 5;
  late AnimationController _waveCtrl;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _waveAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _secondsLeft = 5;
    });

    // Countdown timer
    for (int i = 5; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _secondsLeft = i - 1);
    }

    // TODO: Stop recording and send audio to Mahmoud's API
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isDone = true;
      });
    }
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

          // Instructions card
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
                const Text(
                  '"My voice is my password"',
                  style: TextStyle(
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

          // Recording button
          Center(
            child: _isDone
                ? _DoneState(isEnroll: isEnroll)
                : _RecordButton(
              isRecording: _isRecording,
              secondsLeft: _secondsLeft,
              waveAnim: _waveAnim,
              onTap: _isRecording ? null : _startRecording,
            ),
          ),
          const SizedBox(height: 32),

          // Tips
          if (!_isRecording && !_isDone) ...[
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
  const _DoneState({required this.isEnroll});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withOpacity(0.1),
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          isEnroll ? 'Voice enrolled!' : 'Voice verified!',
          style: const TextStyle(
            color: AppColors.success,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEnroll
              ? 'Your voiceprint has been saved'
              : 'Identity confirmed successfully',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isEnroll ? 'Continue' : 'Done'),
        ),
      ],
    );
  }
}