import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:first_project/pages/citizen_booking_controls.dart';
import 'package:first_project/pages/queue_ticket_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SavePicker extends FilePickerPlatform {
  Uint8List? saved;
  String? name;
  String? mime;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    name = fileName;
    mime = mimeType;
    saved = bytes;
    return Uri.file('/tickets/$fileName');
  }
}

void main() {
  testWidgets('confirm uses the selected service and disables while booking', (
    tester,
  ) async {
    String? selected;
    final submitted = <String>[];
    var busy = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, update) => CitizenBookingControls(
              queues: const {'first': 'Accounts', 'second': 'Transfers'},
              selected: selected,
              busy: busy,
              reward: 'priority',
              onSelect: (id) => update(() => selected = id),
              onConfirm: (id) => update(() {
                busy = true;
                submitted.add(id);
              }),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('100 points'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfers').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Booking'));
    await tester.pump();
    expect(submitted, ['second']);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('save ticket sends a real PNG of the card to the system picker', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    final picker = _SavePicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = original);
    await tester.pumpWidget(
      MaterialApp(
        home: QueueTicketScreen(
          liveTicket: false,
          ticketNumber: 'ABC',
          queueNumber: 17,
          facilityName: 'BOP',
          idNumber: '123456789',
          createdAt: DateTime.utc(2026, 11, 22),
          estimatedWaiting: '~10 min',
          qrPayload: 'DAWROK|ticket=ABC|facility=BOP|queue=first',
        ),
      ),
    );
    expect(find.text('•••••6789'), findsOneWidget);
    await tester.ensureVisible(find.text('Save Ticket'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final save =
          tester
                  .widget<OutlinedButton>(
                    find.widgetWithText(OutlinedButton, 'Save Ticket'),
                  )
                  .onPressed!
              as Future<void> Function();
      await save();
      final bytes = picker.saved!;
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(bytes.length, greaterThan(2000));
      expect(picker.name, 'DAWROK-ticket-ABC.png');
      expect(picker.mime, 'image/png');
    });
    await tester.pumpAndSettle();
    expect(find.text('Ticket saved'), findsOneWidget);
  });
}
