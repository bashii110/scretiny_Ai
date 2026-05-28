import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_color.dart';
import '../provider/checkin_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// morning_checkin_screen.dart
//
// 5-step animated morning check-in flow.
//
// Step 0 — Sleep quality       (1–5 moon icons)
// Step 1 — Energy level        (1–5 bolt icons)
// Step 2 — Anxiety + clarity   (dual sliders)
// Step 3 — Work stress + mood  (dual sliders)
// Step 4 — Gratitude note      (free text)
//
// Architecture:
//   • ConsumerStatefulWidget drives the PageView animation.
//   • All form state lives in CheckInController (checkin_provider.dart).
//   • On final submit the controller saves to Firestore and pops back.
// ─────────────────────────────────────────────────────────────────────────────

class MorningCheckinScreen extends ConsumerStatefulWidget {
  const MorningCheckinScreen({super.key});

  @override
  ConsumerState<MorningCheckinScreen> createState() =>
      _MorningCheckinScreenState();
}

class _MorningCheckinScreenState extends ConsumerState<MorningCheckinScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _gratitudeController = TextEditingController();
  late final AnimationController _progressController;
  late final AnimationController _entryController;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  static const _totalSteps = 5;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));
    _entryController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _gratitudeController.dispose();
    _progressController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next() {
    final state = ref.read(checkinControllerProvider);
    if (state.currentStep < _totalSteps - 1) {
      ref.read(checkinControllerProvider.notifier).nextStep();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
      HapticFeedback.selectionClick();
    } else {
      _submit();
    }
  }

  void _prev() {
    final state = ref.read(checkinControllerProvider);
    if (state.currentStep > 0) {
      ref.read(checkinControllerProvider.notifier).prevStep();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
      HapticFeedback.selectionClick();
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final success =
    await ref.read(checkinControllerProvider.notifier).submitMorning();
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      context.pop();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinControllerProvider);
    final isLast = state.currentStep == _totalSteps - 1;

    // Error snackbar
    ref.listen(checkinControllerProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
          ),
        );
        ref.read(checkinControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
                _TopBar(
                  currentStep: state.currentStep,
                  totalSteps: _totalSteps,
                  onBack: _prev,
                ),

                // ── Page content ─────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _SleepStep(
                        value: state.sleepQuality,
                        onChanged: ref
                            .read(checkinControllerProvider.notifier)
                            .setSleepQuality,
                      ),
                      _EnergyStep(
                        value: state.energyLevel,
                        onChanged: ref
                            .read(checkinControllerProvider.notifier)
                            .setEnergyLevel,
                      ),
                      _DualSliderStep(
                        title: 'Mind & anxiety',
                        subtitle:
                        'How calm does your mind feel right now?',
                        labelA: 'Anxiety level',
                        iconA: Icons.psychology_outlined,
                        valueA: state.anxietyLevel,
                        onChangedA: ref
                            .read(checkinControllerProvider.notifier)
                            .setAnxietyLevel,
                        labelB: 'Mental clarity',
                        iconB: Icons.lightbulb_outline_rounded,
                        valueB: state.mentalClarity,
                        onChangedB: ref
                            .read(checkinControllerProvider.notifier)
                            .setMentalClarity,
                        invertB: true,
                      ),
                      _DualSliderStep(
                        title: 'Work & mood',
                        subtitle:
                        'How are stress and your overall mood sitting today?',
                        labelA: 'Work stress',
                        iconA: Icons.work_outline_rounded,
                        valueA: state.workStress,
                        onChangedA: ref
                            .read(checkinControllerProvider.notifier)
                            .setWorkStress,
                        labelB: 'Overall mood',
                        iconB: Icons.sentiment_satisfied_alt_outlined,
                        valueB: state.overallMood,
                        onChangedB: ref
                            .read(checkinControllerProvider.notifier)
                            .setOverallMood,
                        invertB: true,
                      ),
                      _GratitudeStep(
                        controller: _gratitudeController,
                        onChanged: ref
                            .read(checkinControllerProvider.notifier)
                            .setGratitudeNote,
                      ),
                    ],
                  ),
                ),

                // ── Bottom CTA ────────────────────────────────────────────
                _BottomCta(
                  label: isLast ? 'Complete check-in' : 'Continue',
                  isLoading: state.isSubmitting,
                  onTap: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar — back button + animated segmented progress + step label
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;

  const _TopBar({
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          // Back / close button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
            color: AppColors.textDark,
          ),
          // Segmented progress pills
          Expanded(
            child: Row(
              children: List.generate(_totalSteps, (i) {
                final done = i < currentStep;
                final active = i == currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: done || active
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          // Step counter
          Text(
            '${currentStep + 1} / $_totalSteps',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: non_constant_identifier_names
  static const _totalSteps = 5;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom CTA
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _BottomCta({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: isLoading
                    ? null
                    : AppColors.primaryGradient,
                color: isLoading ? AppColors.border : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Sleep quality
// 5 moon icons that fill progressively. Tap any to select.
// ─────────────────────────────────────────────────────────────────────────────

class _SleepStep extends StatelessWidget {
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  const _SleepStep({required this.value, required this.onChanged});

  static const _labels = ['Very poor', 'Poor', 'Fair', 'Good', 'Excellent'];
  static const _moods = ['😫', '😔', '😐', '🙂', '😊'];

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      emoji: '🌙',
      title: 'How did you sleep?',
      subtitle: 'Quality sleep is the foundation of a good day.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Moon rating row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final selected = i < value;
              final isCurrent = i == value - 1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i + 1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isCurrent ? 1.25 : (selected ? 1.1 : 1.0),
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '🌙',
                      style: TextStyle(
                        fontSize: 38,
                        color: selected ? null : Colors.black12,
                      ).merge(
                        TextStyle(
                          shadows: selected
                              ? [
                            Shadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                            )
                          ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _labels[value - 1],
              key: ValueKey(value),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _moods[value - 1],
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 24),
          // Description chips
          _RatingDescriptionRow(value: value, labels: _labels),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Energy level
// 5 bolt icons with animated colour fill
// ─────────────────────────────────────────────────────────────────────────────

class _EnergyStep extends StatelessWidget {
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  const _EnergyStep({required this.value, required this.onChanged});

  static const _labels = [
    'Exhausted',
    'Low energy',
    'Okay',
    'Energised',
    'Fully charged',
  ];

  static const _colors = [
    Color(0xFFE53935),
    Color(0xFFFF7043),
    Color(0xFFFFB300),
    Color(0xFF66BB6A),
    Color(0xFF00ACC1),
  ];

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      emoji: '⚡',
      title: 'Energy level?',
      subtitle: 'How charged up do you feel this morning?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Energy bar track
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Row(
                children: List.generate(5, (i) {
                  final filled = i < value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(i + 1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        color: filled
                            ? _colors[value - 1].withOpacity(0.85)
                            : Colors.transparent,
                        child: Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 26,
                            color: filled
                                ? Colors.white
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _labels[value - 1],
              key: ValueKey(value),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _colors[value - 1],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _RatingDescriptionRow(value: value, labels: _labels),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps 2 & 3 — Dual slider step (reusable)
// ─────────────────────────────────────────────────────────────────────────────

class _DualSliderStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final String labelA;
  final IconData iconA;
  final int valueA;
  final ValueChanged<int> onChangedA;
  final String labelB;
  final IconData iconB;
  final int valueB;
  final ValueChanged<int> onChangedB;

  /// When true, the B slider is inverted in meaning (5 = good).
  final bool invertB;

  const _DualSliderStep({
    required this.title,
    required this.subtitle,
    required this.labelA,
    required this.iconA,
    required this.valueA,
    required this.onChangedA,
    required this.labelB,
    required this.iconB,
    required this.valueB,
    required this.onChangedB,
    this.invertB = false,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      emoji: null,
      title: title,
      subtitle: subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SliderCard(
            label: labelA,
            icon: iconA,
            value: valueA,
            onChanged: onChangedA,
            invert: false,
          ),
          const SizedBox(height: 16),
          _SliderCard(
            label: labelB,
            icon: iconB,
            value: valueB,
            onChanged: onChangedB,
            invert: invertB,
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  /// When true, high value = good (green). When false, high = bad (red).
  final bool invert;

  const _SliderCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.invert,
  });

  Color get _color {
    if (invert) {
      // High value is good
      if (value <= 2) return AppColors.stressHigh;
      if (value == 3) return AppColors.stressMedium;
      return AppColors.stressLow;
    } else {
      // High value is bad (stress)
      return AppColors.stressColor(((value - 1) / 4) * 100);
    }
  }

  static const _lowHigh = ['Very low', 'Low', 'Moderate', 'High', 'Very high'];

  @override
  Widget build(BuildContext context) {
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
          // Label row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Container(
                  key: ValueKey(value),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _lowHigh[value - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Custom segmented track
          Row(
            children: List.generate(5, (i) {
              final filled = i < value;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i + 1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: filled
                          ? _color
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textLight),
              ),
              Text(
                '5',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Gratitude note
// ─────────────────────────────────────────────────────────────────────────────

class _GratitudeStep extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _GratitudeStep({
    required this.controller,
    required this.onChanged,
  });

  static const _prompts = [
    'A person who made me smile',
    'Something small that went well',
    'A strength I showed yesterday',
    'Something I am looking forward to',
    'A moment of peace I had',
  ];

  @override
  Widget build(BuildContext context) {
    // Pick a deterministic daily prompt
    final prompt = _prompts[DateTime.now().day % _prompts.length];

    return _StepShell(
      emoji: '🌸',
      title: 'One thing to\nbe grateful for',
      subtitle: 'Gratitude rewires the brain for positivity.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt chip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Try: "$prompt"',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Text field
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 5,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Write anything, even one sentence…',
              alignLabelWithHint: true,
              counterStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared shell — consistent page layout for every step
// ─────────────────────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  final String? emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji header
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
          ],
          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          // Step-specific content
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rating description row — small pills showing all 5 labels
// ─────────────────────────────────────────────────────────────────────────────

class _RatingDescriptionRow extends StatelessWidget {
  final int value; // 1–5
  final List<String> labels;

  const _RatingDescriptionRow({
    required this.value,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(5, (i) {
        final isActive = i == value - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(
            labels[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight:
              isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? AppColors.primary
                  : AppColors.textLight,
            ),
          ),
        );
      }),
    );
  }
}