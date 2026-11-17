import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:first_project/pages/home_screen.dart';

void main() {
  Widget view({
    Map<String, dynamic>? booking,
    bool loading = false,
    String? error,
    VoidCallback? search,
  }) => MaterialApp(
    home: CitizenHomeView(
      name: 'Citizen',
      points: 0,
      booking: booking,
      ticketId: 'test-ticket',
      loading: loading,
      error: error,
      onSearch: search ?? () {},
      onPoints: () {},
      onNotifications: () {},
      onTicket: () {},
      onBookings: () {},
      onProfile: () {},
      onRetry: () {},
    ),
  );
  testWidgets(
    'new citizen has no fabricated ticket and search remains navigable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var searched = false;
      await tester.pumpWidget(view(search: () => searched = true));
      expect(find.text('0 Pts'), findsOneWidget);
      expect(find.text('ACTIVE RESERVATION'), findsNothing);
      await tester.tap(find.text('Search facilities'));
      expect(searched, isTrue);
      await tester.scrollUntilVisible(
        find.text('Your next turn starts here'),
        200,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('real active ticket replaces the empty state', (tester) async {
    await tester.pumpWidget(
      view(
        booking: {
          'facilityName': 'Family Bakery',
          'service': 'Bread',
          'status': 'waiting',
        },
      ),
    );
    await tester.scrollUntilVisible(find.text('ACTIVE RESERVATION'), 200);
    expect(find.textContaining('test-ticket'), findsOneWidget);
    expect(find.text('Your next turn starts here'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading and error never imply no bookings', (tester) async {
    await tester.pumpWidget(view(loading: true));
    expect(find.text('Your next turn starts here'), findsNothing);
    await tester.pumpWidget(view(error: 'Unable to load'));
    expect(find.text('Your next turn starts here'), findsNothing);
  });
}
