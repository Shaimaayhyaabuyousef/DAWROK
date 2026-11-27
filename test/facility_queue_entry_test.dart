import 'package:first_project/pages/facility_empty_state.dart';
import 'package:first_project/pages/facility_queue_window_picker.dart';
import 'package:flutter/material.dart';
import 'package:first_project/services/queue_assignment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner automatically gets an unstaffed active position', () {
    expect(availableOwnerWindow([0], {}, {}), 0);
    expect(availableOwnerWindow([0], {0}, {}), isNull);
    expect(availableOwnerWindow([1, 2, 3], {1}, {}), 2);
    expect(availableOwnerWindow([1, 2], {1, 2}, {}), isNull);
    expect(availableOwnerWindow([], {}, {}), isNull);
  });
  test(
    'owner can resume an outstanding turn without taking a staff position',
    () {
      expect(availableOwnerWindow([1, 2, 3], {1}, {1, 3}), 3);
      expect(availableOwnerWindow([1, 2], {1}, {1}), 2);
    },
  );
  test('window numbers are scoped to the selected queue', () {
    expect(
      assignedServiceWindows({
        'assignments': {
          'a': {'queueId': 'bank', 'windowNumber': 1},
          'b': {'queueId': 'post', 'windowNumber': 2},
        },
      }, 'post'),
      {2},
    );
    expect(assignedServiceWindows(null, 'post'), isEmpty);
  });
  testWidgets('empty lists explain the first action on a narrow phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              FacilityEmptyState.queues(),
              FacilityEmptyState.staff(),
            ],
          ),
        ),
      ),
    );
    expect(find.text('No queues yet'), findsOneWidget);
    expect(find.text('No staff members yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
