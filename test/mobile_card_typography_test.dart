import 'package:first_project/pages/facility_queues_screen.dart';
import 'package:first_project/pages/facility_scan_store.dart';
import 'package:first_project/pages/facility_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter');
    for (final weight in [400, 500, 600, 700]) {
      font.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await font.load();
  });
  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'queue and visitor details remain readable at $width / $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 852);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const QueueWaitSummary(count: 128, minutes: 125),
                      FacilityVisitorCard(
                        visit: FacilityVisit(
                          ticketNumber: 'DkBhLxk9RL8pg1nhlox0',
                          visitorName: 'سارة أحمد · Sara Ahmad Mohammad Salem',
                          maskedId: '•••• 8291',
                          windowNumber: 12,
                          queueId: 'q',
                          estimatedMinutes: 125,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final element in find.byType(RichText).evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: paragraph.text.toPlainText(),
            );
            final x = paragraph.localToGlobal(Offset.zero).dx;
            expect(x, greaterThanOrEqualTo(0));
            expect(x + paragraph.size.width, lessThanOrEqualTo(width + 0.01));
          }
        },
      );
    }
  }
}
