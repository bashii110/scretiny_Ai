import 'package:equatable/equatable.dart';

class FamilyModel extends Equatable {
  final String id;
  final String ownerId;
  final String memberId;
  final String memberName;
  final String memberEmail;
  final bool shareProgress;
  final bool alertOnHighStress;
  final bool alertOnMissedCheckin;
  final String relationship; // parent / spouse / sibling / friend
  final double? lastSharedStressScore;
  final DateTime? lastActiveAt;

  const FamilyModel({
    required this.id,
    required this.ownerId,
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
    this.shareProgress = true,
    this.alertOnHighStress = true,
    this.alertOnMissedCheckin = true,
    this.relationship = 'friend',
    this.lastSharedStressScore,
    this.lastActiveAt,
  });

  factory FamilyModel.fromMap(Map<String, dynamic> map) {
    return FamilyModel(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      memberEmail: map['memberEmail'] as String,
      shareProgress: map['shareProgress'] as bool? ?? true,
      alertOnHighStress: map['alertOnHighStress'] as bool? ?? true,
      alertOnMissedCheckin: map['alertOnMissedCheckin'] as bool? ?? true,
      relationship: map['relationship'] as String? ?? 'friend',
      lastSharedStressScore: (map['lastSharedStressScore'] as num?)?.toDouble(),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'memberId': memberId,
    'memberName': memberName,
    'memberEmail': memberEmail,
    'shareProgress': shareProgress,
    'alertOnHighStress': alertOnHighStress,
    'alertOnMissedCheckin': alertOnMissedCheckin,
    'relationship': relationship,
    if (lastSharedStressScore != null)
      'lastSharedStressScore': lastSharedStressScore,
    if (lastActiveAt != null)
      'lastActiveAt': lastActiveAt!.millisecondsSinceEpoch,
  };

  FamilyModel copyWith({
    String? id,
    String? ownerId,
    String? memberId,
    String? memberName,
    String? memberEmail,
    bool? shareProgress,
    bool? alertOnHighStress,
    bool? alertOnMissedCheckin,
    String? relationship,
    double? lastSharedStressScore,
    DateTime? lastActiveAt,
  }) =>
      FamilyModel(
        id: id ?? this.id,
        ownerId: ownerId ?? this.ownerId,
        memberId: memberId ?? this.memberId,
        memberName: memberName ?? this.memberName,
        memberEmail: memberEmail ?? this.memberEmail,
        shareProgress: shareProgress ?? this.shareProgress,
        alertOnHighStress: alertOnHighStress ?? this.alertOnHighStress,
        alertOnMissedCheckin: alertOnMissedCheckin ?? this.alertOnMissedCheckin,
        relationship: relationship ?? this.relationship,
        lastSharedStressScore:
        lastSharedStressScore ?? this.lastSharedStressScore,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      );

  @override
  List<Object?> get props => [
    id, ownerId, memberId, memberName, memberEmail,
    shareProgress, alertOnHighStress, alertOnMissedCheckin, relationship,
  ];
}