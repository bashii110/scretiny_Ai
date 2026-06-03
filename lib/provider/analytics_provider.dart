import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../auth_repo.dart';
import '../domain_model/checkin_model.dart';
import '../domain_model/family_model.dart';
import '../domain_model/auth_model.dart';
import '../domain_model/stress_model.dart';
import '../provider/auth_provider.dart';
import '../provider/stress_provider.dart';
export '../provider/stress_provider.dart' show DailyStressPoint;

// ─── Helpers ──────────────────────────────────────────────────────────────────
String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ═════════════════════════════════════════════════════════════════════════════
// ANALYTICS
// ═════════════════════════════════════════════════════════════════════════════

class StressAnalyticsReport {
  final List<StressLogModel> logs;
  final List<DailyStressPoint> dailyPoints;
  final Map<int, double> weekdayAverages;
  final double avgScore;
  final String bestDay;
  final String worstDay;
  final int totalCheckins;

  const StressAnalyticsReport({
    required this.logs,
    required this.dailyPoints,
    required this.weekdayAverages,
    required this.avgScore,
    required this.bestDay,
    required this.worstDay,
    required this.totalCheckins,
  });

  static StressAnalyticsReport empty() => const StressAnalyticsReport(
    logs: [],
    dailyPoints: [],
    weekdayAverages: {},
    avgScore: 0,
    bestDay: '—',
    worstDay: '—',
    totalCheckins: 0,
  );
}

class SleepEntry {
  final DateTime date;
  final int value; // 1–5
  const SleepEntry({required this.date, required this.value});
}

// ─── Range toggle ─────────────────────────────────────────────────────────────
final analyticsRangeProvider = StateProvider<String>((_) => 'week');

// ─── Main analytics report ────────────────────────────────────────────────────
final stressAnalyticsProvider = StreamProvider<StressAnalyticsReport>((ref) {
  final range = ref.watch(analyticsRangeProvider);
  final days = range == 'week' ? 7 : 30;
  final uid = _uid();
  if (uid == null) return Stream.value(StressAnalyticsReport.empty());

  return ref
      .watch(stressRepositoryProvider)
      .history(uid, days)
      .map((logs) => _buildReport(logs));
});

StressAnalyticsReport _buildReport(List<StressLogModel> logs) {
  if (logs.isEmpty) return StressAnalyticsReport.empty();

  final byDay = <String, StressLogModel>{};
  for (final l in logs) {
    final key = '${l.date.year}-${l.date.month}-${l.date.day}';
    byDay.putIfAbsent(key, () => l);
  }

  final dailyLogs = byDay.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final dailyPoints = dailyLogs
      .map((l) => DailyStressPoint(
    date: l.date,
    score: l.finalStressScore,
    level: l.stressLevel,
  ))
      .toList();

  final weekdaySums = <int, double>{};
  final weekdayCounts = <int, int>{};
  for (final l in logs) {
    final wd = l.date.weekday;
    weekdaySums[wd] = (weekdaySums[wd] ?? 0) + l.finalStressScore;
    weekdayCounts[wd] = (weekdayCounts[wd] ?? 0) + 1;
  }
  final weekdayAverages = {
    for (final wd in weekdaySums.keys)
      wd: weekdaySums[wd]! / weekdayCounts[wd]!,
  };

  final avg = logs.map((l) => l.finalStressScore).reduce((a, b) => a + b) /
      logs.length;

  final best =
  logs.reduce((a, b) => a.finalStressScore < b.finalStressScore ? a : b);
  final worst =
  logs.reduce((a, b) => a.finalStressScore > b.finalStressScore ? a : b);

  return StressAnalyticsReport(
    logs: logs,
    dailyPoints: dailyPoints,
    weekdayAverages: weekdayAverages,
    avgScore: avg,
    bestDay: _shortDate(best.date),
    worstDay: _shortDate(worst.date),
    totalCheckins: logs.length,
  );
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

// ─── Mood calendar provider ───────────────────────────────────────────────────
// Reads from root 'checkins' collection (matches Firestore screenshot)
final moodCalendarProvider = StreamProvider<Map<int, int>>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value({});

  final now = DateTime.now();
  final startMonth = DateTime(now.year, now.month, 1);
  final endMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  return _db
      .collection('checkins')
      .where('userId', isEqualTo: uid)
      .where('date',
      isGreaterThanOrEqualTo: startMonth.millisecondsSinceEpoch)
      .where('date', isLessThanOrEqualTo: endMonth.millisecondsSinceEpoch)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) {
    final map = <int, int>{};
    for (final doc in snap.docs) {
      final c = CheckInModel.fromMap(doc.data());
      map.putIfAbsent(c.date.day, () => c.overallMood);
    }
    return map;
  });
});

// ─── Sleep quality history ────────────────────────────────────────────────────
// Reads from root 'checkins' collection
final sleepQualityHistoryProvider = StreamProvider<List<SleepEntry>>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);

  final cutoff = DateTime.now().subtract(const Duration(days: 14));

  return _db
      .collection('checkins')
      .where('userId', isEqualTo: uid)
      .where('type', isEqualTo: 'morning')
      .where('date', isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch)
      .orderBy('date', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
    final c = CheckInModel.fromMap(d.data());
    return SleepEntry(date: c.date, value: c.sleepQuality);
  }).toList());
});

// ─── topTriggersProvider ──────────────────────────────────────────────────────
// Returns List<MapEntry<String, int>> — used by analytics_screen.dart
final topTriggersProvider =
StreamProvider<List<MapEntry<String, int>>>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);

  final cutoff = DateTime.now().subtract(const Duration(days: 30));

  return _db
      .collection('stress_logs')
      .where('userId', isEqualTo: uid)
      .where('date', isGreaterThanOrEqualTo: cutoff.millisecondsSinceEpoch)
      .snapshots()
      .map((snap) {
    final freq = <String, int>{};
    for (final doc in snap.docs) {
      final triggers = List<String>.from(doc.data()['triggers'] ?? []);
      for (final t in triggers) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    return (freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .toList();
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// FAMILY
// ═════════════════════════════════════════════════════════════════════════════

class FamilyRepository {
  final _col = _db.collection('family_members');

  Stream<List<FamilyModel>> members(String uid) {
    return _col
        .where('ownerId', isEqualTo: uid)
        .orderBy('memberName')
        .snapshots()
        .map((s) =>
        s.docs.map((d) => FamilyModel.fromMap(d.data())).toList());
  }

  Future<void> invite({
    required String ownerId,
    required String name,
    required String email,
    required String relationship,
  }) async {
    final id = _uuid.v4();
    final doc = FamilyModel(
      id: id,
      ownerId: ownerId,
      memberId: '',
      memberName: name.trim(),
      memberEmail: email.trim().toLowerCase(),
      relationship: relationship,
    );
    await _col.doc(id).set(doc.toMap());
  }

  Future<void> updatePrefs(FamilyModel member) =>
      _col.doc(member.id).update(member.toMap());

  Future<void> remove(String memberId) => _col.doc(memberId).delete();
}

final familyRepositoryProvider =
Provider<FamilyRepository>((_) => FamilyRepository());

final familyMembersProvider = StreamProvider<List<FamilyModel>>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);
  return ref.watch(familyRepositoryProvider).members(uid);
});

class FamilyControllerState {
  final bool isLoading;
  final String? error;
  final String? success;

  const FamilyControllerState({
    this.isLoading = false,
    this.error,
    this.success,
  });

  FamilyControllerState copyWith({
    bool? isLoading,
    String? error,
    String? success,
  }) =>
      FamilyControllerState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        success: success,
      );
}

class FamilyController extends StateNotifier<FamilyControllerState> {
  final FamilyRepository _repo;
  FamilyController(this._repo) : super(const FamilyControllerState());

  Future<bool> inviteMember({
    required String name,
    required String email,
    required String relationship,
  }) async {
    final uid = _uid();
    if (uid == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      await _repo.invite(
        ownerId: uid,
        name: name,
        email: email,
        relationship: relationship,
      );
      state = state.copyWith(
          isLoading: false, success: 'Invitation sent to $email');
      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: 'Could not send invitation. Please try again.');
      return false;
    }
  }

  Future<void> updatePrefs(FamilyModel member) async {
    try {
      await _repo.updatePrefs(member);
    } catch (_) {
      state = state.copyWith(error: 'Could not update preferences.');
    }
  }

  Future<void> removeMember(String memberId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.remove(memberId);
      state = state.copyWith(isLoading: false, success: 'Member removed.');
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Could not remove member.');
    }
  }

  void clearMessages() => state = state.copyWith(error: null, success: null);
}

final familyControllerProvider =
StateNotifierProvider<FamilyController, FamilyControllerState>(
      (ref) => FamilyController(ref.watch(familyRepositoryProvider)),
);

// ═════════════════════════════════════════════════════════════════════════════
// PROFILE
// ═════════════════════════════════════════════════════════════════════════════

class NotificationSettings {
  final bool morningReminder;
  final int morningHour;
  final bool eveningReminder;
  final int eveningHour;
  final bool highStressAlert;
  final bool weeklyReport;

  const NotificationSettings({
    this.morningReminder = true,
    this.morningHour = 8,
    this.eveningReminder = true,
    this.eveningHour = 21,
    this.highStressAlert = true,
    this.weeklyReport = true,
  });

  NotificationSettings copyWith({
    bool? morningReminder,
    int? morningHour,
    bool? eveningReminder,
    int? eveningHour,
    bool? highStressAlert,
    bool? weeklyReport,
  }) =>
      NotificationSettings(
        morningReminder: morningReminder ?? this.morningReminder,
        morningHour: morningHour ?? this.morningHour,
        eveningReminder: eveningReminder ?? this.eveningReminder,
        eveningHour: eveningHour ?? this.eveningHour,
        highStressAlert: highStressAlert ?? this.highStressAlert,
        weeklyReport: weeklyReport ?? this.weeklyReport,
      );
}

class NotifSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotifSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  static const _kMorning = 'notif_morning';
  static const _kMorningHour = 'notif_morning_hour';
  static const _kEvening = 'notif_evening';
  static const _kEveningHour = 'notif_evening_hour';
  static const _kHighStress = 'notif_high_stress';
  static const _kWeekly = 'notif_weekly';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      morningReminder: prefs.getBool(_kMorning) ?? true,
      morningHour: prefs.getInt(_kMorningHour) ?? 8,
      eveningReminder: prefs.getBool(_kEvening) ?? true,
      eveningHour: prefs.getInt(_kEveningHour) ?? 21,
      highStressAlert: prefs.getBool(_kHighStress) ?? true,
      weeklyReport: prefs.getBool(_kWeekly) ?? true,
    );
  }

  Future<void> toggle(String key) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'morning':
        final v = !state.morningReminder;
        state = state.copyWith(morningReminder: v);
        await prefs.setBool(_kMorning, v);
        break;
      case 'evening':
        final v = !state.eveningReminder;
        state = state.copyWith(eveningReminder: v);
        await prefs.setBool(_kEvening, v);
        break;
      case 'highStress':
        final v = !state.highStressAlert;
        state = state.copyWith(highStressAlert: v);
        await prefs.setBool(_kHighStress, v);
        break;
      case 'weekly':
        final v = !state.weeklyReport;
        state = state.copyWith(weeklyReport: v);
        await prefs.setBool(_kWeekly, v);
        break;
    }
  }
}

final notificationSettingsProvider =
StateNotifierProvider<NotifSettingsNotifier, NotificationSettings>(
      (_) => NotifSettingsNotifier(),
);

class ProfileEditState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const ProfileEditState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  ProfileEditState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) =>
      ProfileEditState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isSuccess: isSuccess ?? this.isSuccess,
      );
}

class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  final AuthRepository _authRepo;
  ProfileEditNotifier(this._authRepo) : super(const ProfileEditState());

  Future<bool> updateProfile({
    required UserModel current,
    required String name,
    required String faithPreference,
    required String language,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = current.copyWith(
        name: name.trim(),
        faithPreference: faithPreference,
        language: language,
      );
      await _authRepo.updateUserProfile(updated);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not update profile. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    state = const ProfileEditState();
  }

  void clear() => state = const ProfileEditState();
}

final profileEditProvider =
StateNotifierProvider<ProfileEditNotifier, ProfileEditState>(
      (ref) => ProfileEditNotifier(ref.watch(authRepositoryProvider)),
);

// ─── Tier label extension ─────────────────────────────────────────────────────
extension TierX on String {
  String get tierLabel {
    switch (this) {
      case 'premium':
        return 'Premium';
      case 'basic':
        return 'Basic';
      default:
        return 'Free';
    }
  }

  String get tierDescription {
    switch (this) {
      case 'premium':
        return 'All features unlocked · Priority support';
      case 'basic':
        return 'Extended history · Family mode enabled';
      default:
        return '7-day history · Basic stress tracking';
    }
  }
}