import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_color.dart';
import '../provider/mindfulness_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// breathing_screen.dart
//
// Animated breathing exercise screen.
//
// Layout:
//   • Technique selector (horizontal scroll cards)
//   • Animated breathing circle (scale + color pulse)
//   • Phase label + countdown
//   • Cycle counter
//   • Controls: Start / Pause / Stop
//   • Completion overlay
// ─────────────────────────────────────────────────────────────────────────────

class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key});

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _pulseController;
  late Animation<double> _circleScale;
  late Animation<double> _pulseOpacity;

  BreathPhase _lastPhase = BreathPhase.idle;

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _circleScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Select default technique
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final techniques = ref.read(breathingTechniqueProvider);
      if (techniques.isNotEmpty) {
        ref
            .read(activeBreathingProvider.notifier)
            .selectTechnique(techniques.first);
      }
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _syncAnimation(ActiveBreathingState state) {
    if (state.phase == _lastPhase) return;
    _lastPhase = state.phase;

    _circleController.stop();
    _pulseController.stop();

    final t = state.technique;
    if (t == null) return;

    switch (state.phase) {
      case BreathPhase.inhale:
        _circleController.duration =
            Duration(seconds: t.inhaleSeconds);
        _circleController.forward(from: 0);
        break;
      case BreathPhase.exhale:
        _circleController.duration =
            Duration(seconds: t.exhaleSeconds);
        _circleController.reverse(from: 1);
        break;
      case BreathPhase.holdIn:
      case BreathPhase.holdOut:
        _pulseController.repeat(reverse: true);
        break;
      case BreathPhase.complete:
        _circleController.value = 0.7;
        HapticFeedback.mediumImpact();
        break;
      default:
        _circleController.value = 0.7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeBreathingProvider);
    _syncAnimation(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            ref.read(activeBreathingProvider.notifier).stop();
            context.pop();
          },
        ),
        title: const Text('Breathing Exercise'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: state.phase == BreathPhase.complete
            ? _CompletionView(state: state)
            : _SessionView(
          state: state,
          circleScale: _circleScale,
          pulseOpacity: _pulseOpacity,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session View
// ─────────────────────────────────────────────────────────────────────────────

class _SessionView extends ConsumerWidget {
  final ActiveBreathingState state;
  final Animation<double> circleScale;
  final Animation<double> pulseOpacity;

  const _SessionView({
    required this.state,
    required this.circleScale,
    required this.pulseOpacity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techniques = ref.watch(breathingTechniqueProvider);

    return Column(
      children: [
        // ── Technique selector ──────────────────────────────────────────
        if (!state.isRunning && !state.isPaused) ...[
          const SizedBox(height: 16),
          _TechniqueSelector(techniques: techniques, selected: state.technique),
        ] else ...[
          const SizedBox(height: 24),
          // Cycle counter while running
          _CycleCounter(
            current: state.currentCycle,
            total: state.targetCycles,
          ),
        ],

        // ── Breathing circle ────────────────────────────────────────────
        Expanded(
          child: Center(
            child: _BreathingCircle(
              state: state,
              circleScale: circleScale,
              pulseOpacity: pulseOpacity,
            ),
          ),
        ),

        // ── Cycles control (only when idle) ────────────────────────────
        if (!state.isRunning && !state.isPaused && state.technique != null)
          _CyclesPicker(
            cycles: state.targetCycles,
            onChanged: (v) =>
                ref.read(activeBreathingProvider.notifier).setTargetCycles(v),
          ),

        // ── Controls ────────────────────────────────────────────────────
        _Controls(state: state),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technique Selector
// ─────────────────────────────────────────────────────────────────────────────

class _TechniqueSelector extends ConsumerWidget {
  final List<BreathingTechnique> techniques;
  final BreathingTechnique? selected;

  const _TechniqueSelector({
    required this.techniques,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: techniques.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = techniques[i];
          final isSelected = selected?.id == t.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref
                  .read(activeBreathingProvider.notifier)
                  .selectTechnique(t);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 160,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const Spacer(),
                      if (t.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFFFF9800).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.inhaleSeconds}-'
                        '${t.holdInSeconds > 0 ? '${t.holdInSeconds}-' : ''}'
                        '${t.exhaleSeconds}'
                        '${t.holdOutSeconds > 0 ? '-${t.holdOutSeconds}' : ''} sec',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Breathing Circle
// ─────────────────────────────────────────────────────────────────────────────

class _BreathingCircle extends StatelessWidget {
  final ActiveBreathingState state;
  final Animation<double> circleScale;
  final Animation<double> pulseOpacity;

  const _BreathingCircle({
    required this.state,
    required this.circleScale,
    required this.pulseOpacity,
  });

  Color get _phaseColor {
    switch (state.phase) {
      case BreathPhase.inhale:
        return AppColors.primary;
      case BreathPhase.holdIn:
        return AppColors.secondary;
      case BreathPhase.exhale:
        return AppColors.stressLow;
      case BreathPhase.holdOut:
        return AppColors.stressMedium;
      case BreathPhase.complete:
        return AppColors.success;
      default:
        return AppColors.primary.withOpacity(0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated circle
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              AnimatedBuilder(
                animation: pulseOpacity,
                builder: (_, __) => Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _phaseColor.withOpacity(pulseOpacity.value),
                  ),
                ),
              ),
              // Main circle
              AnimatedBuilder(
                animation: circleScale,
                builder: (_, __) => Transform.scale(
                  scale: circleScale.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _phaseColor.withOpacity(0.9),
                          _phaseColor.withOpacity(0.4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _phaseColor.withOpacity(0.35),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Phase emoji
                        Text(
                          state.phase == BreathPhase.idle
                              ? (state.technique?.emoji ?? '🧘')
                              : state.phaseEmoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                        const SizedBox(height: 4),
                        // Phase label
                        Text(
                          state.phaseLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        // Countdown
                        if (state.isRunning && state.phaseSecondsLeft > 0)
                          Text(
                            '${state.phaseSecondsLeft}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Arc progress
              if (state.isRunning)
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: _ArcProgressPainter(
                      progress: state.cycleProgress,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Technique name + benefit
        if (state.technique != null) ...[
          Text(
            state.technique!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            state.technique!.benefit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }
}

class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ArcProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 4,
      ),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcProgressPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cycle Counter
// ─────────────────────────────────────────────────────────────────────────────

class _CycleCounter extends StatelessWidget {
  final int current;
  final int total;

  const _CycleCounter({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done || active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cycles Picker
// ─────────────────────────────────────────────────────────────────────────────

class _CyclesPicker extends StatelessWidget {
  final int cycles;
  final ValueChanged<int> onChanged;

  const _CyclesPicker({required this.cycles, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Cycles:',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(width: 16),
          for (final c in [3, 5, 7, 10])
            GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cycles == c
                      ? AppColors.primary
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cycles == c ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$c',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cycles == c ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controls
// ─────────────────────────────────────────────────────────────────────────────

class _Controls extends ConsumerWidget {
  final ActiveBreathingState state;

  const _Controls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(activeBreathingProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stop (only when active)
          if (state.isRunning || state.isPaused) ...[
            _CircleButton(
              icon: Icons.stop_rounded,
              color: AppColors.danger,
              onTap: () {
                ctrl.stop();
                HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(width: 24),
          ],

          // Main action
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (!state.isRunning && !state.isPaused) {
                ctrl.start();
              } else if (state.isRunning) {
                ctrl.pause();
              } else {
                ctrl.resume();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                state.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),

          // Reset (only when paused)
          if (state.isPaused) ...[
            const SizedBox(width: 24),
            _CircleButton(
              icon: Icons.refresh_rounded,
              color: AppColors.secondary,
              onTap: () {
                ctrl.reset();
                HapticFeedback.lightImpact();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion View
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionView extends ConsumerWidget {
  final ActiveBreathingState state;

  const _CompletionView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('✅', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Session Complete!',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            if (state.technique != null) ...[
              Text(
                state.technique!.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.targetCycles} cycles completed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_outline,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.technique?.benefit ??
                          'Great work taking care of your mental health.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref
                          .read(activeBreathingProvider.notifier)
                          .reset();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    child: const Text('Again'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(activeBreathingProvider.notifier).reset();
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}