import 'workspace_style.dart';

import 'package:flutter/material.dart';
import 'package:first_project/l10n/app_language.dart';

const facilityBlue = Color(0xFF4FAAF4);
const facilityDark = Color(0xFF222E43);
const facilityMuted = Color(0xFF94A5BE);
const facilityBorder = Color(0xFFDCE9F4);

void goToFacilityTab(BuildContext context, int index, int current) {
  if (index == current) return;
  const routes = [
    'facility_home_screen',
    'facility_queues_screen',
    'facility_staff_screen',
    'facility_search_screen',
    'facility_profile_screen',
  ];
  Navigator.pushReplacementNamed(context, routes[index]);
}

class FacilityBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int>? onTap;
  const FacilityBottomNav({super.key, required this.selected, this.onTap});
  @override
  Widget build(BuildContext context) {
    final icons = [
      'queues_home',
      selected == 1 ? 'queues_active' : 'queues',
      'staff',
      selected == 3 ? 'search_active' : 'search',
      'profile',
    ];
    const labels = ['Home', 'Queues', 'Staff', 'Search', 'Profile'];
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selected,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xff087cc2),
      unselectedItemColor: const Color(0xff586c83),
      selectedFontSize: 12,
      unselectedFontSize: 12,
      showUnselectedLabels: true,
      onTap: (i) =>
          onTap == null ? goToFacilityTab(context, i, selected) : onTap!(i),
      items: List.generate(
        labels.length,
        (i) => BottomNavigationBarItem(
          label: tr(labels[i]),
          tooltip: trOpt(labels[i]),
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: SizedBox.square(
              dimension: 22,
              child: WorkspaceIcon(
                icons[i],
                color: i == selected
                    ? const Color(0xff087cc2)
                    : const Color(0xff586c83),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmFacilityAction(
  BuildContext context,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Confirm action')),
        content: Text(tr(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Confirm')),
          ),
        ],
      ),
    ) ??
    false;
