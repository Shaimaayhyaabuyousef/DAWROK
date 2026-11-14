import 'package:flutter/material.dart';

const facilityBlue = Color(0xFF4FAAF4);
const facilityDark = Color(0xFF222E43);
const facilityMuted = Color(0xFF94A5BE);
const facilityBorder = Color(0xFFDCE9F4);

void goToFacilityTab(BuildContext context, int index, int current) {
  if (index == current) return;
  const routes = [
    'facility_home_screen', 'facility_queues_screen',
    'facility_staff_screen', 'facility_search_screen', 'facility_profile_screen',
  ];
  Navigator.pushReplacementNamed(context, routes[index]);
}

class FacilityBottomNav extends StatelessWidget {
  final int selected;
  const FacilityBottomNav({super.key, required this.selected});
  @override
  Widget build(BuildContext context) {
    const icons = [Icons.bar_chart_rounded, Icons.receipt_long_outlined,
      Icons.groups_outlined, Icons.search_rounded, Icons.account_circle_outlined];
    const labels = ['Home', 'Queues', 'Staff', 'Search', 'Profile'];
    return SafeArea(top: false, child: Container(
      height: 65, color: Colors.white,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (i) => IconButton(
          tooltip: labels[i],
          onPressed: () => goToFacilityTab(context, i, selected),
          icon: Icon(icons[i], size: 29, color: i == selected ? const Color(0xFF2195E9) : const Color(0xFF6AB9FA)),
        )),
      ),
    ));
  }
}

Future<bool> confirmFacilityAction(BuildContext context, String message) async =>
  await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Text('Confirm action'), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm'))],
  )) ?? false;
