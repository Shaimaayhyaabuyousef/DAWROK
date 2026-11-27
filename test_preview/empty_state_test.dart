// Renders the empty facility screens (no queues, no staff) in both languages.
import 'dart:io';

import 'package:first_project/l10n/app_language.dart';
import 'package:first_project/pages/facility_empty_state.dart';
import 'package:first_project/pages/facility_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Widget _button(String label) => SizedBox(
  height: 54,
  child: ElevatedButton.icon(
    onPressed: () {},
    style: ElevatedButton.styleFrom(backgroundColor: facilityBlue, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    icon: const Icon(Icons.add_circle_outline, size: 24),
    label: Text(tr(label), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
  ),
);

void main() {
  tearDownAll(() => debugDisableShadows = true);
  setUpAll(() async {
    // Draw real soft shadows instead of the test default solid outlines.
    debugDisableShadows = false;
    await _font('Inter', [for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf']);
    await _font('IBMPlexSansArabic', [for (final w in [400, 500, 600, 700]) 'assets/fonts/IBMPlexSansArabic-$w.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _font('MaterialIcons', [icons.path]);
  });
  final screens = <String, Widget Function()>{
    'empty_queues': () => FacilityEmptyState.queues(action: _button('Add Queue')),
    'empty_staff': () => FacilityEmptyState.staff(action: _button('Add Staff Member')),
  };
  for (final lang in ['en', 'ar']) {
    for (final e in screens.entries) {
      for (final size in [const Size(393, 852), const Size(320, 568)]) {
        testWidgets('${e.key} $lang ${size.height.toInt()}', (tester) async {
          tester.view.physicalSize = size * 2;
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
            theme: ThemeData(useMaterial3: true, fontFamily: 'Inter', fontFamilyFallback: const ['IBMPlexSansArabic']),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(bottom: false, child: FacilityCentered(child: e.value())),
              bottomNavigationBar: FacilityBottomNav(selected: e.key == 'empty_queues' ? 1 : 2, onTap: (_) {}),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 300));
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('goldens/${e.key}_${lang}_${size.height.toInt()}.png'));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
