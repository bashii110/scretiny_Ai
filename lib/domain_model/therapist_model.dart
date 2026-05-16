import 'package:equatable/equatable.dart';

class TherapistModel extends Equatable {
  final String id;
  final String name;
  final String specialization;
  final List<String> languages;
  final List<String> faithSensitive;
  final double rating;
  final int reviewCount;
  final double pricePerSession;
  final String currency;
  final bool isOnline;
  final String profileImageUrl;
  final String about;
  final List<DateTime> availableSlots;

  const TherapistModel({
    required this.id,
    required this.name,
    required this.specialization,
    this.languages = const ['en'],
    this.faithSensitive = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.pricePerSession,
    this.currency = 'USD',
    this.isOnline = false,
    this.profileImageUrl = '',
    this.about = '',
    this.availableSlots = const [],
  });

  factory TherapistModel.fromMap(Map<String, dynamic> map) {
    return TherapistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      specialization: map['specialization'] as String,
      languages: List<String>.from(map['languages'] ?? ['en']),
      faithSensitive: List<String>.from(map['faithSensitive'] ?? []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      pricePerSession: (map['pricePerSession'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'USD',
      isOnline: map['isOnline'] as bool? ?? false,
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      about: map['about'] as String? ?? '',
      availableSlots: (map['availableSlots'] as List<dynamic>? ?? [])
          .map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'specialization': specialization,
    'languages': languages,
    'faithSensitive': faithSensitive,
    'rating': rating,
    'reviewCount': reviewCount,
    'pricePerSession': pricePerSession,
    'currency': currency,
    'isOnline': isOnline,
    'profileImageUrl': profileImageUrl,
    'about': about,
    'availableSlots':
    availableSlots.map((d) => d.millisecondsSinceEpoch).toList(),
  };

  String get formattedPrice => '$currency ${pricePerSession.toStringAsFixed(0)}';

  @override
  List<Object?> get props => [
    id, name, specialization, languages, faithSensitive,
    rating, reviewCount, pricePerSession, currency, isOnline,
  ];
}

// ─── Therapist Session Model ──────────────────────────────────────────────────
class TherapistSessionModel extends Equatable {
  final String id;
  final String userId;
  final String therapistId;
  final String therapistName;
  final DateTime scheduledAt;
  final String status; // upcoming / completed / cancelled
  final double price;
  final String currency;

  const TherapistSessionModel({
    required this.id,
    required this.userId,
    required this.therapistId,
    required this.therapistName,
    required this.scheduledAt,
    this.status = 'upcoming',
    required this.price,
    this.currency = 'USD',
  });

  factory TherapistSessionModel.fromMap(Map<String, dynamic> map) {
    return TherapistSessionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      therapistId: map['therapistId'] as String,
      therapistName: map['therapistName'] as String,
      scheduledAt:
      DateTime.fromMillisecondsSinceEpoch(map['scheduledAt'] as int),
      status: map['status'] as String? ?? 'upcoming',
      price: (map['price'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'therapistId': therapistId,
    'therapistName': therapistName,
    'scheduledAt': scheduledAt.millisecondsSinceEpoch,
    'status': status,
    'price': price,
    'currency': currency,
  };

  @override
  List<Object?> get props =>
      [id, userId, therapistId, scheduledAt, status];
}