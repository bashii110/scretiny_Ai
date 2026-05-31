import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/therapist_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// therapist_provider.dart
//
// Providers:
//   • therapistFilterProvider        – current filter state
//   • therapistsProvider             – stream of filtered therapists
//   • therapistDetailProvider        – single therapist by id
//   • upcomingSessionsProvider       – user's booked sessions
//   • pastSessionsProvider           – user's completed sessions
//   • therapistControllerProvider    – booking / cancellation controller
// ─────────────────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Filter State
// ─────────────────────────────────────────────────────────────────────────────

class TherapistFilter {
  final String? faith;         // null = all
  final String? language;      // null = all
  final bool onlineOnly;
  final double? maxPrice;
  final String sortBy;         // 'rating' | 'price' | 'online'

  const TherapistFilter({
    this.faith,
    this.language,
    this.onlineOnly = false,
    this.maxPrice,
    this.sortBy = 'rating',
  });

  TherapistFilter copyWith({
    Object? faith = _sentinel,
    Object? language = _sentinel,
    bool? onlineOnly,
    Object? maxPrice = _sentinel,
    String? sortBy,
  }) =>
      TherapistFilter(
        faith: faith == _sentinel ? this.faith : faith as String?,
        language:
        language == _sentinel ? this.language : language as String?,
        onlineOnly: onlineOnly ?? this.onlineOnly,
        maxPrice:
        maxPrice == _sentinel ? this.maxPrice : maxPrice as double?,
        sortBy: sortBy ?? this.sortBy,
      );
}

const _sentinel = Object();

final therapistFilterProvider =
StateProvider<TherapistFilter>((_) => const TherapistFilter());

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

class TherapistRepository {
  final _therapistsCol = _db.collection('therapists');
  final _sessionsCol = _db.collection('therapist_sessions');

  // ── Therapists ──────────────────────────────────────────────────────────

  Stream<List<TherapistModel>> fetchTherapists({
    String? faith,
    String? language,
    bool onlineOnly = false,
  }) {
    Query<Map<String, dynamic>> q = _therapistsCol;

    if (onlineOnly) {
      q = q.where('isOnline', isEqualTo: true);
    }

    return q.snapshots().map((s) {
      var list = s.docs
          .map((d) => TherapistModel.fromMap(d.data()))
          .toList();

      if (faith != null && faith != 'all') {
        list = list
            .where((t) =>
        t.faithSensitive.isEmpty ||
            t.faithSensitive.contains(faith))
            .toList();
      }

      if (language != null) {
        list = list
            .where((t) => t.languages.contains(language))
            .toList();
      }

      return list;
    });
  }

  Future<TherapistModel?> fetchTherapistById(String id) async {
    final doc = await _therapistsCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return TherapistModel.fromMap(doc.data()!);
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  Stream<List<TherapistSessionModel>> upcomingSessions(String uid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _sessionsCol
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'upcoming')
        .where('scheduledAt', isGreaterThanOrEqualTo: now)
        .orderBy('scheduledAt')
        .snapshots()
        .map((s) => s.docs
        .map((d) => TherapistSessionModel.fromMap(d.data()))
        .toList());
  }

  Stream<List<TherapistSessionModel>> pastSessions(String uid) {
    return _sessionsCol
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('scheduledAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs
        .map((d) => TherapistSessionModel.fromMap(d.data()))
        .toList());
  }

  Future<void> bookSession(TherapistSessionModel session) async {
    await _sessionsCol.doc(session.id).set(session.toMap());
  }

  Future<void> cancelSession(String sessionId) async {
    await _sessionsCol
        .doc(sessionId)
        .update({'status': 'cancelled'});
  }
}

final therapistRepositoryProvider =
Provider<TherapistRepository>((_) => TherapistRepository());

// ─────────────────────────────────────────────────────────────────────────────
// Therapists Stream
// ─────────────────────────────────────────────────────────────────────────────

final therapistsProvider =
StreamProvider<List<TherapistModel>>((ref) {
  final filter = ref.watch(therapistFilterProvider);
  final repo = ref.watch(therapistRepositoryProvider);

  return repo
      .fetchTherapists(
    faith: filter.faith,
    language: filter.language,
    onlineOnly: filter.onlineOnly,
  )
      .map((list) {
    // Client-side sort & price filter
    var filtered = list;
    if (filter.maxPrice != null) {
      filtered = filtered
          .where((t) => t.pricePerSession <= filter.maxPrice!)
          .toList();
    }

    switch (filter.sortBy) {
      case 'price':
        filtered.sort(
                (a, b) => a.pricePerSession.compareTo(b.pricePerSession));
        break;
      case 'online':
        filtered.sort((a, b) =>
            (b.isOnline ? 1 : 0).compareTo(a.isOnline ? 1 : 0));
        break;
      default: // rating
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return filtered;
  });
});

// Fallback local therapist stubs when Firestore is empty
List<TherapistModel> get localTherapistStubs => [
  TherapistModel(
    id: 'stub_1',
    name: 'Dr. Sara Ahmed',
    specialization: 'Anxiety & Stress',
    languages: ['en', 'ar'],
    faithSensitive: ['islam', 'all'],
    rating: 4.9,
    reviewCount: 128,
    pricePerSession: 45,
    currency: 'USD',
    isOnline: true,
    about:
    'Specialises in Islamic-sensitive CBT for anxiety and work stress.',
  ),
  TherapistModel(
    id: 'stub_2',
    name: 'Dr. James Okafor',
    specialization: 'Depression & Burnout',
    languages: ['en'],
    faithSensitive: [],
    rating: 4.7,
    reviewCount: 94,
    pricePerSession: 60,
    currency: 'USD',
    isOnline: true,
    about:
    'Certified CBT therapist with 12 years in burnout recovery.',
  ),
  TherapistModel(
    id: 'stub_3',
    name: 'Dr. Priya Nair',
    specialization: 'Mindfulness & Trauma',
    languages: ['en', 'ur'],
    faithSensitive: ['hindu', 'buddhism', 'all'],
    rating: 4.8,
    reviewCount: 76,
    pricePerSession: 50,
    currency: 'USD',
    isOnline: false,
    about:
    'Integrates yoga-based therapy with evidence-based trauma work.',
  ),
  TherapistModel(
    id: 'stub_4',
    name: 'Dr. Carlos Mendez',
    specialization: 'Family & Relationships',
    languages: ['en', 'es'],
    faithSensitive: ['christian', 'all'],
    rating: 4.6,
    reviewCount: 52,
    pricePerSession: 40,
    currency: 'USD',
    isOnline: true,
    about:
    'Faith-based family counselling with 8 years of experience.',
  ),
  TherapistModel(
    id: 'stub_5',
    name: 'Dr. Amina Hassan',
    specialization: 'Postpartum & Women\'s Health',
    languages: ['en', 'ar', 'fr'],
    faithSensitive: ['islam', 'all'],
    rating: 4.95,
    reviewCount: 210,
    pricePerSession: 55,
    currency: 'USD',
    isOnline: true,
    about:
    'Women\'s mental health specialist with a holistic, culturally sensitive approach.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Sessions Providers
// ─────────────────────────────────────────────────────────────────────────────

final upcomingSessionsProvider =
StreamProvider<List<TherapistSessionModel>>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);
  return ref.watch(therapistRepositoryProvider).upcomingSessions(uid);
});

final pastSessionsProvider =
StreamProvider<List<TherapistSessionModel>>((ref) {
  final uid = _uid();
  if (uid == null) return Stream.value([]);
  return ref.watch(therapistRepositoryProvider).pastSessions(uid);
});

// ─────────────────────────────────────────────────────────────────────────────
// Booking Controller
// ─────────────────────────────────────────────────────────────────────────────

class TherapistBookingState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final TherapistModel? selectedTherapist;
  final DateTime? selectedSlot;

  const TherapistBookingState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.selectedTherapist,
    this.selectedSlot,
  });

  TherapistBookingState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    TherapistModel? selectedTherapist,
    DateTime? selectedSlot,
  }) =>
      TherapistBookingState(
        isLoading: isLoading ?? this.isLoading,
        isSuccess: isSuccess ?? this.isSuccess,
        error: error,
        selectedTherapist:
        selectedTherapist ?? this.selectedTherapist,
        selectedSlot: selectedSlot ?? this.selectedSlot,
      );
}

class TherapistBookingController
    extends StateNotifier<TherapistBookingState> {
  final TherapistRepository _repo;

  TherapistBookingController(this._repo)
      : super(const TherapistBookingState());

  void selectTherapist(TherapistModel t) {
    state = state.copyWith(selectedTherapist: t);
  }

  void selectSlot(DateTime slot) {
    state = state.copyWith(selectedSlot: slot);
  }

  Future<bool> confirmBooking() async {
    final uid = _uid();
    if (uid == null ||
        state.selectedTherapist == null ||
        state.selectedSlot == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      final session = TherapistSessionModel(
        id: _uuid.v4(),
        userId: uid,
        therapistId: state.selectedTherapist!.id,
        therapistName: state.selectedTherapist!.name,
        scheduledAt: state.selectedSlot!,
        price: state.selectedTherapist!.pricePerSession,
        currency: state.selectedTherapist!.currency,
      );
      await _repo.bookSession(session);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Booking failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> cancelSession(String sessionId) async {
    try {
      await _repo.cancelSession(sessionId);
    } catch (_) {}
  }

  void clear() => state = const TherapistBookingState();
}

final therapistBookingProvider = StateNotifierProvider<
    TherapistBookingController, TherapistBookingState>(
      (ref) => TherapistBookingController(
      ref.watch(therapistRepositoryProvider)),
);