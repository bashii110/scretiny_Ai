import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/mindfulness_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// mindfulness_provider.dart
//
// Riverpod providers for the Mindfulness tab (Phase 2).
//
// Providers:
//   • mindfulnessRepositoryProvider     – Firestore CRUD for sessions & logs
//   • breathingTechniqueProvider        – list of built-in breathing exercises
//   • meditationContentProvider         – StreamProvider of MindfulnessContentModels
//   • activeSessionProvider             – StateNotifier driving live session UI
//   • sessionHistoryProvider            – last N completed sessions
//   • totalMindfulnessMinutesProvider   – aggregate for profile / analytics
//   • todayMindfulnessProvider          – today's completed sessions
// ─────────────────────────────────────────────────────────────────────────────

// ── Helpers ───────────────────────────────────────────────────────────────────
String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Domain — BreathingTechnique (pure in-memory data, no Firestore needed)
// ─────────────────────────────────────────────────────────────────────────────

class BreathingTechnique {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int inhaleSeconds;
  final int holdInSeconds;
  final int exhaleSeconds;
  final int holdOutSeconds; // hold after exhale (box breathing)
  final int defaultCycles;
  final String benefit;
  final bool isPremium;
  final String faith; // 'all' | 'islam' | 'christian' | etc.

  const BreathingTechnique({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.inhaleSeconds,
    this.holdInSeconds = 0,
    required this.exhaleSeconds,
    this.holdOutSeconds = 0,
    this.defaultCycles = 5,
    required this.benefit,
    this.isPremium = false,
    this.faith = 'all',
  });

  /// Total duration of one cycle in seconds.
  int get cycleDuration =>
      inhaleSeconds + holdInSeconds + exhaleSeconds + holdOutSeconds;

  /// Total session duration in seconds for [defaultCycles] cycles.
  int get sessionDuration => cycleDuration * defaultCycles;
}

// ─── Built-in techniques ──────────────────────────────────────────────────────
const List<BreathingTechnique> _builtInTechniques = [
  BreathingTechnique(
    id: 'box_breathing',
    name: 'Box Breathing',
    description:
    'Equal inhale, hold, exhale, hold — used by Navy SEALs and athletes.',
    emoji: '⬜',
    inhaleSeconds: 4,
    holdInSeconds: 4,
    exhaleSeconds: 4,
    holdOutSeconds: 4,
    defaultCycles: 5,
    benefit: 'Reduces anxiety & sharpens focus',
  ),
  BreathingTechnique(
    id: '478_breathing',
    name: '4-7-8 Breathing',
    description:
    'Inhale for 4, hold for 7, exhale for 8. Calms the nervous system fast.',
    emoji: '🌊',
    inhaleSeconds: 4,
    holdInSeconds: 7,
    exhaleSeconds: 8,
    defaultCycles: 4,
    benefit: 'Promotes sleep & eases tension',
  ),
  BreathingTechnique(
    id: 'belly_breathing',
    name: 'Belly Breathing',
    description:
    'Deep diaphragmatic breathing that activates the parasympathetic nervous system.',
    emoji: '🌬️',
    inhaleSeconds: 5,
    exhaleSeconds: 5,
    defaultCycles: 6,
    benefit: 'Instant stress relief',
  ),
  BreathingTechnique(
    id: 'resonance_breathing',
    name: 'Resonance Breathing',
    description:
    '5-second inhale and 5-second exhale to reach heart rate variability resonance.',
    emoji: '💜',
    inhaleSeconds: 5,
    exhaleSeconds: 5,
    defaultCycles: 10,
    benefit: 'Maximises HRV & calm',
  ),
  BreathingTechnique(
    id: 'islamic_dhikr_breath',
    name: 'Dhikr Breathing',
    description:
    'Slow breath synchronised with dhikr rhythm. Inhale remembering Allah, exhale with peace.',
    emoji: '☪️',
    inhaleSeconds: 4,
    holdInSeconds: 2,
    exhaleSeconds: 6,
    defaultCycles: 7,
    benefit: 'Spiritual grounding & calm',
    faith: 'islam',
    isPremium: false,
  ),
  BreathingTechnique(
    id: 'christian_breath_prayer',
    name: 'Breath Prayer',
    description:
    'Inhale a word of trust, exhale a word of surrender. A contemplative Christian practice.',
    emoji: '✝️',
    inhaleSeconds: 4,
    exhaleSeconds: 6,
    defaultCycles: 6,
    benefit: 'Centring & peace',
    faith: 'christian',
  ),
  BreathingTechnique(
    id: 'pranayama_sama_vritti',
    name: 'Sama Vritti',
    description:
    'Equal breathing from the yoga tradition — balances prana and steadies the mind.',
    emoji: '🕉️',
    inhaleSeconds: 4,
    exhaleSeconds: 4,
    defaultCycles: 8,
    benefit: 'Balance & clarity',
    faith: 'hindu',
  ),
  BreathingTechnique(
    id: 'anapanasati',
    name: 'Anapanasati',
    description:
    'Mindfulness of breathing from the Pāli Canon — observe the natural breath without control.',
    emoji: '☸️',
    inhaleSeconds: 5,
    exhaleSeconds: 5,
    defaultCycles: 8,
    benefit: 'Present-moment awareness',
    faith: 'buddhism',
  ),
];

final breathingTechniqueProvider =
Provider<List<BreathingTechnique>>((ref) => _builtInTechniques);

// ─────────────────────────────────────────────────────────────────────────────
// Session Log Model (Firestore)
// ─────────────────────────────────────────────────────────────────────────────

class MindfulnessSessionLog {
  final String id;
  final String userId;
  final String sessionType; // 'breathing' | 'meditation'
  final String contentId;   // technique id or content id
  final String contentName;
  final int durationSeconds;
  final int completedCycles; // for breathing
  final DateTime completedAt;
  final double moodBefore; // 1–5 (optional, defaults to 3)
  final double moodAfter;  // 1–5 (optional, defaults to 3)

  const MindfulnessSessionLog({
    required this.id,
    required this.userId,
    required this.sessionType,
    required this.contentId,
    required this.contentName,
    required this.durationSeconds,
    this.completedCycles = 0,
    required this.completedAt,
    this.moodBefore = 3,
    this.moodAfter = 3,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'sessionType': sessionType,
    'contentId': contentId,
    'contentName': contentName,
    'durationSeconds': durationSeconds,
    'completedCycles': completedCycles,
    'completedAt': completedAt.millisecondsSinceEpoch,
    'moodBefore': moodBefore,
    'moodAfter': moodAfter,
  };

  factory MindfulnessSessionLog.fromMap(Map<String, dynamic> map) =>
      MindfulnessSessionLog(
        id: map['id'] as String,
        userId: map['userId'] as String,
        sessionType: map['sessionType'] as String,
        contentId: map['contentId'] as String,
        contentName: map['contentName'] as String,
        durationSeconds: (map['durationSeconds'] as num).toInt(),
        completedCycles: (map['completedCycles'] as num?)?.toInt() ?? 0,
        completedAt:
        DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int),
        moodBefore: (map['moodBefore'] as num?)?.toDouble() ?? 3,
        moodAfter: (map['moodAfter'] as num?)?.toDouble() ?? 3,
      );

  int get durationMinutes => (durationSeconds / 60).round();
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

class MindfulnessRepository {
  final _sessionsCol = _db.collection('mindfulness_sessions');
  final _contentCol = _db.collection('mindfulness_content');

  Future<void> saveSession(MindfulnessSessionLog log) async {
    await _sessionsCol.doc(log.id).set(log.toMap());
  }

  Stream<List<MindfulnessSessionLog>> sessionHistory(int days) {
    final uid = _uid();
    if (uid == null) return Stream.value([]);

    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _sessionsCol
        .where('userId', isEqualTo: uid)
        .where('completedAt',
        isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) =>
        s.docs.map((d) => MindfulnessSessionLog.fromMap(d.data())).toList());
  }

  Stream<List<MindfulnessSessionLog>> todaySessions() {
    final uid = _uid();
    if (uid == null) return Stream.value([]);

    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _sessionsCol
        .where('userId', isEqualTo: uid)
        .where('completedAt',
        isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((s) =>
        s.docs.map((d) => MindfulnessSessionLog.fromMap(d.data())).toList());
  }

  Stream<List<MindfulnessContentModel>> fetchContent({
    String? faith,
    String? type,
  }) {
    Query<Map<String, dynamic>> q = _contentCol;
    if (faith != null && faith != 'secular') {
      q = q.where('faith', whereIn: [faith, 'all']);
    }
    if (type != null) {
      q = q.where('type', isEqualTo: type);
    }
    return q.snapshots().map(
          (s) => s.docs
          .map((d) => MindfulnessContentModel.fromMap(d.data()))
          .toList(),
    );
  }
}

final mindfulnessRepositoryProvider =
Provider<MindfulnessRepository>((_) => MindfulnessRepository());

// ─────────────────────────────────────────────────────────────────────────────
// Session History
// ─────────────────────────────────────────────────────────────────────────────

final mindfulnessSessionHistoryProvider =
StreamProvider.family<List<MindfulnessSessionLog>, int>((ref, days) {
  return ref.watch(mindfulnessRepositoryProvider).sessionHistory(days);
});

final todayMindfulnessProvider =
StreamProvider<List<MindfulnessSessionLog>>((ref) {
  return ref.watch(mindfulnessRepositoryProvider).todaySessions();
});

final totalMindfulnessMinutesProvider = Provider<AsyncValue<int>>((ref) {
  final historyAsync = ref.watch(mindfulnessSessionHistoryProvider(30));
  return historyAsync.when(
    data: (logs) {
      final total = logs.fold<int>(0, (acc, l) => acc + l.durationSeconds);
      return AsyncData((total / 60).round());
    },
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Active Breathing Session State
// ─────────────────────────────────────────────────────────────────────────────

enum BreathPhase { idle, inhale, holdIn, exhale, holdOut, complete }

class ActiveBreathingState {
  final BreathingTechnique? technique;
  final BreathPhase phase;
  final int currentCycle;       // 1-based
  final int targetCycles;
  final int phaseSecondsLeft;   // countdown within current phase
  final bool isRunning;
  final bool isPaused;

  const ActiveBreathingState({
    this.technique,
    this.phase = BreathPhase.idle,
    this.currentCycle = 0,
    this.targetCycles = 5,
    this.phaseSecondsLeft = 0,
    this.isRunning = false,
    this.isPaused = false,
  });

  ActiveBreathingState copyWith({
    BreathingTechnique? technique,
    BreathPhase? phase,
    int? currentCycle,
    int? targetCycles,
    int? phaseSecondsLeft,
    bool? isRunning,
    bool? isPaused,
  }) =>
      ActiveBreathingState(
        technique: technique ?? this.technique,
        phase: phase ?? this.phase,
        currentCycle: currentCycle ?? this.currentCycle,
        targetCycles: targetCycles ?? this.targetCycles,
        phaseSecondsLeft: phaseSecondsLeft ?? this.phaseSecondsLeft,
        isRunning: isRunning ?? this.isRunning,
        isPaused: isPaused ?? this.isPaused,
      );

  double get cycleProgress {
    if (technique == null || technique!.cycleDuration == 0) return 0;
    final phaseStart = _phaseStartSecond;
    final elapsed = phaseStart + (technique!.cycleDuration - phaseSecondsLeft);
    return (elapsed / technique!.cycleDuration).clamp(0.0, 1.0);
  }

  int get _phaseStartSecond {
    if (technique == null) return 0;
    switch (phase) {
      case BreathPhase.inhale:
        return 0;
      case BreathPhase.holdIn:
        return technique!.inhaleSeconds;
      case BreathPhase.exhale:
        return technique!.inhaleSeconds + technique!.holdInSeconds;
      case BreathPhase.holdOut:
        return technique!.inhaleSeconds +
            technique!.holdInSeconds +
            technique!.exhaleSeconds;
      default:
        return 0;
    }
  }

  String get phaseLabel {
    switch (phase) {
      case BreathPhase.idle:
        return 'Ready';
      case BreathPhase.inhale:
        return 'Inhale';
      case BreathPhase.holdIn:
        return 'Hold';
      case BreathPhase.exhale:
        return 'Exhale';
      case BreathPhase.holdOut:
        return 'Hold';
      case BreathPhase.complete:
        return 'Complete';
    }
  }

  String get phaseEmoji {
    switch (phase) {
      case BreathPhase.inhale:
        return '🌬️';
      case BreathPhase.holdIn:
      case BreathPhase.holdOut:
        return '⏸';
      case BreathPhase.exhale:
        return '💨';
      case BreathPhase.complete:
        return '✅';
      default:
        return '🧘';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Breathing Controller
// ─────────────────────────────────────────────────────────────────────────────

class ActiveBreathingController
    extends StateNotifier<ActiveBreathingState> {
  final MindfulnessRepository _repo;
  Timer? _timer;
  DateTime? _sessionStart;

  ActiveBreathingController(this._repo)
      : super(const ActiveBreathingState());

  void selectTechnique(BreathingTechnique technique) {
    _timer?.cancel();
    state = ActiveBreathingState(
      technique: technique,
      targetCycles: technique.defaultCycles,
      phase: BreathPhase.idle,
    );
  }

  void setTargetCycles(int cycles) {
    state = state.copyWith(targetCycles: cycles);
  }

  void start() {
    if (state.technique == null) return;
    _sessionStart = DateTime.now();
    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      currentCycle: 1,
      phase: BreathPhase.inhale,
      phaseSecondsLeft: state.technique!.inhaleSeconds,
    );
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPaused: true, isRunning: false);
  }

  void resume() {
    state = state.copyWith(isPaused: false, isRunning: true);
    _startTimer();
  }

  void stop() {
    _timer?.cancel();
    _saveSession();
    state = const ActiveBreathingState();
  }

  void reset() {
    _timer?.cancel();
    final t = state.technique;
    state = ActiveBreathingState(
      technique: t,
      targetCycles: t?.defaultCycles ?? 5,
      phase: BreathPhase.idle,
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!state.isRunning || state.isPaused) return;
    final t = state.technique!;

    if (state.phaseSecondsLeft > 1) {
      state = state.copyWith(phaseSecondsLeft: state.phaseSecondsLeft - 1);
      return;
    }

    // Move to next phase
    switch (state.phase) {
      case BreathPhase.inhale:
        if (t.holdInSeconds > 0) {
          state = state.copyWith(
            phase: BreathPhase.holdIn,
            phaseSecondsLeft: t.holdInSeconds,
          );
        } else {
          state = state.copyWith(
            phase: BreathPhase.exhale,
            phaseSecondsLeft: t.exhaleSeconds,
          );
        }
        break;

      case BreathPhase.holdIn:
        state = state.copyWith(
          phase: BreathPhase.exhale,
          phaseSecondsLeft: t.exhaleSeconds,
        );
        break;

      case BreathPhase.exhale:
        if (t.holdOutSeconds > 0) {
          state = state.copyWith(
            phase: BreathPhase.holdOut,
            phaseSecondsLeft: t.holdOutSeconds,
          );
        } else {
          _endCycle();
        }
        break;

      case BreathPhase.holdOut:
        _endCycle();
        break;

      default:
        break;
    }
  }

  void _endCycle() {
    final t = state.technique!;
    if (state.currentCycle >= state.targetCycles) {
      _timer?.cancel();
      _saveSession();
      state = state.copyWith(
        phase: BreathPhase.complete,
        isRunning: false,
        phaseSecondsLeft: 0,
      );
    } else {
      state = state.copyWith(
        currentCycle: state.currentCycle + 1,
        phase: BreathPhase.inhale,
        phaseSecondsLeft: t.inhaleSeconds,
      );
    }
  }

  Future<void> _saveSession() async {
    final uid = _uid();
    if (uid == null || state.technique == null) return;
    final start = _sessionStart ?? DateTime.now();
    final durationSecs = DateTime.now().difference(start).inSeconds;

    final log = MindfulnessSessionLog(
      id: _uuid.v4(),
      userId: uid,
      sessionType: 'breathing',
      contentId: state.technique!.id,
      contentName: state.technique!.name,
      durationSeconds: durationSecs.clamp(1, 3600),
      completedCycles: state.currentCycle,
      completedAt: DateTime.now(),
    );

    try {
      await _repo.saveSession(log);
    } catch (_) {
      // Silent fail — session data is non-critical
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final activeBreathingProvider = StateNotifierProvider.autoDispose<
    ActiveBreathingController, ActiveBreathingState>(
      (ref) => ActiveBreathingController(ref.watch(mindfulnessRepositoryProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────
// Meditation Content Provider
// ─────────────────────────────────────────────────────────────────────────────

final meditationContentProvider =
StreamProvider<List<MindfulnessContentModel>>((ref) {
  return ref
      .watch(mindfulnessRepositoryProvider)
      .fetchContent(type: 'meditation');
});

// ─────────────────────────────────────────────────────────────────────────────
// Selected Mindfulness Tab
// ─────────────────────────────────────────────────────────────────────────────

/// 0 = Breathing  1 = Meditation  2 = Prayer  3 = Journal
final mindfulnessTabProvider = StateProvider<int>((_) => 0);