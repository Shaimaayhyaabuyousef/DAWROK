import 'dart:async';
import '../services/queue_assignment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/facility_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Firestore queue configuration, independent of service-window assignments.
enum FacilityQueueShift { morning, evening }

class FacilityQueue {
  final int windowNumber; // Stable legacy queue number, not a service window.
  final int windowCount;
  final String service;
  final String counter;
  final int capacity;
  final int rewardCapacity;
  final int beneficiaries;
  final int waitingMinutes;
  final FacilityQueueShift shift;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;
  final bool isActive;

  const FacilityQueue({
    required this.windowNumber,
    this.windowCount = 1,
    required this.service,
    required this.counter,
    required this.capacity,
    this.rewardCapacity = 0,
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
    int? rewardCapacity,
    int? beneficiaries,
    int? waitingMinutes,
    FacilityQueueShift? shift,
    TimeOfDay? startsAt,
    TimeOfDay? endsAt,
    bool? isActive,
  }) {
    return FacilityQueue(
      windowNumber: windowNumber,
      windowCount: windowCount,
      service: service ?? this.service,
      counter: counter ?? this.counter,
      capacity: capacity ?? this.capacity,
      rewardCapacity: rewardCapacity ?? this.rewardCapacity,
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
  final int windowCount;
  final String service;
  final int capacity;
  final int rewardCapacity;
  final int waitingMinutes;
  final FacilityQueueShift shift;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;

  const FacilityQueueDraft({
    this.windowCount = 0,
    required this.service,
    required this.capacity,
    this.rewardCapacity = 0,
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
          final window = int.tryParse((data['queueId'] as String? ?? '').replaceFirst('window_', '')) ?? 0;
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
      }, onError: (Object e) { error = 'Failed to load queues: $e'; debugPrint('DAWROK $error'); notifyListeners(); });
    } catch (e) {
      error = 'Failed to load facility: $e'; debugPrint('DAWROK $error');
      _queues.clear();
      notifyListeners();
    }
  }

  // Fetch a fresh server snapshot even if the real-time listener was lost.
  Future<void> refresh() async {
    try {
      final id = await FacilityContext.instance.requireFacilityId();
      if (_facilityId != id || _watch == null) {
        await _watch?.cancel();
        await _bookingsSub?.cancel();
        _watch = null;
        _bookingsSub = null;
        await _listen();
      }
      final snapshot = await _db.collection('facilities').doc(id)
          .collection('queues').get(const GetOptions(source: Source.server));
      _facilityId = id;
      _queues
        ..clear()
        ..addAll(snapshot.docs.where((d) => d.data()['archived'] != true)
          .map(_fromDoc).map((q) =>
            q.copyWith(beneficiaries: _counts[q.windowNumber] ?? 0)));
      _queues.sort((a, b) => a.windowNumber.compareTo(b.windowNumber));
      error = null;
      notifyListeners();
      debugPrint('DAWROK: loaded ${snapshot.docs.length} queue documents '
          'from facilities/$id/queues');
    } catch (e) {
      error = 'Could not refresh facility queues: $e';
      debugPrint('DAWROK $error');
      notifyListeners();
      rethrow;
    }
  }

  FacilityQueue _fromDoc(QueryDocumentSnapshot<Map<String,dynamic>> doc) {
    final m = doc.data();
    final start = (m['startsAtMinutes'] as num?)?.toInt() ?? 480;
    final end = (m['endsAtMinutes'] as num?)?.toInt() ?? 1020;
    return FacilityQueue(
      windowNumber: (m['windowNumber'] as num?)?.toInt() ?? 0,
      windowCount: (m['windowCount'] as num?)?.toInt() ?? 1,
      service: m['service'] as String? ?? '',
      counter: m['counter'] as String? ?? 'A',
      capacity: (m['capacity'] as num?)?.toInt() ?? 0,
      rewardCapacity: (m['rewardCapacity'] as num?)?.toInt() ?? 0,
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
    late DocumentReference<Map<String, dynamic>> createdQueue;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(fac);
      final n = ((snap.data()?['nextWindowNumber'] as num?)?.toInt() ?? 0) + 1;
      tx.update(fac, {'nextWindowNumber': n});
      createdQueue = fac.collection('queues').doc('window_$n');
      tx.set(createdQueue, {
        'windowNumber': n,
        'windowCount': draft.windowCount,
        'service': draft.service.trim(),
        'counter': 'A',
        'capacity': draft.capacity,
    'rewardCapacity': draft.rewardCapacity,
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

    await QueueAssignmentService.instance.rebalance(id);
    // Check the actual server document, not only local UI state.
    final verified = await createdQueue.get(
      const GetOptions(source: Source.server),
    );
    if (!verified.exists) {
      throw StateError(
        'Firestore committed but could not find ${createdQueue.path}.',
      );
    }
    debugPrint('DAWROK: created queue at ${createdQueue.path}');
    try {
      await refresh();
    } catch (e) {
      // The queue is already persisted; this is a read/sync failure.
      error = 'Queue saved at ${createdQueue.path}, but list refresh failed: $e';
      debugPrint('DAWROK $error');
      notifyListeners();
    }
  }

  Future<void> update(int n, FacilityQueueDraft draft) async {
    final ref = _ref(n);
    final before = await ref.get();
    if ((before.data()?['windowCount'] ?? 1) != draft.windowCount) {
      final tickets = await _db.collection('bookings').where('facilityId', isEqualTo: _facilityId).get();
      if (tickets.docs.any((d) => d.data()['queueId'] == ref.id && d.data()['status'] == 'called')) {
        throw StateError('Finish called tickets before changing the number of windows.');
      }
    }
    await _db.runTransaction((tx) async {
      final q = (await tx.get(ref)).data()!;
      final oldCount = (q['windowCount'] as num?)?.toInt() ?? 1;
      if (oldCount != draft.windowCount) {
        for (final w in serviceWindows(oldCount)) {
          final lane = await tx.get(ref.collection('lanes').doc('$w'));
          if ((lane.data()?['ticketId'] as String? ?? '').isNotEmpty) {
            throw StateError('Finish called tickets before changing windows.');
          }
        }
      }
      tx.update(ref, {
        'service': draft.service.trim(), 'windowCount': draft.windowCount,
        'capacity': draft.capacity, 'rewardCapacity': draft.rewardCapacity,
        'waitingMinutes': draft.waitingMinutes, 'shift': draft.shift.name,
        'startsAtMinutes': facilityTimeInMinutes(draft.startsAt),
        'endsAtMinutes': facilityTimeInMinutes(draft.endsAt),
      });
    });
    await QueueAssignmentService.instance.rebalance(_facilityId!);
  }

  Future<void> setActive(int n, bool active) => _ref(n).update({'isActive': active});
  /// Archive instead of deleting ticket history.
  Future<void> delete(int n) async {
    final tickets = await _db.collection('bookings').where('facilityId', isEqualTo: _facilityId).get();
    if (tickets.docs.any((d) => d.data()['queueId'] == _ref(n).id && ['waiting','called'].contains(d.data()['status']))) throw StateError('Finish existing tickets before archiving this queue.');
    await _ref(n).update({'archived': true, 'isActive': false});
    await QueueAssignmentService.instance.rebalance(_facilityId!);
  }
  /// Ticket counts are owned by reservation transactions, not local widgets.
  void recordHandled(int n) {}
}
