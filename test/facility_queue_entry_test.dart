import 'package:first_project/pages/facility_empty_state.dart';
import 'package:first_project/pages/facility_queue_window_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final count in [0, 1, 3]) {
    testWidgets('owner opens queue with $count service windows', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await chooseFacilityQueueWindow(
                    context,
                    count,
                    'Service A',
                  );
                },
                child: const Text('Manage queue'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Manage queue'));
      await tester.pumpAndSettle();
      if (count == 3) {
        expect(selected, isNull);
        await tester.tap(find.text('Window 2'));
        await tester.pumpAndSettle();
      }
      expect(selected, count == 3 ? 2 : count);
    });
  }
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
