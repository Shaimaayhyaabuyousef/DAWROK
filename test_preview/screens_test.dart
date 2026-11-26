// Renders key screens in English and Arabic for visual review of the
// right-to-left layout. Run: flutter test --update-goldens test_preview
import 'dart:io';

import 'package:first_project/l10n/app_language.dart';
import 'package:first_project/models/citizen_registration_draft.dart';
import 'package:first_project/pages/citizen_id_verification_screen.dart';
import 'package:first_project/pages/citizen_signup_screen.dart';
import 'package:first_project/pages/facility_add_staff_screen.dart';
import 'package:first_project/pages/home_screen.dart';
import 'package:first_project/pages/login.dart';
import 'package:first_project/pages/onboarding.dart';
import 'package:first_project/pages/queue_ticket_screen.dart';
import 'package:first_project/pages/who_we_are_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _font('Inter', [for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf']);
    await _font('IBMPlexSansArabic', [for (final w in [400, 500, 600, 700]) 'assets/fonts/IBMPlexSansArabic-$w.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _font('MaterialIcons', [icons.path]);
  });

  final screens = <String, Widget Function()>{
    'onboarding': () => const Onboarding(),
    'login': () => const Login(),
    'signup': () => const CitizenSignUpScreen(),
    'id_verification': () => const CitizenIdVerificationScreen(
      draft: CitizenRegistrationDraft(fullName: 'Sara', nationalId: '407830363', phone: '0591234567', password: 'testing1'),
    ),
    'home': () => CitizenHomeView(
      name: 'Sara',
      points: 25,
      booking: const {'facilityName': 'Bank of Palestine', 'service': 'Teller', 'status': 'waiting'},
      ticketId: 'A1B2C3',
      loading: false,
      error: null,
      onSearch: () {},
      onPoints: () {},
      onNotifications: () {},
      onTicket: () {},
      onBookings: () {},
      onProfile: () {},
      onRetry: () {},
    ),
    'ticket': () => QueueTicketScreen(
      ticketNumber: 'A1B2C3',
      liveTicket: false,
      queueNumber: 17,
      windowNumber: 2,
      facilityName: 'Bank of Palestine',
      idNumber: '407830363',
      createdAt: DateTime.utc(2026, 11, 26, 7),
      scheduledAt: DateTime.utc(2026, 11, 26, 8, 30),
      estimatedWaiting: '~35 min',
      qrPayload: 'DAWROK|ticket=A1B2C3|facility=f|queue=q',
    ),
    'add_staff': () => const FacilityAddStaffScreen(),
    'who_we_are': () => const WhoWeAreScreen(),
  };

  for (final lang in ['en', 'ar']) {
    for (final e in screens.entries) {
      testWidgets('${e.key} $lang', (tester) async {
        tester.view.physicalSize = const Size(393 * 2, 852 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppLanguage.locale.value = Locale(lang);
        addTearDown(() => AppLanguage.locale.value = const Locale('en'));
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          supportedLocales: AppLanguage.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['IBMPlexSansArabic'],
            scaffoldBackgroundColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3), primary: const Color(0xFF2196F3), surface: Colors.white),
          ),
          home: e.value(),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${e.key}_$lang.png'));
        // Overflow and layout errors in either language are failures.
        final error = tester.takeException();
        if (error != null) {
          File('goldens/${e.key}_$lang.error.txt')
            ..createSync(recursive: true)
            ..writeAsStringSync('$error');
        }
      });
    }
  }
}
