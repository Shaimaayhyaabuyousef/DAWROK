import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:first_project/pages/facility_add_queue_sheet.dart';
import 'package:first_project/pages/facility_queue_store.dart';
import 'package:first_project/services/queue_assignment_service.dart';
import 'package:first_project/services/booking_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  testWidgets('queue editor saves zero or multiple service windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FacilityQueueDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showFacilityAddQueueSheet(
                  context,
                  editing: const FacilityQueue(
                    windowNumber: 7,
                    windowCount: 0,
                    service: 'General Service',
                    counter: 'A',
                    capacity: 50,
                    beneficiaries: 0,
                    waitingMinutes: 15,
                    shift: FacilityQueueShift.morning,
                    startsAt: TimeOfDay(hour: 8, minute: 0),
                    endsAt: TimeOfDay(hour: 13, minute: 30),
                    isActive: false,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('No windows — direct queue service'), findsOneWidget);
    final row = find
        .ancestor(of: find.text('Service windows'), matching: find.byType(Row))
        .first;
    final plus = find.descendant(of: row, matching: find.byIcon(Icons.add));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(saved?.windowCount, 2);
    expect(tester.takeException(), isNull);
  });
  test('direct service and multiple windows allocate without duplicates', () {
    expect(serviceWindows(0), [0]);
    expect(serviceWindows(3), [1, 2, 3]);
    final a = allocateStaff({'a': 0, 'b': 2}, ['e4', 'e3', 'e2', 'e1'], {});
    expect(a.length, 3);
    expect(a['e1'], {'queueId': 'a', 'windowNumber': 0});
    expect(a['e3'], {'queueId': 'b', 'windowNumber': 2});
    expect(a.containsKey('e4'), isFalse);
    final next = allocateStaff({'a': 0, 'b': 2}, ['e4', 'e3', 'e2'], a);
    expect(next['e2'], a['e2']);
    expect(next['e4'], a['e1']);
    final resized = allocateStaff({'b': 1}, ['e4', 'e3', 'e2'], next);
    expect(resized.length, 1);
    expect(resized['e2'], a['e2']);
    expect(allocateStaff({'a': 0}, [], {}), isEmpty);
  });
  test('postponed tickets move behind other due tickets', () {
    final time = Timestamp.fromDate(DateTime.utc(2026, 11, 19, 8));
    final a = {'slotStart': time, 'postponements': 1, 'queuePosition': 1};
    final b = {'slotStart': time, 'postponements': 0, 'queuePosition': 2};
    expect(compareBookingRows(a, 'a', b, 'b'), greaterThan(0));
  });
}
