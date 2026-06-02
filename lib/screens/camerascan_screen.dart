import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../components/app_color.dart';
import '../provider/camerascan_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// camera_scan_screen.dart
//
// 30-second rPPG camera HRV scan screen.
//
// UI phases (driven by CameraScanState.phase):
//   idle       → instruction card + "Start scan" button
//   preparing  → "Warming up…" with torch countdown ring (2 s)
//   scanning   → animated progress ring + live waveform + elapsed timer
//   processing → pulsing brain icon + "Analysing…" copy
//   complete   → result card with HRV, stress score, level badge + actions
//   error      → error state with retry button
// ─────────────────────────────────────────────────────────────────────────────

class CameraScanScreen extends ConsumerStatefulWidget {
  const CameraScanScreen({super.key});

  @override
  ConsumerState<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends ConsumerState<CameraScanScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;

  // Animations
  late final AnimationController _ringController;   // rotating ring
  late final AnimationController _pulseController;  // processing pulse
  late final AnimationController _waveController;   // live waveform
  late final AnimationController _resultController; // result entry

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await ref.read(availableCamerasProvider.future);
    if (!mounted) return;
    final controller =
    await ref.read(cameraScanControllerProvider.notifier).initCamera(cameras);
    if (mounted) setState(() => _cameraController = controller);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    HapticFeedback.mediumImpact();
    await ref.read(cameraScanControllerProvider.notifier).startScan();
  }

  Future<void> _saveAndExit() async {
    final saved =
    await ref.read(cameraScanControllerProvider.notifier).saveResult();
    if (saved && mounted) {
      HapticFeedback.mediumImpact();
      context.pop();
    }
  }

  void _rescan() {
    ref.read(cameraScanControllerProvider.notifier).reset();
    _resultController.reset();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraScanControllerProvider);

    // Trigger result animation when complete
    ref.listen(cameraScanControllerProvider, (prev, next) {
      if (next.phase == ScanPhase.complete &&
          prev?.phase != ScanPhase.complete) {
        _resultController.forward(from: 0);
        HapticFeedback.mediumImpact();
      }
      if (next.phase == ScanPhase.error) {
        HapticFeedback.vibrate();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview (full bleed) ──────────────────────────────────
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(
              child: _CameraBackground(controller: _cameraController!),
            ),

          // ── Dark overlay ─────────────────────────────────────────────────
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),

          // ── Safe-area content ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _AppBar(
                  onBack: () {
                    ref
                        .read(cameraScanControllerProvider.notifier)
                        .cancelScan();
                    context.pop();
                  },
                ),
                Expanded(
                  child: _buildBody(state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(CameraScanState state) {
    return switch (state.phase) {
      ScanPhase.idle      => _IdleView(onStart: _startScan),
      ScanPhase.preparing => _PreparingView(ringController: _ringController),
      ScanPhase.scanning  => _ScanningView(
        state: state,
        waveController: _waveController,
      ),
      ScanPhase.processing => _ProcessingView(
        pulseController: _pulseController,
      ),
      ScanPhase.complete  => _ResultView(
        state: state,
        entryController: _resultController,
        onSave: _saveAndExit,
        onRescan: _rescan,
      ),
      ScanPhase.error     => _ErrorView(
        message: state.errorMessage ?? 'An error occurred.',
        onRetry: () async {
          ref.read(cameraScanControllerProvider.notifier).reset();
          await _initCamera();
        },
      ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera background with red tint during scan
// ─────────────────────────────────────────────────────────────────────────────

class _CameraBackground extends StatelessWidget {
  final CameraController controller;
  const _CameraBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize!.height,
        height: controller.value.previewSize!.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final VoidCallback onBack;
  const _AppBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Colors.white),
            onPressed: onBack,
          ),
          const Expanded(
            child: Text(
              'Camera HRV Scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Placeholder to balance the back button
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),

          // Finger placement illustration
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👆', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 4),
                Text(
                  'Cover camera',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Title
          const Text(
            'Measure your\nHRV stress score',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Place your fingertip gently over the rear camera and torch. '
                'Keep still for 30 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          // Tips row
          _TipRow(
            items: const [
              _TipItem('💡', 'Torch on'),
              _TipItem('🤫', 'Stay still'),
              _TipItem('⏱️', '30 seconds'),
            ],
          ),
          const Spacer(),

          // Start button
          _GlowButton(label: 'Start scan', onTap: onStart),
          const SizedBox(height: 8),

          Text(
            'Counts as 30% of your daily stress score',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: preparing (2-second torch warm-up)
// ─────────────────────────────────────────────────────────────────────────────

class _PreparingView extends StatelessWidget {
  final AnimationController ringController;
  const _PreparingView({required this.ringController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: ringController,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.6),
                  width: 3,
                ),
              ),
              child: const Center(
                child: Text('🔦', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Warming up torch…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cover the camera with your fingertip now',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: scanning
// ─────────────────────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  final CameraScanState state;
  final AnimationController waveController;

  const _ScanningView({
    required this.state,
    required this.waveController,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = state.totalSeconds - state.elapsedSeconds;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),

          // Progress ring
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _ScanRingPainter(
                progress: state.progress,
                color: AppColors.secondary,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      'seconds left',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Live waveform
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: waveController,
              builder: (context, _) => CustomPaint(
                painter: _WavePainter(
                  phase: waveController.value * 2 * math.pi,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Keep your finger still on the camera',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),

          const Spacer(),

          // Cancel
          TextButton(
            onPressed: () {},
            child: Text(
              'Cancel scan',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
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
            scale: Tween<double>(begin: 0.9, end: 1.1).animate(
              CurvedAnimation(
                  parent: pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('🧠', style: TextStyle(fontSize: 48)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Analysing HRV signal…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Computing heart-rate variability\nfrom your pulse signal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 14,
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
  final CameraScanState state;
  final AnimationController entryController;
  final VoidCallback onSave;
  final VoidCallback onRescan;

  const _ResultView({
    required this.state,
    required this.entryController,
    required this.onSave,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final score = state.stressScore ?? 0;
    final hrv = state.hrvMs ?? 0;
    final level = state.stressLevel ?? 'low';
    final color = AppColors.stressColor(score);
    final recommendation =
    _recommendation(level);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: entryController, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: entryController,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              // ── Result card ────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: color.withOpacity(0.35), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      // Score arc
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CustomPaint(
                          painter: _ScanRingPainter(
                            progress: score / 100,
                            color: color,
                            strokeWidth: 10,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  score.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
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
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          level.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // HRV metric row
                      _MetricRow(
                        items: [
                          _MetricItem(
                            label: 'HRV (RMSSD)',
                            value: '${hrv.toStringAsFixed(1)} ms',
                            icon: Icons.favorite_outline_rounded,
                            color: color,
                          ),
                          _MetricItem(
                            label: 'Stress score',
                            value: score.toStringAsFixed(0),
                            icon: Icons.show_chart_rounded,
                            color: color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Recommendation
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _levelEmoji(level),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                recommendation,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Action buttons ─────────────────────────────────────────
              _GlowButton(
                label: state.isSaving ? 'Saving…' : 'Save & continue',
                onTap: state.isSaving ? () {} : onSave,
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: onRescan,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: Colors.white54),
                    label: Text(
                      'Scan again',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.self_improvement,
                        size: 16, color: Colors.white54),
                    label: Text(
                      'Start breathing',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recommendation(String level) {
    switch (level) {
      case 'low':
        return 'Great HRV — your nervous system is well-balanced. Keep up your current routine.';
      case 'medium':
        return 'Moderate stress detected. A short breathing exercise can help bring HRV up.';
      case 'high':
        return 'Elevated stress. Try box breathing (4-4-4-4) or a 10-minute walk outside.';
      case 'critical':
        return 'High stress load on your nervous system. Rest, hydrate, and consider talking to someone.';
      default:
        return 'Take a moment to breathe and check in with yourself.';
    }
  }

  String _levelEmoji(String level) {
    switch (level) {
      case 'low': return '✅';
      case 'medium': return '⚠️';
      case 'high': return '🔴';
      case 'critical': return '🆘';
      default: return '💡';
    }
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
              color: AppColors.danger.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan failed',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.6),
          ),
          const SizedBox(height: 32),
          _GlowButton(label: 'Try again', onTap: onRetry),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final List<_TipItem> items;
  const _TipRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map((t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Text(t.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              t.label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ))
          .toList(),
    );
  }
}

class _TipItem {
  final String emoji;
  final String label;
  const _TipItem(this.emoji, this.label);
}

class _MetricRow extends StatelessWidget {
  final List<_MetricItem> items;
  const _MetricRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map((item) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: item.color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const SizedBox(height: 6),
              Text(
                item.value,
                style: TextStyle(
                  color: item.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ))
          .toList(),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricItem(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color});
}

class _GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GlowButton({required this.label, required this.onTap});

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
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

/// Circular arc progress ring used in scanning and result phases.
class _ScanRingPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color color;
  final double strokeWidth;

  const _ScanRingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withOpacity(0.15),
    );

    // Progress arc
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
  bool shouldRepaint(_ScanRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Animated sine-wave painter simulating a live pulse signal.
class _WavePainter extends CustomPainter {
  final double phase; // radians, updated every frame
  final Color color;

  const _WavePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const segments = 120;
    final dx = size.width / segments;

    for (int i = 0; i <= segments; i++) {
      final x = i * dx;
      // Composite wave: primary heartbeat + subtle noise
      final t = (i / segments) * 4 * math.pi + phase;
      final y = size.height / 2 +
          math.sin(t) * size.height * 0.25 +
          math.sin(t * 3.1) * size.height * 0.06;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}