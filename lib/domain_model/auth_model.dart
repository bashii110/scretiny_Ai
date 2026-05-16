import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final int age;
  final String language;         // en, ar, ur, es, fr
  final String faithPreference;  // islam, christian, hindu, buddhism, secular
  final String subscriptionTier; // free, basic, premium
  final List<String> familyMembers;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? profileImageUrl;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.age,
    this.language = 'en',
    this.faithPreference = 'secular',
    this.subscriptionTier = 'free',
    this.familyMembers = const [],
    required this.createdAt,
    required this.lastActive,
    this.profileImageUrl,
  });

  // ─── Factory from Firestore ───────────────────────────────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      age: (map['age'] as num).toInt(),
      language: map['language'] as String? ?? 'en',
      faithPreference: map['faithPreference'] as String? ?? 'secular',
      subscriptionTier: map['subscriptionTier'] as String? ?? 'free',
      familyMembers: List<String>.from(map['familyMembers'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      lastActive: DateTime.fromMillisecondsSinceEpoch(
        (map['lastActive'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  // ─── To Firestore Map ─────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'age': age,
      'language': language,
      'faithPreference': faithPreference,
      'subscriptionTier': subscriptionTier,
      'familyMembers': familyMembers,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActive': lastActive.millisecondsSinceEpoch,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────────────────────
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    int? age,
    String? language,
    String? faithPreference,
    String? subscriptionTier,
    List<String>? familyMembers,
    DateTime? createdAt,
    DateTime? lastActive,
    String? profileImageUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      language: language ?? this.language,
      faithPreference: faithPreference ?? this.faithPreference,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      familyMembers: familyMembers ?? this.familyMembers,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  bool get isPremium => subscriptionTier == 'premium';
  bool get isBasic => subscriptionTier == 'basic' || isPremium;
  String get firstName => name.split(' ').first;

  @override
  List<Object?> get props => [
    uid,
    name,
    email,
    age,
    language,
    faithPreference,
    subscriptionTier,
    familyMembers,
    createdAt,
    lastActive,
    profileImageUrl,
  ];

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, email: $email)';
}