import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_color.dart';
import '../provider/notification_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// notification_screen.dart
//
// Sections:
//   1. App bar with "Mark all read" action
//   2. Notification list grouped by Today / Earlier
//   3. Empty state
//   4. Swipe to delete
// ─────────────────────────────────────────────────────────────────────────────

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationHistoryProvider);
    final notifier = ref.read(notificationHistoryProvider.notifier);

    final today = DateTime.now();
    final todayItems = notifications.where((n) =>
    n.createdAt.year == today.year &&
        n.createdAt.month == today.month &&
        n.createdAt.day == today.day).toList();
    final earlierItems = notifications.where((n) =>
    !(n.createdAt.year == today.year &&
        n.createdAt.month == today.month &&
        n.createdAt.day == today.day)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: notifier.markAllRead,
              child: const Text('Mark all read'),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, notifier),
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _EmptyState()
          : ListView(
        padding: const EdgeInsets.fromLTRB(
            20, 12, 20, 32),
        children: [
          if (todayItems.isNotEmpty) ...[
            _GroupLabel(label: 'Today'),
            const SizedBox(height: 8),
            ...todayItems.map((n) =>
                _NotificationTile(notif: n)),
            const SizedBox(height: 16),
          ],
          if (earlierItems.isNotEmpty) ...[
            _GroupLabel(label: 'Earlier'),
            const SizedBox(height: 8),
            ...earlierItems.map((n) =>
                _NotificationTile(notif: n)),
          ],
        ],
      ),
    );
  }

  void _confirmClear(
      BuildContext context,
      NotificationHistoryNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content:
        const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.clearAll();
            },
            child: const Text('Clear',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Label
// ─────────────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: AppColors.textLight),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends ConsumerWidget {
  final AppNotification notif;
  const _NotificationTile({required this.notif});

  static const _typeConfig = {
    'reminder': (Icons.alarm_outlined, AppColors.primary, '⏰'),
    'alert': (Icons.warning_amber_outlined, AppColors.danger, '⚠️'),
    'report': (Icons.bar_chart_outlined, AppColors.secondary, '📊'),
    'family': (Icons.people_outline, Color(0xFFFF9800), '👨‍👩‍👧'),
    'morning_checkin': (Icons.wb_sunny_outlined, AppColors.primary, '🌅'),
    'evening_checkin': (Icons.nights_stay_outlined, AppColors.secondary, '🌙'),
    'high_stress': (Icons.warning_rounded, AppColors.danger, '🚨'),
    'weekly_report': (Icons.analytics_outlined, AppColors.secondary, '📈'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = _typeConfig[notif.type] ??
        (Icons.notifications_outlined, AppColors.primary, '🔔');
    final icon = cfg.$1;
    final color = cfg.$2;
    final emoji = cfg.$3;

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline,
            color: AppColors.danger),
      ),
      onDismissed: (_) => ref
          .read(notificationHistoryProvider.notifier)
          .deleteNotification(notif.id),
      child: GestureDetector(
        onTap: () => ref
            .read(notificationHistoryProvider.notifier)
            .markRead(notif.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? AppColors.surface
                : color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notif.isRead
                  ? AppColors.border
                  : color.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _timeAgo(notif.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔔',
                    style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see reminders, alerts, and\nwellness updates here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}