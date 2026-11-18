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

class QueueBookingStore extends ChangeNotifier {
  QueueBookingStore._() {
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      final generation = ++_generation;
      await _sub?.cancel();
      if (generation != _generation) return;
      _sub = null;
      error = null;
      _bookings.clear();
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
        _sub = FirebaseFirestore.instance
            .collection('bookings')
            .where('citizenId', isEqualTo: u.uid)
            .snapshots()
            .listen(
              (snap) {
                if (generation != _generation) return;
                _bookings
                  ..clear()
                  ..addAll(
                    snap.docs
                        .where(
                          (d) =>
                              d.data()['status'] != 'served' &&
                              d.data()['status'] != 'absent',
                        )
                        .map((d) {
                          final m = d.data();
                          final time =
                              (m['slotStart'] as Timestamp?)?.toDate() ??
                              DateTime.now();
                          final state = m['status'] as String? ?? 'waiting';
                          final ahead = 0;
                          final status = state == 'called'
                              ? QueueBookingStatus.yourTurnSoon
                              : time.isAfter(
                                  DateTime.now().add(
                                    const Duration(minutes: 30),
                                  ),
                                )
                              ? QueueBookingStatus.scheduled
                              : QueueBookingStatus.inQueue;
                          return QueueBooking(
                            ticketNumber: d.id,
                            queueNumber:
                                (m['queuePosition'] as num?)?.toInt() ?? 0,
                            windowNumber: (m['windowNumber'] as num?)?.toInt(),
                            scheduledAt: time,
                            facilityName: m['facilityName'] as String? ?? '',
                            idNumber: savedId, // Read only from this citizen's private identity document.
                            beneficiaryName: m['citizenName'] as String? ?? '',
                            createdAt:
                                (m['createdAt'] as Timestamp?)?.toDate() ??
                                time,
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
                                ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                                : null,
                          );
                        }),
                  );
                _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                notifyListeners();
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
  List<QueueBooking> get bookings => List.unmodifiable(_bookings);

  @Deprecated(
    'Use BookingService.reserve to create transactional Firestore tickets.',
  )
  void addBooking(QueueBooking booking) {
    throw StateError('Create bookings using BookingService.reserve.');
  }
}
