import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'domain_model/auth_model.dart';

// ─── Custom exceptions ────────────────────────────────────────────────────────
class AuthException implements Exception {
  final String message;
  final String code;
  const AuthException({required this.message, required this.code});

  @override
  String toString() => 'AuthException($code): $message';
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final Logger _log = Logger();

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  // ─── Convenience ─────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  // ─── Auth state stream ────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  // ─── Get current user profile ─────────────────────────────────────────────
  Stream<UserModel?> getUserProfile(String uid) {
    return _usersCol.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(snap.data()!);
    });
  }

  Future<UserModel?> getUserProfileOnce(String uid) async {
    try {
      final doc = await _usersCol.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      _log.e('Error fetching user profile', error: e);
      return null;
    }
  }

  // ─── Ensure Firestore document exists ─────────────────────────────────────
  //
  // Called on every sign-in path. If the Auth account exists but the Firestore
  // document is missing (e.g. a previous write failed, or the user was created
  // directly in the Firebase console), this creates a minimal document so the
  // rest of the app never hits a null profile.
  //
  // Safe to call repeatedly — uses set() with merge:false only when doc is
  // absent; existing documents are never overwritten.
  Future<UserModel> ensureUserDocument(User firebaseUser) async {
    try {
      final existing = await getUserProfileOnce(firebaseUser.uid);
      if (existing != null) return existing;

      _log.w('Firestore doc missing for uid=${firebaseUser.uid} — creating now');

      final now = DateTime.now();
      final fallback = UserModel(
        uid:            firebaseUser.uid,
        name:           firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'User',
        email:          firebaseUser.email ?? '',
        age:            0,
        profileImageUrl: firebaseUser.photoURL,
        createdAt:      now,
        lastActive:     now,
      );
      await _usersCol.doc(firebaseUser.uid).set(fallback.toMap());
      return fallback;
    } catch (e) {
      _log.e('ensureUserDocument failed', error: e);
      // Return a local-only model so the UI can still render
      final now = DateTime.now();
      return UserModel(
        uid:       firebaseUser.uid,
        name:      firebaseUser.displayName ?? 'User',
        email:     firebaseUser.email ?? '',
        age:       0,
        createdAt: now,
        lastActive: now,
      );
    }
  }

  // ─── Sign In with Email ───────────────────────────────────────────────────
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
            message: 'Sign in failed', code: 'null-user');
      }

      // Ensure Firestore doc exists — creates it if missing instead of
      // throwing 'no-profile'. This handles users whose registration write
      // failed or who were created outside the app.
      final profile = await ensureUserDocument(user);

      // Stamp last-active (best-effort, non-fatal if it fails)
      _usersCol.doc(user.uid).update({
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) => _log.w('lastActive update failed: $e'));

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), code: 'unknown');
    }
  }

  // ─── Register with Email ──────────────────────────────────────────────────
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required int age,
    String language = 'en',
    String faithPreference = 'secular',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
            message: 'Registration failed', code: 'null-user');
      }

      await user.updateDisplayName(name);

      final now = DateTime.now();
      final newUser = UserModel(
        uid:             user.uid,
        name:            name.trim(),
        email:           email.trim(),
        age:             age,
        language:        language,
        faithPreference: faithPreference,
        createdAt:       now,
        lastActive:      now,
      );

      // Use set() so a partial earlier write is fully overwritten
      await _usersCol.doc(user.uid).set(newUser.toMap());
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), code: 'unknown');
    }
  }

  // ─── Sign In with Google ──────────────────────────────────────────────────
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException(
            message: 'Google sign-in was cancelled', code: 'cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw const AuthException(
            message: 'Google sign-in failed', code: 'null-user');
      }

      // ensureUserDocument handles both new and returning Google users —
      // creates the Firestore doc on first sign-in, returns existing on repeat.
      final profile = await ensureUserDocument(user);

      // Stamp last-active for returning users (best-effort)
      _usersCol.doc(user.uid).update({
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) => _log.w('lastActive update failed: $e'));

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), code: 'unknown');
    }
  }

  // ─── Update user profile ──────────────────────────────────────────────────
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _usersCol.doc(user.uid).set(
        user.toMap(),
        // merge:true preserves fields not included in UserModel.toMap()
        SetOptions(merge: true),
      );
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(user.name);
      }
    } on FirebaseException catch (e) {
      _log.e('Update profile error', error: e);
      throw AuthException(
          message: e.message ?? 'Update failed', code: e.code);
    }
  }

  // ─── Send password reset email ────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  // ─── Sign out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      _log.e('Sign out error', error: e);
    }
  }

  // ─── Delete account ───────────────────────────────────────────────────────
  Future<void> deleteAccount(String uid) async {
    try {
      await _usersCol.doc(uid).delete();
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on FirebaseException catch (e) {
      throw AuthException(
          message: e.message ?? 'Delete failed', code: e.code);
    }
  }

  // ─── Map Firebase errors to friendly messages ─────────────────────────────
  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthException(
            message: 'No account found with this email.',
            code: 'user-not-found');
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException(
            message: 'Incorrect email or password.',
            code: 'wrong-password');
      case 'email-already-in-use':
        return const AuthException(
            message: 'An account already exists with this email.',
            code: 'email-in-use');
      case 'invalid-email':
        return const AuthException(
            message: 'Please enter a valid email address.',
            code: 'invalid-email');
      case 'weak-password':
        return const AuthException(
            message: 'Password is too weak. Use at least 8 characters.',
            code: 'weak-password');
      case 'too-many-requests':
        return const AuthException(
            message: 'Too many attempts. Please try again later.',
            code: 'too-many-requests');
      case 'network-request-failed':
        return const AuthException(
            message: 'No internet connection. Please check your network.',
            code: 'network-error');
      case 'requires-recent-login':
        return const AuthException(
            message:
            'Please log out and sign in again to perform this action.',
            code: 'requires-reauth');
      default:
        return AuthException(
            message: e.message ?? 'An error occurred.', code: e.code);
    }
  }
}