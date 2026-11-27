import 'package:first_project/pages/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [0.85, 1.0, 1.5, 2.0]) {
    testWidgets('app routes and dialogs respect design sizes at scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // Use the production MaterialApp builder with a route independent of Firebase.
      await tester.pumpWidget(const SizedBox());
      final app = const MyApp().app(
        tester.element(find.byType(SizedBox)),
        const Locale('en'),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: app.builder,
          theme: app.theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('Dialog title')),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      );
      for (final label in ['Open dialog', 'Dialog title']) {
        final context = tester.element(find.text(label));
        for (final size in [11.0, 16.0, 24.0]) {
          expect(
            MediaQuery.textScalerOf(context).scale(size),
            closeTo(size * scale.clamp(0.9, 1.0), 0.001),
          );
        }
        if (label == 'Open dialog') {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
      }
    });
  }
}
