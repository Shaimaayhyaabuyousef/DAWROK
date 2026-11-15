import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/facility_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Demo-only state. Connect this service to a server to make changes shared
/// between the facility staff and citizen applications.
enum FacilityQueueShift { morning, evening }

class FacilityQueue {
  final int windowNumber;
  final String service;
  final String counter;
  final int capacity;
  final int beneficiaries;
  final int waitingMinutes;
  final FacilityQueueShift shift;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;
  final bool isActive;

  const FacilityQueue({
    required this.windowNumber,
    required this.service,
    required this.counter,
    required this.capacity,
    required this.beneficiaries,
    required this.waitingMinutes,
    required this.shift,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  FacilityQueue copyWith({
    String? service,
    String? counter,
    int? capacity,
    int? beneficiaries,
    int? waitingMinutes,
    FacilityQueueShift? shift,
    TimeOfDay? startsAt,
    TimeOfDay? endsAt,
    bool? isActive,
  }) {
    return FacilityQueue(
      windowNumber: windowNumber,
      service: service ?? this.service,
      counter: counter ?? this.counter,
      capacity: capacity ?? this.capacity,
      beneficiaries: beneficiaries ?? this.beneficiaries,
      waitingMinutes: waitingMinutes ?? this.waitingMinutes,
      shift: shift ?? this.shift,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class FacilityQueueDraft {
  final String service;
  final int capacity;
  final int waitingMinutes;
  final FacilityQueueShift shift;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;

  const FacilityQueueDraft({
    required this.service,
    required this.capacity,
    required this.waitingMinutes,
    required this.shift,
    required this.startsAt,
    required this.endsAt,
  });
}

String facilityTimeText(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

int facilityTimeInMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

class FacilityQueueStore extends ChangeNotifier {
  FacilityQueueStore._() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _watch?.cancel();
      _bookingsSub?.cancel();
      _counts = {};
      _facilityId = null;
      _queues.clear();
      notifyListeners();
      _listen();
    });
  }
  static final instance = FacilityQueueStore._();
  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _watch, _bookingsSub;
  Map<int,int> _counts = {};
  String? _facilityId;
  String? error;
  final List<FacilityQueue> _queues = [];

  List<FacilityQueue> get queues => List.unmodifiable(_queues);
  int get totalQueues => _queues.length;
  int get totalWaiting => _queues.fold(0, (n, q) => n + q.beneficiaries);
  int get averageWaitMinutes => _queues.isEmpty ? 0 :
    (_queues.fold<int>(0, (n, q) => n + q.waitingMinutes) / _queues.length).round();

  Future<void> _listen() async {
    try {
      final id = await FacilityContext.instance.requireFacilityId();
      _facilityId = id;
      _bookingsSub = _db.collection('bookings')
          .where('facilityId', isEqualTo: id).snapshots().listen((snap) {
        final counts = <int,int>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['status'] != 'waiting' && data['status'] != 'called') continue;
          final window = (data['windowNumber'] as num?)?.toInt() ?? 0;
          counts[window] = (counts[window] ?? 0) + 1;
        }
        _counts = counts;
        for (var i = 0; i < _queues.length; i++) {
          final q = _queues[i];
          _queues[i] = q.copyWith(beneficiaries: counts[q.windowNumber] ?? 0);
        }
        notifyListeners();
      }, onError: (Object e) { error = e.toString(); notifyListeners(); });
      _watch = _db.collection('facilities').doc(id).collection('queues')
          .snapshots().listen((snap) {
        _queues
          ..clear()
          ..addAll(snap.docs.where((d) => d.data()['archived'] != true)
              .map(_fromDoc).map((q) => q.copyWith(beneficiaries: _counts[q.windowNumber] ?? 0)));
        _queues.sort((a,b) => a.windowNumber.compareTo(b.windowNumber));
        error = null;
        notifyListeners();
      }, onError: (Object e) { error = e.toString(); notifyListeners(); });
    } catch (e) {
      error = e.toString();
      _queues.clear();
      notifyListeners();
    }
  }

  FacilityQueue _fromDoc(QueryDocumentSnapshot<Map<String,dynamic>> doc) {
    final m = doc.data();
    final start = (m['startsAtMinutes'] as num?)?.toInt() ?? 480;
    final end = (m['endsAtMinutes'] as num?)?.toInt() ?? 1020;
    return FacilityQueue(
      windowNumber: (m['windowNumber'] as num?)?.toInt() ?? 0,
      service: m['service'] as String? ?? '',
      counter: m['counter'] as String? ?? 'A',
      capacity: (m['capacity'] as num?)?.toInt() ?? 0,
      beneficiaries: (m['waitingCount'] as num?)?.toInt() ?? 0,
      waitingMinutes: (m['waitingMinutes'] as num?)?.toInt() ?? 0,
      shift: m['shift'] == 'evening' ? FacilityQueueShift.evening : FacilityQueueShift.morning,
      startsAt: TimeOfDay(hour: start ~/ 60, minute: start % 60),
      endsAt: TimeOfDay(hour: end ~/ 60, minute: end % 60),
      isActive: m['isActive'] == true,
    );
  }

  DocumentReference<Map<String,dynamic>> _ref(int n) {
    final id = _facilityId;
    if (id == null) throw StateError('Facility data has not loaded.');
    return _db.collection('facilities').doc(id).collection('queues').doc('window_$n');
  }

  Future<void> create(FacilityQueueDraft draft) async {
    final id = await FacilityContext.instance.requireFacilityId();
    final fac = _db.collection('facilities').doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(fac);
      final n = ((snap.data()?['nextWindowNumber'] as num?)?.toInt() ?? 0) + 1;
      tx.update(fac, {'nextWindowNumber': n});
      tx.set(fac.collection('queues').doc('window_$n'), {
        'windowNumber': n,
        'service': draft.service.trim(),
        'counter': 'A',
        'capacity': draft.capacity,
        'waitingCount': 0,
        'waitingMinutes': draft.waitingMinutes,
        'shift': draft.shift.name,
        'startsAtMinutes': facilityTimeInMinutes(draft.startsAt),
        'endsAtMinutes': facilityTimeInMinutes(draft.endsAt),
        'isActive': false,
        'archived': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> update(int n, FacilityQueueDraft draft) => _ref(n).update({
    'service': draft.service.trim(),
    'capacity': draft.capacity,
    'waitingMinutes': draft.waitingMinutes,
    'shift': draft.shift.name,
    'startsAtMinutes': facilityTimeInMinutes(draft.startsAt),
    'endsAtMinutes': facilityTimeInMinutes(draft.endsAt),
  });

  Future<void> setActive(int n, bool active) => _ref(n).update({'isActive': active});
  /// Archive instead of deleting ticket history.
  Future<void> delete(int n) => _ref(n).update({'archived': true, 'isActive': false});
  /// Ticket counts are owned by reservation transactions, not local widgets.
  void recordHandled(int n) {}
}
