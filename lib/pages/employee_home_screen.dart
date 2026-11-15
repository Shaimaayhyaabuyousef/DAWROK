import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';
import '../services/employee_work_service.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF25354B);
const _muted = Color(0xFF8597B0);

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});
  @override State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}
class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _tab = 0;
  String? _message;
  bool _busy = false;
  final _search = TextEditingController();
  final _ticket = TextEditingController();
  late final Future<Map<String,dynamic>> _access;

  @override void initState() {
    super.initState(); _access = _load();
  }
  Future<Map<String,dynamic>> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Employee not signed in.');
    final route = await EmployeeAccessService.instance.routeFor(user);
    if (route != 'employee_home_screen') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      });
      throw StateError('Employee access requirements not completed.');
    }
    final doc = await FirebaseFirestore.instance
      .collection('staff_memberships').doc(user.uid).get();
    return doc.data() ?? {};
  }
  @override void dispose() { _search.dispose(); _ticket.dispose(); super.dispose(); }
  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final result = await action();
      if (mounted) setState(() => _message = result);
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, 'employee_login_screen', (_) => false);
  }
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>>(
    future: _access,
    builder: (context, access) {
      if (!access.hasData) return Scaffold(
        body: Center(child: access.hasError
          ? Text('${access.error}') : const CircularProgressIndicator()));
      final m = access.data!;
      final fid = m['facilityId'] as String? ?? '';
      final role = m['role'] as String? ?? 'employee';
      final canOperate = role == 'windowOfficer' || role == 'supervisor';
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: EmployeeWorkService.instance.tickets(fid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Unable to load tickets: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final active = snapshot.data!.docs.where((x) =>
              x.data()['status'] == 'waiting' || x.data()['status'] == 'called').toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                child: Row(children: [
                  const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE6F6FF),
                    child: Icon(Icons.badge_outlined, color: _blue)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back,', style: TextStyle(color: _muted, fontSize: 12)),
                      Text(FirebaseAuth.instance.currentUser?.displayName ?? 'Employee',
                        style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700))
                    ])),
                  IconButton(onPressed: _signOut, icon: const Icon(Icons.logout, color: _blue)),
                ]),
              ),
              Expanded(child: _tab == 0
                ? _dashboard(fid, m, active)
                : _tab == 1 ? _tickets(active, canOperate)
                : _tab == 2 ? _scanner(canOperate) : _profile(m)),
            ]);
          },
        )),
        bottomNavigationBar: SafeArea(top: false, child: Container(height: 64,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE9F0F8)))),
          child: Row(children: [
            _nav(0, Icons.home_outlined, 'Home'),
            _nav(1, Icons.receipt_long_outlined, 'Queues'),
            _nav(2, Icons.qr_code_scanner, 'Scan'),
            _nav(3, Icons.person_outline, 'Profile'),
          ]))),
      );
    },
  );
  Widget _nav(int index, IconData icon, String label) => Expanded(
    child: InkWell(onTap: () => setState(() => _tab = index),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 25, color: _tab == index ? _blue : _muted),
        Text(label, style: TextStyle(fontSize: 11,
          color: _tab == index ? _blue : _muted)),
      ])));

  Widget _card(Widget child) => Container(width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white, border: Border.all(color: const Color(0xFFDCEBF6)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x0A4C6E90),
        blurRadius: 10, offset: Offset(0, 5))]),
    child: child);

  Widget _dashboard(String fid, Map<String,dynamic> m,
      List<QueryDocumentSnapshot<Map<String,dynamic>>> active) =>
    SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 25, 24, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('facilities').doc(fid).snapshots(),
          builder: (context, fac) => _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MY FACILITY', style: TextStyle(
                color: _muted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(fac.data?.data()?['name'] as String? ?? 'Facility',
                style: const TextStyle(fontSize: 19,
                  fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 13),
              Text('Role: ${m['role']}', style: const TextStyle(color: _muted)),
              Text('Station: ${m['window']}', style: const TextStyle(color: _muted)),
            ]))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
          color: const Color(0xFFEAF7FF), borderRadius: BorderRadius.circular(17)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                Text('${active.length}', style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 26, color: _blue)),
                const Text('ACTIVE TICKETS', style: TextStyle(fontSize: 11, color: _muted)),
              ]),
              Column(children: [
                Text('${active.where((x) => x.data()['status'] == 'called').length}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 26, color: _blue)),
                const Text('CALLED', style: TextStyle(fontSize: 11, color: _muted)),
              ]),
            ])),
        const SizedBox(height: 23),
        const Text('Queue Activity', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 13),
        if (active.isEmpty) _card(const Text('No active reservations yet.',
          style: TextStyle(color: _muted)))
        else for (final doc in active.take(5)) ...[
          _ticketCard(doc, m['role'] != 'logistics'),
          const SizedBox(height: 12),
        ],
      ]));

  Widget _tickets(List<QueryDocumentSnapshot<Map<String,dynamic>>> items,
      bool canOperate) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(23, 22, 23, 32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Queue Tickets', style: TextStyle(
        color: _ink, fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      TextField(controller: _search, onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: _blue),
          hintText: 'Search ticket or citizen',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_message!, style: const TextStyle(color: _blue))),
      const SizedBox(height: 16),
      for (final doc in items.where((x) {
        final q = _search.text.toLowerCase();
        return x.id.toLowerCase().contains(q) ||
          (x.data()['citizenName'] as String? ?? '').toLowerCase().contains(q);
      })) ...[_ticketCard(doc, canOperate), const SizedBox(height: 12)],
      if (items.isEmpty) const Center(child: Padding(
        padding: EdgeInsets.only(top: 45),
        child: Text('No queue tickets available.', style: TextStyle(color: _muted)))),
    ]));

  Widget _ticketCard(QueryDocumentSnapshot<Map<String,dynamic>> doc, bool canOperate) {
    final m = doc.data();
    final status = m['status'] as String? ?? 'waiting';
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(m['citizenName'] as String? ?? 'Citizen',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink))),
        Text(status.toUpperCase(), style: const TextStyle(color: _blue,
          fontWeight: FontWeight.bold, fontSize: 11)),
      ]),
      const SizedBox(height: 8),
      Text('Ticket: ${doc.id}', style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 6),
      Text('Window ${m['windowNumber']} · ${m['service']}',
        style: const TextStyle(color: _muted, fontSize: 12)),
      if (canOperate) ...[
        const SizedBox(height: 11),
        Wrap(spacing: 7, children: [
          if (status == 'waiting') _actionButton('Call',
            () => _run(() => EmployeeWorkService.instance.changeTicket(doc.id, 'called'))),
          if (status == 'called') ...[
            _actionButton('Served', () => _run(
              () => EmployeeWorkService.instance.changeTicket(doc.id, 'served'))),
            _actionButton('Postpone', () => _run(
              () => EmployeeWorkService.instance.changeTicket(doc.id, 'postpone'))),
            _actionButton('Absent', () => _run(
              () => EmployeeWorkService.instance.changeTicket(doc.id, 'absent'))),
          ],
        ]),
      ],
    ]));
  }
  Widget _actionButton(String label, VoidCallback onTap) => OutlinedButton(
    onPressed: _busy ? null : onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: _blue,
      side: const BorderSide(color: Color(0xFFC5E6FA))),
    child: Text(label, style: const TextStyle(fontSize: 12)));

  Widget _scanner(bool canOperate) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 36, 24, 26),
    child: Column(children: [
      const Text('Ticket Verification', style: TextStyle(
        fontWeight: FontWeight.bold, fontSize: 23, color: _ink)),
      const SizedBox(height: 24),
      Container(width: 245, height: 218,
        decoration: BoxDecoration(color: const Color(0xFF132036),
          borderRadius: BorderRadius.circular(19)),
        child: const Icon(Icons.qr_code_scanner, color: _blue, size: 99)),
      const SizedBox(height: 20),
      const Text('Enter the ticket number or QR content',
        style: TextStyle(color: _muted, fontSize: 13)),
      const SizedBox(height: 12),
      TextField(controller: _ticket,
        decoration: InputDecoration(hintText: 'Ticket / QR payload',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 19),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _busy || !canOperate ? null
          : () => _run(() => EmployeeWorkService.instance.checkIn(_ticket.text)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue, foregroundColor: Colors.white),
        child: Text(canOperate ? 'Verify Ticket' : 'No verification permission'))),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 13),
        child: Text(_message!, style: const TextStyle(color: _blue))),
    ]));

  Widget _profile(Map<String,dynamic> m) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.account_circle_outlined, size: 83, color: _blue),
      const SizedBox(height: 16),
      const Text('Employee Profile', textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23, color: _ink)),
      const SizedBox(height: 21),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(FirebaseAuth.instance.currentUser?.email ?? ''),
        const SizedBox(height: 9),
        Text('Role: ${m['role']}', style: const TextStyle(color: _muted)),
        Text('Status: ${m['state']}', style: const TextStyle(color: _blue)),
      ])),
      const SizedBox(height: 15),
      ElevatedButton.icon(onPressed: () =>
        Navigator.pushNamed(context, 'employee_profile_screen'),
        icon: const Icon(Icons.edit_outlined), label: const Text('Edit My Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue, foregroundColor: Colors.white)),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _signOut,
        icon: const Icon(Icons.logout), label: const Text('Log Out')),
    ]));
}
