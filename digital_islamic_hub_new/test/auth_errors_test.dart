import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_islamic_hub_new/utils/auth_errors.dart';

void main() {
  test('maps known Firebase auth codes to user-friendly copy', () {
    expect(
      AuthErrors.fromFirebase(
          FirebaseAuthException(code: 'wrong-password', message: 'x')),
      contains('Incorrect password'),
    );
    expect(
      AuthErrors.fromFirebase(
          FirebaseAuthException(code: 'user-not-found', message: 'x')),
      contains('not registered'),
    );
    expect(
      AuthErrors.fromFirebase(
          FirebaseAuthException(code: 'email-already-in-use', message: 'x')),
      contains('already registered'),
    );
    expect(
      AuthErrors.fromFirebase(
          FirebaseAuthException(code: 'too-many-requests', message: 'x')),
      contains('Too many attempts'),
    );
    expect(
      AuthErrors.fromFirebase(
          FirebaseAuthException(code: 'network-request-failed', message: 'x')),
      contains('Network error'),
    );
  });
}
