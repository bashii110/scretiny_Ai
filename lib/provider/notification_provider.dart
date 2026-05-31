import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// notification_provider.dart
//
// Providers:
//   • notificationServiceProvider     – singleton service (init, schedule, send)
//   • notificationHistoryProvider     – local notification history list
//   • fcmTokenProvider                – current FCM token
//   • unreadNotificationCountProvider – badge count
// ─────────────────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;

// ─────────────────────────────────────────────────────────────────────────────
// Notification Item Model
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'reminder' | 'alert' | 'report' | 'family'
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) =>
      AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        type: j['type'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            j['createdAt'] as int),
        isRead: j['isRead'] as bool? ?? false,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Service
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationService(this._plugin);

  static const _channelId = 'serenity_main';
  static const _channelName = 'SerenityAI Notifications';

  // ── Schedule daily reminder ───────────────────────────────────────────────

  Future<void> scheduleMorningReminder(int hour) async {
    await _plugin.cancelAll(); // clear existing schedules first
    // Note: timezone scheduling requires timezone package.
    // For now we show an immediate notification as a demonstration.
    await _plugin.show(
      1001,
      '🌅 Morning Check-In',
      'How did you sleep? Start your day with a quick check-in.',
      _details(),
      payload: jsonEncode({'type': 'morning_checkin'}),
    );
  }

  Future<void> scheduleEveningReminder(int hour) async {
    await _plugin.show(
      1002,
      '🌙 Evening Check-In',
      'Take a moment to reflect on your day.',
      _details(),
      payload: jsonEncode({'type': 'evening_checkin'}),
    );
  }

  // ── High stress alert ─────────────────────────────────────────────────────

  Future<void> sendHighStressAlert(double score) async {
    await _plugin.show(
      2001,
      '⚠️ High Stress Detected',
      'Your stress score is ${score.toStringAsFixed(0)}. Try a breathing exercise.',
      _details(),
      payload: jsonEncode({'type': 'high_stress', 'score': score}),
    );
  }

  // ── Weekly report ─────────────────────────────────────────────────────────

  Future<void> sendWeeklyReport(double avgScore) async {
    await _plugin.show(
      3001,
      '📊 Your Weekly Report is Ready',
      'Average stress: ${avgScore.toStringAsFixed(0)}/100. Tap to view.',
      _details(),
      payload: jsonEncode({'type': 'weekly_report'}),
    );
  }

  // ── Generic push ─────────────────────────────────────────────────────────

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(id, title, body, _details(),
        payload: payload);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}

final notificationServiceProvider =
Provider<NotificationService>((ref) {
  // The plugin instance is initialised in main.dart
  // We expose a new instance here for use across the app
  return NotificationService(FlutterLocalNotificationsPlugin());
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM Token Provider
// ─────────────────────────────────────────────────────────────────────────────

final fcmTokenProvider = FutureProvider<String?>((ref) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    final uid = _uid();
    if (token != null && uid != null) {
      // Persist token to Firestore so backend can send push notifications
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return token;
  } catch (_) {
    return null;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Notification History  (SharedPreferences backed, max 50)
// ─────────────────────────────────────────────────────────────────────────────

class NotificationHistoryNotifier
    extends StateNotifier<List<AppNotification>> {
  NotificationHistoryNotifier() : super([]) {
    _load();
  }

  static const _key = 'notification_history';
  static const _maxItems = 50;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = raw
        .map((s) =>
        AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> add(AppNotification notif) async {
    final updated = [notif, ...state];
    if (updated.length > _maxItems) updated.removeLast();
    state = updated;
    await _persist();
  }

  Future<void> markRead(String id) async {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    await _persist();
  }

  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _persist();
  }

  Future<void> deleteNotification(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _persist();
  }

  Future<void> clearAll() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }
}

final notificationHistoryProvider = StateNotifierProvider<
    NotificationHistoryNotifier, List<AppNotification>>(
      (_) => NotificationHistoryNotifier(),
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final history = ref.watch(notificationHistoryProvider);
  return history.where((n) => !n.isRead).length;
});