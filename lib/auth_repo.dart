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
      if (user == null) throw const AuthException(message: 'Sign in failed', code: 'null-user');

      // Update last active
      await _usersCol.doc(user.uid).update({
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });

      final profile = await getUserProfileOnce(user.uid);
      if (profile == null) throw const AuthException(message: 'User profile not found', code: 'no-profile');

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), code: 'unknown');
    }
  }

  // ─── Register with Email ─────────────────────────────────────────────────
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
      if (user == null) throw const AuthException(message: 'Registration failed', code: 'null-user');

      // Update display name
      await user.updateDisplayName(name);

      final now = DateTime.now();
      final newUser = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        age: age,
        language: language,
        faithPreference: faithPreference,
        createdAt: now,
        lastActive: now,
      );

      await _usersCol.doc(user.uid).set(newUser.toMap());
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), code: 'unknown');
    }
  }

  // ─── Sign In with Google ─────────────────────────────────────────────────
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException(message: 'Google sign-in was cancelled', code: 'cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) throw const AuthException(message: 'Google sign-in failed', code: 'null-user');

      // Check if new user
      final existing = await getUserProfileOnce(user.uid);
      if (existing != null) {
        await _usersCol.doc(user.uid).update({
          'lastActive': DateTime.now().millisecondsSinceEpoch,
        });
        return existing;
      }

      // Create new profile
      final now = DateTime.now();
      final newUser = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        age: 0,
        profileImageUrl: user.photoURL,
        createdAt: now,
        lastActive: now,
      );

      await _usersCol.doc(user.uid).set(newUser.toMap());
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), code: 'unknown');
    }
  }

  // ─── Update user profile ─────────────────────────────────────────────────
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _usersCol.doc(user.uid).update(user.toMap());
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(user.name);
      }
    } on FirebaseException catch (e) {
      _log.e('Update profile error', error: e);
      throw AuthException(message: e.message ?? 'Update failed', code: e.code);
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
      // Delete Firestore data
      await _usersCol.doc(uid).delete();
      // Delete auth account
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on FirebaseException catch (e) {
      throw AuthException(message: e.message ?? 'Delete failed', code: e.code);
    }
  }

  // ─── Map Firebase errors to friendly messages ─────────────────────────────
  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthException(
            message: 'No account found with this email.', code: 'user-not-found');
      case 'wrong-password':
        return const AuthException(
            message: 'Incorrect password. Please try again.', code: 'wrong-password');
      case 'email-already-in-use':
        return const AuthException(
            message: 'An account already exists with this email.', code: 'email-in-use');
      case 'invalid-email':
        return const AuthException(
            message: 'Please enter a valid email address.', code: 'invalid-email');
      case 'weak-password':
        return const AuthException(
            message: 'Password is too weak. Use at least 8 characters.', code: 'weak-password');
      case 'too-many-requests':
        return const AuthException(
            message: 'Too many attempts. Please try again later.', code: 'too-many-requests');
      case 'network-request-failed':
        return const AuthException(
            message: 'No internet connection. Please check your network.', code: 'network-error');
      case 'requires-recent-login':
        return const AuthException(
            message: 'Please log out and log back in to perform this action.', code: 'requires-reauth');
      default:
        return AuthException(message: e.message ?? 'An error occurred.', code: e.code);
    }
  }
}