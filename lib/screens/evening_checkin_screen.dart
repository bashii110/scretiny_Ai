import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../components/app_color.dart';
import '../components/checkin_widgets.dart';
import '../provider/checkin_provider.dart';


// ─────────────────────────────────────────────────────────────────────────────
// evening_checkin_screen.dart
//
// 4-step animated evening check-in flow.
//
// Step 0 — Mood wheel          (7 emoji moods, tap to select)
// Step 1 — Anxiety + clarity   (dual segmented sliders)
// Step 2 — Work stress + mood  (dual segmented sliders)
// Step 3 — Daily reflection    (free text with evening-specific prompts)
//
// Differences from morning:
//   • 4 steps instead of 5  (no sleep / energy — those are morning concerns)
//   • Step 0 is a mood wheel with 7 states instead of moon icons
//   • Colour theme uses warmer sunset tones
//   • Gratitude step uses evening reflection prompts
//   • Calls submitEvening() on the shared CheckInController
// ─────────────────────────────────────────────────────────────────────────────

class EveningCheckinScreen extends ConsumerStatefulWidget {
  const EveningCheckinScreen({super.key});

  @override
  ConsumerState<EveningCheckinScreen> createState() =>
      _EveningCheckinScreenState();
}

class _EveningCheckinScreenState
    extends ConsumerState<EveningCheckinScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _reflectionController = TextEditingController();
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  static const _totalSteps = 4;

  @override
  void initState() {
    super.initState();
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
    _reflectionController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next() {
    final step = ref.read(checkinControllerProvider).currentStep;
    if (step < _totalSteps - 1) {
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
    final step = ref.read(checkinControllerProvider).currentStep;
    if (step > 0) {
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
    await ref.read(checkinControllerProvider.notifier).submitEvening();
    if (success && mounted) {
      HapticFeedback.mediumImpact();
      _showCompletionSheet();
    }
  }

  // ── Completion bottom sheet ────────────────────────────────────────────────

  void _showCompletionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _CompletionSheet(
        onDone: () {
          Navigator.of(context).pop(); // close sheet
          context.pop();              // back to home
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinControllerProvider);
    final isLast = state.currentStep == _totalSteps - 1;
    final notifier = ref.read(checkinControllerProvider.notifier);

    // Error snackbar
    ref.listen(checkinControllerProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
          ),
        );
        notifier.clearError();
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
                CheckinTopBar(
                  currentStep: state.currentStep,
                  totalSteps: _totalSteps,
                  onBack: _prev,
                ),

                // ── Pages ─────────────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Step 0 — Mood wheel
                      _MoodWheelStep(
                        value: state.overallMood,
                        onChanged: notifier.setOverallMood,
                      ),

                      // Step 1 — Anxiety & mental clarity
                      CheckinDualSliderStep(
                        title: 'Mind check',
                        subtitle:
                        'How did anxiety and mental clarity feel today?',
                        labelA: 'Anxiety level',
                        iconA: Icons.psychology_outlined,
                        valueA: state.anxietyLevel,
                        onChangedA: notifier.setAnxietyLevel,
                        invertA: false,
                        labelB: 'Mental clarity',
                        iconB: Icons.lightbulb_outline_rounded,
                        valueB: state.mentalClarity,
                        onChangedB: notifier.setMentalClarity,
                        invertB: true,
                      ),

                      // Step 2 — Work stress & energy
                      CheckinDualSliderStep(
                        title: 'Work & energy',
                        subtitle:
                        'How did work stress and your energy hold up?',
                        labelA: 'Work stress',
                        iconA: Icons.work_outline_rounded,
                        valueA: state.workStress,
                        onChangedA: notifier.setWorkStress,
                        invertA: false,
                        labelB: 'Energy level',
                        iconB: Icons.bolt_rounded,
                        valueB: state.energyLevel,
                        onChangedB: notifier.setEnergyLevel,
                        invertB: true,
                      ),

                      // Step 3 — Evening reflection
                      CheckinGratitudeStep(
                        controller: _reflectionController,
                        onChanged: notifier.setGratitudeNote,
                        isEvening: true,
                      ),
                    ],
                  ),
                ),

                // ── CTA ───────────────────────────────────────────────────
                CheckinBottomCta(
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
// Step 0 — Mood wheel
//
// 7 emoji mood states in two rows.
// Tapping one highlights it with an animated glow ring and shows
// the mood label + a contextual colour.
// The overallMood field (1–5) maps to the 7-state wheel via _moodToSlider().
// ─────────────────────────────────────────────────────────────────────────────

class _MoodWheelStep extends StatefulWidget {
  final int value;           // 1–5 stored value
  final ValueChanged<int> onChanged;

  const _MoodWheelStep({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_MoodWheelStep> createState() => _MoodWheelStepState();
}

class _MoodWheelStepState extends State<_MoodWheelStep>
    with SingleTickerProviderStateMixin {
  // Internal 0-based index into the 7 moods
  int _selectedIndex = 3; // default = neutral

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // ── Mood data ─────────────────────────────────────────────────────────────

  static const _moods = [
    _Mood('😢', 'Sad',        Color(0xFF5C6BC0)),
    _Mood('😟', 'Anxious',    Color(0xFF7E57C2)),
    _Mood('😐', 'Meh',        Color(0xFF78909C)),
    _Mood('🙂', 'Okay',       Color(0xFF26A69A)),
    _Mood('😊', 'Good',       Color(0xFF42A5F5)),
    _Mood('😄', 'Happy',      Color(0xFF66BB6A)),
    _Mood('🤩', 'Fantastic',  Color(0xFFFFCA28)),
  ];

  /// Maps 7-index → 1–5 scale for CheckInModel storage.
  /// 0,1 → 1 | 2 → 2 | 3 → 3 | 4 → 4 | 5,6 → 5
  static int _indexToSlider(int i) {
    if (i <= 1) return 1;
    if (i == 2) return 2;
    if (i == 3) return 3;
    if (i == 4) return 4;
    return 5;
  }

  /// Maps 1–5 → nearest 7-index (reverse of above).
  static int _sliderToIndex(int v) {
    switch (v) {
      case 1: return 0;
      case 2: return 2;
      case 3: return 3;
      case 4: return 4;
      case 5: return 6;
      default: return 3;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = _sliderToIndex(widget.value);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _select(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
    widget.onChanged(_indexToSlider(index));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mood = _moods[_selectedIndex];

    return CheckinStepShell(
      emoji: '🌆',
      title: 'How are you\nfeeling tonight?',
      subtitle: 'Tap the emoji that best matches your mood right now.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected mood hero display
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: mood.color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: mood.color.withOpacity(0.4),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: mood.color.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Text(
                    mood.emoji,
                    key: ValueKey(_selectedIndex),
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mood label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              mood.label,
              key: ValueKey(_selectedIndex),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: mood.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Emoji grid — two rows: 4 top, 3 bottom
          _buildMoodGrid(),
        ],
      ),
    );
  }

  Widget _buildMoodGrid() {
    return Column(
      children: [
        // Row 1 — indices 0–3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) => _MoodTile(
            mood: _moods[i],
            isSelected: _selectedIndex == i,
            onTap: () => _select(i),
          )),
        ),
        const SizedBox(height: 16),
        // Row 2 — indices 4–6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) => _MoodTile(
            mood: _moods[i + 4],
            isSelected: _selectedIndex == i + 4,
            onTap: () => _select(i + 4),
          )),
        ),
      ],
    );
  }
}

// Individual mood tile widget
class _MoodTile extends StatelessWidget {
  final _Mood mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodTile({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? mood.color.withOpacity(0.12)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? mood.color.withOpacity(0.5)
                : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 220),
              child: Text(
                mood.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? mood.color : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Immutable mood data class
class _Mood {
  final String emoji;
  final String label;
  final Color color;

  const _Mood(this.emoji, this.label, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion bottom sheet
// Shown after a successful submitEvening() call.
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionSheet extends StatefulWidget {
  final VoidCallback onDone;

  const _CompletionSheet({required this.onDone});

  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated check icon
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Evening check-in\ncomplete 🌙',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Great job taking time for yourself today.\nYour stress score has been updated.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),

            // Streak nudge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF6B35),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Keep your streak going — see you tomorrow!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFF6B35).withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Material(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: widget.onDone,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Back to home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}