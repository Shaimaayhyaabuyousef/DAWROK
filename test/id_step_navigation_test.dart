import 'dart:convert';

import 'package:first_project/models/citizen_registration_draft.dart';
import 'package:first_project/pages/citizen_id_verification_screen.dart';
import 'package:first_project/pages/citizen_pin_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class TestPicker extends ImagePickerPlatform {
  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse();
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/ahkAAAAASUVORK5CYII=',
    ),
    mimeType: 'image/png',
    name: 'card.png',
  );
}

void main() {
  testWidgets(
    'a rejected photo stays in step two and a successful retry opens PIN',
    (tester) async {
      final original = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = TestPicker();
      addTearDown(() => ImagePickerPlatform.instance = original);
      const channel = MethodChannel('dawrok/id_reader');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var recognized = '123456788';
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'aspect': 1.6,
          'lines': [
            {'text': 'السلطة الفلسطينية', 'y': 0.1},
            {'text': 'بطاقة هوية', 'y': 0.2},
            {'text': 'رقم الهوية $recognized', 'y': 0.35},
            {'text': 'الاسم الشخصي', 'y': 0.5},
            {'text': 'تاريخ الميلاد', 'y': 0.7},
          ],
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        const MaterialApp(
          home: CitizenIdVerificationScreen(
            draft: CitizenRegistrationDraft(
              fullName: 'Test',
              nationalId: '123456789',
              phone: '0590000000',
              password: 'testing',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Gallery');
      await tester.scrollUntilVisible(button, 160);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.textContaining('number differs'), findsOneWidget);
      expect(find.byType(CitizenPinSetupScreen), findsNothing);
      recognized = '123456789';
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(CitizenPinSetupScreen), findsOneWidget);
    },
  );
}
