import 'package:flutter/material.dart';
import 'package:first_project/l10n/app_language.dart';

/// Shown in the middle of the screen when a facility has no queues or staff yet.
/// [action] is the screen's own add button, placed right under the message.
class FacilityEmptyState extends StatelessWidget {
  const FacilityEmptyState.queues({super.key, this.action})
    : icon = Icons.format_list_numbered_rounded,
      title = 'No queues yet',
      description =
          'Add your first queue so citizens can book a turn at your facility.';

  const FacilityEmptyState.staff({super.key, this.action})
    : icon = Icons.group_add_outlined,
      title = 'No staff members yet',
      description =
          'Invite your first employee to help serve your queues. You can also manage them yourself.';

  final IconData icon;
  final String title, description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(color: Color(0xFFF1F8FF), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(color: Color(0xFFE1F0FD), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF2196F3), size: 36),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr(title),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xff243148),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              tr(description),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                height: 1.6,
                color: Color(0xff62728b),
              ),
            ),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 32), action!],
      ],
    ),
  );
}

/// Places [child] in the middle of the space left on screen, and still scrolls
/// when the screen is too short for it.
class FacilityCentered extends StatelessWidget {
  const FacilityCentered({super.key, required this.child, this.maxWidth = 354});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: Center(
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
        ),
      ),
    ),
  );
}
