import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../components/app_color.dart';
import '../provider/voicechekin_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// voice_checkin_screen.dart
//
// 30-second voice check-in screen.
//
// UI phases (driven by VoiceCheckinState.phase):
//   idle       → prompt card + speaking tips + "Start recording" button
//   countdown  → animated 3-2-1 countdown overlay
//   recording  → live bar waveform + progress ring + elapsed timer + stop btn
//   processing → pulsing mic icon + "Analysing voice…"
//   complete   → result card with score breakdown + save / retry actions
//   error      → error state with retry button
// ─────────────────────────────────────────────────────────────────────────────

class VoiceCheckinScreen extends ConsumerStatefulWidget {
  const VoiceCheckinScreen({super.key});

  @override
  ConsumerState<VoiceCheckinScreen> createState() =>
      _VoiceCheckinScreenState();
}

class _VoiceCheckinScreenState extends ConsumerState<VoiceCheckinScreen>
    with TickerProviderStateMixin {
  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _countdownController;
  late final AnimationController _resultController;
  late final AnimationController _waveController;

  // Live bar heights for animated waveform (20 bars)
  static const _barCount = 20;
  final _barHeights = List<double>.filled(_barCount, 0.1);
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..addListener(_updateBars);
  }

  void _updateBars() {
    final db = ref.read(voiceCheckinControllerProvider).currentDb;
    // Map dB (-60 to 0) → 0.05–1.0 bar height
    final normalised = ((db + 60) / 60).clamp(0.0, 1.0);
    setState(() {
      for (int i = 0; i < _barCount; i++) {
        // Each bar deviates slightly from the normalised amplitude
        final noise = (_rng.nextDouble() - 0.5) * 0.3;
        _barHeights[i] =
            (normalised + noise).clamp(0.05, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    _resultController.dispose();
    _waveController
      ..removeListener(_updateBars)
      ..dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _start() {
    HapticFeedback.mediumImpact();
    ref.read(voiceCheckinControllerProvider.notifier).startCountdown();
  }

  Future<void> _stopEarly() async {
    HapticFeedback.selectionClick();
    await ref.read(voiceCheckinControllerProvider.notifier).stopEarly();
  }

  Future<void> _save() async {
    final saved =
    await ref.read(voiceCheckinControllerProvider.notifier).saveResult();
    if (saved && mounted) {
      HapticFeedback.mediumImpact();
      context.pop();
    }
  }

  void _retry() {
    ref.read(voiceCheckinControllerProvider.notifier).reset();
    _resultController.reset();
    _countdownController.reset();
  }

  // ── Phase transition side-effects ──────────────────────────────────────────

  void _onPhaseChange(VoicePhase? prev, VoicePhase next) {
    switch (next) {
      case VoicePhase.countdown:
        _countdownController.forward(from: 0);
        break;
      case VoicePhase.recording:
        _waveController.repeat();
        break;
      case VoicePhase.processing:
        _waveController.stop();
        break;
      case VoicePhase.complete:
        _resultController.forward(from: 0);
        HapticFeedback.mediumImpact();
        break;
      case VoicePhase.error:
        HapticFeedback.vibrate();
        break;
      default:
        break;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceCheckinControllerProvider);

    ref.listen(voiceCheckinControllerProvider, (prev, next) {
      if (prev?.phase != next.phase) {
        _onPhaseChange(prev?.phase, next.phase);
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.danger,
          ),
        );
        ref.read(voiceCheckinControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: () {
                ref
                    .read(voiceCheckinControllerProvider.notifier)
                    .cancel();
                context.pop();
              },
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(VoiceCheckinState state) {
    return switch (state.phase) {
      VoicePhase.idle       => _IdleView(onStart: _start),
      VoicePhase.countdown  => _CountdownView(
        value: state.countdownValue,
        controller: _countdownController,
      ),
      VoicePhase.recording  => _RecordingView(
        state: state,
        barHeights: _barHeights,
        onStop: _stopEarly,
      ),
      VoicePhase.processing => _ProcessingView(
        pulseController: _pulseController,
      ),
      VoicePhase.complete   => _ResultView(
        state: state,
        entryController: _resultController,
        onSave: _save,
        onRetry: _retry,
      ),
      VoicePhase.error      => _ErrorView(
        message: state.errorMessage ?? 'Something went wrong.',
        onRetry: _retry,
      ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
            color: AppColors.textDark,
          ),
          Expanded(
            child: Text(
              'Voice Check-In',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Balance spacer
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: idle
// ─────────────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final VoidCallback onStart;
  const _IdleView({required this.onStart});

  static const _prompts = [
    '"How has your day been going so far?"',
    '"What\'s been on your mind lately?"',
    '"Describe something that\'s bothering you."',
    '"Talk about how you\'re feeling right now."',
    '"What are you looking forward to this week?"',
  ];

  @override
  Widget build(BuildContext context) {
    final prompt = _prompts[DateTime.now().day % _prompts.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          // Mic illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Voice stress\ncheck-in',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Speak naturally for 30 seconds. SerenityAI analyses '
                'your vocal patterns to measure stress — your audio '
                'is never stored.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // Daily prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Today's prompt",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  prompt,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tips
          const _TipsRow(
            tips: const [
              _Tip(Icons.volume_up_outlined, 'Normal\nvolume'),
              _Tip(Icons.room_outlined, 'Quiet\nspace'),
              _Tip(Icons.lock_outline_rounded, 'Audio\nnot saved'),
            ],
          ),

          const Spacer(),

          // Start button
          _PrimaryButton(
            label: 'Start recording',
            icon: Icons.mic_rounded,
            onTap: onStart,
          ),
          const SizedBox(height: 10),

          Text(
            'Counts as 25% of your daily stress score',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: countdown (3-2-1)
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownView extends StatelessWidget {
  final int value;
  final AnimationController controller;

  const _CountdownView({required this.value, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: const TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Get ready to speak…',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: recording
// ─────────────────────────────────────────────────────────────────────────────

class _RecordingView extends StatelessWidget {
  final VoiceCheckinState state;
  final List<double> barHeights;
  final VoidCallback onStop;

  const _RecordingView({
    required this.state,
    required this.barHeights,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = state.totalSeconds - state.elapsedSeconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          // Recording pill badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.danger.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(),
                const SizedBox(width: 8),
                const Text(
                  'RECORDING',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Progress ring + timer
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: state.progress,
                color: AppColors.danger,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$remaining',
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        height: 1,
                      ),
                    ),
                    Text(
                      'sec left',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Live bar waveform
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                _RecordingView._barCount,
                    (i) => _AnimatedBar(
                  targetHeight: barHeights[i],
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Speak naturally about how you feel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
            ),
          ),

          const Spacer(),

          // Stop early button
          OutlinedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop early'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _barCount = 20;
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: processing
// ─────────────────────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  final AnimationController pulseController;
  const _ProcessingView({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.1).animate(
              CurvedAnimation(
                  parent: pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.secondary,
                size: 46,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Analysing voice patterns…',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Measuring amplitude variance,\nspeaking rate and pitch stability',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: complete — result card
// ─────────────────────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final VoiceCheckinState state;
  final AnimationController entryController;
  final VoidCallback onSave;
  final VoidCallback onRetry;

  const _ResultView({
    required this.state,
    required this.entryController,
    required this.onSave,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final score = state.voiceScore ?? 0;
    final level = state.stressLevel ?? 'low';
    final color = AppColors.stressColor(score);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.07),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: entryController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: entryController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              // ── Score card ─────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Mic icon with score ring
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CustomPaint(
                          painter: _ProgressRingPainter(
                            progress: score / 100,
                            color: color,
                            strokeWidth: 9,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic_rounded,
                                    color: color, size: 28),
                                const SizedBox(height: 2),
                                Text(
                                  score.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Level badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${level.toUpperCase()} VOICE STRESS',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sub-score breakdown
                      _SubScoreRow(dbLog: state.dbLog),
                      const SizedBox(height: 20),

                      // Recommendation
                      _RecommendationCard(
                          level: level, color: color),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Actions ────────────────────────────────────────────────
              _PrimaryButton(
                label: state.isSaving ? 'Saving…' : 'Save & continue',
                icon: Icons.check_rounded,
                onTap: state.isSaving ? () {} : onSave,
              ),
              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: AppColors.textLight),
                label: Text(
                  'Record again',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-score breakdown row
// ─────────────────────────────────────────────────────────────────────────────

class _SubScoreRow extends StatelessWidget {
  final List<double> dbLog;

  const _SubScoreRow({required this.dbLog});

  @override
  Widget build(BuildContext context) {
    // Recompute sub-scores for display
    final amp = _clamp(
        _approxAmplitudeScore(dbLog));
    final rate = _clamp(
        _approxRateScore(dbLog));
    final pitch = _clamp(
        _approxPitchScore(dbLog));

    return Row(
      children: [
        _SubScoreTile(
          label: 'Amplitude',
          score: amp,
          icon: Icons.graphic_eq_rounded,
        ),
        const SizedBox(width: 8),
        _SubScoreTile(
          label: 'Speech rate',
          score: rate,
          icon: Icons.speed_rounded,
        ),
        const SizedBox(width: 8),
        _SubScoreTile(
          label: 'Pitch',
          score: pitch,
          icon: Icons.music_note_outlined,
        ),
      ],
    );
  }

  double _clamp(double v) => v.clamp(0.0, 100.0);

  // Lightweight re-implementations for display only
  double _approxAmplitudeScore(List<double> log) {
    if (log.length < 10) return 50;
    final linear = log.map((db) {
      if (db <= -160) return 0.0;
      return math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
    }).toList();
    final mean = linear.reduce((a, b) => a + b) / linear.length;
    final variance = linear
        .map((v) => math.pow(v - mean, 2).toDouble())
        .reduce((a, b) => a + b) /
        linear.length;
    return (variance / 0.08).clamp(0.0, 1.0) * 100;
  }

  double _approxRateScore(List<double> log) {
    if (log.isEmpty) return 50;
    final speech = log.where((db) => db > -40).length;
    return (1.0 - speech / log.length).clamp(0.0, 1.0) * 100;
  }

  double _approxPitchScore(List<double> log) {
    if (log.length < 20) return 50;
    final linear = log.map((db) {
      if (db <= -160) return 0.0;
      return math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
    }).toList();
    final mean = linear.reduce((a, b) => a + b) / linear.length;
    int crossings = 0;
    for (int i = 1; i < linear.length; i++) {
      if ((linear[i - 1] - mean) * (linear[i] - mean) < 0) crossings++;
    }
    return ((crossings / linear.length) * 2).clamp(0.0, 1.0) * 100;
  }
}

class _SubScoreTile extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;

  const _SubScoreTile({
    required this.label,
    required this.score,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stressColor(score);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation card
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final String level;
  final Color color;

  const _RecommendationCard(
      {required this.level, required this.color});

  String get _copy {
    switch (level) {
      case 'low':
        return 'Your voice sounds calm and steady. Great emotional balance!';
      case 'medium':
        return 'Some vocal tension detected. A few minutes of humming or '
            'deep breathing can help reset your voice.';
      case 'high':
        return 'Elevated vocal stress. Try slowing your speech and taking '
            'longer pauses — your nervous system will follow.';
      case 'critical':
        return 'High vocal arousal detected. Rest your voice and consider '
            'a guided relaxation session.';
      default:
        return 'Keep practising mindful speaking.';
    }
  }

  String get _emoji {
    switch (level) {
      case 'low': return '✅';
      case 'medium': return '💛';
      case 'high': return '🔶';
      case 'critical': return '🔴';
      default: return '💡';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _copy,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMedium,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: error
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_off_rounded,
                color: AppColors.danger, size: 38),
          ),
          const SizedBox(height: 24),
          Text('Recording failed',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textLight, height: 1.6),
          ),
          const SizedBox(height: 32),
          _PrimaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onTap: onRetry),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Animated single bar for the live waveform.
class _AnimatedBar extends StatelessWidget {
  final double targetHeight; // 0.0–1.0
  final Color color;

  const _AnimatedBar({required this.targetHeight, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      width: 8,
      height: 80 * targetHeight,
      decoration: BoxDecoration(
        color: color.withOpacity(0.7 + targetHeight * 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Pulsing red dot indicating active recording.
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Tips row for idle screen.
class _TipsRow extends StatelessWidget {
  final List<_Tip> tips;
  const _TipsRow({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: tips
          .map((t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(t.icon,
                  size: 20, color: AppColors.textMedium),
            ),
            const SizedBox(height: 6),
            Text(
              t.label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textLight),
            ),
          ],
        ),
      ))
          .toList(),
    );
  }
}

class _Tip {
  final IconData icon;
  final String label;
  const _Tip(this.icon, this.label);
}

/// Reusable gradient CTA button.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — circular progress ring
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withOpacity(0.12),
    );

    // Progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}