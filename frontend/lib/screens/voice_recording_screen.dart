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
  bool _isUploading = false;
  bool _isDone = false;
  bool _uploadSuccess = false;
  int _secondsLeft = 5;
  int _currentRecording = 1;
  final List<String> _audioPaths = [];
  double _audioLevel = 0.0;
  bool _isSilent = false;
  int? _failedRecordingIndex;
  bool _isRedoMode = false;

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
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Clean up recorder
    try {
      final isRecording = await _recorder.isRecording();
      if (isRecording) {
        await _recorder.stop();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      print('Recorder cleanup error: $e');
    }

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
    final audioPath =
        '${dir.path}/voice_sample_${_currentRecording}_${DateTime.now().millisecondsSinceEpoch}.wav';

    if (mounted) {
      setState(() {
        _isRecording = true;
        _secondsLeft = 5;
        _audioLevel = 0.0;
        _isSilent = false;
      });
    }

    // Start recording immediately
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: audioPath,
    );

    // Monitor audio level in real time
    bool hadSound = false;

    _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 100),
    ).listen((amp) {
      if (mounted) {
        final db = amp.current;
        final level = ((db + 60) / 60).clamp(0.0, 1.0);
        setState(() {
          _audioLevel = level;
          _isSilent = level < 0.05;
        });
        if (level >= 0.05) hadSound = true;
      }
    });

    // Run full countdown from 5 to 0
    for (int i = 4; i >= 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _secondsLeft = i);
    }

    await _recorder.stop();

    // After full 5 seconds — check if any sound was detected
    if (!hadSound && mounted) {
      try {
        final f = File(audioPath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        print('Silent file cleanup: $e');
      }

      setState(() {
        _isRecording = false;
        _audioLevel = 0.0;
        _isSilent = false;
        _secondsLeft = 5;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.volume_off_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No sound detected. Please speak louder and try again.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Sound detected — save recording
    if (mounted) {
      setState(() {
        _audioLevel = 0.0;
        _isSilent = false;
        _isRecording = false;
      });
    }

    // Insert at correct position if in redo mode
    if (_isRedoMode) {
      _audioPaths.insert(_currentRecording - 1, audioPath);
    } else {
      _audioPaths.add(audioPath);
    }

    if (mounted) {
      if (_isRedoMode) {
        // Redo mode — go straight to upload after one recording
        setState(() => _isRedoMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording replaced! Uploading...'),
            backgroundColor: AppColors.success,
          ),
        );
        await _uploadVoice();
      } else if (_currentRecording < 3) {
        setState(() => _currentRecording++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Recording ${_currentRecording - 1} saved! Now record #$_currentRecording'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await _uploadVoice();
      }
    }
  }

  Future<void> _uploadVoice() async {
    setState(() => _isUploading = true);

    final api = ApiService();
    final result = await api.uploadVoiceProfile3(
      audioPath1: _audioPaths[0],
      audioPath2: _audioPaths[1],
      audioPath3: _audioPaths[2],
    ).timeout(
      const Duration(seconds: 120),
      onTimeout: () => {
        'success': false,
        'message': 'Upload timed out — please try again'
      },
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
        _isDone = true;
        _uploadSuccess = result['success'];
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice enrolled successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        final message = result['message'].toString();

        // Detect which specific recording failed
        // Matches Mahmoud's exact format:
        // "Recording 2 sounds inconsistent with your other recordings..."
        int? failedIndex;
        final match = RegExp(r'Recording (\d+) sounds inconsistent')
            .firstMatch(message);
        if (match != null) {
          failedIndex = int.tryParse(match.group(1) ?? '');
        }

        setState(() => _failedRecordingIndex = failedIndex);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isNotEmpty
                  ? message
                  : 'Server error — please try again',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _resetRecording() async {
    try {
      final isRecording = await _recorder.isRecording();
      if (isRecording) {
        await _recorder.stop();
      }
    } catch (e) {
      print('Recorder stop error: $e');
    }

    for (final path in _audioPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('File delete error: $e');
      }
    }

    setState(() {
      _isRecording = false;
      _isDone = false;
      _isUploading = false;
      _uploadSuccess = false;
      _currentRecording = 1;
      _secondsLeft = 5;
      _audioLevel = 0.0;
      _isSilent = false;
      _failedRecordingIndex = null;
      _isRedoMode = false;
      _audioPaths.clear();
    });
  }

  Future<void> _redoRecording(int recordingNumber) async {
    // Stop recorder completely
    try {
      final isRec = await _recorder.isRecording();
      if (isRec) await _recorder.stop();
    } catch (e) {
      print('Recorder stop error: $e');
    }

    // Delete the failed audio file
    if (_audioPaths.length >= recordingNumber) {
      final failedPath = _audioPaths[recordingNumber - 1];
      try {
        final f = File(failedPath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        print('Delete failed recording: $e');
      }
      _audioPaths.removeAt(recordingNumber - 1);
    }

    // Small delay to let recorder reset properly
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isDone = false;
      _isUploading = false;
      _uploadSuccess = false;
      _failedRecordingIndex = null;
      _currentRecording = recordingNumber;
      _secondsLeft = 5;
      _audioLevel = 0.0;
      _isSilent = false;
      _isRedoMode = true;
    });
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
                ? 'Record your voice 3 times to create a strong voiceprint.'
                : 'Speak to verify your identity.',
          ),
          const SizedBox(height: 24),

          if (isEnroll && !_isDone) ...[
            _RecordingProgress(
              current: _currentRecording,
              completed: _audioPaths.length,
              isRedoMode: _isRedoMode,
            ),
            const SizedBox(height: 24),
          ],

          // Phrase card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'SAY THIS PHRASE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '"My voice is my password"',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Read this phrase aloud clearly when recording',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Main state
          Center(
            child: _isUploading
                ? const Column(
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 16),
                Text(
                  'Creating your voiceprint...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'This may take up to 60 seconds',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            )
                : _isDone
                ? _DoneState(
              isEnroll: isEnroll,
              uploadSuccess: _uploadSuccess,
              failedRecordingIndex: _failedRecordingIndex,
              onRetry: () async => await _resetRecording(),
              onRedoRecording: (index) async =>
              await _redoRecording(index),
            )
                : _RecordButton(
              isRecording: _isRecording,
              secondsLeft: _secondsLeft,
              recordingNumber: _currentRecording,
              waveAnim: _waveAnim,
              audioLevel: _audioLevel,
              isSilent: _isSilent,
              isRedoMode: _isRedoMode,
              onTap: _isRecording ? null : _startRecording,
            ),
          ),
          const SizedBox(height: 32),

          // Tips
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
            _tip(Icons.refresh_rounded, 'Each recording improves accuracy'),
            _tip(Icons.timer_outlined, 'Speak for at least 2 seconds'),
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

// ── Recording Progress ─────────────────────────────────────────────
class _RecordingProgress extends StatelessWidget {
  final int current;
  final int completed;
  final bool isRedoMode;

  const _RecordingProgress({
    required this.current,
    required this.completed,
    required this.isRedoMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isRedoMode
                  ? 'Re-recording #$current'
                  : 'Recording $current of 3',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              isRedoMode ? 'Fixing recording $current' : '$completed/3 complete',
              style: TextStyle(
                color: isRedoMode ? AppColors.error : AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) {
            final isDone = i < completed;
            final isCurrent = i == (current - 1);
            final isRedo = isRedoMode && isCurrent;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isRedo
                      ? AppColors.error
                      : isDone
                      ? AppColors.success
                      : isCurrent
                      ? AppColors.accent
                      : AppColors.border,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Record Button ──────────────────────────────────────────────────
class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final int secondsLeft;
  final int recordingNumber;
  final Animation<double> waveAnim;
  final double audioLevel;
  final bool isSilent;
  final bool isRedoMode;
  final VoidCallback? onTap;

  const _RecordButton({
    required this.isRecording,
    required this.secondsLeft,
    required this.recordingNumber,
    required this.waveAnim,
    required this.audioLevel,
    required this.isSilent,
    required this.isRedoMode,
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
                          : isRedoMode
                          ? AppColors.error
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
                      : Icon(
                    isRedoMode
                        ? Icons.mic_none_rounded
                        : Icons.mic_none_rounded,
                    color: isRedoMode
                        ? AppColors.error
                        : AppColors.textSecondary,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Audio level bars and status
            if (isRecording) ...[
              _AudioLevelBars(audioLevel: audioLevel),
              const SizedBox(height: 12),
              if (isSilent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_off_rounded,
                          color: AppColors.error, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Can\'t hear you — speak louder!',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'Listening...',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ] else ...[
              Text(
                isRedoMode
                    ? 'Tap to re-record #$recordingNumber'
                    : 'Tap to record #$recordingNumber',
                style: TextStyle(
                  color: isRedoMode
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRedoMode)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Only this recording will be replaced',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Audio Level Bars ───────────────────────────────────────────────
class _AudioLevelBars extends StatelessWidget {
  final double audioLevel;

  const _AudioLevelBars({required this.audioLevel});

  @override
  Widget build(BuildContext context) {
    final barHeights = [0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: barHeights.map((multiplier) {
        final height =
        (8 + (40 * audioLevel * multiplier)).clamp(4.0, 48.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 5,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: audioLevel < 0.05
                ? AppColors.border
                : AppColors.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }).toList(),
    );
  }
}

// ── Done State ─────────────────────────────────────────────────────
class _DoneState extends StatelessWidget {
  final bool isEnroll;
  final bool uploadSuccess;
  final int? failedRecordingIndex;
  final Future<void> Function() onRetry;
  final Future<void> Function(int)? onRedoRecording;

  const _DoneState({
    required this.isEnroll,
    required this.uploadSuccess,
    required this.onRetry,
    this.failedRecordingIndex,
    this.onRedoRecording,
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
              ? isEnroll
              ? 'Voice enrolled!'
              : 'Voice verified!'
              : 'Enrollment failed',
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
              : failedRecordingIndex != null
              ? 'Recording $failedRecordingIndex was inconsistent.\nPlease redo only that recording.'
              : 'One of your recordings was inconsistent.\nTap Try Again to re-record all 3.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (uploadSuccess)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEnroll ? 'Continue' : 'Done'),
          )
        else if (failedRecordingIndex != null && onRedoRecording != null)
          Column(
            children: [
              ElevatedButton(
                onPressed: () async =>
                await onRedoRecording!(failedRecordingIndex!),
                child: Text('Redo Recording $failedRecordingIndex'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async => await onRetry(),
                child: const Text(
                  'Start over — redo all 3',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          )
        else
          ElevatedButton(
            onPressed: () async => await onRetry(),
            child: const Text('Try Again'),
          ),
      ],
    );
  }
}