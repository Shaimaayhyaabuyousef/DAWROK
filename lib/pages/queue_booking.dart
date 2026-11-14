import 'package:flutter/foundation.dart';

/// Queue status values shown in the My Queue screen.
enum QueueBookingStatus { yourTurnSoon, scheduled, inQueue }

class QueueBooking {
  final String ticketNumber;
  final int queueNumber;
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

/// In-memory store shared by the booking form, ticket screen and My Queue tab.
/// Replace this with Firestore/API persistence when the backend is connected.
class QueueBookingStore extends ChangeNotifier {
  QueueBookingStore._();

  static final QueueBookingStore instance = QueueBookingStore._();

  final List<QueueBooking> _bookings = [
    QueueBooking(
      ticketNumber: 'BK-94821',
      queueNumber: 8,
      facilityName: 'Family Bakery',
      idNumber: '402948219',
      beneficiaryName: 'Ahmad Salem',
      createdAt: DateTime.now(),
      estimatedWaiting: '~5 mins',
      qrPayload: 'DAWROK|ticket=BK-94821|facility=Family Bakery|queue=8',
      peopleAhead: 2,
      status: QueueBookingStatus.yourTurnSoon,
    ),
    QueueBooking(
      ticketNumber: 'BK-71093',
      queueNumber: 14,
      facilityName: 'Central Relief Hub',
      idNumber: '402948220',
      beneficiaryName: 'Omar Salem',
      createdAt: DateTime.now(),
      estimatedWaiting: '2:30 PM',
      qrPayload: 'DAWROK|ticket=BK-71093|facility=Central Relief Hub|queue=14',
      peopleAhead: 0,
      status: QueueBookingStatus.scheduled,
      scheduledTime: '2:30 PM',
      windowOpensIn: '2h 15m',
    ),
    QueueBooking(
      ticketNumber: 'BK-88412',
      queueNumber: 19,
      facilityName: 'Al-Amal Medical Center',
      idNumber: '402948221',
      beneficiaryName: 'Fatima Salem',
      createdAt: DateTime.now(),
      estimatedWaiting: '~5 mins',
      qrPayload: 'DAWROK|ticket=BK-88412|facility=Al-Amal Medical Center|queue=19',
      peopleAhead: 11,
      status: QueueBookingStatus.inQueue,
    ),
  ];

  List<QueueBooking> get bookings => List.unmodifiable(_bookings);

  void addBooking(QueueBooking booking) {
    _bookings.insert(0, booking);
    notifyListeners();
  }
}
