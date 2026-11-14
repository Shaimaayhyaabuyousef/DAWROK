import 'package:flutter/material.dart';
import 'facility_nav.dart';

class _Visitor {
  final String ticket, name, id, badge, label, initials;
  final int minutes;
  final Color tint;
  const _Visitor(this.ticket, this.name, this.id, this.badge, this.label, this.initials, this.minutes, this.tint);
}

class FacilitySearchScreen extends StatefulWidget {
  const FacilitySearchScreen({super.key});
  @override State<FacilitySearchScreen> createState() => _FacilitySearchScreenState();
}
class _FacilitySearchScreenState extends State<FacilitySearchScreen> {
  final query = TextEditingController();
  final entries = const [
    _Visitor('A-104', 'Khalid Abdullah Al-Omari', 'SA-49102', 'Calling Next', 'Counter 02', 'KO', 8, Color(0xFFD9F1FF)),
    _Visitor('A-105', 'Fatima Salem Al-Dawsari', 'SA-38291', 'Family', '3 Persons', 'FD', 15, Color(0xFFF3E4FF)),
    _Visitor('A-106', 'Mohammad Tariq Hassan', 'SA-58190', 'In Queue', 'Standard', 'MH', 22, Color(0xFFDCEBFF)),
    _Visitor('A-108', 'Nour El-Din Mansoor', 'SA-58191', 'In Queue', 'Standard', 'NM', 30, Color(0xFFDCEBFF)),
  ];
  @override void dispose() { query.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final text = query.text.trim().toLowerCase();
    final result = entries.where((e) => text.isEmpty || '${e.name} ${e.id} ${e.ticket}'.toLowerCase().contains(text)).toList();
    return Scaffold(backgroundColor: Colors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(19, 38, 19, 26), child: TextField(controller: query, onChanged: (_) => setState(() {}), decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Color(0xFF00A4ED), size: 28), hintText: 'Full Name OR ID', hintStyle: const TextStyle(color: Color(0xFFB3DFFF), fontSize: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 12), filled: true, fillColor: Colors.white,
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
    );
  }
  Widget _visitorCard(_Visitor visitor) => Container(
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFDDE7F1)), borderRadius: BorderRadius.circular(19), boxShadow: const [BoxShadow(color: Color(0x0B42658A), blurRadius: 5, offset: Offset(0, 3))]),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 5, children: [
          _tag('Ticket #${visitor.ticket}', const Color(0xFFF0F4F8), const Color(0xFF34455E)),
          _tag(visitor.badge, visitor.badge == 'Family' ? const Color(0xFFF8F1FF) : const Color(0xFFEBF9FF), visitor.badge == 'Family' ? const Color(0xFF9A36E8) : const Color(0xFF0086C8)),
        ]),
        const SizedBox(height: 9), Text(visitor.name, style: const TextStyle(color: facilityDark, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 2),
        const Divider(height: 14, color: Color(0xFFE5EAF1)),
        Row(children: [const Icon(Icons.badge_outlined, size: 16, color: facilityMuted), const SizedBox(width: 5), Expanded(child: Text('ID: #${visitor.id}', style: const TextStyle(color: Color(0xFF53647C), fontSize: 12))), const Icon(Icons.schedule, size: 15, color: Color(0xFF008CD5)), Text(' ~${visitor.minutes} mins', style: const TextStyle(color: Color(0xFF008CD5), fontSize: 12))]),
      ])),
      const SizedBox(width: 10), Container(height: 89, width: 80, decoration: BoxDecoration(color: const Color(0xFFF7FAFD), border: Border.all(color: facilityBorder), borderRadius: BorderRadius.circular(13)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 22, backgroundColor: visitor.tint, child: Text(visitor.initials, style: const TextStyle(color: Color(0xFF0088D0)))), const SizedBox(height: 7), Text(visitor.label, style: const TextStyle(color: Color(0xFF61748F), fontSize: 11), textAlign: TextAlign.center)])),
    ]),
  );
  Widget _tag(String label, Color bg, Color fg) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5), border: Border.all(color: fg.withValues(alpha: .16))), child: Text(label, style: TextStyle(color: fg, fontSize: 12)));
}
