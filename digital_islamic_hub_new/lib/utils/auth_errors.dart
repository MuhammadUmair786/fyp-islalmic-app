import 'package:firebase_auth/firebase_auth.dart';

class AuthErrors {
  static String fromFirebase(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with letters and numbers.';
      case 'operation-not-allowed':
        return 'This sign-in method is currently disabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'requires-recent-login':
        return 'Please log in again to complete this action.';
      default:
        return error.message?.isNotEmpty == true
            ? error.message!
            : 'Authentication failed. Please try again.';
    }
  }

  static String fromAny(Object error) {
    if (error is FirebaseAuthException) return fromFirebase(error);
    final text = error.toString().toLowerCase();
    if (text.contains('network')) {
      return 'Network error. Check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
