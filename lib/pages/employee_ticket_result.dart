import 'package:flutter/material.dart';
import 'package:first_project/l10n/app_language.dart';

class EmployeeTicketResult extends StatelessWidget {
  const EmployeeTicketResult({super.key, this.match, this.failure});
  final Map<String, dynamic>? match;
  final String? failure;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: match == null
            ? const Color(0xfffff7f7)
            : const Color(0xffeef8f2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: match == null
              ? const Color(0xffffdada)
              : const Color(0xff9be4b8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                match == null ? Icons.close : Icons.check_circle,
                color: match == null ? Colors.red : Colors.teal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(failure ?? "Ticket matches #${match?['queuePosition'] ?? ''}"),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: match == null
                        ? Colors.red.shade800
                        : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (match case final data?) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _detail('Name', data['citizenName'])),
                Expanded(child: _detail('Ticket ID', data['ticketId'])),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _detail('Service', data['service'])),
                Expanded(child: _detail('Today', 'Checked in')),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  Widget _detail(String label, dynamic value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label), style: const TextStyle(fontSize: 12, color: Colors.teal)),
      Text(
        tr('${value ?? '—'}'),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xff28374e),
        ),
      ),
    ],
  );
}
