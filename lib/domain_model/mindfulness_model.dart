import 'package:equatable/equatable.dart';

class MindfulnessContentModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String type;       // breathing / meditation / prayer / journal
  final String faith;      // islam / christian / hindu / secular / all
  final int duration;      // in seconds
  final String language;
  final String audioUrl;
  final bool isPremium;
  final String? thumbnailUrl;
  final int? completionCount;

  const MindfulnessContentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.faith = 'all',
    required this.duration,
    this.language = 'en',
    this.audioUrl = '',
    this.isPremium = false,
    this.thumbnailUrl,
    this.completionCount,
  });

  factory MindfulnessContentModel.fromMap(Map<String, dynamic> map) {
    return MindfulnessContentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      faith: map['faith'] as String? ?? 'all',
      duration: (map['duration'] as num).toInt(),
      language: map['language'] as String? ?? 'en',
      audioUrl: map['audioUrl'] as String? ?? '',
      isPremium: map['isPremium'] as bool? ?? false,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      completionCount: (map['completionCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'faith': faith,
    'duration': duration,
    'language': language,
    'audioUrl': audioUrl,
    'isPremium': isPremium,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (completionCount != null) 'completionCount': completionCount,
  };

  String get formattedDuration {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  @override
  List<Object?> get props => [
    id, title, description, type, faith, duration,
    language, audioUrl, isPremium,
  ];
}