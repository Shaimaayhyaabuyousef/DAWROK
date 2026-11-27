import 'package:first_project/pages/facility_add_staff_screen.dart';
import 'package:first_project/pages/facility_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    testWidgets(
      'staff invitation fits a ${width.toInt()} logical pixel screen',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.4)),
              child: child!,
            ),
            home: const FacilityAddStaffScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('National / Emp ID'), findsOneWidget);
        expect(find.text('Automatic'), findsOneWidget);
        expect(find.text('Active Pairing Code'), findsNothing);
        final field = tester.element(find.byType(TextFormField).first);
        expect(Theme.of(field).textTheme.bodyMedium?.fontFamily, 'Inter');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('facility navigation retains its tab callback', (tester) async {
    int? target;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FacilityBottomNav(
            selected: 1,
            onTap: (i) => target = i,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Search'));
    expect(target, 3);
  });
}
