// lib/repository/checkin_repo.dart
//
// COLLECTION MAP (matches what the app actually queries — confirmed from logs):
//
//  WRITES:  users/{uid}/checkIns/{id}   ← subcollection, ruled by users/{uid}
//  READS:   stress_logs                 ← root flat collection, filtered by userId
//           users/{uid}/checkIns        ← subcollection

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/checkin_model.dart';
import '../domain_model/stress_model.dart';

class CheckInRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _log = Logger();

  CheckInRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ─── Auth guard ───────────────────────────────────────────────────────────
  // Throws a clear, user-visible message if not authenticated.
  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception(
        'You must be signed in to save a check-in. '
            'Please sign out and sign in again.',
      );
    }
    return uid;
  }

  // ─── Collection references ────────────────────────────────────────────────

  // Check-ins live under the user's own subcollection.
  // Rule: allow read, write: if request.auth.uid == uid  ✓
  CollectionReference<Map<String, dynamic>> get _checkInsCol =>
      _firestore.collection('users').doc(_uid).collection('checkIns');

  // Stress logs live in a ROOT flat collection, filtered by userId.
  // Rule: allow read: if resource.data.userId == request.auth.uid  ✓
  CollectionReference<Map<String, dynamic>> get _stressLogsCol =>
      _firestore.collection('stress_logs');

  // ─── Save check-in ────────────────────────────────────────────────────────
  Future<CheckInModel> saveCheckIn(CheckInModel checkIn) async {
    try {
      final uid = _uid; // throws if unauthenticated
      final id =
      checkIn.id.isEmpty ? const Uuid().v4() : checkIn.id;

      final model = CheckInModel(
        id: id,
        userId: uid, // always stamp with real UID
        type: checkIn.type,
        date: checkIn.date,
        sleepQuality: checkIn.sleepQuality,
        anxietyLevel: checkIn.anxietyLevel,
        energyLevel: checkIn.energyLevel,
        mentalClarity: checkIn.mentalClarity,
        overallMood: checkIn.overallMood,
        workStress: checkIn.workStress,
        gratitudeNote: checkIn.gratitudeNote,
      );

      // Write to users/{uid}/checkIns/{id}
      await _checkInsCol.doc(id).set(model.toMap());
      _log.i('Check-in saved: $id  type=${model.type}  uid=$uid');
      return model;
    } on FirebaseException catch (e) {
      _log.e('Firestore error saving check-in  code=${e.code}', error: e);
      if (e.code == 'permission-denied') {
        // This means the Firestore rules are not deployed yet.
        // See firestore.rules — deploy with: firebase deploy --only firestore:rules
        throw Exception(
          'Firestore permission denied.\n'
              'Please deploy the updated firestore.rules file:\n'
              '  firebase deploy --only firestore:rules',
        );
      }
      throw Exception('Failed to save check-in: ${e.message}');
    } catch (e) {
      _log.e('Error saving check-in', error: e);
      rethrow;
    }
  }

  // ─── Stream today's check-ins (subcollection) ─────────────────────────────
  Stream<List<CheckInModel>> streamTodayCheckIns() {
    try {
      final uid = _uid;
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

      return _firestore
          .collection('users')
          .doc(uid)
          .collection('checkIns')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .snapshots()
          .map((snap) => snap.docs
          .map((d) => CheckInModel.fromMap(d.data()))
          .toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  // ─── Stream today's stress log (root flat collection) ─────────────────────
  Stream<StressLogModel?> streamTodayStress() {
    try {
      final uid = _uid;
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

      return _stressLogsCol
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return null;
        return StressLogModel.fromMap(snap.docs.first.data());
      });
    } catch (e) {
      return const Stream.empty();
    }
  }

  // ─── Fetch stress history N days (root flat collection) ───────────────────
  Future<List<StressLogModel>> getStressHistory(int days) async {
    try {
      final uid = _uid;
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;

      final snap = await _stressLogsCol
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: since)
          .orderBy('date')
          .get();

      return snap.docs
          .map((d) => StressLogModel.fromMap(d.data()))
          .toList();
    } on FirebaseException catch (e) {
      _log.e('Error fetching stress history', error: e);
      return [];
    }
  }

  // ─── Checkin-based streak ─────────────────────────────────────────────────
  Future<int> getStreak() async {
    try {
      final uid = _uid;
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('checkIns')
          .orderBy('date', descending: true)
          .limit(60)
          .get();

      if (snap.docs.isEmpty) return 0;

      final checkedDays = <String>{};
      for (final doc in snap.docs) {
        final ts = doc.data()['date'] as int? ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(ts);
        checkedDays.add('${date.year}-${date.month}-${date.day}');
      }

      int streak = 0;
      var day = DateTime.now();
      while (true) {
        final key = '${day.year}-${day.month}-${day.day}';
        if (checkedDays.contains(key)) {
          streak++;
          day = day.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }
}