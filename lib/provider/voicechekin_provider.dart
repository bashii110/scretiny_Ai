import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../domain_model/stress_model.dart';
import '../stress_calculator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// voice_checkin_provider.dart
//
// State and logic for the 30-second voice stress check-in.
//
// How the stress score is derived (25 % of final score):
//   Voice stress analysis uses three proxy signals captured during recording:
//
//   1. Amplitude variance  – high variance = erratic volume = elevated stress
//   2. Speaking rate       – silence ratio; more pauses = lower engagement
//   3. Pitch proxy         – fast amplitude oscillations approximate pitch
//      instability which correlates with emotional arousal
//
//   The three sub-scores are blended:  0.5 × amplitude  +
//                                      0.3 × rate       +
//                                      0.2 × pitch
//
//   Note: The `record` package exposes amplitude (dB) via onAmplitudeChanged.
//   True FFT pitch analysis requires a native audio plugin beyond the scope of
//   this provider — the pitch proxy is a reasonable approximation for a
//   production v1.
//
// Providers:
//   • voiceCheckinControllerProvider  – StateNotifier driving the UI
// ─────────────────────────────────────────────────────────────────────────────

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Recording phases
// ─────────────────────────────────────────────────────────────────────────────

enum VoicePhase {
  idle,        // pre-recording instruction screen
  countdown,   // 3-2-1 before recording starts
  recording,   // actively capturing audio + amplitude
  processing,  // computing stress score from amplitude log
  complete,    // result ready
  error,       // unrecoverable failure
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class VoiceCheckinState {
  final VoicePhase phase;
  final int countdownValue;    // 3 → 0
  final int elapsedSeconds;    // 0 → 30 during recording
  final int totalSeconds;
  final double currentDb;      // live amplitude for waveform display
  final List<double> dbLog;    // amplitude samples collected during recording
  final double? voiceScore;    // 0–100 derived stress score
  final String? stressLevel;
  final bool isSaving;
  final String? errorMessage;

  const VoiceCheckinState({
    this.phase = VoicePhase.idle,
    this.countdownValue = 3,
    this.elapsedSeconds = 0,
    this.totalSeconds = 30,
    this.currentDb = -60,
    this.dbLog = const [],
    this.voiceScore,
    this.stressLevel,
    this.isSaving = false,
    this.errorMessage,
  });

  double get progress => elapsedSeconds / totalSeconds;

  bool get isActive =>
      phase == VoicePhase.countdown || phase == VoicePhase.recording;

  VoiceCheckinState copyWith({
    VoicePhase? phase,
    int? countdownValue,
    int? elapsedSeconds,
    double? currentDb,
    List<double>? dbLog,
    double? voiceScore,
    String? stressLevel,
    bool? isSaving,
    String? errorMessage,
  }) =>
      VoiceCheckinState(
        phase: phase ?? this.phase,
        countdownValue: countdownValue ?? this.countdownValue,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        totalSeconds: totalSeconds,
        currentDb: currentDb ?? this.currentDb,
        dbLog: dbLog ?? this.dbLog,
        voiceScore: voiceScore ?? this.voiceScore,
        stressLevel: stressLevel ?? this.stressLevel,
        isSaving: isSaving ?? this.isSaving,
        errorMessage: errorMessage,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice stress analyser  (pure functions)
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceAnalyser {
  /// Minimum dB considered "speech" (above background noise floor).
  static const double _speechThreshold = -40.0;

  /// Converts a raw dB value (typically -160 to 0) to 0–1 normalised power.
  static double _dbToLinear(double db) {
    if (db <= -160) return 0.0;
    return math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
  }

  /// Amplitude variance score (0–100).
  /// High variance → speaker is erratic / stressed.
  static double amplitudeVarianceScore(List<double> dbLog) {
    if (dbLog.length < 10) return 50.0;

    final linear = dbLog.map(_dbToLinear).toList();
    final mean = linear.reduce((a, b) => a + b) / linear.length;
    final variance =
        linear.map((v) => math.pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
            linear.length;

    // Normalise: variance > 0.08 = very high stress; < 0.005 = low
    final normalised = (variance / 0.08).clamp(0.0, 1.0);
    return normalised * 100;
  }

  /// Speaking-rate score (0–100).
  /// Low speech ratio → lots of silence / hesitation → higher stress.
  static double speakingRateScore(List<double> dbLog) {
    if (dbLog.isEmpty) return 50.0;
    final speechFrames =
        dbLog.where((db) => db > _speechThreshold).length;
    final ratio = speechFrames / dbLog.length;

    // Invert: low speech ratio = more stress
    // Very low speech (<20 %) → score 80+; fluent (>60 %) → score <30
    final stressRatio = (1.0 - ratio).clamp(0.0, 1.0);
    return stressRatio * 100;
  }

  /// Pitch-proxy score (0–100).
  /// Counts rapid amplitude sign-changes as a proxy for high-frequency
  /// vocal tremor / pitch instability.
  static double pitchProxyScore(List<double> dbLog) {
    if (dbLog.length < 20) return 50.0;

    final linear = dbLog.map(_dbToLinear).toList();
    final mean = linear.reduce((a, b) => a + b) / linear.length;

    int crossings = 0;
    for (int i = 1; i < linear.length; i++) {
      final prev = linear[i - 1] - mean;
      final curr = linear[i] - mean;
      if (prev * curr < 0) crossings++;
    }

    // Normalise: >50 % of samples cross mean = high instability
    final ratio = crossings / linear.length;
    return (ratio * 2).clamp(0.0, 1.0) * 100;
  }

  /// Blended voice stress score (0–100).
  static double computeVoiceScore(List<double> dbLog) {
    final amp = amplitudeVarianceScore(dbLog);
    final rate = speakingRateScore(dbLog);
    final pitch = pitchProxyScore(dbLog);
    return (amp * 0.5 + rate * 0.3 + pitch * 0.2).clamp(0.0, 100.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class VoiceCheckinController extends StateNotifier<VoiceCheckinState> {
  VoiceCheckinController() : super(const VoiceCheckinState());

  final _recorder = AudioRecorder();
  Timer? _countdownTimer;
  Timer? _recordTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final _dbLog = <double>[];

  // ── Start flow ─────────────────────────────────────────────────────────────

  Future<void> startCountdown() async {
    // Check permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(
        phase: VoicePhase.error,
        errorMessage:
        'Microphone permission is required. Please enable it in Settings.',
      );
      return;
    }

    state = state.copyWith(
      phase: VoicePhase.countdown,
      countdownValue: 3,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = state.countdownValue - 1;
      if (next <= 0) {
        t.cancel();
        _startRecording();
      } else {
        state = state.copyWith(countdownValue: next);
      }
    });
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    _dbLog.clear();
    state = state.copyWith(
      phase: VoicePhase.recording,
      elapsedSeconds: 0,
      dbLog: [],
    );

    try {
      // Record to a temp file (we only need amplitude, not the audio itself)
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: '/dev/null', // discard audio; only amplitude matters
      );

      // Sample amplitude at ~10 Hz
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        _dbLog.add(amp.current);
        state = state.copyWith(
          currentDb: amp.current,
          dbLog: List.unmodifiable(_dbLog),
        );
      });

      // Progress timer
      _recordTimer =
          Timer.periodic(const Duration(seconds: 1), (t) {
            final elapsed = t.tick;
            state = state.copyWith(elapsedSeconds: elapsed);
            if (elapsed >= state.totalSeconds) {
              t.cancel();
              _stopAndProcess();
            }
          });
    } catch (e) {
      state = state.copyWith(
        phase: VoicePhase.error,
        errorMessage: 'Could not start recording. Please try again.',
      );
    }
  }

  // ── Stop + analyse ─────────────────────────────────────────────────────────

  Future<void> _stopAndProcess() async {
    await _amplitudeSub?.cancel();
    await _recorder.stop();

    state = state.copyWith(phase: VoicePhase.processing);

    // Run analysis (synchronous, <1 ms for 300 samples)
    final score = _VoiceAnalyser.computeVoiceScore(_dbLog);
    final level = StressCalculator.getStressLevel(score);

    state = state.copyWith(
      phase: VoicePhase.complete,
      voiceScore: score,
      stressLevel: level,
    );
  }

  // ── Early stop (user taps "Stop early") ───────────────────────────────────

  Future<void> stopEarly() async {
    _recordTimer?.cancel();
    if (state.phase == VoicePhase.recording && _dbLog.length >= 30) {
      await _stopAndProcess();
    } else {
      await _amplitudeSub?.cancel();
      await _recorder.stop();
      state = const VoiceCheckinState(); // back to idle
    }
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────

  Future<void> cancel() async {
    _countdownTimer?.cancel();
    _recordTimer?.cancel();
    await _amplitudeSub?.cancel();
    if (await _recorder.isRecording()) await _recorder.stop();
    state = const VoiceCheckinState();
  }

  // ── Save to Firestore ──────────────────────────────────────────────────────

  Future<bool> saveResult() async {
    final uid = _uid();
    if (uid == null || state.voiceScore == null) return false;

    state = state.copyWith(isSaving: true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Merge with today's existing stress log
      final snap = await _db
          .collection('stress_logs')
          .where('userId', isEqualTo: uid)
          .where('date',
          isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final old = StressLogModel.fromMap(snap.docs.first.data());
        final newFinal = StressCalculator.calculateFinalStressScore(
          cameraHRV: old.cameraHRVScore,
          voiceScore: state.voiceScore!,
          phoneUsage: old.phoneUsageScore,
          sleepScore: StressCalculator.sleepQualityToStress(3),
          checkInScore: old.checkInScore,
        );
        final updated = old.copyWith(
          voiceScore: state.voiceScore,
          finalStressScore: newFinal,
          stressLevel: StressCalculator.getStressLevel(newFinal),
        );
        await _db
            .collection('stress_logs')
            .doc(old.id)
            .update(updated.toMap());
      } else {
        final log = StressLogModel(
          id: _uuid.v4(),
          userId: uid,
          date: now,
          voiceScore: state.voiceScore!,
          finalStressScore: state.voiceScore!,
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

  void reset() => state = const VoiceCheckinState();
  void clearError() => state = state.copyWith(errorMessage: null);

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final voiceCheckinControllerProvider = StateNotifierProvider.autoDispose<
    VoiceCheckinController, VoiceCheckinState>(
      (_) => VoiceCheckinController(),
);