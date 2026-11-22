import 'package:flutter/material.dart';

class CitizenBookingControls extends StatelessWidget {
  final Map<String, String> queues;
  final String? selected;
  final bool busy;
  final String reward;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onConfirm;

  const CitizenBookingControls({
    super.key,
    required this.queues,
    required this.selected,
    required this.busy,
    required this.reward,
    required this.onSelect,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final queue = queues.containsKey(selected)
        ? selected
        : selected == null && queues.length == 1
        ? queues.keys.single
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (queues.isNotEmpty) ...[
          if (queues.length == 1 && queue != null)
            Text('Service: ${queues[queue]}')
          else
            DropdownButton<String>(
              hint: const Text('Choose a service'),
              value: queue,
              isExpanded: true,
              items: queues.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : onSelect,
            ),
          if (reward != 'none')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${reward == 'extra' ? 'Extra reward place' : 'Priority within your time slot'} · 100 points. Returned if you cancel before being called or the facility cancels service.',
              ),
            ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: busy || queue == null ? null : () => onConfirm(queue),
          icon: const Icon(Icons.calendar_month_outlined, size: 22),
          label: Text(
            busy ? 'Checking booking…' : 'Confirm Booking',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: const Color(0xFF49AAF2),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFADD8F7),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
        ),
      ],
    );
  }
}
