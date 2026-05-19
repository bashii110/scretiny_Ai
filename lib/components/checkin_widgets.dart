import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// checkin_widgets.dart
//
// Shared UI components consumed by both:
//   • morning_checkin_screen.dart
//   • evening_checkin_screen.dart
//
// Widgets exported:
//   • CheckinTopBar          – segmented progress bar + back button
//   • CheckinBottomCta       – gradient submit / continue button
//   • CheckinStepShell       – consistent page scaffold (emoji, title, subtitle)
//   • CheckinSliderCard      – single labelled 1–5 segmented slider card
//   • CheckinDualSliderStep  – two SliderCards stacked with a shared header
//   • CheckinRatingPills     – animated pill row showing all 5 labels
//   • CheckinGratitudeStep   – free-text gratitude entry with daily prompt
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// CheckinTopBar
// ─────────────────────────────────────────────────────────────────────────────

class CheckinTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;

  const CheckinTopBar({
    super.key,
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
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
            color: AppColors.textDark,
          ),
          Expanded(
            child: Row(
              children: List.generate(totalSteps, (i) {
                final active = i <= currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: active ? AppColors.primary : AppColors.border,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${currentStep + 1} / $totalSteps',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckinBottomCta
// ─────────────────────────────────────────────────────────────────────────────

class CheckinBottomCta extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const CheckinBottomCta({
    super.key,
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
                gradient: isLoading ? null : AppColors.primaryGradient,
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
                    valueColor:
                    AlwaysStoppedAnimation(AppColors.primary),
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
// CheckinStepShell
// ─────────────────────────────────────────────────────────────────────────────

class CheckinStepShell extends StatelessWidget {
  final String? emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const CheckinStepShell({
    super.key,
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
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckinSliderCard
// ─────────────────────────────────────────────────────────────────────────────

class CheckinSliderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  /// When true, high value = good (green). When false, high = bad (red).
  final bool invert;

  const CheckinSliderCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.invert = false,
  });

  Color get _color {
    if (invert) {
      if (value <= 2) return AppColors.stressHigh;
      if (value == 3) return AppColors.stressMedium;
      return AppColors.stressLow;
    }
    return AppColors.stressColor(((value - 1) / 4) * 100);
  }

  static const _labels = [
    'Very low',
    'Low',
    'Moderate',
    'High',
    'Very high',
  ];

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
          // Header row
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
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Container(
                  key: ValueKey(value),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labels[value - 1],
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
          // Segmented track
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
                      color: filled ? _color : AppColors.border,
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
              Text('1',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight)),
              Text('5',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckinDualSliderStep
// ─────────────────────────────────────────────────────────────────────────────

class CheckinDualSliderStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final String labelA;
  final IconData iconA;
  final int valueA;
  final ValueChanged<int> onChangedA;
  final bool invertA;
  final String labelB;
  final IconData iconB;
  final int valueB;
  final ValueChanged<int> onChangedB;
  final bool invertB;

  const CheckinDualSliderStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.labelA,
    required this.iconA,
    required this.valueA,
    required this.onChangedA,
    this.invertA = false,
    required this.labelB,
    required this.iconB,
    required this.valueB,
    required this.onChangedB,
    this.invertB = false,
  });

  @override
  Widget build(BuildContext context) {
    return CheckinStepShell(
      emoji: null,
      title: title,
      subtitle: subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckinSliderCard(
            label: labelA,
            icon: iconA,
            value: valueA,
            onChanged: onChangedA,
            invert: invertA,
          ),
          const SizedBox(height: 16),
          CheckinSliderCard(
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

// ─────────────────────────────────────────────────────────────────────────────
// CheckinRatingPills
// ─────────────────────────────────────────────────────────────────────────────

class CheckinRatingPills extends StatelessWidget {
  final int value; // 1–5
  final List<String> labels;

  const CheckinRatingPills({
    super.key,
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
              color:
              isActive ? AppColors.primary : AppColors.textLight,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckinGratitudeStep
// ─────────────────────────────────────────────────────────────────────────────

class CheckinGratitudeStep extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Evening-specific prompts focus on reflection rather than anticipation.
  final bool isEvening;

  const CheckinGratitudeStep({
    super.key,
    required this.controller,
    required this.onChanged,
    this.isEvening = false,
  });

  static const _morningPrompts = [
    'A person who made me smile recently',
    'Something small that went well yesterday',
    'A strength I showed this week',
    'Something I am looking forward to today',
    'A moment of peace I had',
  ];

  static const _eveningPrompts = [
    'One good thing that happened today',
    'A kind act I gave or received',
    'Something I learned today',
    'A challenge I handled well',
    'A small joy I noticed today',
  ];

  @override
  Widget build(BuildContext context) {
    final prompts = isEvening ? _eveningPrompts : _morningPrompts;
    final prompt = prompts[DateTime.now().day % prompts.length];

    return CheckinStepShell(
      emoji: isEvening ? '✨' : '🌸',
      title: isEvening
          ? 'Reflect on\nyour day'
          : 'One thing to\nbe grateful for',
      subtitle: isEvening
          ? 'Taking a moment to reflect builds resilience over time.'
          : 'Gratitude rewires the brain for positivity.',
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
              border:
              Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Try: "$prompt"',
                    style: const TextStyle(
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
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 5,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Write anything, even one sentence…',
              alignLabelWithHint: true,
              counterStyle: TextStyle(
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