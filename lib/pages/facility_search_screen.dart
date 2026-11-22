import 'workspace_style.dart';
import 'package:flutter/material.dart';
import 'facility_nav.dart';
import 'facility_scan_store.dart';

class _Visitor {
  final String ticket, reference, name, id, badge, label, initials;
  final int minutes;
  final Color tint;
  const _Visitor(this.ticket, this.reference, this.name, this.id, this.badge, this.label, this.initials, this.minutes, this.tint);
}

class FacilitySearchScreen extends StatefulWidget {
  const FacilitySearchScreen({super.key});
  @override State<FacilitySearchScreen> createState() => _FacilitySearchScreenState();
}
class _FacilitySearchScreenState extends State<FacilitySearchScreen> {
  final query = TextEditingController();
  @override
  void initState() {
    super.initState();
    FacilityScanStore.instance.addListener(_refresh);
  }
  void _refresh() { if (mounted) setState(() {}); }

  List<_Visitor> get entries => FacilityScanStore.instance.visits.map((v) =>
    _Visitor(
      v.queuePosition?.toString().padLeft(2, '0') ?? v.ticketNumber, v.ticketNumber, v.visitorName, v.maskedId,
      v.status.name, v.windowNumber == 0 ? 'Unassigned' : 'Counter ${v.windowNumber}',
      v.visitorName.isEmpty ? '?' : v.visitorName[0].toUpperCase(),
      v.estimatedMinutes, const Color(0xFFD9F1FF),
    )).toList();
  @override void dispose() { FacilityScanStore.instance.removeListener(_refresh); query.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final text = query.text.trim().toLowerCase();
    final result = entries.where((e) => text.isEmpty || '${e.name} ${e.id} ${e.ticket} ${e.reference}'.toLowerCase().contains(text)).toList();
    return WorkspaceStyle(child: Scaffold(backgroundColor: Colors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(29, 28, 29, 22), child: TextField(controller: query, onChanged: (_) => setState(() {}), decoration: InputDecoration(
          prefixIcon: const Center(widthFactor: 1, child: WorkspaceIcon('search', color: Color(0xFF00A4ED))), hintText: 'Full Name OR ID', hintStyle: const TextStyle(color: Color(0xFFB3DFFF), fontSize: 16),
          isDense: true, prefixIconConstraints: const BoxConstraints(minWidth: 42), contentPadding: const EdgeInsets.symmetric(vertical: 8), filled: true, fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: facilityBorder), borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF4AAAF3)), borderRadius: BorderRadius.circular(15)),
          suffixIcon: query.text.isNotEmpty ? IconButton(onPressed: () => setState(query.clear), icon: const Icon(Icons.clear)) : null,
        ))),
        Expanded(child: result.isEmpty ? const Center(child: Text('No matching tickets')) : ListView.separated(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 20), itemCount: result.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, i) => _visitorCard(result[i]),
        )),
      ])),
      bottomNavigationBar: const FacilityBottomNav(selected: 3),
    ));
  }
  Widget _visitorCard(_Visitor visitor) => Container(
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDDE7F1)), borderRadius: BorderRadius.circular(19), boxShadow: const [BoxShadow(color: Color(0x0B42658A), blurRadius: 5, offset: Offset(0, 3))]),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 5, children: [
          _tag('Ticket #${visitor.ticket}', const Color(0xFFF0F4F8), const Color(0xFF34455E)),
          _tag(visitor.badge, visitor.badge == 'Family' ? const Color(0xFFF8F1FF) : const Color(0xFFEBF9FF), visitor.badge == 'Family' ? const Color(0xFF9A36E8) : const Color(0xFF0086C8)),
        ]),
        const SizedBox(height: 9), Text(visitor.name, style: const TextStyle(color: facilityDark, fontSize: 13, fontWeight: FontWeight.w400), maxLines: 2),
        const Divider(height: 14, color: Color(0xFFE5EAF1)),
        Row(children: [const WorkspaceIcon('id', color: facilityMuted), const SizedBox(width: 5), Expanded(child: Text('ID: #${visitor.id}', style: const TextStyle(color: Color(0xFF53647C), fontSize: 11))), const WorkspaceIcon('time', color: Color(0xFF008CD5)), Text(' ~${visitor.minutes} mins', style: const TextStyle(color: Color(0xFF008CD5), fontSize: 11))]),
      ])),
      const SizedBox(width: 10), Container(constraints: const BoxConstraints(minHeight: 80), width: 80, decoration: BoxDecoration(color: const Color(0xFFF7FAFD), border: Border.all(color: facilityBorder), borderRadius: BorderRadius.circular(13)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 20, backgroundColor: visitor.tint, child: Text(visitor.initials, style: const TextStyle(color: Color(0xFF0088D0)))), const SizedBox(height: 7), Text(visitor.label, style: const TextStyle(color: Color(0xFF61748F), fontSize: 11), textAlign: TextAlign.center)])),
    ]),
  );
  Widget _tag(String label, Color bg, Color fg) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5), border: Border.all(color: fg.withValues(alpha: .16))), child: Text(label, style: TextStyle(color: fg, fontSize: 11)));
}
