import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'facility_nav.dart';

/// Display only to the signed-in facility owner.
/// The same code is kept in the owner's restricted staff document until
/// it is redeemed, rejected, revoked or expires.
Future<void> showStaffCodeDialog(
  BuildContext context, {
  required String code,
  required String staffName,
  required DateTime expiresAt,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    title: const Row(children: [
      Icon(Icons.vpn_key_outlined, color: facilityBlue),
      SizedBox(width: 10),
      Expanded(child: Text('Employee Link Code')),
    ]),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Share this code securely with $staffName. '
            'The employee uses it to request access to your facility.'),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            border: Border.all(color: const Color(0xFFA9DFFF)),
            borderRadius: BorderRadius.circular(13),
          ),
          child: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: facilityDark),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Expires: ${expiresAt.toLocal()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: facilityMuted),
        ),
        const SizedBox(height: 6),
        const Text(
          'The code also remains on this employee’s card after closing.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: facilityMuted),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: facilityBlue),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Code copied to clipboard')),
            );
          }
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy Code'),
      ),
    ],
  ),
);
