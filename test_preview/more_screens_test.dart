// Renders more screens in Arabic for the presentation deck.
// Run: flutter test --update-goldens test_preview
import 'dart:io';

import 'package:first_project/l10n/app_language.dart';
import 'package:first_project/models/citizen_registration_draft.dart';
import 'package:first_project/pages/citizen_pin_setup_screen.dart';
import 'package:first_project/pages/demo_recovery_screen.dart';
import 'package:first_project/pages/employee_join_screen.dart';
import 'package:first_project/pages/employee_login_screen.dart';
import 'package:first_project/pages/employee_register_screen.dart';
import 'package:first_project/pages/employee_ticket_result.dart';
import 'package:first_project/pages/facility_add_queue_sheet.dart';
import 'package:first_project/pages/facility_empty_state.dart';
import 'package:first_project/pages/facility_staff_code_dialog.dart';
import 'package:first_project/pages/home_screen.dart';
import 'package:first_project/pages/onboarding.dart';
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

/// Opens a dialog or sheet over a plain page once the first frame is drawn.
class _Opener extends StatefulWidget {
  const _Opener(this.open, {this.background});
  final void Function(BuildContext) open;
  final Widget? background;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: const Color(0xFFF5F9FE), body: widget.background ?? const SizedBox.expand());
}

Widget _result({Map<String, dynamic>? match, String? failure}) => Scaffold(
  backgroundColor: Colors.white,
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [EmployeeTicketResult(match: match, failure: failure)]),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await _font('Inter', [for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf']);
    await _font('IBMPlexSansArabic', [for (final w in [400, 500, 600, 700]) 'assets/fonts/IBMPlexSansArabic-$w.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _font('MaterialIcons', [icons.path]);
  });

  // name -> (widget, pages to swipe forward before the picture)
  final screens = <String, (Widget Function(), int)>{
    'home_called': (
      () => CitizenHomeView(
        name: 'Sara',
        points: 30,
        booking: const {'facilityName': 'Bank of Palestine', 'service': 'Teller', 'status': 'called', 'windowNumber': 2},
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
        onScan: () {},
      ),
      0,
    ),
    'onboarding2': (() => const Onboarding(), 1),
    'onboarding3': (() => const Onboarding(), 2),
    'pin_setup': (
      () => const CitizenPinSetupScreen(
        draft: CitizenRegistrationDraft(fullName: 'Sara', nationalId: '407830363', phone: '0591234567', password: 'testing1'),
      ),
      0,
    ),
    'recovery': (() => const DemoRecoveryScreen(), 0),
    'staff_join': (() => const EmployeeJoinScreen(), 0),
    'staff_login': (() => const EmployeeLoginScreen(), 0),
    'staff_register': (
      () => const EmployeeRegisterScreen(facilityNumber: '1024', invitationCode: 'K7M2QX', contactPhone: '0591234567'),
      0,
    ),
    'staff_verified': (
      () => _result(match: {'queuePosition': 13, 'citizenName': 'Sara', 'ticketId': 'A1B2C3', 'service': 'Teller'}),
      0,
    ),
    'staff_wrong': (
      () => _result(failure: 'This is ticket #15, not #13. Please wait for the called turn.'),
      0,
    ),
    'empty_queues': (() => const Scaffold(backgroundColor: Colors.white, body: Center(child: FacilityEmptyState.queues())), 0),
    'add_queue': (() => _Opener((c) => showFacilityAddQueueSheet(c)), 0),
    'staff_code': (
      () => _Opener(
        (c) => showStaffCodeDialog(
          c,
          code: 'K7M2QX',
          facilityNumber: '1024',
          staffName: 'Lina',
          expiresAt: DateTime.utc(2026, 11, 28, 9),
        ),
      ),
      0,
    ),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key} ar', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppLanguage.locale.value = const Locale('ar');
      addTearDown(() => AppLanguage.locale.value = const Locale('en'));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
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
        home: e.value.$1(),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      for (var p = 0; p < e.value.$2; p++) {
        // Right-to-left: the next page comes in from the left.
        await tester.drag(find.byType(PageView), const Offset(500, 0));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${e.key}_ar.png'));
      final error = tester.takeException();
      if (error != null) {
        File('goldens/${e.key}_ar.error.txt')
          ..createSync(recursive: true)
          ..writeAsStringSync('$error');
      }
    });
  }
}
