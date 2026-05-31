import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_repo.dart';
import '../domain_model/auth_model.dart';

// ─── Repository provider ──────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ─── Firebase Auth state stream ───────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ─── Current user profile stream ─────────────────────────────────────────────
//
// On every Auth sign-in this calls ensureUserDocument() so the Firestore
// document is always created if it was missing. The profile stream is then
// attached to that document for real-time updates.
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (firebaseUser) {
      if (firebaseUser == null) return Stream.value(null);

      // Ensure doc exists — non-blocking, result not awaited here because
      // getUserProfile() below will stream the document once it's written.
      ref
          .read(authRepositoryProvider)
          .ensureUserDocument(firebaseUser)
          .catchError((_) {});   // errors are logged inside ensureUserDocument

      return ref
          .watch(authRepositoryProvider)
          .getUserProfile(firebaseUser.uid);
    },
    loading: () => Stream.value(null),
    error:   (_, __) => Stream.value(null),
  );
});

// ─── Auth controller state ────────────────────────────────────────────────────
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
    bool?   isLoading,
    String? error,
    bool?   isSuccess,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error:     error,
        isSuccess: isSuccess ?? this.isSuccess,
      );
}

// ─── Auth controller ──────────────────────────────────────────────────────────
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
        name:            name,
        email:           email,
        password:        password,
        age:             age,
        language:        language,
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
    state = AuthState(
        isLoading: state.isLoading, isSuccess: state.isSuccess);
  }
}

final authControllerProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});