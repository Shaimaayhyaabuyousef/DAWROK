import 'workspace_style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';
import 'employee_scanner_screen.dart';
import 'employee_profile_screen.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF27344D);
const _muted = Color(0xFF899BB4);
const _outline = Color(0xFFE0E9F2);

/// Two-tab staff workspace, matching the supplied employee-home reference.
/// The facility's operational controls and owner screens are unchanged.
class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});
  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _tab = 0;
  String? _queueId;
  bool _checkingRoute = false;

  Future<void> _ensureAccess() async {
    if (_checkingRoute || !mounted) return;
    _checkingRoute = true;
    try {
      final next = await EmployeeAccessService.instance.currentDestination();
      if (!mounted) return;
      if (next != 'employee_home_screen') {
        Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access check failed: $e')));
    } finally {
      _checkingRoute = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAccess());
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(color: Color(0x080D2B47), blurRadius: 5, offset: Offset(0, 2)),
      ]),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushNamedAndRemoveUntil(
          context, 'employee_login_screen', (_) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('staff_memberships').doc(uid).snapshots(),
      builder: (context, membership) {
        if (membership.hasError) return Scaffold(
          body: Center(child: Text('Cannot load staff membership: ${membership.error}')));
        if (!membership.hasData) return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
        final m = membership.data!.data();
        if (m == null || m['state'] != 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAccess());
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final fid = m['facilityId'] as String? ?? '';
        if (fid.isEmpty) return const Scaffold(body: Center(
          child: Text('Employee is not linked to a facility.')));

        return WorkspaceStyle(child: Scaffold(
          backgroundColor: Colors.white,
          body: _tab == 1 ? const EmployeeProfileScreen(embedded: true) : SafeArea(child: _homeTab(fid, m)),
          bottomNavigationBar: SafeArea(top: false, child: Container(
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _outline)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17))),
            child: Row(children: [
              _nav(0, 'Home'),
              _nav(1, 'Profile'),
            ]),
          )),
        ));
      },
    );
  }

  Widget _nav(int index, String label) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _tab = index),
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _tab == index ? const Color(0xFFE6F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(35)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          WorkspaceIcon(index == 0 ? 'staff_home' : 'staff_profile', color: _blue),
          if (_tab == index) ...[
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(
              fontSize: 13, color: _blue)),
          ],
        ]),
      )),
    ),
  );

  Widget _homeTab(String fid, Map<String, dynamic> membership) =>
    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('facilities').doc(fid).collection('operations').doc('assignments').snapshots(),
      builder: (context, routing) {
        if (routing.hasError) return const Center(child: Text('Unable to load your service assignment. Please try again.'));
        if (!routing.hasData) return const Center(child: CircularProgressIndicator());
        final assignment = (routing.data?.data()?['assignments'] as Map?)?[FirebaseAuth.instance.currentUser?.uid] as Map?;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('facilities').doc(fid).snapshots(),
      builder: (context, facility) =>
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('facilities')
              .doc(fid).collection('queues').snapshots(),
          builder: (context, queues) {
            final facilityData = facility.data?.data() ?? {};
            final online = facilityData['isOnline'] == true;
            final available = queues.data?.docs.where((doc) =>
                doc.id == assignment?['queueId'] && doc.data()['archived'] != true).toList() ?? [];
            final selected = available.where((doc) => doc.id == _queueId).toList();
            final q = selected.isNotEmpty
                ? selected.first : (available.isNotEmpty ? available.first : null);
            if (q != null && _queueId != q.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _queueId = q.id);
              });
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('bookings')
                .where('facilityId', isEqualTo: fid).snapshots(),
              builder: (context, bookings) {
                final tickets = bookings.data?.docs.where((doc) =>
                  q != null && doc.data()['queueId'] == q.id).toList() ?? [];
                final waiting = tickets.where((doc) =>
                  doc.data()['status'] == 'waiting' ||
                  doc.data()['status'] == 'called').length;
                final utc = DateTime.now().toUtc();
                final key = '${utc.year}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';
                final served = tickets.where((doc) =>
                  doc.data()['status'] == 'served' && doc.data()['dayKey'] == key).length;
                final start = (q?.data()['startsAtMinutes'] as num?)?.toInt() ?? 0;
                final end = (q?.data()['endsAtMinutes'] as num?)?.toInt() ?? 0;
                String clock(int v) => '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 4, backgroundColor:
                        online ? const Color(0xFF14B889) : Colors.orange),
                      const SizedBox(width: 12),
                      Text(online ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(fontSize: 13, letterSpacing: 1,
                          color: online ? const Color(0xFF00A47A) : Colors.orange)),
                    ]),
                    const SizedBox(height: 45),
                    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCCECFF))),
                          child: const Center(child: WorkspaceIcon('facility', color: _blue))),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Flexible(child: Text('Active Facility', style: TextStyle(color: _muted, fontSize: 12))),
                            SizedBox(width: 7), WorkspaceIcon('verified', color: Color(0xFF00A97F)),
                          ]),
                          const SizedBox(height: 5),
                          Text(facilityData['name'] as String? ?? 'Facility',
                            style: const TextStyle(color: _ink,
                              fontWeight: FontWeight.w700, fontSize: 16)),
                        ])),
                      ]),
                      const Divider(height: 27, color: _outline),
                      Row(children: [
                        Expanded(child: Text(
                          'Zone: ${facilityData['address'] ?? 'Not specified'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF687C99), fontSize: 12))),
                        if (q != null) Text('Hours: ${clock(start)} - ${clock(end)}',
                          style: const TextStyle(color: Color(0xFF008DDB), fontSize: 11)),
                      ]),
                    ])),
                    const SizedBox(height: 44),
                    const Padding(
                      padding: EdgeInsets.only(left: 9, bottom: 22),
                      child: Text('Select the teller',
                        style: TextStyle(color: Color(0xFF384962),
                          fontSize: 14, fontWeight: FontWeight.w600))),
                    _card(Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: const Color(0xFFF0F4F8)),
                        child: const Center(child: WorkspaceIcon('teller', color: _blue))),
                      const SizedBox(width: 9),
                      Expanded(child: available.isEmpty
                        ? const Text('Awaiting a vacant service position', style: TextStyle(fontSize: 12, color: _muted))
                        : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          itemHeight: null,
                          isDense: true,
                          style: const TextStyle(fontFamily: 'Inter', color: _ink, fontSize: 12),
                          value: q?.id,
                          hint: const Text('Awaiting a vacant service position', style: TextStyle(fontSize: 12)),
                          items: [
                            for (final doc in available)
                              DropdownMenuItem(
                                value: doc.id,
                                child: Text('${doc.data()['service']} • ${assignment?['windowNumber'] == 0 ? 'Direct service' : 'Window ${assignment?['windowNumber']}'}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (id) => setState(() => _queueId = id),
                        ),
                      )),
                    ])),
                    const SizedBox(height: 50),
                    IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _stat('served',
                        'Served Today', served.toString(), 'beneficiaries')),
                      const SizedBox(width: 12),
                      Expanded(child: _stat('waiting',
                        'In Waiting Queue', waiting.toString(), 'waiting')),
                    ])),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF09AFF7), Color(0xFF0084C8)]),
                        borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x2FFFFFFF),
                            borderRadius: BorderRadius.circular(25)),
                          child: Text(q == null ? 'Awaiting assignment' : '● Ready to Serve',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                        const SizedBox(height: 22),
                        const Text('Scan Beneficiary Card or Code',
                          style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 21),
                        SizedBox(
                          width: double.infinity, height: 42,
                          child: ElevatedButton.icon(
                            onPressed: q == null ||
                              !{'windowOfficer','supervisor'}.contains(membership['role'])
                              ? null : () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => EmployeeScannerScreen(
                                  facilityId: fid,
                                  queueId: q.id,
                                  windowNumber: (assignment!['windowNumber'] as num).toInt(),
                                ))),
                            icon: const WorkspaceIcon('scanner', color: _blue),
                            label: const Text('Open Instant Scanner',
                              style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: const Color(0xFF0084CA),
                              backgroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFE4EEF3),
                              disabledForegroundColor: const Color(0xFF5C7080),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13))),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                );
              },
            );
          },
        ),
    );
      },
    );

  Widget _stat(String asset, String title, String count, String suffix) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEDF1F6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          WorkspaceIcon(asset, color: asset == 'waiting' ? Colors.orange : _blue),
          const SizedBox(width: 7),
          Expanded(child: Text(title,
            style: const TextStyle(color: Color(0xFF7789A1), fontSize: 12))),
        ]),
        const SizedBox(height: 11),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 4, children: [
          Text(count, style: const TextStyle(color: _ink,
            fontWeight: FontWeight.w700, fontSize: 20)),
          Text(suffix, style: const TextStyle(color: _muted, fontSize: 12)),
        ]),
      ]),
    );

}
