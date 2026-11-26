import 'package:flutter/material.dart';
import 'package:first_project/l10n/app_language.dart';

/// Introductory copy above the existing add button on an empty facility list.
class FacilityEmptyState extends StatelessWidget {
  const FacilityEmptyState.queues({super.key})
    : icon = Icons.format_list_numbered_rounded,
      title = 'No queues yet',
      description =
          'Add your first queue so citizens can book a turn at your facility.';

  const FacilityEmptyState.staff({super.key})
    : icon = Icons.group_add_outlined,
      title = 'No staff members yet',
      description =
          'Invite your first employee to help serve your queues. You can also manage them yourself.';

  final IconData icon;
  final String title, description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 48, 16, 24),
    child: Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: const Color(0xffe8f7ff),
          child: Icon(icon, color: const Color(0xff03a9f4), size: 30),
        ),
        const SizedBox(height: 18),
        Text(
          tr(title),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xff243148),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(description),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.45,
            color: Color(0xff62728b),
          ),
        ),
      ],
    ),
  );
}
