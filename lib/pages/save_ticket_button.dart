import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SaveTicketButton extends StatefulWidget {
  final GlobalKey cardKey;
  final String ticketNumber;

  const SaveTicketButton({
    super.key,
    required this.cardKey,
    required this.ticketNumber,
  });

  @override
  State<SaveTicketButton> createState() => _SaveTicketButtonState();
}

class _SaveTicketButtonState extends State<SaveTicketButton> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final card =
          widget.cardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (card == null) throw StateError('Ticket is unavailable');
      final image = await card.toImage(pixelRatio: 3);
      final ByteData? png;
      try {
        png = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (png == null) throw StateError('Unable to create ticket image');
      if (!mounted) return;
      final name = widget.ticketNumber.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save ticket',
        fileName: 'DAWROK-ticket-$name.png',
        mimeType: 'image/png',
        bytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
      if (mounted && result != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ticket saved')));
      }
    } catch (error, stack) {
      debugPrint('Ticket export failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the ticket. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _saving ? null : _save,
    icon: const Icon(Icons.download_outlined),
    label: Text(_saving ? 'Saving…' : 'Save Ticket'),
  );
}
