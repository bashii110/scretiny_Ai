// lib/provider/checkin_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain_model/checkin_model.dart';
import '../domain_model/stress_model.dart';
import '../repository/checkin_repo.dart';
import 'auth_provider.dart';

// ─── Repository Provider ──────────────────────────────────────────────────────
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository();
});

// ─── Check-In State ───────────────────────────────────────────────────────────
class CheckInState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final CheckInModel? saved;

  const CheckInState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.saved,
  });

  CheckInState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    CheckInModel? saved,
  }) =>
      CheckInState(
        isLoading: isLoading ?? this.isLoading,
        isSuccess: isSuccess ?? this.isSuccess,
        error: error,
        saved: saved ?? this.saved,
      );
}

// ─── Check-In Controller ──────────────────────────────────────────────────────
class CheckInController extends StateNotifier<CheckInState> {
  final CheckInRepository _repo;

  CheckInController(this._repo) : super(const CheckInState());

  Future<bool> saveCheckIn(CheckInModel checkIn) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final saved = await _repo.saveCheckIn(checkIn);
      state = CheckInState(isSuccess: true, saved: saved);
      return true;
    } catch (e) {
      state = CheckInState(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() {
    state = CheckInState(
      isLoading: state.isLoading,
      isSuccess: state.isSuccess,
      saved: state.saved,
    );
  }

  void reset() => state = const CheckInState();
}

final checkInControllerProvider =
StateNotifierProvider<CheckInController, CheckInState>((ref) {
  return CheckInController(ref.watch(checkInRepositoryProvider));
});

// ─── Today's check-in stream ──────────────────────────────────────────────────
final todayCheckInsProvider = StreamProvider<List<CheckInModel>>((ref) {
  // Re-initialize when auth changes
  ref.watch(authStateProvider);
  return ref.watch(checkInRepositoryProvider).streamTodayCheckIns();
});

// ─── Today's stress log ───────────────────────────────────────────────────────
final todayStressProvider = StreamProvider<StressLogModel?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(checkInRepositoryProvider).streamTodayStress();
});

// ─── Stress history (last N days) ────────────────────────────────────────────
final stressHistoryProvider =
FutureProvider.family<List<StressLogModel>, int>((ref, days) async {
  ref.watch(authStateProvider);
  return ref.watch(checkInRepositoryProvider).getStressHistory(days);
});

// ─── Streak ───────────────────────────────────────────────────────────────────
final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(checkInRepositoryProvider).getStreak();
});

// ─── Weekly average stress score ─────────────────────────────────────────────
final weeklyAverageProvider = FutureProvider<double>((ref) async {
  final logs = await ref.watch(stressHistoryProvider(7).future);
  if (logs.isEmpty) return 0.0;
  final sum = logs.fold<double>(0, (acc, l) => acc + l.finalStressScore);
  return sum / logs.length;
});

// ─── Daily wellness tip (rotates by day of year) ─────────────────────────────
final dailyTipProvider = Provider<String>((ref) {
  const tips = [
    'Take 3 deep breaths before responding to stressful messages.',
    'A 10-minute walk can reduce cortisol levels by up to 15%.',
    'Gratitude journaling for 5 minutes boosts serotonin naturally.',
    'Staying hydrated improves focus and reduces anxiety symptoms.',
    'Set a "worry time" — 15 minutes to write concerns, then let go.',
    'Connecting with one person today can lower your stress score.',
    'Try the 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s.',
    'Morning sunlight within 30 minutes of waking regulates cortisol.',
    'Decluttering one small space can bring a surprising sense of calm.',
    'Progressive muscle relaxation before bed improves sleep quality.',
    'A short meditation of just 5 minutes changes brain wave patterns.',
    'Saying "no" to one unnecessary task today protects your energy.',
    'Cold water on your wrists can quickly reduce acute stress.',
    'Writing down tomorrow\'s tasks tonight frees your mind to rest.',
  ];
  final index = DateTime.now().dayOfYear % tips.length;
  return tips[index];
});

// ─── Bottom nav state ─────────────────────────────────────────────────────────
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

extension on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays;
  }
}