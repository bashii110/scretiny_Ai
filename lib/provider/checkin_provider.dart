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
// All Riverpod providers for the morning / evening check-in feature.
//
// Responsibility boundary:
//   This file owns everything that touches the 'checkins' Firestore collection
//   and the derived partial StressLogModel that results from a check-in.
//   It does NOT own camera or voice stress — those providers merge into the
//   same stress_logs document independently.
//
// Public surface:
//   Repositories
//     checkinRepositoryProvider   – CheckInRepository singleton
//
//   Read-only streams
//     todayMorningCheckinProvider – StreamProvider<CheckInModel?>
//     todayEveningCheckinProvider – StreamProvider<CheckInModel?>
//     checkinHistoryProvider      – StreamProvider.family<List<CheckInModel>, int>
//
//   Form controller
//     checkinControllerProvider   – StateNotifierProvider<CheckInController>
//
// Firestore collections used:
//   checkins     – one document per check-in (type: morning | evening)
//   stress_logs  – one document per day; check-in merges into today's log
// ─────────────────────────────────────────────────────────────────────────────

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

/// Returns a DateTime representing midnight at the start of today (local).
DateTime get _startOfToday {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckInRepository
// ─────────────────────────────────────────────────────────────────────────────

/// Thin data-access layer for check-in documents and the stress-log merge.
///
/// All Firestore reads / writes for check-ins go through this class so that
/// controllers stay free of raw query strings and the logic is unit-testable
/// by injecting a mock.
class CheckInRepository {
  final _checkinsCol = _db.collection('checkins');
  final _stressCol   = _db.collection('stress_logs');

  // ── Writes ──────────────────────────────────────────────────────────────

  /// Persists a completed [CheckInModel] document.
  Future<void> saveCheckIn(CheckInModel model) =>
      _checkinsCol.doc(model.id).set(model.toMap());

  /// Creates or updates today's stress log with the check-in contribution.
  ///
  /// Merge strategy:
  ///   • If a stress log already exists for today (created by camera / voice),
  ///     only `checkInScore`, `finalStressScore`, and `stressLevel` are
  ///     updated — camera and voice scores are preserved.
  ///   • If no log exists yet, a new one is created with only the check-in
  ///     fields populated (camera / voice default to 0.0 until those scans
  ///     are run).
  Future<void> upsertStressLogFromCheckIn({
    required String uid,
    required double checkInScore,
    required double sleepScore,
    required DateTime date,
  }) async {
    final snap = await _stressCol
        .where('userId', isEqualTo: uid)
        .where('date',
        isGreaterThanOrEqualTo: _startOfToday.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      // ── Merge into existing log ──────────────────────────────────────
      final existing = StressLogModel.fromMap(snap.docs.first.data());
      final newFinal = StressCalculator.calculateFinalStressScore(
        cameraHRV:    existing.cameraHRVScore,
        voiceScore:   existing.voiceScore,
        phoneUsage:   existing.phoneUsageScore,
        sleepScore:   sleepScore,
        checkInScore: checkInScore,
      );
      await _stressCol.doc(existing.id).update({
        'checkInScore':    checkInScore,
        'finalStressScore': newFinal,
        'stressLevel':     StressCalculator.getStressLevel(newFinal),
      });
    } else {
      // ── Create new partial log ───────────────────────────────────────
      final finalScore = StressCalculator.calculateFinalStressScore(
        cameraHRV:    0,
        voiceScore:   0,
        phoneUsage:   0,
        sleepScore:   sleepScore,
        checkInScore: checkInScore,
      );
      final log = StressLogModel(
        id:               _uuid.v4(),
        userId:           uid,
        date:             date,
        checkInScore:     checkInScore,
        finalStressScore: finalScore,
        stressLevel:      StressCalculator.getStressLevel(finalScore),
      );
      await _stressCol.doc(log.id).set(log.toMap());
    }
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Real-time stream of today's [type] check-in ('morning' | 'evening').
  Stream<CheckInModel?> todayCheckin(String type) {
    final uid = _uid();
    if (uid == null) return Stream.value(null);

    return _checkinsCol
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: type)
        .where('date',
        isGreaterThanOrEqualTo: _startOfToday.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
        ? null
        : CheckInModel.fromMap(s.docs.first.data()));
  }

  /// Last [days] check-ins of any type for the current user, newest first.
  Stream<List<CheckInModel>> history(int days) {
    final uid = _uid();
    if (uid == null) return Stream.value([]);

    final cutoff =
    DateTime.now().subtract(Duration(days: days));

    return _checkinsCol
        .where('userId', isEqualTo: uid)
        .where('date',
        isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) => CheckInModel.fromMap(d.data()))
        .toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository provider
// ─────────────────────────────────────────────────────────────────────────────

final checkinRepositoryProvider = Provider<CheckInRepository>(
      (_) => CheckInRepository(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Read-only stream providers
// ─────────────────────────────────────────────────────────────────────────────

/// Today's morning check-in, or null if not yet completed.
final todayMorningCheckinProvider = StreamProvider<CheckInModel?>((ref) =>
    ref.watch(checkinRepositoryProvider).todayCheckin('morning'));

/// Today's evening check-in, or null if not yet completed.
final todayEveningCheckinProvider = StreamProvider<CheckInModel?>((ref) =>
    ref.watch(checkinRepositoryProvider).todayCheckin('evening'));

/// Last [days] check-ins (any type). Family provider — pass the window size:
/// ```dart
/// ref.watch(checkinHistoryProvider(7));   // last week
/// ref.watch(checkinHistoryProvider(30));  // last month
/// ```
final checkinHistoryProvider =
StreamProvider.family<List<CheckInModel>, int>((ref, days) =>
    ref.watch(checkinRepositoryProvider).history(days));

// ─────────────────────────────────────────────────────────────────────────────
// CheckInFormState
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable value object holding all form field values and UI state for
/// both the morning (5-step) and evening (4-step) flows.
class CheckInFormState {
  final int    currentStep;
  final bool   isSubmitting;
  final bool   isComplete;
  final String? error;

  // ── Slider fields (1–5) ──────────────────────────────────────────────────
  final int sleepQuality;   // morning only
  final int energyLevel;
  final int anxietyLevel;
  final int mentalClarity;
  final int overallMood;
  final int workStress;
  final String gratitudeNote;

  const CheckInFormState({
    this.currentStep  = 0,
    this.isSubmitting = false,
    this.isComplete   = false,
    this.error,
    this.sleepQuality  = 3,
    this.energyLevel   = 3,
    this.anxietyLevel  = 3,
    this.mentalClarity = 3,
    this.overallMood   = 3,
    this.workStress    = 3,
    this.gratitudeNote = '',
  });

  CheckInFormState copyWith({
    int?    currentStep,
    bool?   isSubmitting,
    bool?   isComplete,
    String? error,
    int?    sleepQuality,
    int?    energyLevel,
    int?    anxietyLevel,
    int?    mentalClarity,
    int?    overallMood,
    int?    workStress,
    String? gratitudeNote,
  }) =>
      CheckInFormState(
        currentStep:   currentStep   ?? this.currentStep,
        isSubmitting:  isSubmitting  ?? this.isSubmitting,
        isComplete:    isComplete    ?? this.isComplete,
        error:         error,                             // null resets error
        sleepQuality:  sleepQuality  ?? this.sleepQuality,
        energyLevel:   energyLevel   ?? this.energyLevel,
        anxietyLevel:  anxietyLevel  ?? this.anxietyLevel,
        mentalClarity: mentalClarity ?? this.mentalClarity,
        overallMood:   overallMood   ?? this.overallMood,
        workStress:    workStress    ?? this.workStress,
        gratitudeNote: gratitudeNote ?? this.gratitudeNote,
      );

  double get morningProgress => (currentStep + 1) / 5;
  double get eveningProgress => (currentStep + 1) / 4;
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckInController
// ─────────────────────────────────────────────────────────────────────────────

/// Drives both the morning and evening check-in flows.
///
/// Step navigation, field mutations, and Firestore submission all go through
/// here. The UI reads [CheckInFormState] and calls the notifier methods —
/// no business logic leaks into widgets.
class CheckInController extends StateNotifier<CheckInFormState> {
  final CheckInRepository _repo;

  CheckInController(this._repo) : super(const CheckInFormState());

  // ── Field setters ─────────────────────────────────────────────────────────

  void setSleepQuality(int v)   => state = state.copyWith(sleepQuality:  v);
  void setEnergyLevel(int v)    => state = state.copyWith(energyLevel:   v);
  void setAnxietyLevel(int v)   => state = state.copyWith(anxietyLevel:  v);
  void setMentalClarity(int v)  => state = state.copyWith(mentalClarity: v);
  void setOverallMood(int v)    => state = state.copyWith(overallMood:   v);
  void setWorkStress(int v)     => state = state.copyWith(workStress:    v);
  void setGratitudeNote(String v) =>
      state = state.copyWith(gratitudeNote: v);

  // ── Step navigation ───────────────────────────────────────────────────────

  void nextStep() =>
      state = state.copyWith(currentStep: state.currentStep + 1);

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void reset() => state = const CheckInFormState();
  void clearError() => state = state.copyWith(error: null);

  // ── Submit morning ────────────────────────────────────────────────────────

  /// Saves the morning [CheckInModel] and upserts today's stress log.
  /// Returns `true` on success so the screen can navigate away.
  Future<bool> submitMorning() async {
    final uid = _uid();
    if (uid == null) return false;

    state = state.copyWith(isSubmitting: true);
    try {
      final now = DateTime.now();
      final s   = state;

      // 1 — Persist check-in document
      final model = CheckInModel(
        id:            _uuid.v4(),
        userId:        uid,
        type:          'morning',
        date:          now,
        sleepQuality:  s.sleepQuality,
        anxietyLevel:  s.anxietyLevel,
        energyLevel:   s.energyLevel,
        mentalClarity: s.mentalClarity,
        overallMood:   s.overallMood,
        workStress:    s.workStress,
        gratitudeNote: s.gratitudeNote,
      );
      await _repo.saveCheckIn(model);

      // 2 — Derive stress contributions
      final checkInScore = StressCalculator.checkInToStress(
        anxietyLevel:  s.anxietyLevel,
        workStress:    s.workStress,
        energyLevel:   s.energyLevel,
        mentalClarity: s.mentalClarity,
      );
      final sleepScore =
      StressCalculator.sleepQualityToStress(s.sleepQuality);

      // 3 — Upsert stress log (merge with camera/voice if already exists)
      await _repo.upsertStressLogFromCheckIn(
        uid:          uid,
        checkInScore: checkInScore,
        sleepScore:   sleepScore,
        date:         now,
      );

      state = state.copyWith(isSubmitting: false, isComplete: true);
      return true;
    } catch (e, st) {
      print('SUBMIT MORNING ERROR: $e');
      print(st);

      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );

      return false;
    }
  }

  // ── Submit evening ────────────────────────────────────────────────────────

  /// Saves the evening [CheckInModel] and upserts today's stress log.
  /// Sleep score is 0 for evening (no sleep data collected at night).
  Future<bool> submitEvening() async {
    final uid = _uid();
    if (uid == null) return false;

    state = state.copyWith(isSubmitting: true);
    try {
      final now = DateTime.now();
      final s   = state;

      final model = CheckInModel(
        id:            _uuid.v4(),
        userId:        uid,
        type:          'evening',
        date:          now,
        sleepQuality:  s.sleepQuality,
        anxietyLevel:  s.anxietyLevel,
        energyLevel:   s.energyLevel,
        mentalClarity: s.mentalClarity,
        overallMood:   s.overallMood,
        workStress:    s.workStress,
        gratitudeNote: s.gratitudeNote,
      );
      await _repo.saveCheckIn(model);

      final checkInScore = StressCalculator.checkInToStress(
        anxietyLevel:  s.anxietyLevel,
        workStress:    s.workStress,
        energyLevel:   s.energyLevel,
        mentalClarity: s.mentalClarity,
      );

      await _repo.upsertStressLogFromCheckIn(
        uid:          uid,
        checkInScore: checkInScore,
        sleepScore:   0, // evening has no sleep signal
        date:         now,
      );

      state = state.copyWith(isSubmitting: false, isComplete: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Could not save check-in. Please try again.',
      );
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller provider
// ─────────────────────────────────────────────────────────────────────────────

/// autoDispose ensures form state is wiped when the user leaves a check-in
/// screen so reopening always starts from step 0 with default values.
final checkinControllerProvider =
StateNotifierProvider.autoDispose<CheckInController, CheckInFormState>(
      (ref) => CheckInController(ref.watch(checkinRepositoryProvider)),
);