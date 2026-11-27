import 'package:first_project/services/phone_login.dart';
import 'package:first_project/pages/demo_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recovery PIN completes the demo and returns to sign in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DemoRecoveryScreen()),
              ),
              child: const Text('Signin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Signin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0591234567');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.textContaining('Demo PIN:')).data!;
    for (final digit in label.split(': ').last.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, digit));
      await tester.pump();
    }
    final verify = find.text('Verify demo PIN');
    await tester.ensureVisible(verify);
    await tester.tap(verify);
    await tester.pumpAndSettle();
    expect(find.text('Signin'), findsOneWidget);
  });
  test('the same Palestinian mobile has one sign-in identity', () {
    for (final value in [
      '0591234567',
      '591234567',
      '+970 59-123-4567',
      '٠٠٩٧٠٥٩١٢٣٤٥٦٧',
      '۰۵۹۱۲۳۴۵۶۷',
    ]) {
      expect(localMobile(value), '0591234567');
      expect(mobileLoginId(value), 'p970591234567@login.dawrok.invalid');
    }
    expect(localMobile('0561234567'), '0561234567');
    for (final invalid in [
      '',
      'someone@example.com',
      '0591234567x',
      '1234',
      '+1 555 123 4567',
    ]) {
      expect(localMobile(invalid), isNull);
    }
  });
}
