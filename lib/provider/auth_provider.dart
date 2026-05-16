import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_repo.dart';
import '../domain_model/auth_model.dart';

// ─── Repository Provider ──────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ─── Firebase Auth State Stream ───────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ─── Current User Profile Stream ─────────────────────────────────────────────
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).getUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Auth Controller State ────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isSuccess: isSuccess ?? this.isSuccess,
      );
}

// ─── Auth Controller ──────────────────────────────────────────────────────────
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState());

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signInWithEmail(email: email, password: password);
      state = const AuthState(isSuccess: true);
      return true;
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required int age,
    String language = 'en',
    String faithPreference = 'secular',
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.registerWithEmail(
        name: name,
        email: email,
        password: password,
        age: age,
        language: language,
        faithPreference: faithPreference,
      );
      state = const AuthState(isSuccess: true);
      return true;
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signInWithGoogle();
      state = const AuthState(isSuccess: true);
      return true;
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
      return false;
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.sendPasswordReset(email);
      state = const AuthState(isSuccess: true);
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: 'Failed to send reset email.');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _repository.signOut();
    state = const AuthState();
  }

  Future<void> updateProfile(UserModel user) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateUserProfile(user);
      state = const AuthState(isSuccess: true);
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    }
  }

  void clearError() {
    state = AuthState(isLoading: state.isLoading, isSuccess: state.isSuccess);
  }
}

final authControllerProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});