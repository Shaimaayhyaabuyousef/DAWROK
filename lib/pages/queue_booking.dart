import '../services/facility_time.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Queue status values shown in the My Queue screen.
enum QueueBookingStatus { yourTurnSoon, scheduled, inQueue }

class QueueBooking {
  final String ticketNumber;
  final int queueNumber;
  final int? windowNumber;
  final int? windowCount;
  final DateTime? scheduledAt;
  final String facilityName;
  final String idNumber;
  final String beneficiaryName;
  final DateTime createdAt;
  final String estimatedWaiting;
  final String qrPayload;
  final int peopleAhead;
  final QueueBookingStatus status;
  final String? scheduledTime;
  final String? windowOpensIn;

  const QueueBooking({
    required this.ticketNumber,
    required this.queueNumber,
    this.windowNumber,
    this.windowCount,
    this.scheduledAt,
    required this.facilityName,
    required this.idNumber,
    required this.beneficiaryName,
    required this.createdAt,
    required this.estimatedWaiting,
    required this.qrPayload,
    required this.peopleAhead,
    required this.status,
    this.scheduledTime,
    this.windowOpensIn,
  });
}

/// A moment the citizen should notice even if they are on another screen.
class TurnAlert {
  final String ticketId;
  final bool called;
  final int? windowNumber;
  final String facilityName;
  const TurnAlert({
    required this.ticketId,
    required this.called,
    required this.windowNumber,
    required this.facilityName,
  });
}

class QueueBookingStore extends ChangeNotifier {
  QueueBookingStore._() {
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      final generation = ++_generation;
      await _sub?.cancel();
      _clearProgress();
      if (generation != _generation) return;
      _sub = null;
      error = null;
      _bookings.clear();
      _docs = const [];
      _lastStatus.clear();
      _nearShown.clear();
      _firstSnapshot = true;
      notifyListeners();
      if (u != null) {
        String savedId = '';
        try {
          final identity = await FirebaseFirestore.instance
              .collection('citizen_identity')
              .doc(u.uid)
              .get();
          savedId = identity.data()?['nationalId'] as String? ?? '';
        } catch (_) {
          // Existing tickets stay accessible even if private identity is absent.
        }
        if (generation != _generation) return;
        _savedId = savedId;
        _sub = FirebaseFirestore.instance
            .collection('bookings')
            .where('citizenId', isEqualTo: u.uid)
            .snapshots()
            .listen(
              (snap) {
                if (generation != _generation) return;
                _docs = snap.docs
                    .where(
                      (d) => ['waiting', 'called'].contains(d.data()['status']),
                    )
                    .toList();
                _detectCalled();
                _syncProgress();
                _rebuild();
              },
              onError: (Object e) {
                if (generation != _generation) return;
                error = e.toString();
                notifyListeners();
              },
            );
      }
    });
  }
  static final instance = QueueBookingStore._();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final List<QueueBooking> _bookings = [];
  String? error;
  int _generation = 0;
  String _savedId = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = const [];
  List<QueueBooking> get bookings => List.unmodifiable(_bookings);

  /// The latest turn alert (called to a window, or only a few people left).
  final alert = ValueNotifier<TurnAlert?>(null);
  final Map<String, String> _lastStatus = {};
  final Set<String> _nearShown = {};
  bool _firstSnapshot = true;

  // Public "now serving" position per facility/queue/day, written by the
  // window that calls a ticket. Citizens never read other people's tickets.
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _progressSubs = {};
  final Map<String, int> _serving = {};

  static String _key(Map<String, dynamic> m) =>
      '${m['facilityId']}/${m['queueId']}/${m['dayKey']}';

  void _clearProgress() {
    for (final s in _progressSubs.values) {
      s.cancel();
    }
    _progressSubs.clear();
    _serving.clear();
  }

  void _syncProgress() {
    final wanted = <String>{
      for (final d in _docs)
        if (d.data()['facilityId'] is String &&
            d.data()['queueId'] is String &&
            d.data()['dayKey'] is String)
          _key(d.data()),
    };
    for (final k in _progressSubs.keys.toList()) {
      if (!wanted.contains(k)) {
        _progressSubs.remove(k)?.cancel();
        _serving.remove(k);
      }
    }
    for (final k in wanted) {
      if (_progressSubs.containsKey(k)) continue;
      final parts = k.split('/');
      _progressSubs[k] = FirebaseFirestore.instance
          .collection('facilities')
          .doc(parts[0])
          .collection('queues')
          .doc(parts[1])
          .collection('progress')
          .doc(parts[2])
          .snapshots()
          .listen(
            (doc) {
              final p = (doc.data()?['position'] as num?)?.toInt();
              if (p == null) {
                _serving.remove(k);
              } else {
                _serving[k] = p;
              }
              _rebuild();
            },
            // Older rules without the progress document: keep the estimate.
            onError: (_) {},
          );
    }
  }

  void _detectCalled() {
    for (final d in _docs) {
      final status = d.data()['status'] as String? ?? 'waiting';
      final before = _lastStatus[d.id];
      if (!_firstSnapshot && status == 'called' && before != 'called') {
        alert.value = TurnAlert(
          ticketId: d.id,
          called: true,
          windowNumber: (d.data()['windowNumber'] as num?)?.toInt(),
          facilityName: d.data()['facilityName'] as String? ?? '',
        );
      }
      _lastStatus[d.id] = status;
    }
    _firstSnapshot = false;
  }

  /// People ahead, from the last called position in this queue today.
  /// It is an estimate: priority, postponed and cancelled tickets shift it.
  int? peopleAheadOf(Map<String, dynamic> m) {
    final mine = (m['queuePosition'] as num?)?.toInt();
    if (mine == null) return null;
    final serving = _serving[_key(m)] ?? 0;
    return (mine - serving - 1).clamp(0, 100000);
  }

  void _rebuild() {
    _bookings
      ..clear()
      ..addAll(
        _docs.map((d) {
          final m = d.data();
          final time =
              (m['slotStart'] as Timestamp?)?.toDate() ?? DateTime.now();
          final state = m['status'] as String? ?? 'waiting';
          final ahead = state == 'called' ? 0 : (peopleAheadOf(m) ?? 0);
          if (state == 'waiting' &&
              _serving.containsKey(_key(m)) &&
              ahead <= 2 &&
              _nearShown.add(d.id)) {
            alert.value = TurnAlert(
              ticketId: d.id,
              called: false,
              windowNumber: null,
              facilityName: m['facilityName'] as String? ?? '',
            );
          }
          final status = state == 'called'
              ? QueueBookingStatus.yourTurnSoon
              : time.isAfter(DateTime.now().add(const Duration(minutes: 30)))
              ? QueueBookingStatus.scheduled
              : QueueBookingStatus.inQueue;
          return QueueBooking(
            ticketNumber: d.id,
            queueNumber: (m['queuePosition'] as num?)?.toInt() ?? 0,
            windowNumber: (m['windowNumber'] as num?)?.toInt(),
            windowCount: (m['windowCount'] as num?)?.toInt(),
            scheduledAt: time,
            facilityName: m['facilityName'] as String? ?? '',
            idNumber: _savedId, // Read only from this citizen's private identity document.
            beneficiaryName: m['citizenName'] as String? ?? '',
            createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? time,
            estimatedWaiting: state == 'served'
                ? 'Completed'
                : state == 'absent'
                ? 'Absent'
                : '~${time.difference(DateTime.now()).inMinutes.clamp(0, 1440)} min',
            qrPayload:
                'DAWROK|ticket=${d.id}|facility=${m['facilityId']}|queue=${m['queueId']}',
            peopleAhead: ahead,
            status: status,
            scheduledTime: state == 'waiting'
                ? '${FacilityTime.wall(time).hour.toString().padLeft(2, '0')}:${FacilityTime.wall(time).minute.toString().padLeft(2, '0')}'
                : null,
          );
        }),
      );
    _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  @Deprecated(
    'Use BookingService.reserve to create transactional Firestore tickets.',
  )
  void addBooking(QueueBooking booking) {
    throw StateError('Create bookings using BookingService.reserve.');
  }
}
