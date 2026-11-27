import 'package:first_project/pages/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    testWidgets('intro navigation and signup at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: const Onboarding(),
          routes: {
            'login': (_) => const Scaffold(body: Text('Login destination')),
            'signup': (_) => const Scaffold(body: Text('Signup destination')),
          },
        ),
      );
      Future<void> forward() async {
        await tester.drag(find.byType(PageView), Offset(-width * .8, 0));
        await tester.pumpAndSettle();
      }

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Signup'), findsNothing);
      await forward();
      await forward();
      await tester.tap(find.byTooltip('Back').hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.text('Book your appointment easily').hitTestable(),
        findsOneWidget,
      );
      await forward();
      final signup = find.text('Signup');
      await tester.ensureVisible(signup);
      await tester.tap(signup);
      await tester.pumpAndSettle();
      expect(find.text('Signup destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
