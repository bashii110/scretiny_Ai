import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_color.dart';
import '../domain_model/therapist_model.dart';
import '../provider/subscription_provider.dart';
import '../provider/therapist_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// therapist_screen.dart  —  Full therapist booking experience
//
// Sections:
//   1. SliverAppBar with filter icon
//   2. Premium gate banner (free users)
//   3. Upcoming sessions strip
//   4. Filter chips (Online Now / Top Rated / Lowest Price / Faith Match)
//   5. Therapist cards list
//   6. Therapist detail bottom sheet → slot picker → confirm booking
// ─────────────────────────────────────────────────────────────────────────────

class TherapistScreen extends ConsumerWidget {
  const TherapistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapistsAsync = ref.watch(therapistsProvider);
    final upcomingAsync = ref.watch(upcomingSessionsProvider);
    final canBook =
    ref.watch(featureAccessProvider(AppFeature.therapistBooking));

    // Show booking success snackbar
    ref.listen(therapistBookingProvider, (prev, next) {
      if (next.isSuccess && prev?.isSuccess == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session booked successfully! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(therapistBookingProvider.notifier).clear();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
          ),
        );
        ref.read(therapistBookingProvider.notifier).clear();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Therapists',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('Book a session with a professional',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textLight)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded,
                    color: AppColors.textDark),
                onPressed: () => _showFilterSheet(context, ref),
                tooltip: 'Filter',
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Premium gate banner ─────────────────────────────────
                if (!canBook) ...[
                  _PremiumGateBanner(),
                  const SizedBox(height: 16),
                ],

                // ── Upcoming sessions ───────────────────────────────────
                upcomingAsync.when(
                  data: (sessions) => sessions.isEmpty
                      ? const SizedBox.shrink()
                      : _UpcomingStrip(sessions: sessions),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── Filter chips ────────────────────────────────────────
                const _FilterChips(),
                const SizedBox(height: 16),

                // ── Therapist list ──────────────────────────────────────
                therapistsAsync.when(
                  data: (therapists) {
                    final list =
                    therapists.isEmpty ? localTherapistStubs : therapists;
                    return Column(
                      children: list
                          .map((t) => _TherapistCard(
                        therapist: t,
                        canBook: canBook,
                      ))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => Column(
                    children: localTherapistStubs
                        .map((t) => _TherapistCard(
                      therapist: t,
                      canBook: canBook,
                    ))
                        .toList(),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Gate Banner
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumGateBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Feature',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.white),
                ),
                Text(
                  'Upgrade to Premium to book therapist sessions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              'Upgrade',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upcoming Sessions Strip
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingStrip extends StatelessWidget {
  final List<TherapistSessionModel> sessions;
  const _UpcomingStrip({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Sessions',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...sessions.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.video_call_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.therapistName,
                        style:
                        Theme.of(context).textTheme.titleSmall),
                    Text(
                      _formatDateTime(s.scheduledAt),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              Text(
                '${s.currency} ${s.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}  ·  $hour:$min';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chips
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(therapistFilterProvider);
    final notifier = ref.read(therapistFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Online Now',
            icon: Icons.circle,
            iconColor: AppColors.stressLow,
            isSelected: filter.onlineOnly,
            onTap: () => notifier.state =
                filter.copyWith(onlineOnly: !filter.onlineOnly),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Top Rated',
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFFF9800),
            isSelected: filter.sortBy == 'rating',
            onTap: () =>
            notifier.state = filter.copyWith(sortBy: 'rating'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Lowest Price',
            icon: Icons.attach_money_rounded,
            iconColor: AppColors.stressLow,
            isSelected: filter.sortBy == 'price',
            onTap: () =>
            notifier.state = filter.copyWith(sortBy: 'price'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Faith Match',
            icon: Icons.self_improvement,
            iconColor: AppColors.secondary,
            isSelected: filter.faith != null,
            onTap: () => notifier.state = filter.copyWith(
              faith: filter.faith == null ? 'all' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
            isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Therapist Card
// ─────────────────────────────────────────────────────────────────────────────

class _TherapistCard extends StatelessWidget {
  final TherapistModel therapist;
  final bool canBook;

  const _TherapistCard({
    required this.therapist,
    required this.canBook,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                      AppColors.primary.withOpacity(0.12),
                      child: Text(
                        therapist.name.split(' ').last[0],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (therapist.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.stressLow,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(therapist.name,
                          style:
                          Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        therapist.specialization,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFFF9800)),
                          const SizedBox(width: 3),
                          Text(
                            therapist.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '  (${therapist.reviewCount})',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      therapist.formattedPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Text(
                      'per session',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Language & status tags
            Row(
              children: [
                Wrap(
                  spacing: 6,
                  children: therapist.languages.map((l) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(l.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
                const Spacer(),
                if (therapist.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                      AppColors.stressLow.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '● Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.stressLow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (therapist.about.isNotEmpty) ...[
              Text(
                therapist.about,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                    color: AppColors.textLight, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canBook ? () => _showDetail(context) : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: canBook
                      ? AppColors.primary
                      : AppColors.border,
                  disabledBackgroundColor: AppColors.border,
                ),
                child: Text(
                  canBook ? 'Book Session' : '🔒 Premium Only',
                  style: TextStyle(
                    fontSize: 14,
                    color: canBook
                        ? Colors.white
                        : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TherapistDetailSheet(
          therapist: therapist, canBook: canBook),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Therapist Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TherapistDetailSheet extends ConsumerStatefulWidget {
  final TherapistModel therapist;
  final bool canBook;

  const _TherapistDetailSheet({
    required this.therapist,
    required this.canBook,
  });

  @override
  ConsumerState<_TherapistDetailSheet> createState() =>
      _TherapistDetailSheetState();
}

class _TherapistDetailSheetState
    extends ConsumerState<_TherapistDetailSheet> {
  DateTime? _selectedSlot;

  List<DateTime> get _slots {
    final slots = <DateTime>[];
    final now = DateTime.now();
    for (int d = 1; d <= 7; d++) {
      final day = now.add(Duration(days: d));
      for (final hour in [10, 14, 17]) {
        slots.add(DateTime(day.year, day.month, day.day, hour));
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(therapistBookingProvider);
    final t = widget.therapist;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Header
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor:
                      AppColors.primary.withOpacity(0.12),
                      child: Text(
                        t.name.split(' ').last[0],
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (t.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.stressLow,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                      Text(t.specialization,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFFF9800)),
                          Text(
                            ' ${t.rating.toStringAsFixed(1)}  ·  ${t.reviewCount} reviews',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // About
            if (t.about.isNotEmpty) ...[
              Text('About',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(t.about,
                  style: const TextStyle(
                      color: AppColors.textMedium, height: 1.5)),
              const SizedBox(height: 16),
            ],

            // Stats row
            Row(
              children: [
                _DetailStat(
                    label: 'Price',
                    value: t.formattedPrice,
                    icon: Icons.attach_money_rounded),
                const SizedBox(width: 10),
                _DetailStat(
                    label: 'Languages',
                    value: t.languages
                        .join(', ')
                        .toUpperCase(),
                    icon: Icons.language_outlined),
                const SizedBox(width: 10),
                _DetailStat(
                    label: 'Status',
                    value: t.isOnline ? 'Online' : 'Offline',
                    icon: Icons.circle,
                    valueColor: t.isOnline
                        ? AppColors.stressLow
                        : AppColors.textLight),
              ],
            ),
            const SizedBox(height: 20),

            // Faith tags
            if (t.faithSensitive.isNotEmpty) ...[
              Text('Faith Sensitive',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: t.faithSensitive
                    .where((f) => f != 'all')
                    .map((f) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withOpacity(0.08),
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary
                            .withOpacity(0.2)),
                  ),
                  child: Text(
                    _faithLabel(f),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Slot picker
            if (widget.canBook) ...[
              Text('Choose a Slot',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _slots.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final slot = _slots[i];
                    final isSelected = _selectedSlot == slot;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedSlot = slot),
                      child: AnimatedContainer(
                        duration:
                        const Duration(milliseconds: 200),
                        width: 76,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius:
                          BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(
                              _dayLabel(slot),
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white
                                    .withOpacity(0.8)
                                    : AppColors.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${slot.hour}:00',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                            ),
                            Text(
                              slot.hour < 12 ? 'AM' : 'PM',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white
                                    .withOpacity(0.7)
                                    : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Confirm booking button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                  _selectedSlot == null || bookingState.isLoading
                      ? null
                      : () => _book(context, ref),
                  child: bookingState.isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    _selectedSlot == null
                        ? 'Select a slot first'
                        : 'Confirm Booking · ${t.formattedPrice}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'You can cancel up to 24 hours before the session',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textLight),
                ),
              ),
            ] else ...[
              // Non-premium CTA
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFFF9800).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFF9800)
                          .withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    const Text('👑',
                        style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      'Upgrade to Premium to book sessions',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                          color: const Color(0xFFFF9800)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Access all therapists for \$9.99/month',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                          color: AppColors.textLight),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFFF9800),
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('Upgrade Now'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(therapistBookingProvider.notifier);
    ctrl.selectTherapist(widget.therapist);
    ctrl.selectSlot(_selectedSlot!);
    final success = await ctrl.confirmBooking();
    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[dt.weekday - 1]}\n${months[dt.month - 1]} ${dt.day}';
  }

  String _faithLabel(String faith) {
    const map = {
      'islam': 'Islam ☪️',
      'christian': 'Christian ✝️',
      'hindu': 'Hindu 🕉️',
      'buddhism': 'Buddhism ☸️',
      'secular': 'Secular 🌿',
    };
    return map[faith] ?? faith;
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.textLight),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(therapistFilterProvider);
    final notifier = ref.read(therapistFilterProvider.notifier);

    const faithOptions = [
      ('All', null),
      ('Islam ☪️', 'islam'),
      ('Christian ✝️', 'christian'),
      ('Hindu 🕉️', 'hindu'),
      ('Buddhism ☸️', 'buddhism'),
    ];

    const languageOptions = [
      ('All', null),
      ('English', 'en'),
      ('Arabic', 'ar'),
      ('Urdu', 'ur'),
      ('Spanish', 'es'),
      ('French', 'fr'),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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
          const SizedBox(height: 16),
          Text('Filter Therapists',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),

          Text('Faith Preference',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: faithOptions.map((f) {
              final isSelected = filter.faith == f.$2;
              return _FilterPill(
                label: f.$1,
                isSelected: isSelected,
                onTap: () => notifier.state =
                    filter.copyWith(faith: f.$2),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Text('Language',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languageOptions.map((l) {
              final isSelected = filter.language == l.$2;
              return _FilterPill(
                label: l.$1,
                isSelected: isSelected,
                onTap: () => notifier.state =
                    filter.copyWith(language: l.$2),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Text('Online only',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Switch.adaptive(
                value: filter.onlineOnly,
                onChanged: (v) => notifier.state =
                    filter.copyWith(onlineOnly: v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                notifier.state = const TherapistFilter();
                Navigator.pop(context);
              },
              child: const Text('Reset Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color:
            isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}