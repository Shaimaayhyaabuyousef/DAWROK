import 'package:firebase_auth/firebase_auth.dart';

String citizenAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This phone number is already in use.';
      case 'invalid-email':
        return 'The phone number format is not valid.';
      case 'weak-password':
        return 'The password is weak. Use at least 6 characters.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Incorrect phone number or password.';
      case 'account-exists-with-different-credential':
        return 'You already have an account with another sign-in method. Sign in with it first.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'popup-blocked':
        return 'Allow pop-ups to complete sign-in.';
      default:
        return 'Authentication failed: ${error.code}';
    }
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Could not save the citizen profile. Check the account permissions.';
  }
  if (error is StateError) return error.message.toString();
  return 'Something went wrong while signing in. ${error.toString()}';
}
