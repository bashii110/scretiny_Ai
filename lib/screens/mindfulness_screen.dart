import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_color.dart';
import '../components/app_router.dart';
import '../domain_model/mindfulness_model.dart';
import '../provider/auth_provider.dart';
import '../provider/mindfulness_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// mindfulness_screen.dart
//
// Main Mindfulness tab (index 2 in BottomNav).
//
// Tabs:
//   0 – Breathing  (local techniques grid)
//   1 – Meditation (Firestore content cards)
//   2 – Prayer     (faith-filtered content)
//   3 – Journal    (placeholder / coming soon)
//
// Stats bar at top shows today's session count and minutes.
// ─────────────────────────────────────────────────────────────────────────────

class MindfulnessScreen extends ConsumerWidget {
  const MindfulnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mindfulnessTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mindfulness',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Find your calm',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Stats bar ───────────────────────────────────────────
                const _StatsBar(),
                const SizedBox(height: 20),

                // ── Tab pills ───────────────────────────────────────────
                _TabPills(selected: tab),
                const SizedBox(height: 20),

                // ── Tab content ─────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _tabContent(tab),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabContent(int tab) {
    switch (tab) {
      case 0:
        return const _BreathingTab(key: ValueKey('breathing'));
      case 1:
        return const _MeditationTab(key: ValueKey('meditation'));
      case 2:
        return const _PrayerTab(key: ValueKey('prayer'));
      case 3:
        return const _JournalTab(key: ValueKey('journal'));
      default:
        return const _BreathingTab(key: ValueKey('breathing'));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayMindfulnessProvider);
    final totalMinsAsync = ref.watch(totalMindfulnessMinutesProvider);

    final todaySessions = todayAsync.valueOrNull?.length ?? 0;
    final todayMins = todayAsync.valueOrNull
        ?.fold<int>(0, (a, s) => a + s.durationSeconds) ??
        0;
    final totalMins = totalMinsAsync.valueOrNull ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StatChip(
            emoji: '🧘',
            label: 'Today',
            value: '$todaySessions ${todaySessions == 1 ? 'session' : 'sessions'}',
          ),
          _VerticalDivider(),
          _StatChip(
            emoji: '⏱',
            label: 'Today',
            value: '${(todayMins / 60).floor()}m ${todayMins % 60}s',
          ),
          _VerticalDivider(),
          _StatChip(
            emoji: '📅',
            label: '30 days',
            value: '${totalMins}m',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatChip({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Pills
// ─────────────────────────────────────────────────────────────────────────────

class _TabPills extends ConsumerWidget {
  final int selected;

  const _TabPills({required this.selected});

  static const _tabs = [
    ('🌬️', 'Breathing'),
    ('🧘', 'Meditation'),
    ('🙏', 'Prayer'),
    ('📓', 'Journal'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = i == selected;
          return GestureDetector(
            onTap: () =>
            ref.read(mindfulnessTabProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Text(_tabs[i].$1,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    _tabs[i].$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Breathing Tab
// ─────────────────────────────────────────────────────────────────────────────

class _BreathingTab extends ConsumerWidget {
  const _BreathingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techniques = ref.watch(breathingTechniqueProvider);
    final userAsync = ref.watch(userProfileProvider);
    final userFaith = userAsync.valueOrNull?.faithPreference ?? 'secular';

    // Filter: show universal + user's faith
    final filtered = techniques
        .where((t) => t.faith == 'all' || t.faith == userFaith)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Breathing Exercises',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Scientifically-backed techniques to calm your nervous system.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textLight),
        ),
        const SizedBox(height: 16),
        ...filtered.map((t) => _BreathingTechniqueCard(technique: t)),
      ],
    );
  }
}

class _BreathingTechniqueCard extends StatelessWidget {
  final BreathingTechnique technique;

  const _BreathingTechniqueCard({required this.technique});

  String get _patternLabel {
    final parts = <String>[
      '${technique.inhaleSeconds}s inhale',
      if (technique.holdInSeconds > 0) '${technique.holdInSeconds}s hold',
      '${technique.exhaleSeconds}s exhale',
      if (technique.holdOutSeconds > 0) '${technique.holdOutSeconds}s hold',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.breathing),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(technique.emoji,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          technique.name,
                          style:
                          Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (technique.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _patternLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textLight),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    technique.benefit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meditation Tab
// ─────────────────────────────────────────────────────────────────────────────

class _MeditationTab extends ConsumerWidget {
  const _MeditationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(meditationContentProvider);

    return contentAsync.when(
      data: (items) => items.isEmpty
          ? _MeditationPlaceholder()
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guided Meditations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _MeditationCard(content: item)),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => _MeditationPlaceholder(),
    );
  }
}

class _MeditationPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Show curated local meditation stubs when Firestore is empty
    final stubs = [
      (
      '🌅',
      'Morning Clarity',
      '10 min',
      'Start your day with a clear and focused mind.',
      false,
      ),
      (
      '🌙',
      'Sleep Induction',
      '15 min',
      'Progressive relaxation to ease you into restful sleep.',
      false,
      ),
      (
      '💆',
      'Anxiety Release',
      '8 min',
      'Body scan technique to dissolve tension and worry.',
      false,
      ),
      (
      '🎯',
      'Focus & Flow',
      '12 min',
      'Deep work preparation meditation for peak performance.',
      true,
      ),
      (
      '❤️',
      'Loving-Kindness',
      '10 min',
      'Metta meditation to cultivate compassion and warmth.',
      true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guided Meditations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Tap any session to begin.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textLight),
        ),
        const SizedBox(height: 16),
        ...stubs.map(
              (s) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child:
                    Text(s.$1, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.$2,
                              style:
                              Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (s.$5)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF9800),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.$3,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.$4,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_outline_rounded,
                    color: AppColors.secondary, size: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MeditationCard extends StatelessWidget {
  final MindfulnessContentModel content;

  const _MeditationCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🧘', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.title,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  content.formattedDuration,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_outline_rounded,
              color: AppColors.secondary, size: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer Tab
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerTab extends ConsumerWidget {
  const _PrayerTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final faith = userAsync.valueOrNull?.faithPreference ?? 'secular';

    final content = _prayerContent[faith] ?? _prayerContent['secular']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content['title'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          content['subtitle'] as String,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textLight),
        ),
        const SizedBox(height: 20),
        ...(content['practices'] as List<Map<String, String>>)
            .map((p) => _PracticeCard(practice: p)),
        const SizedBox(height: 12),
        // Breathing integration CTA
        GestureDetector(
          onTap: () => context.push(AppRoutes.breathing),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🌬️', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mindful Breathing',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      Text(
                        'Pair breathing with your practice for deeper calm.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                            color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const _prayerContent = {
'islam': {
'title': 'Islamic Mindfulness',
'subtitle': 'Dhikr and breath practices rooted in Islamic tradition.',
'practices': [
{
'emoji': '📿',
'name': 'Dhikr Breathing',
'desc': 'Synchronise the breath with SubhanAllah, Alhamdulillah, Allahu Akbar.',
'duration': '5–10 min',
},
{
'emoji': '🌙',
'name': 'Tawakkul Meditation',
'desc': 'Release worries through trust in Allah with guided visualisation.',
'duration': '8 min',
},
{
'emoji': '🤲',
'name': 'Dua & Stillness',
'desc': 'Sit in quiet supplication after Fajr or before sleep.',
'duration': '5 min',
},
],
},
'christian': {
'title': 'Christian Contemplation',
'subtitle': 'Breath prayers and contemplative practices.',
'practices': [
{
'emoji': '✝️',
'name': 'Breath Prayer',
'desc': 'Inhale a name of God, exhale a surrender. Ancient Christian practice.',
'duration': '5 min',
},
{
'emoji': '📖',
'name': 'Lectio Divina',
'desc': 'Slow, contemplative reading of Scripture with silence between verses.',
'duration': '15 min',
},
{
'emoji': '🕊️',
'name': 'Centering Prayer',
'desc': 'Silent consent to Gods presence using a sacred word as anchor.',
'duration': '20 min',
},
],
},
'hindu': {
'title': 'Hindu Mindfulness',
'subtitle': 'Pranayama and devotional practices from the Vedic tradition.',
'practices': [
{
'emoji': '🕉️',
'name': 'Sama Vritti Pranayama',
'desc': 'Equal breathing (4-4-4-4) to balance prana and still the mind.',
'duration': '10 min',
},
{
'emoji': '🪔',
'name': 'Trataka',
'desc': 'Concentrated gazing at a flame to develop one-pointed focus.',
'duration': '10 min',
},
{
'emoji': '🎶',
'name': 'Mantra Japa',
'desc': 'Repetition of a mantra synchronised with the breath.',
'duration': '15 min',
},
],
},
'buddhism': {
'title': 'Buddhist Mindfulness',
'subtitle': 'Practices from the Theravāda and Mahāyāna traditions.',
'practices': [
{
'emoji': '☸️',
'name': 'Anapanasati',
'desc': 'Mindfulness of the natural breath — observe without controlling.',
'duration': '15 min',
},
{
'emoji': '❤️',
'name': 'Metta (Loving-Kindness)',
'desc': 'Cultivate goodwill toward self, loved ones, neutral people, and all beings.',
'duration': '12 min',
},
{
'emoji': '🌏',
'name': 'Body Scan',
'desc': 'Vipassanā-style systematic awareness of bodily sensations.',
'duration': '20 min',
},
],
},
'secular': {
'title': 'Mindful Practices',
'subtitle': 'Evidence-based secular mindfulness techniques.',
'practices': [
{
'emoji': '🧠',
'name': 'MBSR Body Scan',
'desc': 'Mindfulness-Based Stress Reduction body scan for deep relaxation.',
'duration': '20 min',
},
{
'emoji': '🌿',
'name': 'Nature Visualisation',
'desc': 'Guided imagery of peaceful natural settings to lower cortisol.',
'duration': '10 min',
},
{
'emoji': '🪴',
'name': 'Present Moment',
'desc': '5-4-3-2-1 grounding technique using the five senses.',
'duration': '5 min',
},
],
},
};

class _PracticeCard extends StatelessWidget {
  final Map<String, String> practice;

  const _PracticeCard({required this.practice});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(practice['emoji']!,
              style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        practice['name']!,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        practice['duration']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  practice['desc']!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Journal Tab  (Phase 3 placeholder)
// ─────────────────────────────────────────────────────────────────────────────

class _JournalTab extends StatelessWidget {
  const _JournalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📓', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Journal',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your private wellness journal is\ncoming in Phase 3.',
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