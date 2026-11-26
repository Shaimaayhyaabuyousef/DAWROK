import 'package:firebase_auth/firebase_auth.dart';

String citizenAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'رقم الهاتف هذا مستخدم مسبقًا.';
      case 'invalid-email':
        return 'صيغة رقم الهاتف غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
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
