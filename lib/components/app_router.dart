import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:serenity_ai/provider/auth_provider.dart';
import 'package:serenity_ai/screens/notification_screen.dart';
import 'package:serenity_ai/screens/splash_screen.dart';
import 'package:serenity_ai/screens/stressresult_screen.dart';
import 'package:serenity_ai/screens/voicecheckin_screen.dart';
import '../screens/breathing screen.dart';
import '../screens/camerascan_screen.dart';
import '../screens/evening_checkin_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mindfulness_screen.dart';
import '../screens/morning_checkin_screen.dart';
import '../screens/on_boarding_screen.dart';
import '../screens/register_screen.dart';

// Route name constants
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const analytics = '/analytics';
  static const mindfulness = '/mindfulness';
  static const breathing = '/breathing';
  static const meditation = '/meditation';
  static const family = '/family';
  static const profile = '/profile';
  static const cameraScan = '/camera-scan';
  static const voiceCheckin = '/voice-checkin';
  static const stressResult = '/stress-result';
  static const morningCheckin = '/morning-checkin';
  static const eveningCheckin = '/evening-checkin';
  static const therapists = '/therapists';
  static const therapistDetail = '/therapists/:id';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final user = authState.valueOrNull;
      final isAuthenticated = user != null;
      final currentPath = state.matchedLocation;

      final authPaths = [AppRoutes.login, AppRoutes.register, AppRoutes.onboarding];
      final isOnAuthScreen = authPaths.any((p) => currentPath.startsWith(p));

      if (!isAuthenticated && !isOnAuthScreen && currentPath != AppRoutes.splash) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isOnAuthScreen) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.morningCheckin,
        builder: (context, state) => const MorningCheckInScreen(),
      ),
      GoRoute(
        path: AppRoutes.eveningCheckin,
        builder: (context, state) => const EveningCheckInScreen(),
      ),
      GoRoute(
        path: AppRoutes.cameraScan,
        builder: (context, state) => const CameraScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.voiceCheckin,
        builder: (context, state) => const VoiceCheckinScreen(),
      ),
      GoRoute(
        path: AppRoutes.voiceCheckin,
        builder: (context, state) => const StressResultScreen(),
      ),
      GoRoute(
        path: AppRoutes.breathing,
        builder: (context, state) => const BreathingScreen(),
      ),
      GoRoute(
        path: AppRoutes.mindfulness,
        builder: (context, state) => const MindfulnessScreen(),
      ),
      // GoRoute(
      //   path: AppRoutes.mindfulness,
      //   builder: (context, state) => const NotificationScreen(),
      // ),
      // Add remaining routes as screens are built
    ],
  );
});