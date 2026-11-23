import 'package:first_project/pages/employee_ticket_result.dart';
import 'package:first_project/services/employee_work_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual and QR entry identify the same ticket within its queue', () {
    expect(employeeTicketCode(' #BK-123 ', 'f', 'q'), 'BK-123');
    expect(
      employeeTicketCode('DAWROK|ticket=BK-123|facility=f|queue=q', 'f', 'q'),
      'BK-123',
    );
    expect(
      () => employeeTicketCode(
        'DAWROK|ticket=t|facility=f|queue=other',
        'f',
        'q',
      ),
      throwsStateError,
    );
  });
  for (final width in [320.0, 393.0]) {
    testWidgets('both ticket results fit at width $width with enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: const ListViewResults(),
            ),
          ),
        ),
      );
      expect(find.text('Ticket matches #13'), findsOneWidget);
      expect(find.textContaining('not #13'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class ListViewResults extends StatelessWidget {
  const ListViewResults({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: const [
      EmployeeTicketResult(
        match: {
          'queuePosition': 13,
          'ticketId': 'exampleVeryLongBookingIdentifier',
          'citizenName': 'Long beneficiary name',
          'service': 'Express service',
        },
      ),
      EmployeeTicketResult(
        failure:
            'This is ticket #15, not #13. Please wait for the called turn.',
      ),
    ],
  );
}
