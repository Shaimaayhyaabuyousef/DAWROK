import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:first_project/pages/citizen_report_screen.dart';
import 'package:first_project/services/report_service.dart';
import 'package:first_project/services/report_photo.dart';

class FakeReports implements ReportRepository {
  final ReporterRole role;
  FakeReports(this.role);
  bool fail = false;
  Completer<void>? pending;
  int attempts = 0;
  final List<String> ids = [];
  ReportDraft? saved;
  @override
  Future<ReportAuthor> author() async => ReportAuthor(
    'test-user',
    role,
    facilityId: role == ReporterRole.citizen ? '' : 'workplace',
  );
  @override
  Future<List<ReportFacility>> facilities() async => [
    const ReportFacility('bakery-id', 'Family Bakery'),
    const ReportFacility('clinic-id', 'Clinic'),
  ];
  @override
  String newId() => 'report-reference';
  @override
  Future<void> submit(String id, ReportAuthor author, ReportDraft draft) async {
    attempts++;
    ids.add(id);
    if (fail) throw StateError('Offline');
    await pending?.future;
    saved = draft;
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeReports repository, {
    Uint8List? photo,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportScreen(
          repository: repository,
          photoPicker: (_) => Future.value(photo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Send Report'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send Report'));
    await tester.pumpAndSettle();
  }

  testWidgets('citizen selects a real facility and sends the linked report', (
    tester,
  ) async {
    final repo = FakeReports(ReporterRole.citizen);
    await mount(tester, repo);
    await tester.tap(find.text('Select the type of report'));
    await tester.pumpAndSettle();
    expect(find.text('Report an issue with the app'), findsOneWidget);
    await tester.tap(find.text('Facility Report'));
    await tester.pumpAndSettle();
    expect(find.text('FACILITY NAME'), findsOneWidget);
    await tester.tap(find.text('facility name'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search facilities'),
      'Family',
    );
    await tester.pumpAndSettle();
    expect(find.text('Clinic'), findsNothing);
    await tester.tap(find.text('Family Bakery'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('report-description')),
      'There is a delay at this facility.',
    );
    await send(tester);
    expect(repo.saved!.kind, ReportKind.facility);
    expect(repo.saved!.facility!.id, 'bakery-id');
    expect(repo.saved!.anonymous, isTrue);
    expect(find.text('Report sent successfully'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final role in [ReporterRole.facility, ReporterRole.employee]) {
    testWidgets('${role.name} can only send app reports', (tester) async {
      final repo = FakeReports(role);
      await mount(tester, repo);
      expect(find.text('FACILITY NAME'), findsNothing);
      await tester.tap(find.text('Report an issue with the app'));
      await tester.pumpAndSettle();
      expect(find.text('Facility Report'), findsNothing);
      await tester.tap(find.text('Report an issue with the app').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report-description')),
        'The application is not responding.',
      );
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await send(tester);
      expect(repo.saved!.kind, ReportKind.app);
      expect(repo.saved!.facility, isNull);
      expect(repo.saved!.anonymous, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'validation, photo preview/removal and retry preserve the draft and ID',
    (tester) async {
      final repo = FakeReports(ReporterRole.citizen);
      final photo = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 10, height: 10)),
      );
      await mount(tester, repo, photo: photo);
      await send(tester);
      expect(repo.attempts, 0);
      expect(find.text('Select the type of report.'), findsOneWidget);
      await tester.ensureVisible(find.text('Select the type of report'));
      await tester.tap(find.text('Select the type of report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report an issue with the app'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report-description')),
        'x' * 501,
      );
      await tester.pump();
      expect(find.text('500 / 500'), findsOneWidget);
      await tester.tap(find.text('Add Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove photo'), findsNothing);
      await tester.tap(find.text('Add Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      repo.fail = true;
      await send(tester);
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      expect(repo.attempts, 1);
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      repo.fail = false;
      await send(tester);
      expect(repo.ids.toSet(), {'report-reference'});
      expect(repo.saved!.photo, photo);
      expect(find.text('Report sent successfully'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('send is disabled while submitting', (tester) async {
    final repo = FakeReports(ReporterRole.employee)
      ..pending = Completer<void>();
    await mount(tester, repo);
    await tester.enterText(
      find.byKey(const ValueKey('report-description')),
      'The scanner screen freezes every time.',
    );
    await tester.scrollUntilVisible(
      find.text('Send Report'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send Report'));
    await tester.pump();
    expect(repo.attempts, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(repo.attempts, 1);
    expect(find.text('Report sent successfully'), findsOneWidget);
  });
  test('report photos are bounded JPEGs and invalid photos are rejected', () {
    final picture = img.Image(width: 1200, height: 1000);
    final result = compressReportPhoto(
      Uint8List.fromList(img.encodePng(picture)),
    );
    expect(result.length, lessThanOrEqualTo(200000));
    expect(img.decodeJpg(result)!.width, 900);
    expect(
      () => compressReportPhoto(Uint8List.fromList([1, 2, 3])),
      throwsStateError,
    );
  });
}
