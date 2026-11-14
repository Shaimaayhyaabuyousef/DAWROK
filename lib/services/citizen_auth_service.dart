import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Citizen registration/login only.
/// Staff and facilities must be provisioned by a trusted backend, not this UI.
class CitizenAuthService {
  CitizenAuthService._();

  static final CitizenAuthService instance = CitizenAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void>? _googleInitialization;

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    await _finishCitizenSignIn(
      credential.user,
      preferredName: name.trim(),
      createIfMissing: true,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _finishCitizenSignIn(credential.user);
  }

  /// Returns false if the provider interaction was cancelled by the user.
  Future<bool> signInWithGoogle() async {
    late final UserCredential result;
    if (kIsWeb) {
      result = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      _googleInitialization ??= GoogleSignIn.instance.initialize();
      await _googleInitialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('لم نستلم رمز دخول صالحًا من Google.');
      }
      result = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }
    await _finishCitizenSignIn(result.user, createIfMissing: true);
    return true;
  }

  Future<bool> signInWithX() async {
    final provider = TwitterAuthProvider(); // X is still named Twitter in Firebase.
    final result = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    await _finishCitizenSignIn(result.user, createIfMissing: true);
    return true;
  }

  Future<bool> signInWithFacebook() async {
    late final UserCredential result;
    if (kIsWeb) {
      result = await _auth.signInWithPopup(FacebookAuthProvider());
    } else {
      final login = await FacebookAuth.instance.login();
      if (login.status == LoginStatus.cancelled) return false;
      if (login.status != LoginStatus.success || login.accessToken == null) {
        throw StateError(login.message ?? 'لم يكتمل تسجيل الدخول عبر Facebook.');
      }
      final accessToken = login.accessToken!;
      final OAuthCredential credential;
      if (accessToken is LimitedToken) {
        // iOS Limited Login requires the OIDC token + original nonce.
        credential = OAuthProvider('facebook.com').credential(
          idToken: accessToken.tokenString,
          // rawNonce: FacebookAuth.instance.nonce ,
        );
      } else {
        credential = FacebookAuthProvider.credential(accessToken.tokenString);
      }
      result = await _auth.signInWithCredential(credential);
    }
    await _finishCitizenSignIn(result.user, createIfMissing: true);
    return true;
  }

  /// Checks the saved citizen record without converting existing facility
  /// accounts into citizen accounts.
  Future<bool> isExistingCitizen(User user) async {
    final role = (await user.getIdTokenResult()).claims?['role'];
    if (role != null && role != 'citizen') return false;
    final document = await _firestore.collection('users').doc(user.uid).get();
    return document.exists && document.data()?['role'] == 'citizen';
  }

  Future<void> _finishCitizenSignIn(
    User? user, {
    String? preferredName,
    bool createIfMissing = false,
  }) async {
    if (user == null) {
      throw StateError('تعذّر الحصول على بيانات المستخدم.');
    }
    try {
      // Trusted custom claims, if set by an administrator, take precedence.
      final role = (await user.getIdTokenResult()).claims?['role'];
      if (role != null && role != 'citizen') {
        throw StateError('هذا الحساب ليس حساب مواطن.');
      }

      final reference = _firestore.collection('users').doc(user.uid);
      final existing = await reference.get();
      if (existing.exists) {
        if (existing.data()?['role'] != 'citizen') {
          throw StateError('هذا الحساب مرتبط بنوع مستخدم آخر.');
        }
        return;
      }

      if (!createIfMissing) {
        throw StateError(
          'لم نجد ملف مواطن مرتبطًا بهذا الحساب. يرجى استكمال التسجيل أو التواصل مع الدعم.',
        );
      }

      // A Firestore security rule must only allow creation with role=citizen.
      await reference.set({
        'uid': user.uid,
        'role': 'citizen',
        'displayName': preferredName ?? user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'providers': user.providerData.map((p) => p.providerId).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never navigate to Citizen Home without a valid citizen profile.
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

bool isCitizenAuthCancellation(Object error) {
  if (error is GoogleSignInException) {
    return error.code == GoogleSignInExceptionCode.canceled;
  }
  if (error is FirebaseAuthException) {
    return {
      'cancelled-popup-request',
      'popup-closed-by-user',
      'web-context-cancelled',
      'canceled',
      'cancelled',
      'user-cancelled',
    }.contains(error.code);
  }
  return false;
}

String citizenAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم مسبقًا.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'account-exists-with-different-credential':
        return 'لديك حساب بالطريقة الأخرى. سجّل الدخول بها أولاً ثم اربط الحسابات لاحقًا.';
      case 'operation-not-allowed':
        return 'طريقة الدخول هذه غير مفعلة في Firebase Console.';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت وحاول مجددًا.';
      case 'too-many-requests':
        return 'محاولات كثيرة. حاول لاحقًا.';
      case 'popup-blocked':
        return 'اسمح بالنوافذ المنبثقة لإكمال تسجيل الدخول.';
      default:
        return 'فشلت المصادقة: ${error.code}';
    }
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'تعذّر حفظ بيانات المواطن. راجع قواعد Firestore وصلاحيات الحساب.';
  }
  if (error is StateError) return error.message.toString();
  return 'حدث خطأ أثناء تسجيل الدخول. ${error.toString()}';
}
