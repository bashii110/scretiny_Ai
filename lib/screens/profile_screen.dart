import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/app_color.dart';
import '../components/app_router.dart';
import '../domain_model/auth_model.dart';
import '../provider/auth_provider.dart';
import '../provider/analytics_provider.dart';
// ─────────────────────────────────────────────────────────────────────────────
// profile_screen.dart
//
// Sections:
//   1. Avatar + name + email header
//   2. Subscription tier card
//   3. Edit profile bottom sheet
//   4. Notification toggles
//   5. App preferences (faith, language)
//   6. Privacy & account actions
//   7. Sign out
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        data: (user) => user == null
            ? const Center(
            child: Text('Profile document not found'),
            )
            : _ProfileBody(user: user),
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Profile error:\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Body
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final UserModel user;
  const _ProfileBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifSettings = ref.watch(notificationSettingsProvider);

    return CustomScrollView(
      slivers: [
        // ── App bar ──────────────────────────────────────────────────
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text('Profile',
              style: Theme.of(context).textTheme.titleLarge),
          actions: [
            TextButton(
              onPressed: () =>
                  _showEditSheet(context, ref, user),
              child: const Text('Edit'),
            ),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Avatar + info ────────────────────────────────────────
              _AvatarHeader(user: user),
              const SizedBox(height: 20),

              // ── Subscription ─────────────────────────────────────────
              _SubscriptionCard(tier: user.subscriptionTier),
              const SizedBox(height: 24),

              // ── Notifications ─────────────────────────────────────────
              _SectionHeader(title: 'Notifications'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _ToggleTile(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Morning check-in reminder',
                    subtitle:
                    '${notifSettings.morningHour}:00',
                    value: notifSettings.morningReminder,
                    onChanged: (_) => ref
                        .read(notificationSettingsProvider
                        .notifier)
                        .toggle('morning'),
                  ),
                  _Divider(),
                  _ToggleTile(
                    icon: Icons.nights_stay_outlined,
                    title: 'Evening check-in reminder',
                    subtitle:
                    '${notifSettings.eveningHour}:00',
                    value: notifSettings.eveningReminder,
                    onChanged: (_) => ref
                        .read(notificationSettingsProvider
                        .notifier)
                        .toggle('evening'),
                  ),
                  _Divider(),
                  _ToggleTile(
                    icon: Icons.warning_amber_outlined,
                    title: 'High stress alerts',
                    subtitle: 'Notify family when critical',
                    value: notifSettings.highStressAlert,
                    onChanged: (_) => ref
                        .read(notificationSettingsProvider
                        .notifier)
                        .toggle('highStress'),
                  ),
                  _Divider(),
                  _ToggleTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'Weekly wellness report',
                    value: notifSettings.weeklyReport,
                    onChanged: (_) => ref
                        .read(notificationSettingsProvider
                        .notifier)
                        .toggle('weekly'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Preferences ───────────────────────────────────────────
              _SectionHeader(title: 'Preferences'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _InfoTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    value: _languageLabel(user.language),
                    onTap: () =>
                        _showEditSheet(context, ref, user),
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.self_improvement,
                    title: 'Faith preference',
                    value: _faithLabel(user.faithPreference),
                    onTap: () =>
                        _showEditSheet(context, ref, user),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Account ───────────────────────────────────────────────
              _SectionHeader(title: 'Account'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _InfoTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy policy',
                    onTap: () {},
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of service',
                    onTap: () {},
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.info_outline,
                    title: 'App version',
                    value: '1.0.0',
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Sign out ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const Icon(Icons.logout_rounded,
                      size: 18, color: AppColors.danger),
                  label: const Text('Sign Out',
                      style:
                      TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.danger),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Scranity AI · Your mental wellness companion',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  Future<void> _signOut(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You\'ll need to sign in again to access your data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out',
                style:
                TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(profileEditProvider.notifier)
          .signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  String _languageLabel(String code) {
    const map = {
      'en': 'English 🇬🇧',
      'ar': 'العربية 🇸🇦',
      'ur': 'اردو 🇵🇰',
      'es': 'Español 🇪🇸',
      'fr': 'Français 🇫🇷',
    };
    return map[code] ?? code;
  }

  String _faithLabel(String faith) {
    const map = {
      'islam': 'Islam ☪️',
      'christian': 'Christian ✝️',
      'hindu': 'Hindu 🕉️',
      'buddhism': 'Buddhism ☸️',
      'secular': 'Secular / None 🌿',
    };
    return map[faith] ?? faith;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Header
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final UserModel user;
  const _AvatarHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.firstName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Age ${user.age}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Member',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
// Subscription Card
// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final String tier;
  const _SubscriptionCard({required this.tier});

  Color get _tierColor {
    switch (tier) {
      case 'premium':
        return const Color(0xFFFF9800);
      case 'basic':
        return AppColors.secondary;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _tierColor.withOpacity(0.12),
            _tierColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: _tierColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tier == 'premium'
                  ? Icons.workspace_premium_rounded
                  : tier == 'basic'
                  ? Icons.star_half_rounded
                  : Icons.person_outline_rounded,
              color: _tierColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tier.tierLabel} Plan',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: _tierColor),
                ),
                const SizedBox(height: 2),
                Text(
                  tier.tierDescription,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          ),
          if (tier != 'premium')
            TextButton(
              onPressed: () {},
              child: Text(
                'Upgrade',
                style: TextStyle(color: _tierColor),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context).textTheme.titleMedium);
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 52, color: AppColors.border);
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: Text(title,
          style: Theme.of(context).textTheme.bodyMedium),
      subtitle: subtitle != null
          ? Text(subtitle!,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textLight))
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: Text(title,
          style: Theme.of(context).textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textLight)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textLight),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() =>
      _EditProfileSheetState();
}

class _EditProfileSheetState
    extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late String _faith;
  late String _language;

  static const _faithOptions = [
    ('🌿', 'Secular', 'secular'),
    ('☪️', 'Islam', 'islam'),
    ('✝️', 'Christian', 'christian'),
    ('🕉️', 'Hindu', 'hindu'),
    ('☸️', 'Buddhism', 'buddhism'),
  ];

  static const _languages = [
    ('🇬🇧', 'English', 'en'),
    ('🇸🇦', 'العربية', 'ar'),
    ('🇵🇰', 'اردو', 'ur'),
    ('🇪🇸', 'Español', 'es'),
    ('🇫🇷', 'Français', 'fr'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.user.name);
    _faith = widget.user.faithPreference;
    _language = widget.user.language;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final success = await ref
        .read(profileEditProvider.notifier)
        .updateProfile(
      current: widget.user,
      name: _nameCtrl.text,
      faithPreference: _faith,
      language: _language,
    );
    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(profileEditProvider);

    ref.listen(profileEditProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
          ),
        );
        ref.read(profileEditProvider.notifier).clear();
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom:
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Edit Profile',
                style:
                Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon:
                Icon(Icons.person_outline, size: 20),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Faith
            Text('Faith Preference',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _faithOptions.map((f) {
                final isSelected = f.$3 == _faith;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _faith = f.$3),
                  child: AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius:
                      BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${f.$1} ${f.$2}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Language
            Text('Language',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.map((l) {
                final isSelected = l.$3 == _language;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _language = l.$3),
                  child: AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius:
                      BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${l.$1} ${l.$2}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                editState.isLoading ? null : _save,
                child: editState.isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}