import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/checkin_model.dart';
import '../domain_model/stress_model.dart';
import '../stress_calculator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// checkin_provider.dart
//
// Riverpod providers and state for the morning / evening check-in flow.
//
// Providers:
//   • checkinControllerProvider  – StateNotifier that drives the multi-step form
//   • todayMorningCheckinProvider – StreamProvider<CheckInModel?> – today's morning log
//   • todayEveningCheckinProvider – StreamProvider<CheckInModel?> – today's evening log
//   • checkinRepositoryProvider   – thin Firestore repo (save / fetch)
// ─────────────────────────────────────────────────────────────────────────────

// ── Helpers ──────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

class CheckInRepository {
  final _col = _db.collection('checkins');
  final _stressCol = _db.collection('stress_logs');

  /// Saves a completed check-in and derives + saves the stress contribution.
  Future<void> saveCheckIn(CheckInModel model) async {
    await _col.doc(model.id).set(model.toMap());
  }

  /// Saves a stress log built from the check-in contribution.
  Future<void> saveStressLog(StressLogModel log) async {
    await _stressCol.doc(log.id).set(log.toMap());
  }

  /// Returns today's check-in of [type] ('morning' | 'evening') or null.
  Stream<CheckInModel?> todayCheckin(String type) {
    final uid = _uid();
    if (uid == null) return Stream.value(null);

    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return _col
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: type)
        .where('date',
        isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
        ? null
        : CheckInModel.fromMap(snap.docs.first.data()));
  }
}

final checkinRepositoryProvider = Provider<CheckInRepository>(
      (_) => CheckInRepository(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Today's check-in streams
// ─────────────────────────────────────────────────────────────────────────────

final todayMorningCheckinProvider = StreamProvider<CheckInModel?>((ref) {
  return ref.watch(checkinRepositoryProvider).todayCheckin('morning');
});

final todayEveningCheckinProvider = StreamProvider<CheckInModel?>((ref) {
  return ref.watch(checkinRepositoryProvider).todayCheckin('evening');
});

// ─────────────────────────────────────────────────────────────────────────────
// Check-in form state
// ─────────────────────────────────────────────────────────────────────────────

class CheckInFormState {
  // Step tracking
  final int currentStep;   // 0-based, max depends on type
  final bool isSubmitting;
  final bool isComplete;
  final String? error;

  // Morning fields
  final int sleepQuality;   // 1–5
  final int energyLevel;    // 1–5
  final int anxietyLevel;   // 1–5
  final int mentalClarity;  // 1–5
  final int overallMood;    // 1–5
  final int workStress;     // 1–5
  final String gratitudeNote;

  const CheckInFormState({
    this.currentStep = 0,
    this.isSubmitting = false,
    this.isComplete = false,
    this.error,
    this.sleepQuality = 3,
    this.energyLevel = 3,
    this.anxietyLevel = 3,
    this.mentalClarity = 3,
    this.overallMood = 3,
    this.workStress = 3,
    this.gratitudeNote = '',
  });

  CheckInFormState copyWith({
    int? currentStep,
    bool? isSubmitting,
    bool? isComplete,
    String? error,
    int? sleepQuality,
    int? energyLevel,
    int? anxietyLevel,
    int? mentalClarity,
    int? overallMood,
    int? workStress,
    String? gratitudeNote,
  }) =>
      CheckInFormState(
        currentStep: currentStep ?? this.currentStep,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isComplete: isComplete ?? this.isComplete,
        error: error,
        sleepQuality: sleepQuality ?? this.sleepQuality,
        energyLevel: energyLevel ?? this.energyLevel,
        anxietyLevel: anxietyLevel ?? this.anxietyLevel,
        mentalClarity: mentalClarity ?? this.mentalClarity,
        overallMood: overallMood ?? this.overallMood,
        workStress: workStress ?? this.workStress,
        gratitudeNote: gratitudeNote ?? this.gratitudeNote,
      );

  /// Progress value 0.0–1.0 for the morning flow (5 steps).
  double get morningProgress => (currentStep + 1) / 5;

  /// Progress value 0.0–1.0 for the evening flow (4 steps).
  double get eveningProgress => (currentStep + 1) / 4;
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class CheckInController extends StateNotifier<CheckInFormState> {
  final CheckInRepository _repo;

  CheckInController(this._repo) : super(const CheckInFormState());

  // ── Field setters ─────────────────────────────────────────────────────────

  void setSleepQuality(int v) => state = state.copyWith(sleepQuality: v);
  void setEnergyLevel(int v) => state = state.copyWith(energyLevel: v);
  void setAnxietyLevel(int v) => state = state.copyWith(anxietyLevel: v);
  void setMentalClarity(int v) => state = state.copyWith(mentalClarity: v);
  void setOverallMood(int v) => state = state.copyWith(overallMood: v);
  void setWorkStress(int v) => state = state.copyWith(workStress: v);
  void setGratitudeNote(String v) => state = state.copyWith(gratitudeNote: v);

  // ── Navigation ────────────────────────────────────────────────────────────

  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void reset() => state = const CheckInFormState();

  // ── Submit morning check-in ───────────────────────────────────────────────

  Future<bool> submitMorning() async {
    final uid = _uid();
    if (uid == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final now = DateTime.now();
      final s = state;

      final model = CheckInModel(
        id: _uuid.v4(),
        userId: uid,
        type: 'morning',
        date: now,
        sleepQuality: s.sleepQuality,
        anxietyLevel: s.anxietyLevel,
        energyLevel: s.energyLevel,
        mentalClarity: s.mentalClarity,
        overallMood: s.overallMood,
        workStress: s.workStress,
        gratitudeNote: s.gratitudeNote,
      );

      await _repo.saveCheckIn(model);

      // Derive partial stress log from check-in only
      final checkInScore = StressCalculator.checkInToStress(
        anxietyLevel: s.anxietyLevel,
        workStress: s.workStress,
        energyLevel: s.energyLevel,
        mentalClarity: s.mentalClarity,
      );
      final sleepScore = StressCalculator.sleepQualityToStress(s.sleepQuality);

      // Partial final score (camera + voice = 0 until scanned today)
      final finalScore = StressCalculator.calculateFinalStressScore(
        cameraHRV: 0,
        voiceScore: 0,
        phoneUsage: 0,
        sleepScore: sleepScore,
        checkInScore: checkInScore,
      );

      final stressLog = StressLogModel(
        id: _uuid.v4(),
        userId: uid,
        date: now,
        checkInScore: checkInScore,
        finalStressScore: finalScore,
        stressLevel: StressCalculator.getStressLevel(finalScore),
      );

      await _repo.saveStressLog(stressLog);

      state = state.copyWith(isSubmitting: false, isComplete: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Could not save check-in. Please try again.',
      );
      return false;
    }
  }

  // ── Submit evening check-in ───────────────────────────────────────────────

  Future<bool> submitEvening() async {
    final uid = _uid();
    if (uid == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final now = DateTime.now();
      final s = state;

      final model = CheckInModel(
        id: _uuid.v4(),
        userId: uid,
        type: 'evening',
        date: now,
        sleepQuality: s.sleepQuality,
        anxietyLevel: s.anxietyLevel,
        energyLevel: s.energyLevel,
        mentalClarity: s.mentalClarity,
        overallMood: s.overallMood,
        workStress: s.workStress,
        gratitudeNote: s.gratitudeNote,
      );

      await _repo.saveCheckIn(model);

      final checkInScore = StressCalculator.checkInToStress(
        anxietyLevel: s.anxietyLevel,
        workStress: s.workStress,
        energyLevel: s.energyLevel,
        mentalClarity: s.mentalClarity,
      );

      final finalScore = StressCalculator.calculateFinalStressScore(
        cameraHRV: 0,
        voiceScore: 0,
        phoneUsage: 0,
        sleepScore: 0,
        checkInScore: checkInScore,
      );

      final stressLog = StressLogModel(
        id: _uuid.v4(),
        userId: uid,
        date: now,
        checkInScore: checkInScore,
        finalStressScore: finalScore,
        stressLevel: StressCalculator.getStressLevel(finalScore),
      );

      await _repo.saveStressLog(stressLog);

      state = state.copyWith(isSubmitting: false, isComplete: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Could not save check-in. Please try again.',
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final checkinControllerProvider =
StateNotifierProvider.autoDispose<CheckInController, CheckInFormState>(
      (ref) => CheckInController(ref.watch(checkinRepositoryProvider)),
);