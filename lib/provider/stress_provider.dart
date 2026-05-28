import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/stress_model.dart';
import '../stress_calculator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// stress_provider.dart
//
// Central data layer for all stress-log reads, writes, and derived analytics.
//
// Responsibility boundary:
//   This file owns the 'stress_logs' Firestore collection.
//   Camera, voice, and check-in providers each write their slice here;
//   this file owns all reads so the rest of the app has a single source of
//   truth for stress data.
//
// Public surface:
//   Repository
//     stressRepositoryProvider        – StressRepository singleton
//
//   Real-time streams
//     todayStressProvider             – StreamProvider<StressLogModel?>
//     stressHistoryProvider(days)     – StreamProvider.family<List<StressLogModel>, int>
//
//   Derived / computed providers
//     weeklyAverageProvider           – Provider<AsyncValue<double>>
//     weeklyTrendProvider             – Provider<AsyncValue<List<DailyStressPoint>>>
//     streakProvider                  – FutureProvider<int>
//     bestDayProvider                 – Provider<AsyncValue<StressLogModel?>>
//     worstDayProvider                – Provider<AsyncValue<StressLogModel?>>
//     topTriggersProvider(days)       – Provider.family<AsyncValue<List<TriggerCount>>, int>
//     scoreBreakdownProvider          – Provider<AsyncValue<ScoreBreakdown>>
//     dailyTipProvider                – Provider<String>
//     stressInsightProvider           – Provider<AsyncValue<String>>
//
//   Write helpers
//     stressLogWriterProvider         – StressLogWriter (used by camera/voice/checkin)
// ─────────────────────────────────────────────────────────────────────────────

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

DateTime get _startOfToday {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _startOf(DateTime d) => DateTime(d.year, d.month, d.day);

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

/// One point on the weekly trend chart.
class DailyStressPoint {
  final DateTime date;
  final double score;
  final String level;

  const DailyStressPoint({
    required this.date,
    required this.score,
    required this.level,
  });
}

/// Trigger label with frequency count for the top-triggers chart.
class TriggerCount {
  final String trigger;
  final int count;
  const TriggerCount(this.trigger, this.count);
}

/// Breakdown of the five weighted components for the score-breakdown row.
class ScoreBreakdown {
  final double cameraHRV;
  final double voice;
  final double phoneUsage;
  final double checkIn;
  final double sleep;
  final double finalScore;

  const ScoreBreakdown({
    required this.cameraHRV,
    required this.voice,
    required this.phoneUsage,
    required this.checkIn,
    required this.sleep,
    required this.finalScore,
  });

  bool get hasCamera    => cameraHRV  > 0;
  bool get hasVoice     => voice      > 0;
  bool get hasPhone     => phoneUsage > 0;
  bool get hasCheckIn   => checkIn    > 0;
  bool get isFull       => hasCamera && hasVoice && hasCheckIn;
}

// ─────────────────────────────────────────────────────────────────────────────
// StressRepository
// ─────────────────────────────────────────────────────────────────────────────

/// All Firestore reads and writes for 'stress_logs'.
///
/// Other providers (camera, voice, check-in) call methods here to merge their
/// contribution into today's document rather than writing independently.
class StressRepository {
  final _col = _db.collection('stress_logs');

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Real-time stream of today's most-recent stress log.
  Stream<StressLogModel?> today(String uid) {
    return _col
        .where('userId', isEqualTo: uid)
        .where('date',
        isGreaterThanOrEqualTo: _startOfToday.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
        ? null
        : StressLogModel.fromMap(s.docs.first.data()));
  }

  /// Real-time stream of stress logs for the last [days] days.
  Stream<List<StressLogModel>> history(String uid, int days) {
    final cutoff =
    DateTime.now().subtract(Duration(days: days));
    return _col
        .where('userId', isEqualTo: uid)
        .where('date',
        isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) => StressLogModel.fromMap(d.data()))
        .toList());
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Creates a new stress log document.
  Future<void> create(StressLogModel log) =>
      _col.doc(log.id).set(log.toMap());

  /// Merges a partial update (only the provided fields) into an existing log.
  Future<void> merge(String docId, Map<String, dynamic> fields) =>
      _col.doc(docId).update(fields);

  /// Fetch-or-create today's log, then apply [updater] and save.
  ///
  /// This is the canonical merge helper used by camera, voice, and check-in
  /// providers to ensure every contribution lands in the same document.
  Future<void> upsert({
    required String uid,
    required Map<String, dynamic> Function(StressLogModel? existing) updater,
  }) async {
    final snap = await _col
        .where('userId', isEqualTo: uid)
        .where('date',
        isGreaterThanOrEqualTo: _startOfToday.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final existing =
      StressLogModel.fromMap(snap.docs.first.data());
      final fields = updater(existing);
      await _col.doc(existing.id).update(fields);
    } else {
      final fields = updater(null);
      // Ensure required fields exist when creating from scratch
      final id = fields['id'] as String? ?? _uuid.v4();
      await _col.doc(id).set({
        'id':     id,
        'userId': uid,
        'date':   DateTime.now().millisecondsSinceEpoch,
        ...fields,
      });
    }
  }

  // ── One-shot reads (for stats) ────────────────────────────────────────────

  Future<List<StressLogModel>> fetchHistory(
      String uid, int days) async {
    final cutoff =
    DateTime.now().subtract(Duration(days: days));
    final snap = await _col
        .where('userId', isEqualTo: uid)
        .where('date',
        isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch)
        .orderBy('date', descending: true)
        .get();
    return snap.docs
        .map((d) => StressLogModel.fromMap(d.data()))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StressLogWriter
// ─────────────────────────────────────────────────────────────────────────────

/// Convenience class consumed by camera_scan_provider and
/// voice_checkin_provider to merge their score into today's log without
/// duplicating the upsert logic.
class StressLogWriter {
  final StressRepository _repo;
  StressLogWriter(this._repo);

  Future<void> mergeCameraHRV(String uid, double score) =>
      _repo.upsert(
        uid: uid,
        updater: (existing) {
          final newFinal = StressCalculator.calculateFinalStressScore(
            cameraHRV:    score,
            voiceScore:   existing?.voiceScore      ?? 0,
            phoneUsage:   existing?.phoneUsageScore ?? 0,
            sleepScore:   0,
            checkInScore: existing?.checkInScore    ?? 0,
          );
          return {
            'cameraHRVScore':   score,
            'finalStressScore': newFinal,
            'stressLevel':
            StressCalculator.getStressLevel(newFinal),
          };
        },
      );

  Future<void> mergeVoiceScore(String uid, double score) =>
      _repo.upsert(
        uid: uid,
        updater: (existing) {
          final newFinal = StressCalculator.calculateFinalStressScore(
            cameraHRV:    existing?.cameraHRVScore  ?? 0,
            voiceScore:   score,
            phoneUsage:   existing?.phoneUsageScore ?? 0,
            sleepScore:   0,
            checkInScore: existing?.checkInScore    ?? 0,
          );
          return {
            'voiceScore':       score,
            'finalStressScore': newFinal,
            'stressLevel':
            StressCalculator.getStressLevel(newFinal),
          };
        },
      );

  Future<void> mergePhoneUsage(String uid, int usageMinutes) =>
      _repo.upsert(
        uid: uid,
        updater: (existing) {
          final phoneScore =
          StressCalculator.phoneUsageToStress(usageMinutes);
          final newFinal = StressCalculator.calculateFinalStressScore(
            cameraHRV:    existing?.cameraHRVScore  ?? 0,
            voiceScore:   existing?.voiceScore      ?? 0,
            phoneUsage:   phoneScore,
            sleepScore:   0,
            checkInScore: existing?.checkInScore    ?? 0,
          );
          return {
            'phoneUsageScore':  phoneScore,
            'finalStressScore': newFinal,
            'stressLevel':
            StressCalculator.getStressLevel(newFinal),
          };
        },
      );

  Future<void> addTriggers(
      String uid, List<String> triggers) =>
      _repo.upsert(
        uid: uid,
        updater: (existing) {
          final merged = {
            ...?existing?.triggers,
            ...triggers,
          }.toList();
          return {'triggers': merged};
        },
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers — repository & writer
// ─────────────────────────────────────────────────────────────────────────────

final stressRepositoryProvider = Provider<StressRepository>(
      (_) => StressRepository(),
);

final stressLogWriterProvider = Provider<StressLogWriter>(
      (ref) => StressLogWriter(ref.watch(stressRepositoryProvider)),
);

// ─────────────────────────────────────────────────────────────────────────────
// Providers — real-time streams
// ─────────────────────────────────────────────────────────────────────────────

/// Today's stress log, or null if no data yet.
final todayStressProvider = StreamProvider<StressLogModel?>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value(null);
  return ref.watch(stressRepositoryProvider).today(uid);
});

/// Last [days] stress logs, newest first.
///
/// Usage:
/// ```dart
/// ref.watch(stressHistoryProvider(7));   // 7-day chart
/// ref.watch(stressHistoryProvider(30));  // monthly report
/// ```
final stressHistoryProvider =
StreamProvider.family<List<StressLogModel>, int>((ref, days) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);
  return ref.watch(stressRepositoryProvider).history(uid, days);
});

// ─────────────────────────────────────────────────────────────────────────────
// Providers — derived / computed
// ─────────────────────────────────────────────────────────────────────────────

/// Mean stress score over the last 7 days. Returns 0.0 if no data.
final weeklyAverageProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(stressHistoryProvider(7)).when(
    data: (logs) {
      if (logs.isEmpty) return const AsyncData(0.0);
      final sum = logs.fold<double>(
          0, (acc, l) => acc + l.finalStressScore);
      return AsyncData(sum / logs.length);
    },
    loading: () => const AsyncLoading(),
    error:   AsyncError.new,
  );
});

/// 7-day trend as a list of [DailyStressPoint] (one per calendar day,
/// newest last). Days with no data are omitted — the chart handles gaps.
final weeklyTrendProvider =
Provider<AsyncValue<List<DailyStressPoint>>>((ref) {
  return ref.watch(stressHistoryProvider(7)).when(
    data: (logs) {
      // Keep only the last log per calendar day
      final byDay = <String, StressLogModel>{};
      for (final log in logs) {
        final key = _startOf(log.date).toIso8601String();
        byDay.putIfAbsent(key, () => log);
      }
      final points = byDay.values
          .map((l) => DailyStressPoint(
        date:  l.date,
        score: l.finalStressScore,
        level: l.stressLevel,
      ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return AsyncData(points);
    },
    loading: () => const AsyncLoading(),
    error:   AsyncError.new,
  );
});

/// Consecutive days with at least one stress log, counting back from today.
final streakProvider = FutureProvider<int>((ref) async {
  final uid = _uid();
  if (uid == null) return 0;

  final logs = await ref
      .watch(stressRepositoryProvider)
      .fetchHistory(uid, 90);

  if (logs.isEmpty) return 0;

  final loggedDates = logs
      .map((l) => _startOf(l.date))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  int streak  = 0;
  DateTime cursor = _startOfToday;

  for (final date in loggedDates) {
    if (date == cursor) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    } else if (date.isBefore(cursor)) {
      break;
    }
  }
  return streak;
});

/// Log with the lowest stress score in the last [days] days.
final bestDayProvider = Provider.family<AsyncValue<StressLogModel?>, int>(
        (ref, days) {
      return ref.watch(stressHistoryProvider(days)).when(
        data: (logs) {
          if (logs.isEmpty) return const AsyncData(null);
          final best = logs.reduce((a, b) =>
          a.finalStressScore < b.finalStressScore ? a : b);
          return AsyncData(best);
        },
        loading: () => const AsyncLoading(),
        error:   AsyncError.new,
      );
    });

/// Log with the highest stress score in the last [days] days.
final worstDayProvider = Provider.family<AsyncValue<StressLogModel?>, int>(
        (ref, days) {
      return ref.watch(stressHistoryProvider(days)).when(
        data: (logs) {
          if (logs.isEmpty) return const AsyncData(null);
          final worst = logs.reduce((a, b) =>
          a.finalStressScore > b.finalStressScore ? a : b);
          return AsyncData(worst);
        },
        loading: () => const AsyncLoading(),
        error:   AsyncError.new,
      );
    });

/// Top stress triggers by frequency over the last [days] days.
/// Returns a sorted list of [TriggerCount], most frequent first.
///
/// Usage:
/// ```dart
/// ref.watch(topTriggersProvider(30));
/// ```
final topTriggersProvider =
Provider.family<AsyncValue<List<TriggerCount>>, int>((ref, days) {
  return ref.watch(stressHistoryProvider(days)).when(
    data: (logs) {
      final freq = <String, int>{};
      for (final log in logs) {
        for (final t in log.triggers) {
          freq[t] = (freq[t] ?? 0) + 1;
        }
      }
      final sorted = freq.entries
          .map((e) => TriggerCount(e.key, e.value))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      return AsyncData(sorted.take(10).toList());
    },
    loading: () => const AsyncLoading(),
    error:   AsyncError.new,
  );
});

/// Breakdown of today's score into its five weighted components.
/// Consumed by the score-breakdown row on the home screen and result screens.
final scoreBreakdownProvider =
Provider<AsyncValue<ScoreBreakdown>>((ref) {
  return ref.watch(todayStressProvider).when(
    data: (log) {
      if (log == null) {
        return const AsyncData(ScoreBreakdown(
          cameraHRV:  0,
          voice:      0,
          phoneUsage: 0,
          checkIn:    0,
          sleep:      0,
          finalScore: 0,
        ));
      }
      return AsyncData(ScoreBreakdown(
        cameraHRV:  log.cameraHRVScore,
        voice:      log.voiceScore,
        phoneUsage: log.phoneUsageScore,
        checkIn:    log.checkInScore,
        sleep:      0,            // sleep score not stored directly
        finalScore: log.finalStressScore,
      ));
    },
    loading: () => const AsyncLoading(),
    error:   AsyncError.new,
  );
});

/// A natural-language insight derived from today's stress pattern.
/// Used on the home screen "Daily Tip" and result cards.
final stressInsightProvider =
Provider<AsyncValue<String>>((ref) {
  return ref.watch(todayStressProvider).when(
    data: (log) {
      if (log == null) {
        return const AsyncData(
            'Complete a check-in or scan to see your personalised insight.');
      }
      return AsyncData(_buildInsight(log));
    },
    loading: () => const AsyncLoading(),
    error:   AsyncError.new,
  );
});

String _buildInsight(StressLogModel log) {
  final s = log.finalStressScore;

  // Component with highest contribution
  final scores = {
    'HRV':      log.cameraHRVScore,
    'voice':    log.voiceScore,
    'phone':    log.phoneUsageScore,
    'check-in': log.checkInScore,
  }..removeWhere((_, v) => v == 0);

  String? dominant;
  if (scores.isNotEmpty) {
    dominant = scores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  if (s <= 25) {
    return 'Your stress is low today — great balance across all signals. '
        'Keep your routine going.';
  } else if (s <= 50) {
    if (dominant == 'phone') {
      return 'Moderate stress. Your screen time is the biggest contributor '
          'today — try a 20-minute phone-free break.';
    }
    return 'Moderate stress detected. A 5-minute breathing exercise '
        'can bring your HRV up significantly.';
  } else if (s <= 75) {
    if (dominant == 'voice') {
      return 'High stress — your voice patterns show tension. '
          'Slow your breathing and try humming for 2 minutes.';
    }
    if (dominant == 'HRV') {
      return 'High stress — HRV is low, suggesting physical tension. '
          'A short walk or light stretching will help.';
    }
    return 'High stress. Consider a guided meditation or reaching '
        'out to someone you trust.';
  } else {
    return 'Critical stress levels. Please prioritise rest and consider '
        'speaking with a therapist or trusted person today.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily tip provider (deterministic, no network)
// ─────────────────────────────────────────────────────────────────────────────

final dailyTipProvider = Provider<String>((ref) {
  final day = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
  return _tips[day % _tips.length];
});

const _tips = [
  'Take 5 deep breaths before responding to stressful messages.',
  'A short walk outside can lower cortisol levels significantly.',
  'Staying hydrated improves focus and reduces anxiety.',
  'Gratitude journaling for just 2 minutes can shift your mindset.',
  'Screen breaks every 45 minutes protect your mental energy.',
  'Sleep before midnight improves emotional regulation.',
  'Reaching out to a friend reduces the stress hormone cortisol.',
  'Progressive muscle relaxation can be done right at your desk.',
  'A consistent morning routine reduces decision fatigue.',
  'Nature sounds for 10 minutes can calm an overactive mind.',
  'Laughing genuinely boosts endorphins — find something funny today.',
  'Setting one clear priority for the day reduces overwhelm.',
  'Limit news consumption to one 10-minute check-in per day.',
  'Cold water on your wrists can quickly ease acute anxiety.',
  'Eating mindfully — away from screens — improves both digestion and mood.',
  'Five minutes of stretching in the morning reduces muscle-held tension.',
  'Writing down tomorrow\'s tasks tonight clears mental load before sleep.',
  'Spending time with a pet measurably lowers blood pressure.',
  'Singing, even quietly, activates the vagus nerve and calms the body.',
  'Box breathing (4-4-4-4) takes under 2 minutes and resets your baseline.',
];