import 'package:flutter/material.dart';

import '../services/queue_assignment_service.dart';

Future<int?> chooseFacilityQueueWindow(
  BuildContext context,
  int windowCount,
  String service,
) async {
  final windows = serviceWindows(windowCount);
  return windows.length == 1
      ? windows.single
      : showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Choose a window · $service'),
                ),
                for (final w in windows)
                  ListTile(
                    title: Text('Window $w'),
                    onTap: () => Navigator.pop(sheet, w),
                  ),
              ],
            ),
          ),
        );
}
