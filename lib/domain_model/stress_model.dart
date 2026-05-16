import 'package:equatable/equatable.dart';

class StressLogModel extends Equatable {
  final String id;
  final String userId;
  final DateTime date;
  final double cameraHRVScore;   // 0–100
  final double voiceScore;       // 0–100
  final double phoneUsageScore;  // 0–100
  final double checkInScore;     // 0–100
  final double finalStressScore; // 0–100 (weighted avg)
  final String stressLevel;      // low / medium / high / critical
  final List<String> triggers;
  final String notes;

  const StressLogModel({
    required this.id,
    required this.userId,
    required this.date,
    this.cameraHRVScore = 0.0,
    this.voiceScore = 0.0,
    this.phoneUsageScore = 0.0,
    this.checkInScore = 0.0,
    required this.finalStressScore,
    required this.stressLevel,
    this.triggers = const [],
    this.notes = '',
  });

  factory StressLogModel.fromMap(Map<String, dynamic> map) {
    return StressLogModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      cameraHRVScore: (map['cameraHRVScore'] as num?)?.toDouble() ?? 0.0,
      voiceScore: (map['voiceScore'] as num?)?.toDouble() ?? 0.0,
      phoneUsageScore: (map['phoneUsageScore'] as num?)?.toDouble() ?? 0.0,
      checkInScore: (map['checkInScore'] as num?)?.toDouble() ?? 0.0,
      finalStressScore: (map['finalStressScore'] as num).toDouble(),
      stressLevel: map['stressLevel'] as String,
      triggers: List<String>.from(map['triggers'] ?? []),
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'cameraHRVScore': cameraHRVScore,
      'voiceScore': voiceScore,
      'phoneUsageScore': phoneUsageScore,
      'checkInScore': checkInScore,
      'finalStressScore': finalStressScore,
      'stressLevel': stressLevel,
      'triggers': triggers,
      'notes': notes,
    };
  }

  StressLogModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? cameraHRVScore,
    double? voiceScore,
    double? phoneUsageScore,
    double? checkInScore,
    double? finalStressScore,
    String? stressLevel,
    List<String>? triggers,
    String? notes,
  }) {
    return StressLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      cameraHRVScore: cameraHRVScore ?? this.cameraHRVScore,
      voiceScore: voiceScore ?? this.voiceScore,
      phoneUsageScore: phoneUsageScore ?? this.phoneUsageScore,
      checkInScore: checkInScore ?? this.checkInScore,
      finalStressScore: finalStressScore ?? this.finalStressScore,
      stressLevel: stressLevel ?? this.stressLevel,
      triggers: triggers ?? this.triggers,
      notes: notes ?? this.notes,
    );
  }

  bool get isLow => stressLevel == 'low';
  bool get isMedium => stressLevel == 'medium';
  bool get isHigh => stressLevel == 'high';
  bool get isCritical => stressLevel == 'critical';

  @override
  List<Object?> get props => [
    id,
    userId,
    date,
    cameraHRVScore,
    voiceScore,
    phoneUsageScore,
    checkInScore,
    finalStressScore,
    stressLevel,
    triggers,
    notes,
  ];
}