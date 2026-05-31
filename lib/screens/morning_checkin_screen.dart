// lib/screens/checkin/morning_checkin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../components/app_color.dart';
import '../../domain_model/checkin_model.dart';
import '../../provider/checkin_provider.dart';
import '../components/widgets/checkin_widgets.dart';


class MorningCheckInScreen extends ConsumerStatefulWidget {
  const MorningCheckInScreen({super.key});

  @override
  ConsumerState<MorningCheckInScreen> createState() =>
      _MorningCheckInScreenState();
}

class _MorningCheckInScreenState
    extends ConsumerState<MorningCheckInScreen> {
  // Form state
  int _sleepQuality = 3;
  int _energyLevel = 3;
  int _anxietyLevel = 3;
  int _mentalClarity = 3;
  int _overallMood = 3;
  int _workStress = 3;
  final _gratitudeCtrl = TextEditingController();
  List<String> _selectedTriggers = [];

  static const _triggers = [
    '😴 Poor sleep',
    '💼 Work pressure',
    '💰 Financial worry',
    '👨‍👩‍👧 Family stress',
    '🏥 Health concern',
    '📱 Overwhelmed',
    '😔 Low mood',
    '🤝 Social anxiety',
  ];

  // Page controller for step-by-step flow
  final _pageController = PageController();
  int _currentStep = 0;
  static const _totalSteps = 4;

  @override
  void dispose() {
    _gratitudeCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    final checkIn = CheckInModel(
      id: const Uuid().v4(),
      userId: '', // Repository fills this from FirebaseAuth.currentUser
      type: 'morning',
      date: DateTime.now(),
      sleepQuality: _sleepQuality,
      anxietyLevel: _anxietyLevel,
      energyLevel: _energyLevel,
      mentalClarity: _mentalClarity,
      overallMood: _overallMood,
      workStress: _workStress,
      gratitudeNote: _gratitudeCtrl.text.trim(),
    );

    final success =
    await ref.read(checkInControllerProvider.notifier).saveCheckIn(checkIn);

    if (success && mounted) {
      _showSuccessAndPop();
    }
  }

  void _showSuccessAndPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(
        emoji: '🌅',
        title: 'Morning logged!',
        subtitle: 'Great start to the day. Your data has been saved.',
        onDone: () {
          Navigator.of(context).pop(); // close dialog
          context.pop(); // go back to home
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInControllerProvider);

    // Show error snackbar
    ref.listen(checkInControllerProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(checkInControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Hero Header ──────────────────────────────────────────────────
          CheckInHeroHeader(
            emoji: '🌅',
            title: 'Morning Check-In',
            subtitle: 'How did you sleep? Let\'s set up your day.',
            gradientStart: const Color(0xFFFF9F43),
            gradientEnd: const Color(0xFFFF6B6B),
          ),

          // ── Back button row ───────────────────────────────────────────────
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: CheckInProgressBar(
                    current: _currentStep + 1,
                    total: _totalSteps,
                  ),
                ),
              ],
            ),
          ),

          // ── Pages ─────────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                // Step 1: Sleep & Energy
                _CheckInPage(
                  children: [
                    EmojiMoodPicker(
                      label: 'Sleep Quality',
                      description:
                      'How well did you sleep last night?',
                      value: _sleepQuality,
                      onChanged: (v) =>
                          setState(() => _sleepQuality = v),
                      emojis: const [
                        '😫',
                        '😴',
                        '😐',
                        '🙂',
                        '😊'
                      ],
                      labels: const [
                        'Terrible',
                        'Poor',
                        'OK',
                        'Good',
                        'Great'
                      ],
                    ),
                    const SizedBox(height: 28),
                    CheckInSliderQuestion(
                      label: 'Energy Level',
                      description:
                      'How energised do you feel right now?',
                      value: _energyLevel,
                      onChanged: (v) =>
                          setState(() => _energyLevel = v),
                      lowLabel: 'Exhausted',
                      highLabel: 'Energised',
                      activeColor: const Color(0xFF4CAF50),
                    ),
                  ],
                ),

                // Step 2: Anxiety & Mental Clarity
                _CheckInPage(
                  children: [
                    CheckInSliderQuestion(
                      label: 'Anxiety Level',
                      description:
                      'How anxious or worried do you feel?',
                      value: _anxietyLevel,
                      onChanged: (v) =>
                          setState(() => _anxietyLevel = v),
                      lowLabel: 'Calm',
                      highLabel: 'Very anxious',
                      activeColor: const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 28),
                    CheckInSliderQuestion(
                      label: 'Mental Clarity',
                      description:
                      'How clear and focused does your mind feel?',
                      value: _mentalClarity,
                      onChanged: (v) =>
                          setState(() => _mentalClarity = v),
                      lowLabel: 'Foggy',
                      highLabel: 'Crystal clear',
                      activeColor: const Color(0xFF48CAE4),
                    ),
                  ],
                ),

                // Step 3: Mood & Triggers
                _CheckInPage(
                  children: [
                    EmojiMoodPicker(
                      label: 'Overall Mood',
                      description: 'Pick the emoji that best describes you.',
                      value: _overallMood,
                      onChanged: (v) =>
                          setState(() => _overallMood = v),
                    ),
                    const SizedBox(height: 28),
                    QuickTagSelector(
                      label: 'Any stress triggers this morning?',
                      options: _triggers,
                      selected: _selectedTriggers,
                      onChanged: (v) =>
                          setState(() => _selectedTriggers = v),
                    ),
                  ],
                ),

                // Step 4: Gratitude
                _CheckInPage(
                  children: [
                    CheckInSliderQuestion(
                      label: 'Work/Study Stress',
                      description:
                      'Anticipating how stressful today will be?',
                      value: _workStress,
                      onChanged: (v) =>
                          setState(() => _workStress = v),
                      lowLabel: 'Easy day',
                      highLabel: 'Very demanding',
                      activeColor: const Color(0xFF9C27B0),
                    ),
                    const SizedBox(height: 28),
                    CheckInTextArea(
                      label: '✨ Morning Gratitude',
                      description:
                      'Name one thing you\'re grateful for today.',
                      hint:
                      'e.g. I\'m grateful for a warm cup of tea and a quiet morning...',
                      controller: _gratitudeCtrl,
                      maxLines: 4,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bottom CTA ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: CheckInSubmitButton(
              label: _currentStep == _totalSteps - 1
                  ? 'Complete Check-In'
                  : 'Continue',
              isLoading: state.isLoading,
              onPressed: state.isLoading ? null : _nextStep,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scrollable page container ────────────────────────────────────────────────
class _CheckInPage extends StatelessWidget {
  final List<Widget> children;
  const _CheckInPage({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ─── Success dialog ───────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onDone;

  const _SuccessDialog({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}