import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';

const _primary = Color(0xFF03A9F4);

/// Waiting is persisted in Firestore; this page is just a live viewer.
/// Closing the app never cancels the request or approval.
class EmployeePendingScreen extends StatefulWidget {
  const EmployeePendingScreen({super.key});
  @override
  State<EmployeePendingScreen> createState() => _EmployeePendingScreenState();
}
class _EmployeePendingScreenState extends State<EmployeePendingScreen> {
  bool _routing = false;
  Future<void> _continueAfterApproval() async {
    if (_routing) return;
    _routing = true;
    try {
      final next = await EmployeeAccessService.instance.currentDestination();
      if (!mounted) return;
      if (next == 'employee_home_screen' ||
          next == 'employee_profile_screen') {
        Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
      }
    } finally {
      _routing = false;
    }
  }
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(
      context, 'employee_login_screen', (_) => false);
  }
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushNamedAndRemoveUntil(
          context, 'employee_login_screen', (_) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('staff_memberships')
          .doc(user.uid).snapshots(),
      builder: (context, membership) {
        if (membership.data?.data()?['state'] == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _continueAfterApproval();
          });
        }
        return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: FirebaseFirestore.instance.collection('staff_join_requests')
            .where('employeeUid', isEqualTo: user.uid).limit(1).snapshots(),
          builder: (context, joins) {
            final claims = joins.data?.docs ?? [];
            final status = claims.isEmpty
              ? 'not_requested'
              : (claims.first.data()['status'] as String? ?? 'requested');
            final rejected = status == 'rejected';
            final approved = status == 'approved' ||
                membership.data?.data()?['state'] == 'active';
            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                child: Column(children: [
                  Align(alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Color(0xFF8EA1B9)))),
                  const Spacer(),
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: const Color(0xFFE8F7FF),
                    child: Icon(rejected
                      ? Icons.cancel_outlined
                      : approved ? Icons.verified_user_outlined
                          : Icons.hourglass_top_rounded,
                      size: 66, color: rejected ? Colors.redAccent : _primary)),
                  const SizedBox(height: 27),
                  Text(rejected
                    ? 'Request Rejected'
                    : approved ? 'Approval Received'
                    : 'Waiting for Approval',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w700,
                      color: Color(0xFF24334B))),
                  const SizedBox(height: 14),
                  Text(rejected
                      ? 'Your facility did not approve the request. Ask the facility for a new invitation code.'
                      : approved
                        ? 'Your facility has approved you. Your employee profile will open now.'
                        : 'Your request was sent to the facility. Once the facility accepts, your account will become available.',
                    style: const TextStyle(
                      height: 1.6, fontSize: 14,
                      color: Color(0xFF8594AC)),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 23),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F9FF),
                      border: Border.all(color: const Color(0xFFD5EBFC)),
                      borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      const Text('ACCOUNT STATUS',
                        style: TextStyle(color: Color(0xFF92A7C1),
                          fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(rejected ? 'Rejected' :
                        approved ? 'Approved' : 'Pending facility review',
                        style: TextStyle(
                          color: rejected ? Colors.redAccent : _primary,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      Text(user.email ?? '',
                        style: const TextStyle(fontSize: 12,
                          color: Color(0xFF7487A3))),
                    ]),
                  ),
                  if (membership.hasError || joins.hasError) ...[
                    const SizedBox(height: 10),
                    Text('Unable to check status: ${membership.error ?? joins.error}',
                      style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 25),
                  const Text('You can close the application. Approval will remain saved and be checked at your next sign-in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8CA2B8), fontSize: 12)),
                  const Spacer(),
                  SizedBox(
                    height: 53, width: double.infinity,
                    child: ElevatedButton(
                      onPressed: rejected ? _logout : _continueAfterApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                      child: Text(rejected ? 'Return to Staff Login'
                        : 'Check My Status'))),
                  const SizedBox(height: 35),
                ]),
              )),
            );
          },
        );
      },
    );
  }
}
