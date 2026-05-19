import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../components/app_color.dart';
import '../components/app_router.dart';
import '../domain_model/auth_model.dart';
import '../domain_model/stress_model.dart';
import '../provider/auth_provider.dart';
import '../provider/home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: navIndex,
        children: const [
          _HomeTab(),
          _PlaceholderTab(label: 'Analytics', icon: Icons.bar_chart_rounded),
          _PlaceholderTab(label: 'Mindfulness', icon: Icons.self_improvement),
          _PlaceholderTab(label: 'Family', icon: Icons.people_outline),
          _PlaceholderTab(label: 'Profile', icon: Icons.person_outline),
        ],
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }
}

// ─── Bottom Navigation Bar ────────────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(bottomNavIndexProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: index),
              _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics', index: 1, current: index),
              _NavItem(icon: Icons.self_improvement, label: 'Mindful', index: 2, current: index),
              _NavItem(icon: Icons.people_outline, label: 'Family', index: 3, current: index),
              _NavItem(icon: Icons.person_outline, label: 'Profile', index: 4, current: index),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(bottomNavIndexProvider.notifier).state = index,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.primary : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home Tab (main dashboard) ────────────────────────────────────────────────
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final todayStressAsync = ref.watch(todayStressProvider);
    final streakAsync = ref.watch(streakProvider);
    final tip = ref.watch(dailyTipProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            title: userAsync.when(
              data: (user) => _GreetingHeader(user: user),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const Text('SerenityAI'),
            ),
            actions: [
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined, size: 26),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Stress Gauge Card ──────────────────────────────────────
                todayStressAsync.when(
                  data: (log) => _StressGaugeCard(log: log),
                  loading: () => const _StressGaugeCard(log: null),
                  error: (e, _) => const _StressGaugeCard(log: null),
                ),
                const SizedBox(height: 20),

                // ── Quick Actions Row ──────────────────────────────────────
                _QuickActionsRow(),
                const SizedBox(height: 20),

                // ── Check-In Cards ─────────────────────────────────────────
                _CheckInSection(),
                const SizedBox(height: 20),

                // ── Streak + Stats row ─────────────────────────────────────
                streakAsync.when(
                  data: (streak) => _StatsRow(streak: streak),
                  loading: () => const _StatsRow(streak: 0),
                  error: (_, __) => const _StatsRow(streak: 0),
                ),
                const SizedBox(height: 20),

                // ── Daily Tip Card ─────────────────────────────────────────
                _DailyTipCard(tip: tip),
                const SizedBox(height: 20),

                // ── Weekly Trend Mini Chart ────────────────────────────────
                _WeeklyTrendCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greeting Header ──────────────────────────────────────────────────────────
class _GreetingHeader extends StatelessWidget {
  final UserModel? user;
  const _GreetingHeader({this.user});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_greeting, ${user?.firstName ?? 'Friend'} 👋',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          _formattedDate(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textLight),
        ),
      ],
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

// ─── Stress Gauge Card ────────────────────────────────────────────────────────
class _StressGaugeCard extends StatelessWidget {
  final StressLogModel? log;
  const _StressGaugeCard({this.log});

  @override
  Widget build(BuildContext context) {
    final score = log?.finalStressScore ?? 0.0;
    final level = log?.stressLevel ?? 'no data';
    final color = log != null ? AppColors.stressColor(score) : AppColors.textLight;
    final hasData = log != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: hasData
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        )
            : null,
        color: hasData ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasData ? color.withOpacity(0.25) : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Stress",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasData ? score.toStringAsFixed(0) : '--',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StressLevelBadge(level: level, color: color),
                  ],
                ),
              ),
              _StressGaugePainter(score: score, color: color),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            _ScoreBreakdownRow(log: log!),
          ] else ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Tap Quick Scan to measure stress',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StressLevelBadge extends StatelessWidget {
  final String level;
  final Color color;
  const _StressLevelBadge({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StressGaugePainter extends StatelessWidget {
  final double score;
  final Color color;
  const _StressGaugePainter({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _ArcPainter(score: score, color: color),
        child: Center(
          child: Icon(
            _icon,
            size: 32,
            color: color,
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    if (score <= 25) return Icons.sentiment_very_satisfied_outlined;
    if (score <= 50) return Icons.sentiment_neutral_outlined;
    if (score <= 75) return Icons.sentiment_dissatisfied_outlined;
    return Icons.sentiment_very_dissatisfied_outlined;
  }
}

class _ArcPainter extends CustomPainter {
  final double score;
  final Color color;
  const _ArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.15);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Progress
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * (score / 100),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.score != score || old.color != color;
}

class _ScoreBreakdownRow extends StatelessWidget {
  final StressLogModel log;
  const _ScoreBreakdownRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _BreakdownItem(label: 'HRV', value: log.cameraHRVScore, icon: Icons.camera_alt_outlined),
        _BreakdownItem(label: 'Voice', value: log.voiceScore, icon: Icons.mic_outlined),
        _BreakdownItem(label: 'Usage', value: log.phoneUsageScore, icon: Icons.phone_android_outlined),
        _BreakdownItem(label: 'Check-in', value: log.checkInScore, icon: Icons.checklist_outlined),
      ],
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  const _BreakdownItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stressColor(value);
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textLight),
        ),
      ],
    );
  }
}

// ─── Quick Actions Row ────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.camera_alt_outlined,
                label: 'Camera\nScan',
                color: const Color(0xFF6C63FF),
                onTap: () => context.push(AppRoutes.cameraScan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.mic_outlined,
                label: 'Voice\nCheck-in',
                color: const Color(0xFF48CAE4),
                onTap: () => context.push(AppRoutes.voiceCheckin),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.self_improvement,
                label: 'Breathe',
                color: const Color(0xFF4CAF50),
                onTap: () => context.push(AppRoutes.breathing),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.people_outline,
                label: 'Family',
                color: const Color(0xFFFF9800),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Check-In Section ─────────────────────────────────────────────────────────
class _CheckInSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isMorning = now.hour < 14;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Check-In', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CheckInCard(
                icon: '🌅',
                title: 'Morning',
                subtitle: 'Sleep & energy',
                isActive: isMorning,
                isCompleted: false,
                onTap: () => context.push(AppRoutes.morningCheckin),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CheckInCard(
                icon: '🌙',
                title: 'Evening',
                subtitle: 'Mood & gratitude',
                isActive: !isMorning,
                isCompleted: false,
                onTap: () => context.push(AppRoutes.eveningCheckin),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback onTap;

  const _CheckInCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppColors.success.withOpacity(0.08)
              : isActive
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? AppColors.success.withOpacity(0.3)
                : isActive
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                if (isCompleted)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  )
                else if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isCompleted
                    ? AppColors.success
                    : isActive
                    ? AppColors.primary
                    : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isCompleted ? 'Completed ✓' : subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Row (Streak + weekly avg) ─────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  final int streak;
  const _StatsRow({required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAvg = ref.watch(weeklyAverageProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6B35),
            label: 'Day Streak',
            value: streak.toString(),
            suffix: streak == 1 ? 'day' : 'days',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: weeklyAvg.when(
            data: (avg) => _StatCard(
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.secondary,
              label: 'Weekly Avg',
              value: avg.toStringAsFixed(0),
              suffix: '/ 100',
            ),
            loading: () => const _StatCard(
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.secondary,
              label: 'Weekly Avg',
              value: '--',
              suffix: '/ 100',
            ),
            error: (_, __) => const _StatCard(
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.secondary,
              label: 'Weekly Avg',
              value: '--',
              suffix: '/ 100',
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String suffix;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76), // ← fix #1
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // ← fix #2
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              const SizedBox(height: 2),
              Row(                                        // ← fix #3
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    suffix,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Daily Tip Card ───────────────────────────────────────────────────────────
class _DailyTipCard extends StatelessWidget {
  final String tip;
  const _DailyTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9C95FF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('💡', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Wellness Tip',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withOpacity(0.75),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weekly Trend Mini Card ───────────────────────────────────────────────────
class _WeeklyTrendCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(stressHistoryProvider(7));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7-Day Trend', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View All →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            data: (logs) => logs.isEmpty
                ? _EmptyTrendState()
                : _TrendBars(logs: logs),
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const Text('Could not load trend data.'),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrendState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          'Complete check-ins to see your trend',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  final List<StressLogModel> logs;
  const _TrendBars({required this.logs});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Build a map of weekday → last score that day
    final map = <int, double>{};
    for (final log in logs) {
      map[log.date.weekday] = log.finalStressScore;
    }

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final weekday = i + 1; // 1=Mon … 7=Sun
          final score = map[weekday];
          final color = score != null
              ? AppColors.stressColor(score)
              : AppColors.border;
          final barH = score != null ? (score / 100 * 56).clamp(4.0, 56.0) : 4.0;
          final isToday = DateTime.now().weekday == weekday;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (score != null)
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                width: 28,
                height: barH,
                decoration: BoxDecoration(
                  color: color.withOpacity(score != null ? 1 : 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dayLabels[i],
                style: TextStyle(
                  fontSize: 10,
                  color: isToday ? AppColors.primary : AppColors.textLight,
                  fontWeight:
                  isToday ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Placeholder Tab (for unbuilt tabs) ──────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderTab({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              '$label Screen',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}