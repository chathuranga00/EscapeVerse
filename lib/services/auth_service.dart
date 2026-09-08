import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Authentication for EscapeVerse.
///
/// All methods are safe to call before Firebase.initializeApp() — they
/// catch the "no Firebase app" exception and return gracefully.
/// Once Firebase is configured and initializeApp() succeeds, they work normally.
class AuthService {
  // ── Getters ───────────────────────────────────────────────────────────────

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null; // Firebase not initialised yet
    }
  }

  User? get currentUser => _auth?.currentUser;
  String? get uid => _auth?.currentUser?.uid;
  bool get isAnonymous => _auth?.currentUser?.isAnonymous ?? true;

  // ── Sign-in ───────────────────────────────────────────────────────────────

  Future<void> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) return;
    if (auth.currentUser != null) return;
    try {
      await auth.signInAnonymously();
      debugPrint('AuthService: signed in anonymously as ${uid ?? "unknown"}');
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: anonymous sign-in failed — ${e.code}');
    } catch (e) {
      debugPrint('AuthService: sign-in error — $e');
    }
  }

  // ── Link email ────────────────────────────────────────────────────────────

  Future<String?> linkEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) return 'Firebase not available.';
    try {
      final credential = EmailAuthProvider.credential(
          email: email, password: password);
      await auth.currentUser?.linkWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) return 'Firebase not available.';
    try {
      await auth.signInWithEmailAndPassword(
          email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    }
  }

  String _authErrorMessage(String code) {
    const messages = <String, String>{
      'email-already-in-use':     'That email is already linked to another account.',
      'invalid-email':            'The email address is not valid.',
      'weak-password':            'Password must be at least 6 characters.',
      'wrong-password':           'Incorrect password.',
      'user-not-found':           'No account found with that email.',
      'credential-already-in-use':'This credential is already linked to a different account.',
      'network-request-failed':   'No internet connection.',
    };
    return messages[code] ?? 'Authentication error ($code).';
  }
}
