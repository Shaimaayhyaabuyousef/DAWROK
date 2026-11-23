import 'workspace_style.dart';

import 'package:flutter/material.dart';

import 'facility_nav.dart';
import 'facility_scan_store.dart';

class FacilitySearchScreen extends StatefulWidget {
  const FacilitySearchScreen({super.key});
  @override
  State<FacilitySearchScreen> createState() => _FacilitySearchScreenState();
}

class _FacilitySearchScreenState extends State<FacilitySearchScreen> {
  final query = TextEditingController();
  @override
  void initState() {
    super.initState();
    FacilityScanStore.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FacilityScanStore.instance.removeListener(_refresh);
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = query.text.trim().toLowerCase();
    final result = FacilityScanStore.instance.visits
        .where(
          (v) =>
              text.isEmpty ||
              '${v.visitorName} ${v.maskedId} ${v.queuePosition?.toString().padLeft(2, '0') ?? ''} ${v.ticketNumber}'
                  .toLowerCase()
                  .contains(text),
        )
        .toList();
    return WorkspaceStyle(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(29, 28, 29, 22),
                child: TextField(
                  controller: query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Center(
                      widthFactor: 1,
                      child: WorkspaceIcon('search', color: Color(0xFF00A4ED)),
                    ),
                    hintText: 'Full Name OR ID',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB3DFFF),
                      fontSize: 16,
                    ),
                    isDense: true,
                    prefixIconConstraints: const BoxConstraints(minWidth: 42),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: facilityBorder),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4AAAF3)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    suffixIcon: query.text.isNotEmpty
                        ? IconButton(
                            onPressed: () => setState(query.clear),
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: result.isEmpty
                    ? const Center(child: Text('No matching tickets'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(19, 12, 19, 20),
                        itemCount: result.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            FacilityVisitorCard(visit: result[i]),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const FacilityBottomNav(selected: 3),
      ),
    );
  }
}

class FacilityVisitorCard extends StatelessWidget {
  const FacilityVisitorCard({super.key, required this.visit});
  final FacilityVisit visit;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDDE7F1)),
      borderRadius: BorderRadius.circular(19),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B42658A),
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _tag(
                    'Ticket #${visit.queuePosition?.toString().padLeft(2, '0') ?? visit.ticketNumber}',
                    const Color(0xFFF0F4F8),
                    const Color(0xFF34455E),
                  ),
                  _tag(
                    visit.status.name,
                    const Color(0xFFEBF9FF),
                    const Color(0xFF0086C8),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                visit.visitorName,
                style: const TextStyle(
                  color: facilityDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Divider(height: 14, color: Color(0xFFE5EAF1)),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: WorkspaceIcon('id', color: facilityMuted),
                          ),
                          TextSpan(text: '  ID: #${visit.maskedId}'),
                        ],
                      ),
                      style: const TextStyle(
                        color: Color(0xFF53647C),
                        fontSize: 11,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: WorkspaceIcon(
                              'time',
                              color: Color(0xFF008CD5),
                            ),
                          ),
                          TextSpan(text: '  ~${visit.estimatedMinutes} mins'),
                        ],
                      ),
                      style: const TextStyle(
                        color: Color(0xFF008CD5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 80),
          width: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFD),
            border: Border.all(color: facilityBorder),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFD9F1FF),
                child: Text(
                  visit.visitorName.isEmpty
                      ? '?'
                      : visit.visitorName.characters.first.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF0088D0)),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                visit.windowNumber == 0
                    ? 'Unassigned'
                    : 'Counter ${visit.windowNumber}',
                style: const TextStyle(color: Color(0xFF61748F), fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _tag(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: fg.withValues(alpha: .16)),
    ),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11)),
  );
}
