import '../services/booking_order.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/facility_context.dart';

enum FacilityVisitStatus { waiting, called, served, absent, cancelled }

class FacilityVisit {
  final String ticketNumber;
  final int? queuePosition;
  final String visitorName;
  final String maskedId;
  final int windowNumber;
  final String queueId;
  final int estimatedMinutes;
  FacilityVisitStatus status;
  final DateTime? calledAt;
  bool checkedIn;
  int postponements;

  FacilityVisit({
    required this.ticketNumber,
    this.queuePosition,
    required this.visitorName,
    required this.maskedId,
    required this.windowNumber,
    required this.queueId,
    required this.estimatedMinutes,
    this.status = FacilityVisitStatus.waiting,
    this.calledAt,
    this.checkedIn = false,
    this.postponements = 0,
  });
}

class FacilityScanStore extends ChangeNotifier {
  FacilityScanStore._() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      _bookingsSub?.cancel();
      _visits.clear();
      notifyListeners();
      _listen();
    });
  }
  static final instance = FacilityScanStore._();
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _bookingsSub;
  final List<FacilityVisit> _visits = [];
  List<FacilityVisit> get visits => List.unmodifiable(_visits);

  Future<void> _listen() async {
    try {
      final id = await FacilityContext.instance.requireFacilityId();
      _bookingsSub = _db.collection('bookings')
          .where('facilityId', isEqualTo: id)
          .snapshots().listen((snap) {
      final cancelled = cancelledTicketIds(snap.docs);
        _visits
          ..clear()
          ..addAll((snap.docs.toList()..sort((a,b) => compareBookingRows(a.data(),a.id,b.data(),b.id,cancelled:cancelled))).map((d) {
            final m = d.data();
            final status = FacilityVisitStatus.values.firstWhere(
              (v) => v.name == m['status'], orElse: () => FacilityVisitStatus.waiting);
            return FacilityVisit(
              ticketNumber: d.id,
              queuePosition: (m['queuePosition'] as num?)?.toInt(),
              visitorName: m['citizenName'] as String? ?? '',
              maskedId: '••••',
              windowNumber: m['routingVersion'] == 2 ? (m['windowNumber'] as num?)?.toInt() ?? 0 : 1,
              queueId: m['queueId'] as String? ?? '',
              estimatedMinutes: 30,
              calledAt: (m['calledAt'] as Timestamp?)?.toDate(),
              status: status, checkedIn: m['checkedIn'] == true,
              postponements: (m['postponements'] as num?)?.toInt() ?? 0,
            );
          }));
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Facility scans not available: ${e.toString()}');
      notifyListeners();
    }
  }
}
