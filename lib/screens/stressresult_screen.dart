import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_color.dart';
import '../components/app_router.dart';
import '../domain_model/stress_model.dart';
import '../provider/stress_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// stress_result_screen.dart
//
// Full-page stress result screen — navigated to after any scan or check-in
// completes, and also accessible from the home screen gauge card.
//
// Sections (scrollable):
//   1. Large animated arc gauge            — finalStressScore + level badge
//   2. Five-component breakdown            — camera, voice, phone, check-in, sleep
//   3. Completeness banner                 — nudge for missing components
//   4. AI-derived insight card             — contextual recommendation
//   5. Trigger tags                        — editable stress trigger chips
//   6. Quick-action row                    — Breathe / Meditate / Talk
//   7. 7-day mini trend                    — sparkline bar chart
//
// Entry modes:
//   • Route arg = null   → reads todayStressProvider (home screen / standalone)
//   • Route arg = log    — receives a StressLogModel directly (post-scan flow)
//
// The screen is purely read-only — no writes happen here.
// All data comes from stress_provider.dart providers.
// ─────────────────────────────────────────────────────────────────────────────

class StressResultScreen extends ConsumerStatefulWidget {
  /// When non-null, this log is displayed directly without hitting Firestore.
  /// Used by camera_scan_screen and voice_checkin_screen after saving.
  final StressLogModel? log;

  const StressResultScreen({super.key, this.log});

  @override
  ConsumerState<StressResultScreen> createState() =>
      _StressResultScreenState();
}

class _StressResultScreenState extends ConsumerState<StressResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _gaugeController;
  late final AnimationController _entryController;
  late final Animation<double> _gaugeAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _gaugeAnim = CurvedAnimation(
      parent: _gaugeController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    // Stagger gauge after entry
    _entryController.forward().then(
          (_) => _gaugeController.forward(),
    );
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // If a log was passed directly use it; otherwise stream today's log
    final logAsync = widget.log != null
        ? AsyncData<StressLogModel?>(widget.log)
        : ref.watch(todayStressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: logAsync.when(
          data: (log) => log == null
              ? _EmptyState(onBack: () => context.pop())
              : _ResultBody(
            log: log,
            gaugeAnim: _gaugeAnim,
            fadeAnim: _fadeAnim,
            slideAnim: _slideAnim,
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (e, _) => _ErrorState(
            message: e.toString(),
            onBack: () => context.pop(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main scrollable result body
// ─────────────────────────────────────────────────────────────────────────────

class _ResultBody extends ConsumerWidget {
  final StressLogModel log;
  final Animation<double> gaugeAnim;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _ResultBody({
    required this.log,
    required this.gaugeAnim,
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(stressInsightProvider);
    final history = ref.watch(stressHistoryProvider(7));
    final color   = AppColors.stressColor(log.finalStressScore);

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App bar ────────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              floating: true,
              snap: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.textDark,
                ),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Stress result',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 22,
                    color: AppColors.textLight,
                  ),
                  onPressed: () {/* share sheet */},
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Date label ────────────────────────────────────────
                  Center(
                    child: Text(
                      _formattedDate(log.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 1. Gauge ──────────────────────────────────────────
                  _GaugeCard(
                    log: log,
                    animation: gaugeAnim,
                    color: color,
                  ),
                  const SizedBox(height: 20),

                  // ── 2. Component breakdown ────────────────────────────
                  _ComponentBreakdown(log: log),
                  const SizedBox(height: 16),

                  // ── 3. Completeness banner ────────────────────────────
                  _CompletenessBanner(log: log),
                  const SizedBox(height: 20),

                  // ── 4. Insight card ───────────────────────────────────
                  insight.when(
                    data: (text) => _InsightCard(
                      text: text,
                      color: color,
                    ),
                    loading: () => const _InsightCardSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),

                  // ── 5. Trigger tags ───────────────────────────────────
                  if (log.triggers.isNotEmpty) ...[
                    _TriggerSection(triggers: log.triggers),
                    const SizedBox(height: 20),
                  ],

                  // ── 6. Quick actions ──────────────────────────────────
                  _QuickActions(),
                  const SizedBox(height: 20),

                  // ── 7. 7-day mini trend ───────────────────────────────
                  history.when(
                    data: (logs) => logs.length > 1
                        ? _MiniTrend(logs: logs, today: log)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formattedDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final isToday = d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
    if (isToday) {
      return 'Today · ${_time(d)}';
    }
    return '${months[d.month - 1]} ${d.day}, ${d.year} · ${_time(d)}';
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Gauge card
// ─────────────────────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  final StressLogModel log;
  final Animation<double> animation;
  final Color color;

  const _GaugeCard({
    required this.log,
    required this.animation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final score = log.finalStressScore;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value * (score / 100);
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.10),
                color.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: color.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Arc gauge
              SizedBox(
                width: 200,
                height: 130,
                child: CustomPaint(
                  painter: _HalfArcPainter(
                    progress: progress,
                    color: color,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (score * animation.value)
                                .toStringAsFixed(0),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          Text(
                            '/ 100',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Level badge
              _LevelBadge(level: log.stressLevel, color: color),
              const SizedBox(height: 12),

              // Sub-label
              Text(
                _sublabel(log.stressLevel),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _sublabel(String level) {
    switch (level) {
      case 'low':
        return 'Your nervous system is calm and well-regulated.';
      case 'medium':
        return 'Mild stress present — manageable with a short break.';
      case 'high':
        return 'Elevated stress. Consider a breathing or movement break.';
      case 'critical':
        return 'High load detected. Rest and support are recommended.';
      default:
        return '';
    }
  }
}

class _LevelBadge extends StatelessWidget {
  final String level;
  final Color color;

  const _LevelBadge({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_levelIcon(level), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${level.toUpperCase()} STRESS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'low':      return Icons.sentiment_very_satisfied_outlined;
      case 'medium':   return Icons.sentiment_neutral_outlined;
      case 'high':     return Icons.sentiment_dissatisfied_outlined;
      case 'critical': return Icons.sentiment_very_dissatisfied_outlined;
      default:         return Icons.help_outline;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Component breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _ComponentBreakdown extends StatelessWidget {
  final StressLogModel log;

  const _ComponentBreakdown({required this.log});

  @override
  Widget build(BuildContext context) {
    final components = [
      _Component(
        label:   'Camera HRV',
        icon:    Icons.camera_alt_outlined,
        score:   log.cameraHRVScore,
        weight:  '30%',
        hasData: log.cameraHRVScore > 0,
        route:   AppRoutes.cameraScan,
      ),
      _Component(
        label:   'Voice',
        icon:    Icons.mic_outlined,
        score:   log.voiceScore,
        weight:  '25%',
        hasData: log.voiceScore > 0,
        route:   AppRoutes.voiceCheckin,
      ),
      _Component(
        label:   'Phone use',
        icon:    Icons.phone_android_outlined,
        score:   log.phoneUsageScore,
        weight:  '20%',
        hasData: log.phoneUsageScore > 0,
        route:   null,
      ),
      _Component(
        label:   'Check-in',
        icon:    Icons.checklist_outlined,
        score:   log.checkInScore,
        weight:  '10%',
        hasData: log.checkInScore > 0,
        route:   AppRoutes.morningCheckin,
      ),
    ];

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
            children: [
              Text(
                'Score breakdown',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Weight',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...components.map(
                (c) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ComponentRow(component: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _Component {
  final String  label;
  final IconData icon;
  final double  score;
  final String  weight;
  final bool    hasData;
  final String? route;

  const _Component({
    required this.label,
    required this.icon,
    required this.score,
    required this.weight,
    required this.hasData,
    required this.route,
  });
}

class _ComponentRow extends StatelessWidget {
  final _Component component;

  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final c = component;
    final color = c.hasData
        ? AppColors.stressColor(c.score)
        : AppColors.border;

    return Row(
      children: [
        // Icon
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(c.icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),

        // Label + bar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    c.hasData
                        ? c.score.toStringAsFixed(0)
                        : '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    height: 5,
                    width: c.hasData
                        ? null
                        : 0,
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width *
                          (c.hasData ? c.score / 100 * 0.7 : 0),
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Weight tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            c.weight,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Completeness banner
// ─────────────────────────────────────────────────────────────────────────────

class _CompletenessBanner extends StatelessWidget {
  final StressLogModel log;

  const _CompletenessBanner({required this.log});

  @override
  Widget build(BuildContext context) {
    final missing = <String>[];
    if (log.cameraHRVScore == 0) missing.add('camera scan');
    if (log.voiceScore == 0) missing.add('voice check-in');
    if (log.checkInScore == 0) missing.add('daily check-in');

    if (missing.isEmpty) {
      // All complete — show a success banner
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.success.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All signals collected — your score is fully accurate.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.success.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Partial — nudge
    final missingStr = missing.join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.warning.withOpacity(0.9),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Partial score — still missing: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: missingStr),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Insight card
// ─────────────────────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final String text;
  final Color color;

  const _InsightCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.secondary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalised insight',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
                    height: 1.6,
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

class _InsightCardSkeleton extends StatelessWidget {
  const _InsightCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Trigger section
// ─────────────────────────────────────────────────────────────────────────────

class _TriggerSection extends StatelessWidget {
  final List<String> triggers;

  const _TriggerSection({required this.triggers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Stress triggers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${triggers.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: triggers
              .map(
                (t) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.label_outline_rounded,
                    size: 14,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    t,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Quick actions
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Take action now',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                emoji: '🌬️',
                label: 'Breathe',
                sublabel: '5 min',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.breathing);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionCard(
                emoji: '🧘',
                label: 'Meditate',
                sublabel: '10 min',
                color: const Color(0xFF7C4DFF),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.meditation);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionCard(
                emoji: '🩺',
                label: 'Therapist',
                sublabel: 'Book',
                color: const Color(0xFF00ACC1),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.therapists);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String    emoji;
  final String    label;
  final String    sublabel;
  final Color     color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. 7-day mini trend
// ─────────────────────────────────────────────────────────────────────────────

class _MiniTrend extends StatelessWidget {
  final List<StressLogModel> logs;
  final StressLogModel today;

  const _MiniTrend({required this.logs, required this.today});

  @override
  Widget build(BuildContext context) {
    // One entry per weekday — keep last log per day
    final byDay = <int, StressLogModel>{};
    for (final l in logs) {
      byDay[l.date.weekday] ??= l;
    }

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
              Text(
                '7-day trend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'avg ${_avg(logs).toStringAsFixed(0)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final log = byDay[weekday];
                final isToday =
                    DateTime.now().weekday == weekday;
                final score = log?.finalStressScore;
                final color = score != null
                    ? AppColors.stressColor(score)
                    : AppColors.border;
                final barH = score != null
                    ? (score / 100 * 52).clamp(4.0, 52.0)
                    : 4.0;

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
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      width: 26,
                      height: barH,
                      decoration: BoxDecoration(
                        color: score != null
                            ? color
                            : color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(5),
                        border: isToday
                            ? Border.all(
                          color: AppColors.primary,
                          width: 2,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dayLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  double _avg(List<StressLogModel> logs) {
    if (logs.isEmpty) return 0;
    return logs
        .map((l) => l.finalStressScore)
        .reduce((a, b) => a + b) /
        logs.length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onBack;

  const _EmptyState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📊', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            'No data yet today',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Complete a camera scan, voice check-in, or daily\ncheck-in to see your stress result.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onBack,
              child: const Text('Back to home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorState({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 52, color: AppColors.danger),
          const SizedBox(height: 20),
          Text(
            'Could not load result',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: onBack,
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

/// Half-arc gauge painter (bottom semicircle, like a speedometer).
/// Sweeps from 225° to 315° (bottom-left to bottom-right).
class _HalfArcPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color color;

  const _HalfArcPainter({required this.progress, required this.color});

  static const _startAngle = math.pi * 0.75;   // 135°
  static const _sweepTotal = math.pi * 1.5;     // 270° sweep

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 12;
    const sw = 10.0;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweepTotal,
      false,
      Paint()
        ..style   = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap   = StrokeCap.round
        ..color   = color.withOpacity(0.12),
    );

    // Coloured segments — low(green) → medium(amber) → high(red)
    final segments = [
      _ArcSegment(AppColors.stressLow,    0.00, 0.25),
      _ArcSegment(AppColors.stressMedium, 0.25, 0.50),
      _ArcSegment(AppColors.stressHigh,   0.50, 0.75),
      _ArcSegment(AppColors.stressCritical, 0.75, 1.00),
    ];

    for (final seg in segments) {
      if (progress <= seg.start) continue;
      final segProgress =
      ((progress - seg.start) / (seg.end - seg.start)).clamp(0.0, 1.0);
      final segSweep = _sweepTotal * (seg.end - seg.start);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle + _sweepTotal * seg.start,
        segSweep * segProgress,
        false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap   = StrokeCap.round
          ..color       = seg.color,
      );
    }

    // Needle dot at tip
    if (progress > 0) {
      final angle =
          _startAngle + _sweepTotal * progress;
      final tipX = center.dx + radius * math.cos(angle);
      final tipY = center.dy + radius * math.sin(angle);

      canvas.drawCircle(
        Offset(tipX, tipY),
        6,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(tipX, tipY),
        3,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_HalfArcPainter old) =>
      old.progress != progress || old.color != color;
}

class _ArcSegment {
  final Color  color;
  final double start; // 0–1
  final double end;   // 0–1
  const _ArcSegment(this.color, this.start, this.end);
}