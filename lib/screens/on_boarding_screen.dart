import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/App config/custom_button.dart';
import '../components/app_color.dart';
import '../components/app_router.dart';


class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  String _selectedLanguage = 'en';
  String _selectedFaith = 'secular';
  int _stressGoal = 3; // 1–5 severity target

  final _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'ur', 'name': 'اردو', 'flag': '🇵🇰'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
  ];

  final _faithOptions = [
    {'value': 'secular', 'label': 'Secular / None', 'icon': '🌿'},
    {'value': 'islam', 'label': 'Islam', 'icon': '☪️'},
    {'value': 'christian', 'label': 'Christian', 'icon': '✝️'},
    {'value': 'hindu', 'label': 'Hindu', 'icon': '🕉️'},
    {'value': 'buddhism', 'label': 'Buddhism', 'icon': '☸️'},
  ];

  void _next() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('preferred_language', _selectedLanguage);
    await prefs.setString('faith_preference', _selectedFaith);
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(gradient: AppColors.calmGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                ),
                // Page view
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _SlideOne(),
                      _buildLanguageSlide(),
                      _buildFaithSlide(),
                      _buildGoalsSlide(),
                      _buildPermissionsSlide(),
                    ],
                  ),
                ),
                // Dots + button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                              (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        label: _currentPage == 4 ? 'Get Started' : 'Continue',
                        onPressed: _next,
                        trailingIcon: Icons.arrow_forward_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSlide() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('🌍', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          Text(
            'Choose Your Language',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'SerenityAI supports multiple languages for a personalized experience.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: _languages.map((lang) {
                final isSelected = _selectedLanguage == lang['code'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedLanguage = lang['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 16),
                        Text(
                          lang['name']!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.textDark,
                          ),
                        ),
                        if (isSelected) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaithSlide() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('🙏', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          Text(
            'Faith Preference',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll personalize your mindfulness content based on your spiritual background.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: _faithOptions.map((faith) {
                final isSelected = _selectedFaith == faith['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedFaith = faith['value']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(faith['icon']!, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Text(
                          faith['label']!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.textDark,
                          ),
                        ),
                        if (isSelected) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSlide() {
    final goalLabels = ['Mild', 'Moderate', 'Significant', 'Severe', 'Extreme'];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('🎯', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          Text('Set Your Goals', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'How would you describe your current stress level?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Text(
                  goalLabels[_stressGoal - 1],
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Slider(
                  value: _stressGoal.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) => setState(() => _stressGoal = v.toInt()),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:  [
                    Text('Calm', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                    Text('Very stressed', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We\'ll use this to personalize your daily check-in experience.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('🔐', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 20),
          Text(
            'Allow Permissions',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'These permissions are required for stress detection features.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 32),
          const _PermissionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Camera',
            desc:
            'For HRV-based stress detection by measuring pulse via camera.',
          ),
          const SizedBox(height: 16),
          const _PermissionTile(
            icon: Icons.mic_outlined,
            title: 'Microphone',
            desc: 'For voice-based stress analysis during check-ins.',
          ),
          const SizedBox(height: 16),
          const _PermissionTile(
            icon: Icons.phone_android_outlined,
            title: 'Usage Access',
            desc: 'To monitor screen time as a stress indicator.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _requestPermissions,
              child: const Text('Grant Permissions Now'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'You can also grant these later in settings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SlideOne extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('🌸', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text(
              'Welcome to\nSerenityAI',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.textDark,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Monitor your mental health, detect stress without wearables, and get AI-powered support — all in one place.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textMedium,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            ... const[
              _FeatureBullet(icon: '📷', text: 'Camera-based HRV stress detection'),
              _FeatureBullet(icon: '🎙️', text: 'Voice analysis for emotional wellbeing'),
              _FeatureBullet(icon: '🧘', text: 'Faith-sensitive mindfulness content'),
              _FeatureBullet(icon: '👨‍👩‍👧', text: 'Family support mode'),
              _FeatureBullet(icon: '🌍', text: 'Global therapist connection'),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final String icon;
  final String text;
  const _FeatureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
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