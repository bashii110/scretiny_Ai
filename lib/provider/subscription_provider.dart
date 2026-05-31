import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// subscription_provider.dart
//
// Providers:
//   • subscriptionTierProvider     – current user tier: free/basic/premium
//   • subscriptionPlansProvider    – available plan configs
//   • featureAccessProvider        – per-feature gating helper
//   • subscriptionControllerProvider – upgrade / restore flow state
// ─────────────────────────────────────────────────────────────────────────────

String? _uid() => FirebaseAuth.instance.currentUser?.uid;
FirebaseFirestore get _db => FirebaseFirestore.instance;

// ─────────────────────────────────────────────────────────────────────────────
// Plan Model
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionPlan {
  final String id;           // 'free' | 'basic' | 'premium'
  final String name;
  final String price;        // display string e.g. '$4.99/mo'
  final double monthlyUsd;
  final String description;
  final List<String> features;
  final List<String> limitations; // things NOT included
  final String badge;        // emoji
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.monthlyUsd,
    required this.description,
    required this.features,
    required this.limitations,
    required this.badge,
    this.isPopular = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature Keys
// ─────────────────────────────────────────────────────────────────────────────

class AppFeature {
  static const stressScanning = 'stress_scanning';
  static const dailyCheckin = 'daily_checkin';
  static const breathingBasic = 'breathing_basic';
  static const analyticsWeek = 'analytics_week';
  static const familyMode = 'family_mode';          // basic+
  static const analyticsMonth = 'analytics_month';  // basic+
  static const meditationPremium = 'meditation_premium'; // premium
  static const therapistBooking = 'therapist_booking';   // premium
  static const voiceCheckin = 'voice_checkin';           // premium
  static const exportData = 'export_data';               // premium
}

// Feature → minimum tier required
const _featureTiers = <String, String>{
  AppFeature.stressScanning: 'free',
  AppFeature.dailyCheckin: 'free',
  AppFeature.breathingBasic: 'free',
  AppFeature.analyticsWeek: 'free',
  AppFeature.familyMode: 'basic',
  AppFeature.analyticsMonth: 'basic',
  AppFeature.meditationPremium: 'premium',
  AppFeature.therapistBooking: 'premium',
  AppFeature.voiceCheckin: 'premium',
  AppFeature.exportData: 'premium',
};

const _tierRank = {'free': 0, 'basic': 1, 'premium': 2};

// ─────────────────────────────────────────────────────────────────────────────
// Plans data
// ─────────────────────────────────────────────────────────────────────────────

final subscriptionPlansProvider = Provider<List<SubscriptionPlan>>((_) => [
  const SubscriptionPlan(
    id: 'free',
    name: 'Free',
    price: '\$0',
    monthlyUsd: 0,
    description: 'Core mental wellness tools',
    badge: '🌱',
    features: [
      'Camera-based stress scanning',
      'Morning & evening check-ins',
      'Basic breathing exercises',
      '7-day stress analytics',
      'Daily wellness tips',
    ],
    limitations: [
      'No family mode',
      'No monthly analytics',
      'No therapist booking',
      'No voice check-in',
    ],
  ),
  const SubscriptionPlan(
    id: 'basic',
    name: 'Basic',
    price: '\$4.99/mo',
    monthlyUsd: 4.99,
    description: 'For consistent wellness tracking',
    badge: '⭐',
    isPopular: false,
    features: [
      'Everything in Free',
      'Family support mode (up to 3)',
      '30-day analytics & reports',
      'All breathing techniques',
      'Mood calendar',
      'Sleep quality tracking',
    ],
    limitations: [
      'No premium meditations',
      'No therapist booking',
      'No voice check-in',
    ],
  ),
  const SubscriptionPlan(
    id: 'premium',
    name: 'Premium',
    price: '\$9.99/mo',
    monthlyUsd: 9.99,
    description: 'Full mental health support',
    badge: '👑',
    isPopular: true,
    features: [
      'Everything in Basic',
      'Global therapist booking',
      'Voice-based stress check-in',
      'Premium guided meditations',
      'Unlimited family members',
      'Data export (PDF/CSV)',
      'Priority support',
      'Faith-specific content library',
    ],
    limitations: [],
  ),
]);

// ─────────────────────────────────────────────────────────────────────────────
// Current Tier Provider
// ─────────────────────────────────────────────────────────────────────────────

final subscriptionTierProvider = Provider<String>((ref) {
  final userAsync = ref.watch(userProfileProvider);
  return userAsync.valueOrNull?.subscriptionTier ?? 'free';
});

// ─────────────────────────────────────────────────────────────────────────────
// Feature Access Provider
// ─────────────────────────────────────────────────────────────────────────────

final featureAccessProvider =
Provider.family<bool, String>((ref, feature) {
  final tier = ref.watch(subscriptionTierProvider);
  final required = _featureTiers[feature] ?? 'free';
  final userRank = _tierRank[tier] ?? 0;
  final requiredRank = _tierRank[required] ?? 0;
  return userRank >= requiredRank;
});

// ─────────────────────────────────────────────────────────────────────────────
// Subscription Controller
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final String? processingPlanId;

  const SubscriptionState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.processingPlanId,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    String? processingPlanId,
  }) =>
      SubscriptionState(
        isLoading: isLoading ?? this.isLoading,
        isSuccess: isSuccess ?? this.isSuccess,
        error: error,
        processingPlanId:
        processingPlanId ?? this.processingPlanId,
      );
}

class SubscriptionController
    extends StateNotifier<SubscriptionState> {
  SubscriptionController() : super(const SubscriptionState());

  /// In a real app this calls Stripe / RevenueCat.
  /// Here we simulate the flow and write directly to Firestore.
  Future<bool> upgradeTo(String planId) async {
    final uid = _uid();
    if (uid == null) return false;

    state = state.copyWith(
      isLoading: true,
      processingPlanId: planId,
    );

    try {
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Write new tier to Firestore user doc
      await _db.collection('users').doc(uid).update({
        'subscriptionTier': planId,
        'subscriptionUpdatedAt':
        DateTime.now().millisecondsSinceEpoch,
      });

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        processingPlanId: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Payment failed. Please try again.',
        processingPlanId: null,
      );
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      // In production: query RevenueCat/Stripe for existing entitlements
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No purchases found to restore.',
      );
      return false;
    }
  }

  void clear() => state = const SubscriptionState();
}

final subscriptionControllerProvider = StateNotifierProvider<
    SubscriptionController, SubscriptionState>(
      (_) => SubscriptionController(),
);