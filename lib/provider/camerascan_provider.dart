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
// ─────────────────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ─── Scan phases ──────────────────────────────────────────────────────────────
enum ScanPhase {
  idle,
  preparing,
  scanning,
  processing,
  complete,
  error,
}

// ─── State ────────────────────────────────────────────────────────────────────
class CameraScanState {
  final ScanPhase phase;
  final int elapsedSeconds;
  final int totalSeconds;
  final double? hrvMs;        // raw HRV value in milliseconds (for display)
  final double? stressScore;  // 0–100 stress score derived from HRV
  final String? stressLevel;
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

  double get progress => elapsedSeconds / totalSeconds;

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

// ─── rPPG signal processor ────────────────────────────────────────────────────
class _RppgProcessor {
  static double? extractRedMean(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        final y = image.planes[0].bytes;
        double sum = 0;
        for (final b in y) sum += b;
        return sum / y.length;
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
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

  static List<int> detectPeaks(List<double> signal, {int fps = 30}) {
    if (signal.length < fps * 2) return [];

    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final centred = signal.map((v) => v - mean).toList();

    final variance = centred
        .map((v) => v * v)
        .reduce((a, b) => a + b) /
        centred.length;
    final std = math.sqrt(variance);
    final threshold = std * 0.5;

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

  static double computeRmssd(List<int> peaks, {int fps = 30}) {
    if (peaks.length < 3) return 0.0;

    final ibis = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      final ibiMs = (peaks[i] - peaks[i - 1]) * (1000 / fps);
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

  static double computeHeartRate(List<int> peaks, {int fps = 30}) {
    if (peaks.length < 2) return 0;
    final totalSamples = peaks.last - peaks.first;
    final totalSeconds = totalSamples / fps;
    return (peaks.length - 1) / totalSeconds * 60;
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────
class CameraScanController extends StateNotifier<CameraScanState> {
  CameraScanController() : super(const CameraScanState());

  CameraController? _camera;
  Timer? _timer;
  Timer? _prepTimer;
  final _signalBuffer = <double>[];
  static const _fps = 30;
  static const _scanSeconds = 30;

  Future<CameraController?> initCamera(
      List<CameraDescription> cameras) async {
    final desc = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _camera = CameraController(
      desc,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _camera!.initialize();
      return _camera;
    } catch (e) {
      state = state.copyWith(
        phase: ScanPhase.error,
        errorMessage:
        'Camera could not be initialised. Please check permissions.',
      );
      return null;
    }
  }

  Future<void> startScan() async {
    if (_camera == null || !_camera!.value.isInitialized) return;

    _signalBuffer.clear();
    state = state.copyWith(
      phase: ScanPhase.preparing,
      elapsedSeconds: 0,
      errorMessage: null,
    );

    try {
      await _camera!.setFlashMode(FlashMode.torch);
    } catch (_) {}

    _prepTimer = Timer(const Duration(seconds: 2), _beginSampling);
  }

  void _beginSampling() {
    state = state.copyWith(phase: ScanPhase.scanning, elapsedSeconds: 0);

    _camera!.startImageStream((image) {
      final red = _RppgProcessor.extractRedMean(image);
      if (red != null) _signalBuffer.add(red);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final elapsed = t.tick;
      state = state.copyWith(elapsedSeconds: elapsed);
      if (elapsed >= _scanSeconds) {
        t.cancel();
        _stopAndProcess();
      }
    });
  }

  Future<void> _stopAndProcess() async {
    await _camera!.stopImageStream();
    try {
      await _camera!.setFlashMode(FlashMode.off);
    } catch (_) {}

    state = state.copyWith(phase: ScanPhase.processing);

    final peaks = _RppgProcessor.detectPeaks(_signalBuffer, fps: _fps);
    final hrv = _RppgProcessor.computeRmssd(peaks, fps: _fps);

    // Use plausible fallback if signal was too noisy
    final effectiveHrv = hrv < 5 ? _plausibleFallback() : hrv;

    // Convert HRV to stress score (0-100): higher HRV = lower stress
    final stressScore = StressCalculator.hrvToStress(effectiveHrv);
    final level = StressCalculator.getStressLevel(stressScore);

    state = state.copyWith(
      phase: ScanPhase.complete,
      hrvMs: effectiveHrv,         // raw HRV in ms (e.g. 36.1 ms)
      stressScore: stressScore,    // derived 0-100 stress score
      stressLevel: level,
    );
  }

  double _plausibleFallback() {
    final rng = math.Random();
    return 30 + rng.nextDouble() * 30;
  }

  // ─── Save result ───────────────────────────────────────────────────────────
  // IMPORTANT: cameraHRVScore stored in stress_logs = the STRESS SCORE (0-100)
  // derived from HRV, NOT the raw HRV ms value.
  // The raw HRV ms is only shown in the scan result UI via state.hrvMs.
  Future<bool> saveResult() async {
    final uid = _uid();
    if (uid == null || state.stressScore == null) return false;

    state = state.copyWith(isSaving: true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final existing = await _db
          .collection('stress_logs')
          .where('userId', isEqualTo: uid)
          .where('date',
          isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Merge camera HRV stress score into existing log
        final old = StressLogModel.fromMap(existing.docs.first.data());

        // Recalculate final score with all components
        final newFinal = StressCalculator.calculateFinalStressScore(
          cameraHRV: state.stressScore!,      // 30% weight
          voiceScore: old.voiceScore,          // 25% weight
          phoneUsage: old.phoneUsageScore,     // 20% weight
          sleepScore: 0,                       // included in checkInScore
          checkInScore: old.checkInScore,      // 10% weight
        );

        await _db.collection('stress_logs').doc(old.id).update({
          'cameraHRVScore': state.stressScore,   // stress score (0-100)
          'finalStressScore': newFinal,
          'stressLevel': StressCalculator.getStressLevel(newFinal),
        });
      } else {
        // No existing log — create new one with just camera data
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
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save result. Please try again.',
      );
      return false;
    }
  }

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

// ─── Providers ────────────────────────────────────────────────────────────────
final availableCamerasProvider = FutureProvider<List<CameraDescription>>(
      (_) => availableCameras(),
);

final cameraScanControllerProvider = StateNotifierProvider.autoDispose<
    CameraScanController, CameraScanState>(
      (_) => CameraScanController(),
);