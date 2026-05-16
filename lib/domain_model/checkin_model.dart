import 'package:equatable/equatable.dart';

// ─── CheckInModel ─────────────────────────────────────────────────────────────
class CheckInModel extends Equatable {
  final String id;
  final String userId;
  final String type; // morning / evening
  final DateTime date;
  final int sleepQuality;   // 1–5
  final int anxietyLevel;   // 1–5
  final int energyLevel;    // 1–5
  final int mentalClarity;  // 1–5
  final int overallMood;    // 1–5
  final int workStress;     // 1–5
  final String gratitudeNote;

  const CheckInModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.date,
    this.sleepQuality = 3,
    this.anxietyLevel = 3,
    this.energyLevel = 3,
    this.mentalClarity = 3,
    this.overallMood = 3,
    this.workStress = 3,
    this.gratitudeNote = '',
  });

  factory CheckInModel.fromMap(Map<String, dynamic> map) {
    return CheckInModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      type: map['type'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      sleepQuality: (map['sleepQuality'] as num?)?.toInt() ?? 3,
      anxietyLevel: (map['anxietyLevel'] as num?)?.toInt() ?? 3,
      energyLevel: (map['energyLevel'] as num?)?.toInt() ?? 3,
      mentalClarity: (map['mentalClarity'] as num?)?.toInt() ?? 3,
      overallMood: (map['overallMood'] as num?)?.toInt() ?? 3,
      workStress: (map['workStress'] as num?)?.toInt() ?? 3,
      gratitudeNote: map['gratitudeNote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'type': type,
    'date': date.millisecondsSinceEpoch,
    'sleepQuality': sleepQuality,
    'anxietyLevel': anxietyLevel,
    'energyLevel': energyLevel,
    'mentalClarity': mentalClarity,
    'overallMood': overallMood,
    'workStress': workStress,
    'gratitudeNote': gratitudeNote,
  };

  /// Aggregate score from 0–100 for use in stress calculation (higher = more stress)
  double get stressContribution {
    final avg = (anxietyLevel + workStress + (6 - energyLevel) + (6 - mentalClarity)) / 4;
    return ((avg - 1) / 4) * 100;
  }

  CheckInModel copyWith({
    String? id,
    String? userId,
    String? type,
    DateTime? date,
    int? sleepQuality,
    int? anxietyLevel,
    int? energyLevel,
    int? mentalClarity,
    int? overallMood,
    int? workStress,
    String? gratitudeNote,
  }) =>
      CheckInModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        date: date ?? this.date,
        sleepQuality: sleepQuality ?? this.sleepQuality,
        anxietyLevel: anxietyLevel ?? this.anxietyLevel,
        energyLevel: energyLevel ?? this.energyLevel,
        mentalClarity: mentalClarity ?? this.mentalClarity,
        overallMood: overallMood ?? this.overallMood,
        workStress: workStress ?? this.workStress,
        gratitudeNote: gratitudeNote ?? this.gratitudeNote,
      );

  @override
  List<Object?> get props => [
    id, userId, type, date, sleepQuality, anxietyLevel,
    energyLevel, mentalClarity, overallMood, workStress, gratitudeNote,
  ];
}