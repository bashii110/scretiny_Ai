import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain_model/stress_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// home_provider.dart
//
// All Riverpod providers scoped to the Home feature.
// Consumed by HomeScreen and its sub-widgets.
//
// Providers defined here:
//   • bottomNavIndexProvider   – tracks selected bottom-nav tab
//   • todayStressProvider      – today's StressLogModel (nullable)
//   • streakProvider           – consecutive check-in day count
//   • weeklyAverageProvider    – average stress score for last 7 days
//   • stressHistoryProvider    – last N StressLogModels (family of providers)
//   • dailyTipProvider         – rotating wellness tip string
// ─────────────────────────────────────────────────────────────────────────────

// ── Convenience helpers ───────────────────────────────────────────────────────

/// Returns the current Firebase Auth UID, or null when no user is signed in.
/// Guards against startup race conditions — HomeScreen should never reach
/// this state in practice.
String? _uid() => FirebaseAuth.instance.currentUser?.uid;

/// Root Firestore reference.
FirebaseFirestore get _db => FirebaseFirestore.instance;

// ─────────────────────────────────────────────────────────────────────────────
// 1.  Bottom Navigation Index
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the currently selected bottom-navigation tab index (0–4).
///
/// Read in any widget with:
/// ```dart
/// final index = ref.watch(bottomNavIndexProvider);
/// ```
/// Update from a tap handler:
/// ```dart
/// ref.read(bottomNavIndexProvider.notifier).state = 2;
/// ```
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ─────────────────────────────────────────────────────────────────────────────
// 2.  Today's Stress Log
// ─────────────────────────────────────────────────────────────────────────────

/// Streams the most-recent [StressLogModel] logged today for the signed-in
/// user, or `null` if none has been saved yet.
///
/// Listens to Firestore in real-time so the stress gauge on the home screen
/// updates immediately after a new scan is completed.
final todayStressProvider = StreamProvider<StressLogModel?>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value(null);

  // Start-of-day boundary in local time
  final startOfDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  return _db
      .collection('stress_logs')
      .where('userId', isEqualTo: uid)
      .where(
    'date',
    isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch,
  )
      .orderBy('date', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    return StressLogModel.fromMap(snap.docs.first.data());
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// 3.  Stress History  (family provider)
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the last [days] [StressLogModel]s for the signed-in user,
/// ordered newest-first.
///
/// This is a *family* provider so callers can request any window size:
/// ```dart
/// ref.watch(stressHistoryProvider(7));   // 7-day trend chart
/// ref.watch(stressHistoryProvider(30));  // monthly analytics
/// ```
final stressHistoryProvider =
StreamProvider.family<List<StressLogModel>, int>((ref, days) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);

  final cutoff = DateTime.now().subtract(Duration(days: days));

  return _db
      .collection('stress_logs')
      .where('userId', isEqualTo: uid)
      .where(
    'date',
    isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch,
  )
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snap) =>
        snap.docs.map((d) => StressLogModel.fromMap(d.data())).toList(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 4.  Weekly Average Stress Score
// ─────────────────────────────────────────────────────────────────────────────

/// Derives the mean [StressLogModel.finalStressScore] across the last 7 days
/// from [stressHistoryProvider].  Returns `0.0` when there are no logs.
///
/// Watches [stressHistoryProvider] so it recomputes automatically — no
/// separate Firestore query is needed.
final weeklyAverageProvider = Provider<AsyncValue<double>>((ref) {
  final historyAsync = ref.watch(stressHistoryProvider(7));

  return historyAsync.when(
    data: (logs) {
      if (logs.isEmpty) return const AsyncData(0.0);
      final sum =
      logs.fold<double>(0.0, (acc, log) => acc + log.finalStressScore);
      return AsyncData(sum / logs.length);
    },
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// 5.  Check-In Streak
// ─────────────────────────────────────────────────────────────────────────────

/// Counts consecutive calendar days on which the user has at least one
/// stress log, counting backwards from today.
///
/// Example: logs on Monday, Tuesday, Wednesday (today) → streak = 3.
/// A single missing day resets the count to zero.
final streakProvider = FutureProvider<int>((ref) async {
  final uid = _uid();
  if (uid == null) return 0;

  // Fetch up to 90 days — enough to cover any realistic streak
  final cutoff = DateTime.now().subtract(const Duration(days: 90));

  final snap = await _db
      .collection('stress_logs')
      .where('userId', isEqualTo: uid)
      .where(
    'date',
    isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch,
  )
      .orderBy('date', descending: true)
      .get();

  if (snap.docs.isEmpty) return 0;

  // Collect unique calendar dates that contain at least one log
  final loggedDates = snap.docs
      .map((doc) {
    final ms = doc.data()['date'] as int;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(dt.year, dt.month, dt.day); // date-only, no time
  })
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // newest first

  int streak = 0;
  DateTime cursor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  for (final date in loggedDates) {
    if (date == cursor) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    } else if (date.isBefore(cursor)) {
      // Gap found — streak is broken
      break;
    }
    // date == cursor already handled; dates after cursor are skipped
  }

  return streak;
});

// ─────────────────────────────────────────────────────────────────────────────
// 6.  Daily Wellness Tip
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a wellness tip string that rotates once per calendar day.
///
/// The tip is deterministic for the day (same across app restarts) and
/// requires no network call.  To add or translate tips, update [_wellnessTips]
/// — the UI layer does not need to change.
final dailyTipProvider = Provider<String>((ref) {
  final dayIndex = DateTime.now().difference(_kTipEpoch).inDays;
  return _wellnessTips[dayIndex % _wellnessTips.length];
});

/// Fixed reference point for the day-index calculation.
final _kTipEpoch = DateTime(2024, 1, 1);

/// Curated wellness tips.  Extend or localise this list as the app grows.
const List<String> _wellnessTips = [
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
];