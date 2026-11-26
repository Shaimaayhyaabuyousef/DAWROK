import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/citizen_account_service.dart';
import 'citizen_ui.dart';
import 'facilities_screen.dart';
import 'package:first_project/l10n/app_language.dart';

class CitizenPointsScreen extends StatefulWidget {
  const CitizenPointsScreen({super.key});
  @override
  State<CitizenPointsScreen> createState() => _CitizenPointsScreenState();
}

class _CitizenPointsScreenState extends State<CitizenPointsScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _redeem() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('Redeem 100 points'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ListTile(
                leading: const Icon(Icons.event_available),
                title: Text(tr('Book after normal places run out')),
                subtitle: Text(
                  tr('Only when the facility has allocated an extra reward place.'),
                ),
                onTap: () => Navigator.pop(context, 'extra'),
              ),
              ListTile(
                leading: const Icon(Icons.priority_high),
                title: Text(tr('Priority within your time slot')),
                subtitle: Text(
                  tr('Available when a waiting ticket in the same period qualifies under the missed-attendance policy.'),
                ),
                onTap: () => Navigator.pop(context, 'priority'),
              ),
              Text(
                tr('100 points are returned if you cancel before being called or the facility cancels service.'),
                style: TextStyle(color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FacilitiesScreen(reward: choice)),
      );
  }

  Widget _term(String title, String body) => Container(
    padding: const EdgeInsets.all(16),
    decoration: citizenPanel(color: const Color(0xFFF8FBFF), radius: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.circle, color: citizenBlue, size: 9),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(title),
                style: const TextStyle(fontSize: 15, color: citizenInk),
              ),
              const SizedBox(height: 5),
              Text(
                tr(body),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF71849F),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          tr('YOUR POINTS BALANCE'),
          style: TextStyle(color: citizenSoftBlue, fontSize: 20),
        ),
      ),
      body: uid == null
          ? Center(child: Text(tr('Please sign in.')))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: CitizenAccountService.instance.account(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(
                    child: Text(
                      tr('Unable to load your balance. Please try again.'),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final policy = CitizenAccountService.policy(
                  snapshot.data!.data(),
                );
                final blocked = policy.blocked(DateTime.now());
                final progress = (policy.points / 100)
                    .clamp(0.0, 1.0)
                    .toDouble();
                final status = policy.reviewRequired
                    ? 'Review required'
                    : blocked
                    ? 'Temporarily restricted'
                    : 'Good Standing';
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(21, 42, 21, 30),
                      children: [
                        Container(
                          padding: const EdgeInsetsDirectional.fromSTEB(18, 24, 18, 45),
                          decoration: citizenPanel(
                            color: const Color(0xFFF5FBFF),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: citizenPanel(
                                  color: blocked
                                      ? const Color(0xFFFFF4DF)
                                      : const Color(0xFFECFDF5),
                                  radius: 24,
                                ),
                                child: Text(
                                  tr('${blocked ? '!' : '✓'} $status'),
                                  style: TextStyle(
                                    color: blocked
                                        ? Colors.orange.shade800
                                        : const Color(0xFF00846C),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 23),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tr('${policy.points}'),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: citizenInk,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: citizenPanel(
                                      color: const Color(0xFFF0FAFF),
                                      radius: 7,
                                    ),
                                    child: Text(
                                      tr('PTS'),
                                      style: TextStyle(
                                        color: citizenBlue,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 44),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tr('Reward Booking Eligibility'),
                                      style: TextStyle(
                                        color: Color(0xFF52647C),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    tr('${(progress * 100).round()}% Achieved'),
                                    style: const TextStyle(
                                      color: citizenBlue,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 13),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  color: citizenBlue,
                                  backgroundColor: const Color(0xFFE7EEF5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (blocked) ...[
                          Text(
                            tr(policy.reviewRequired
                                ? 'Booking is restricted until administration reviews your report.'
                                : 'Booking is restricted until ${policy.blockedUntil!.toLocal()}.'),
                            style: const TextStyle(color: citizenInk),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, 'citizen_report'),
                            child: Text(
                              tr('Contact administration / Report'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Container(
                          padding: const EdgeInsets.all(17),
                          decoration: citizenPanel(),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.policy_outlined,
                                    color: citizenBlue,
                                  ),
                                  SizedBox(width: 17),
                                  Expanded(
                                    child: Text(
                                      tr('Terms & Compliance Policy'),
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 30),
                              _term(
                                'Attendance & commitment',
                                'Attend your turn: +5 points. Miss your turn: −5 points. Each completed ticket is counted once.',
                              ),
                              _term(
                                'Booking restrictions',
                                'Three consecutive missed turns restrict booking for 7 days. Another missed turn after that period requires administration review.',
                              ),
                              _term(
                                'Redeem every 100 points',
                                'Choose an extra reward place after normal capacity runs out, or priority within your time slot. Rewards do not bypass restrictions.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF49AAF2),
                            minimumSize: const Size.fromHeight(55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: !blocked && policy.points >= 100
                              ? _redeem
                              : null,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            tr('Replace with Booking'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (policy.points < 100)
                          Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              tr('Reach 100 points to redeem a booking reward.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
