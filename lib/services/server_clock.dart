import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServerClock {
  static final _elapsed = Stopwatch();
  static DateTime? _sample;
  static String? _uid;
  static DateTime get estimate =>
      _sample?.add(_elapsed.elapsed) ?? DateTime.now().toUtc();

  static Future<DateTime> now() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (_sample == null || _uid != uid || _elapsed.elapsed.inMinutes >= 5) {
      final ref = FirebaseFirestore.instance
          .collection('clock_samples')
          .doc(uid);
      await ref
          .set({'at': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 12));
      final data = (await ref.get(const GetOptions(source: Source.server)))
          .data()!;
      _sample = (data['at'] as Timestamp).toDate().toUtc();
      _uid = uid;
      _elapsed
        ..reset()
        ..start();
    }
    return estimate;
  }
}
