import 'package:first_project/pages/citizen_bottom_nav.dart';
import 'package:first_project/pages/facility_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    testWidgets('navigation fits equal columns at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CitizenBottomNav(
              selected: 1,
              onTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      final targets = find.descendant(
        of: find.byType(CitizenBottomNav),
        matching: find.byType(InkWell),
      );
      expect(targets, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(
          tester.getSize(targets.at(i)).width,
          closeTo((width - 24) / 3, .1),
        );
        await tester.tap(targets.at(i));
        expect(tapped, i);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FacilityBottomNav(
              selected: 0,
              onTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      for (final (i, label) in [
        'Home',
        'Queues',
        'Staff',
        'Search',
        'Profile',
      ].indexed) {
        expect(find.text(label).hitTestable(), findsOneWidget);
        await tester.tap(find.text(label));
        expect(tapped, i);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
