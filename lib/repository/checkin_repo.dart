// lib/repository/checkin_repo.dart
//
// COLLECTION MAP:
//  WRITES checkins: checkins/{id}  (root flat collection — matches Firestore screenshot)
//  WRITES stress:   stress_logs/{id} (root flat collection)
//  READS both from root flat collections filtered by userId

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../domain_model/checkin_model.dart';
import '../domain_model/stress_model.dart';
import '../stress_calculator.dart';

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
  // Using ROOT flat collections (matches Firestore screenshot which shows
  // "checkins" as a root collection, not a subcollection)
  CollectionReference<Map<String, dynamic>> get _checkInsCol =>
      _firestore.collection('checkins');

  CollectionReference<Map<String, dynamic>> get _stressLogsCol =>
      _firestore.collection('stress_logs');

  // ─── Save check-in ────────────────────────────────────────────────────────
  Future<CheckInModel> saveCheckIn(CheckInModel checkIn) async {
    try {
      final uid = _uid;
      final id = checkIn.id.isEmpty ? const Uuid().v4() : checkIn.id;

      final model = CheckInModel(
        id: id,
        userId: uid,
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

      // 1. Write check-in to root checkins collection
      await _checkInsCol.doc(id).set(model.toMap());
      _log.i('Check-in saved: $id  type=${model.type}  uid=$uid');

      // 2. Compute stress contribution from this check-in
      final checkInStress = StressCalculator.checkInToStress(
        anxietyLevel: model.anxietyLevel,
        workStress: model.workStress,
        energyLevel: model.energyLevel,
        mentalClarity: model.mentalClarity,
      );

      final sleepStress = StressCalculator.sleepQualityToStress(model.sleepQuality);

      // 3. Upsert today's stress_log with checkInScore
      await _upsertStressLog(
        uid: uid,
        checkInScore: checkInStress,
        sleepScore: sleepStress,
      );

      return model;
    } on FirebaseException catch (e) {
      _log.e('Firestore error saving check-in  code=${e.code}', error: e);
      if (e.code == 'permission-denied') {
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

  // ─── Upsert stress log with check-in contribution ─────────────────────────
  Future<void> _upsertStressLog({
    required String uid,
    required double checkInScore,
    required double sleepScore,
  }) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snap = await _stressLogsCol
          .where('userId', isEqualTo: uid)
          .where('date',
          isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        // Update existing log
        final old = StressLogModel.fromMap(snap.docs.first.data());
        final newFinal = StressCalculator.calculateFinalStressScore(
          cameraHRV: old.cameraHRVScore,
          voiceScore: old.voiceScore,
          phoneUsage: old.phoneUsageScore,
          sleepScore: sleepScore,
          checkInScore: checkInScore,
        );
        await _stressLogsCol.doc(old.id).update({
          'checkInScore': checkInScore,
          'finalStressScore': newFinal,
          'stressLevel': StressCalculator.getStressLevel(newFinal),
        });
        _log.i('Stress log updated with checkInScore=$checkInScore, final=$newFinal');
      } else {
        // Create new stress log
        final logId = const Uuid().v4();
        final finalScore = StressCalculator.calculateFinalStressScore(
          cameraHRV: 0,
          voiceScore: 0,
          phoneUsage: 0,
          sleepScore: sleepScore,
          checkInScore: checkInScore,
        );
        final log = StressLogModel(
          id: logId,
          userId: uid,
          date: now,
          checkInScore: checkInScore,
          finalStressScore: finalScore,
          stressLevel: StressCalculator.getStressLevel(finalScore),
        );
        await _stressLogsCol.doc(logId).set(log.toMap());
        _log.i('New stress log created with checkInScore=$checkInScore');
      }
    } catch (e) {
      // Non-fatal: log the error but don't fail the check-in save
      _log.e('Error upserting stress log after check-in', error: e);
    }
  }

  // ─── Stream today's check-ins (root collection) ───────────────────────────
  Stream<List<CheckInModel>> streamTodayCheckIns() {
    try {
      final uid = _uid;
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

      return _checkInsCol
          .where('userId', isEqualTo: uid)
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

  // ─── Stream today's stress log ────────────────────────────────────────────
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
          .orderBy('date', descending: true)
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

  // ─── Fetch stress history N days ──────────────────────────────────────────
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

  // ─── Streak based on root checkins collection ─────────────────────────────
  Future<int> getStreak() async {
    try {
      final uid = _uid;
      final snap = await _checkInsCol
          .where('userId', isEqualTo: uid)
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