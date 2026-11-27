import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:first_project/services/queue_schedule.dart';
import 'package:first_project/pages/queue_ticket_screen.dart';

void main() {
  test('turns fill arrival windows automatically in reservation order', () {
    final now = DateTime.utc(2026, 11, 18, 5);
    DateTime? assign(int reserved, {DateTime? at}) => QueueSchedule.nextBooking(
      start: 480,
      end: 600,
      capacity: 8,
      reserved: reserved,
      now: at ?? now,
    );
    expect(assign(0), DateTime.utc(2026, 11, 18, 6));
    expect(assign(1), assign(0));
    expect(assign(2), DateTime.utc(2026, 11, 18, 6, 30));
    expect(assign(7), DateTime.utc(2026, 11, 18, 7, 30));
    expect(
      assign(8),
      DateTime.utc(2026, 11, 18, 7, 30),
    ); // Separate reward capacity.
    expect(
      assign(0, at: DateTime.utc(2026, 11, 18, 6, 10)),
      DateTime.utc(2026, 11, 18, 6, 30),
    );
    expect(assign(0, at: DateTime.utc(2026, 11, 18, 7, 31)), isNull);
    expect(
      QueueSchedule.nextBooking(
        start: 600,
        end: 620,
        capacity: 8,
        reserved: 0,
        now: now,
      ),
      isNull,
    );
    expect(
      QueueSchedule.nextBooking(
        start: 480,
        end: 600,
        capacity: 0,
        reserved: 0,
        now: now,
      ),
      isNull,
    );
  });

  test('facility day rolls over in Gaza in winter and summer', () {
    expect(
      QueueSchedule.dayKey(DateTime.utc(2026, 11, 21, 22, 15)),
      '20261122',
    );
    expect(QueueSchedule.dayKey(DateTime.utc(2026, 7, 1, 21, 15)), '20260702');
    final localMidnight = QueueSchedule.availableSlots(
      0,
      60,
      DateTime.utc(2026, 11, 21, 22, 10),
    );
    expect(localMidnight, [DateTime.utc(2026, 11, 21, 22, 30)]);
  });

  testWidgets(
    'ticket displays assigned turn and appointment, not window or creation time',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueueTicketScreen(
            ticketNumber: 'ABC',
            liveTicket: false,
            queueNumber: 17,
            windowNumber: 2,
            facilityName: 'Family Bakery',
            idNumber: '123456789',
            createdAt: DateTime.utc(2026, 11, 18, 5),
            scheduledAt: DateTime.utc(2026, 11, 18, 7, 30),
            estimatedWaiting: '~150 min',
            qrPayload: 'DAWROK|ticket=ABC',
          ),
        ),
      );
      expect(find.text('17'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);
      expect(find.text('7:00 AM'), findsNothing);
      expect(find.textContaining('Window 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
