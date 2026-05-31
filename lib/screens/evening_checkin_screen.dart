// lib/screens/checkin/evening_checkin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../components/app_color.dart';
import '../../domain_model/checkin_model.dart';
import '../../provider/checkin_provider.dart';
import '../components/widgets/checkin_widgets.dart';


// Reuse the shared page container & success dialog from morning screen
// (or keep them in a common file — here imported via checkin_widgets)

class EveningCheckInScreen extends ConsumerStatefulWidget {
  const EveningCheckInScreen({super.key});

  @override
  ConsumerState<EveningCheckInScreen> createState() =>
      _EveningCheckInScreenState();
}

class _EveningCheckInScreenState
    extends ConsumerState<EveningCheckInScreen> {
  // Form state
  int _overallMood = 3;
  int _anxietyLevel = 3;
  int _energyLevel = 3;
  int _mentalClarity = 3;
  int _workStress = 3;
  int _sleepQuality = 3; // anticipated sleep quality tonight
  final _gratitudeCtrl = TextEditingController();
  final _reflectionCtrl = TextEditingController();
  List<String> _selectedTriggers = [];

  static const _triggers = [
    '💼 Work deadlines',
    '💬 Difficult conversation',
    '💰 Financial stress',
    '👨‍👩‍👧 Family tension',
    '🚗 Commute/travel',
    '📱 Screen fatigue',
    '🍔 Poor eating',
    '🤕 Physical discomfort',
    '😤 Frustration',
    '😞 Disappointment',
  ];

  final _pageController = PageController();
  int _currentStep = 0;
  static const _totalSteps = 4;

  @override
  void dispose() {
    _gratitudeCtrl.dispose();
    _reflectionCtrl.dispose();
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
      type: 'evening',
      date: DateTime.now(),
      sleepQuality: _sleepQuality,
      anxietyLevel: _anxietyLevel,
      energyLevel: _energyLevel,
      mentalClarity: _mentalClarity,
      overallMood: _overallMood,
      workStress: _workStress,
      // Store gratitude + reflection together in the note field
      gratitudeNote: _buildNote(),
    );

    final success =
    await ref.read(checkInControllerProvider.notifier).saveCheckIn(checkIn);

    if (success && mounted) {
      _showSuccessAndPop();
    }
  }

  String _buildNote() {
    final gratitude = _gratitudeCtrl.text.trim();
    final reflection = _reflectionCtrl.text.trim();
    if (gratitude.isEmpty && reflection.isEmpty) return '';
    if (reflection.isEmpty) return 'Gratitude: $gratitude';
    if (gratitude.isEmpty) return 'Reflection: $reflection';
    return 'Gratitude: $gratitude\n\nReflection: $reflection';
  }

  void _showSuccessAndPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EveningSuccessDialog(
        stressScore: _computeStressPreview(),
        onDone: () {
          Navigator.of(context).pop();
          context.pop();
        },
      ),
    );
  }

  /// Quick local preview score before Firestore confirmation
  double _computeStressPreview() {
    final stressors = (_anxietyLevel + _workStress) * 10.0;
    final protectors = (_energyLevel + _mentalClarity) * 10.0;
    return ((stressors - protectors + 100) / 2).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInControllerProvider);

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
            emoji: '🌙',
            title: 'Evening Check-In',
            subtitle: 'Reflect on your day and unwind.',
            gradientStart: const Color(0xFF2D3561),
            gradientEnd: const Color(0xFF6C63FF),
          ),

          // ── Back + Progress ───────────────────────────────────────────────
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
                // Step 1: Mood & Energy
                _EveningPage(
                  children: [
                    EmojiMoodPicker(
                      label: 'How was your day overall?',
                      description:
                      'Choose the emoji that feels most accurate.',
                      value: _overallMood,
                      onChanged: (v) =>
                          setState(() => _overallMood = v),
                      emojis: const [
                        '😞',
                        '😕',
                        '😐',
                        '🙂',
                        '😄'
                      ],
                      labels: const [
                        'Rough',
                        'Hard',
                        'So-so',
                        'Good',
                        'Great'
                      ],
                    ),
                    const SizedBox(height: 28),
                    CheckInSliderQuestion(
                      label: 'Energy Level',
                      description: 'How are your energy reserves right now?',
                      value: _energyLevel,
                      onChanged: (v) =>
                          setState(() => _energyLevel = v),
                      lowLabel: 'Drained',
                      highLabel: 'Still energised',
                      activeColor: const Color(0xFF4CAF50),
                    ),
                  ],
                ),

                // Step 2: Stress & Anxiety
                _EveningPage(
                  children: [
                    CheckInSliderQuestion(
                      label: 'Work / Study Stress',
                      description:
                      'How stressful was work or study today?',
                      value: _workStress,
                      onChanged: (v) =>
                          setState(() => _workStress = v),
                      lowLabel: 'Very light',
                      highLabel: 'Very heavy',
                      activeColor: const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 28),
                    CheckInSliderQuestion(
                      label: 'Anxiety / Worry',
                      description:
                      'How much did worry weigh on you today?',
                      value: _anxietyLevel,
                      onChanged: (v) =>
                          setState(() => _anxietyLevel = v),
                      lowLabel: 'At ease',
                      highLabel: 'Very anxious',
                      activeColor: const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 28),
                    CheckInSliderQuestion(
                      label: 'Mental Clarity',
                      description: 'How clear-headed did you feel today?',
                      value: _mentalClarity,
                      onChanged: (v) =>
                          setState(() => _mentalClarity = v),
                      lowLabel: 'Very foggy',
                      highLabel: 'Very clear',
                      activeColor: const Color(0xFF48CAE4),
                    ),
                  ],
                ),

                // Step 3: Triggers
                _EveningPage(
                  children: [
                    const _SectionDivider(
                      icon: '⚡',
                      title: 'What stressed you today?',
                      subtitle:
                      'Select all that apply — helps us spot patterns.',
                    ),
                    const SizedBox(height: 16),
                    QuickTagSelector(
                      label: '',
                      options: _triggers,
                      selected: _selectedTriggers,
                      onChanged: (v) =>
                          setState(() => _selectedTriggers = v),
                    ),
                    const SizedBox(height: 28),
                    EmojiMoodPicker(
                      label: 'Anticipated Sleep Quality',
                      description:
                      'How well do you expect to sleep tonight?',
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
                  ],
                ),

                // Step 4: Gratitude & Reflection
                _EveningPage(
                  children: [
                    CheckInTextArea(
                      label: '🙏 Evening Gratitude',
                      description:
                      'What are you thankful for today?',
                      hint:
                      'e.g. I\'m grateful for a productive meeting and a good lunch...',
                      controller: _gratitudeCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    CheckInTextArea(
                      label: '💭 Daily Reflection',
                      description:
                      'What\'s one thing you\'d do differently tomorrow?',
                      hint:
                      'e.g. I\'d take more breaks and drink more water...',
                      controller: _reflectionCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    // Stress preview card
                    _StressPreviewCard(score: _computeStressPreview()),
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

// ─── Evening page container ───────────────────────────────────────────────────
class _EveningPage extends StatelessWidget {
  final List<Widget> children;
  const _EveningPage({required this.children});

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

// ─── Section divider with icon ────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _SectionDivider({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Stress preview card ──────────────────────────────────────────────────────
class _StressPreviewCard extends StatelessWidget {
  final double score;
  const _StressPreviewCard({required this.score});

  String get _level {
    if (score <= 25) return 'Low';
    if (score <= 50) return 'Moderate';
    if (score <= 75) return 'High';
    return 'Critical';
  }

  String get _message {
    if (score <= 25) return 'You had a calm day. Keep it up! 🌿';
    if (score <= 50) return 'Moderate stress day. A good night\'s rest will help. 🌙';
    if (score <= 75) return 'It was a tough day. Try a breathing exercise before sleep. 🧘';
    return 'High stress today. Be gentle with yourself tonight. 💜';
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stressColor(score);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated stress: $_level',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Evening success dialog ───────────────────────────────────────────────────
class _EveningSuccessDialog extends StatelessWidget {
  final double stressScore;
  final VoidCallback onDone;

  const _EveningSuccessDialog({
    required this.stressScore,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stressColor(stressScore);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌙', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Evening logged!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your day has been recorded. Sleep well 💜',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Score pill
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                'Today\'s stress score: ${stressScore.toStringAsFixed(0)} / 100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
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