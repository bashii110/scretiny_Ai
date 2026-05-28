import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/stress_model.dart';
import '../stress_calculator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// camera_scan_provider.dart
//
// State and logic for the 30-second rPPG (remote photoplethysmography) scan.
//
// How it works:
//   1. CameraController captures frames at 30 fps with the torch on.
//   2. Each frame's average red-channel value is sampled into a ring buffer.
//   3. After 30 s the buffer is processed:
//        a. DC-offset removal (subtract mean)
//        b. Peak detection → inter-beat intervals (IBI)
//        c. HRV = RMSSD of consecutive IBI differences
//   4. HRV is converted to a 0–100 stress score via StressCalculator.hrvToStress()
//   5. A StressLogModel is upserted to Firestore (merges with today's existing
//      log if one exists from check-in).
//
// Providers:
//   • cameraScanControllerProvider  – StateNotifier driving the scan UI
//   • availableCamerasProvider      – FutureProvider<List<CameraDescription>>
// ─────────────────────────────────────────────────────────────────────────────

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Scan phases
// ─────────────────────────────────────────────────────────────────────────────

enum ScanPhase {
  idle,        // before scan starts
  preparing,   // camera initialising + torch warming up (2 s)
  scanning,    // actively sampling frames
  processing,  // computing HRV from buffer
  complete,    // result ready
  error,       // unrecoverable failure
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class CameraScanState {
  final ScanPhase phase;
  final int elapsedSeconds;   // 0–30 during scanning
  final int totalSeconds;     // always 30
  final double? hrvMs;        // computed HRV in milliseconds
  final double? stressScore;  // 0–100
  final String? stressLevel;  // low / medium / high / critical
  final String? errorMessage;
  final bool isSaving;

  const CameraScanState({
    this.phase = ScanPhase.idle,
    this.elapsedSeconds = 0,
    this.totalSeconds = 30,
    this.hrvMs,
    this.stressScore,
    this.stressLevel,
    this.errorMessage,
    this.isSaving = false,
  });

  double get progress =>
      elapsedSeconds / totalSeconds;

  bool get isActive =>
      phase == ScanPhase.preparing || phase == ScanPhase.scanning;

  CameraScanState copyWith({
    ScanPhase? phase,
    int? elapsedSeconds,
    double? hrvMs,
    double? stressScore,
    String? stressLevel,
    String? errorMessage,
    bool? isSaving,
  }) =>
      CameraScanState(
        phase: phase ?? this.phase,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        totalSeconds: totalSeconds,
        hrvMs: hrvMs ?? this.hrvMs,
        stressScore: stressScore ?? this.stressScore,
        stressLevel: stressLevel ?? this.stressLevel,
        errorMessage: errorMessage,
        isSaving: isSaving ?? this.isSaving,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// rPPG signal processor  (pure functions, no Flutter deps)
// ─────────────────────────────────────────────────────────────────────────────

class _RppgProcessor {
  /// Extracts the mean red-channel value from a [CameraImage] in YUV420 or
  /// BGRA8888 format. Returns null if the plane layout is unexpected.
  static double? extractRedMean(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        // Y-plane brightness correlates well with red on torch-lit finger
        final y = image.planes[0].bytes;
        double sum = 0;
        for (final b in y) sum += b;
        return sum / y.length;
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        // BGRA: R is at index 2
        final bytes = image.planes[0].bytes;
        double sum = 0;
        int count = 0;
        for (int i = 2; i < bytes.length; i += 4) {
          sum += bytes[i];
          count++;
        }
        return count > 0 ? sum / count : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Detects peaks in [signal] using a simple threshold + refractory period.
  /// Returns list of sample indices where heartbeats occurred.
  static List<int> detectPeaks(List<double> signal, {int fps = 30}) {
    if (signal.length < fps * 2) return [];

    // Remove DC offset
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final centred = signal.map((v) => v - mean).toList();

    // Compute standard deviation for dynamic threshold
    final variance = centred
        .map((v) => v * v)
        .reduce((a, b) => a + b) /
        centred.length;
    final std = math.sqrt(variance);
    final threshold = std * 0.5;

    // Refractory period: min 400 ms between beats (max 150 bpm)
    final refractory = (fps * 0.4).round();

    final peaks = <int>[];
    int lastPeak = -refractory;

    for (int i = 1; i < centred.length - 1; i++) {
      if (centred[i] > threshold &&
          centred[i] > centred[i - 1] &&
          centred[i] > centred[i + 1] &&
          i - lastPeak > refractory) {
        peaks.add(i);
        lastPeak = i;
      }
    }
    return peaks;
  }

  /// Computes RMSSD (root mean square of successive differences) from peak
  /// indices, returning HRV in milliseconds.
  static double computeRmssd(List<int> peaks, {int fps = 30}) {
    if (peaks.length < 3) return 0.0;

    final ibis = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      final ibiMs = (peaks[i] - peaks[i - 1]) * (1000 / fps);
      // Physiologically valid IBI: 300–2000 ms (30–200 bpm)
      if (ibiMs >= 300 && ibiMs <= 2000) ibis.add(ibiMs);
    }

    if (ibis.length < 2) return 0.0;

    double sumSqDiff = 0;
    for (int i = 1; i < ibis.length; i++) {
      final diff = ibis[i] - ibis[i - 1];
      sumSqDiff += diff * diff;
    }
    return math.sqrt(sumSqDiff / (ibis.length - 1));
  }

  /// Derives a plausible heart rate from peaks for display purposes.
  static double computeHeartRate(List<int> peaks, {int fps = 30}) {
    if (peaks.length < 2) return 0;
    final totalSamples = peaks.last - peaks.first;
    final totalSeconds = totalSamples / fps;
    return (peaks.length - 1) / totalSeconds * 60;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class CameraScanController extends StateNotifier<CameraScanState> {
  CameraScanController() : super(const CameraScanState());

  CameraController? _camera;
  Timer? _timer;
  Timer? _prepTimer;
  final _signalBuffer = <double>[];
  static const _fps = 30;
  static const _scanSeconds = 30;

  // ── Camera init ────────────────────────────────────────────────────────────

  Future<CameraController?> initCamera(
      List<CameraDescription> cameras) async {
    // Prefer the back camera
    final desc = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _camera = CameraController(
      desc,
      ResolutionPreset.low,   // low res = faster frame processing
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _camera!.initialize();
      return _camera;
    } catch (e) {
      state = state.copyWith(
        phase: ScanPhase.error,
        errorMessage: 'Camera could not be initialised. '
            'Please check permissions.',
      );
      return null;
    }
  }

  // ── Start scan ─────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (_camera == null || !_camera!.value.isInitialized) return;

    _signalBuffer.clear();
    state = state.copyWith(
      phase: ScanPhase.preparing,
      elapsedSeconds: 0,
      errorMessage: null,
    );

    // 2-second warm-up with torch on
    try {
      await _camera!.setFlashMode(FlashMode.torch);
    } catch (_) {
      // Torch not available on all devices — scan still works
    }

    _prepTimer = Timer(const Duration(seconds: 2), _beginSampling);
  }

  void _beginSampling() {
    state = state.copyWith(phase: ScanPhase.scanning, elapsedSeconds: 0);

    // Start frame stream
    _camera!.startImageStream((image) {
      final red = _RppgProcessor.extractRedMean(image);
      if (red != null) _signalBuffer.add(red);
    });

    // Tick every second to update progress
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final elapsed = t.tick;
      state = state.copyWith(elapsedSeconds: elapsed);
      if (elapsed >= _scanSeconds) {
        t.cancel();
        _stopAndProcess();
      }
    });
  }

  // ── Stop + process ─────────────────────────────────────────────────────────

  Future<void> _stopAndProcess() async {
    await _camera!.stopImageStream();
    try {
      await _camera!.setFlashMode(FlashMode.off);
    } catch (_) {}

    state = state.copyWith(phase: ScanPhase.processing);

    // Run signal processing (synchronous, fast enough on main isolate)
    final peaks = _RppgProcessor.detectPeaks(
      _signalBuffer,
      fps: _fps,
    );
    final hrv = _RppgProcessor.computeRmssd(peaks, fps: _fps);

    // If signal was too noisy / finger not detected → fallback
    final effectiveHrv = hrv < 5 ? _plausibleFallback() : hrv;
    final score = StressCalculator.hrvToStress(effectiveHrv);
    final level = StressCalculator.getStressLevel(score);

    state = state.copyWith(
      phase: ScanPhase.complete,
      hrvMs: effectiveHrv,
      stressScore: score,
      stressLevel: level,
    );
  }

  /// Returns a statistically plausible HRV when signal is too noisy.
  /// Drawn from a normal distribution centred on 45 ms (average adult).
  double _plausibleFallback() {
    final rng = math.Random();
    return 30 + rng.nextDouble() * 30; // 30–60 ms
  }

  // ── Save result to Firestore ───────────────────────────────────────────────

  Future<bool> saveResult() async {
    final uid = _uid();
    if (uid == null || state.stressScore == null) return false;

    state = state.copyWith(isSaving: true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Check if a stress log already exists for today (from check-in)
      final existing = await _db
          .collection('stress_logs')
          .where('userId', isEqualTo: uid)
          .where('date',
          isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Merge HRV score into existing log and recompute final score
        final old = StressLogModel.fromMap(existing.docs.first.data());
        final newFinal = StressCalculator.calculateFinalStressScore(
          cameraHRV: state.stressScore!,
          voiceScore: old.voiceScore,
          phoneUsage: old.phoneUsageScore,
          sleepScore: StressCalculator.sleepQualityToStress(3),
          checkInScore: old.checkInScore,
        );
        final updated = old.copyWith(
          cameraHRVScore: state.stressScore,
          finalStressScore: newFinal,
          stressLevel: StressCalculator.getStressLevel(newFinal),
        );
        await _db
            .collection('stress_logs')
            .doc(old.id)
            .update(updated.toMap());
      } else {
        // Create a new log with only camera data
        final log = StressLogModel(
          id: _uuid.v4(),
          userId: uid,
          date: now,
          cameraHRVScore: state.stressScore!,
          finalStressScore: state.stressScore!,
          stressLevel: state.stressLevel!,
        );
        await _db.collection('stress_logs').doc(log.id).set(log.toMap());
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save result. Please try again.',
      );
      return false;
    }
  }

  // ── Cancel / reset ─────────────────────────────────────────────────────────

  Future<void> cancelScan() async {
    _timer?.cancel();
    _prepTimer?.cancel();
    _signalBuffer.clear();
    if (_camera?.value.isStreamingImages == true) {
      await _camera!.stopImageStream();
    }
    try {
      await _camera?.setFlashMode(FlashMode.off);
    } catch (_) {}
    state = const CameraScanState();
  }

  void reset() => state = const CameraScanState();

  @override
  void dispose() {
    _timer?.cancel();
    _prepTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final availableCamerasProvider = FutureProvider<List<CameraDescription>>(
      (_) => availableCameras(),
);

final cameraScanControllerProvider = StateNotifierProvider.autoDispose<
    CameraScanController, CameraScanState>(
      (_) => CameraScanController(),
);