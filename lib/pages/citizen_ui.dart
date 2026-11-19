import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/citizen_identity_service.dart';
import 'queue_ticket_screen.dart';

const citizenBlue = Color(0xFF03A9F4);
const citizenSoftBlue = Color(0xFF64B9FA);
const citizenInk = Color(0xFF192638);
BoxDecoration citizenPanel({Color color = Colors.white, double radius = 18}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFE2F1FA)),
    );
String citizenTime(DateTime date) =>
    '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
Future<void> openCitizenTicket(
  BuildContext context,
  String id,
  Map<String, dynamic> data,
) async {
  try {
    final nationalId = await CitizenIdentityService.instance.savedNationalId();
    if (!context.mounted) return;
    final time = (data['slotStart'] as Timestamp?)?.toDate();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QueueTicketScreen(
          ticketNumber: id,
          queueNumber: (data['queuePosition'] as num?)?.toInt() ?? 0,
          windowNumber: (data['windowNumber'] as num?)?.toInt(),
          windowCount: (data['windowCount'] as num?)?.toInt(),
          scheduledAt: time,
          facilityName: data['facilityName'] as String? ?? '',
          idNumber: nationalId,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          estimatedWaiting: time == null
              ? '—'
              : '~${time.difference(DateTime.now()).inMinutes.clamp(0, 1440)} min',
          qrPayload:
              'DAWROK|ticket=$id|facility=${data['facilityId']}|queue=${data['queueId']}',
        ),
      ),
    );
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
  }
}
