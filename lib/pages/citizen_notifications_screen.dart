import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/citizen_account_service.dart';
import 'citizen_ui.dart';

class CitizenNotificationsScreen extends StatelessWidget {
  const CitizenNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: uid == null
          ? const Center(child: Text('Please sign in.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: CitizenAccountService.instance
                      .events(uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(
                        child: Text(
                          'Unable to load notifications. Please try again.',
                        ),
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recent Notifications',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'Account updates',
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (snapshot.data!.docs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No notifications yet.'),
                          ),
                        ...snapshot.data!.docs.map((event) {
                          final d = event.data();
                          final type = d['type'];
                          final positive = type == 'served';
                          final absent = type == 'absent';
                          final color = positive
                              ? const Color(0xFF08B990)
                              : absent
                              ? Colors.orange
                              : citizenBlue;
                          final title = switch (type) {
                            'welcome' => 'Welcome to DAWROK!',
                            'service_cancelled' => 'The facility cancelled service today',
                            'cancelled' => 'Booking cancelled',
                            'booking' => 'Your booking is confirmed',
                            'served' => '+5 commitment points added',
                            'absent' => '5 commitment points deducted',
                            _ => 'Account update',
                          };
                          final body = switch (type) {
                            'welcome' => 'Your account was created successfully. Explore facilities and book your first turn.',
                            'service_cancelled' || 'cancelled' => d['delta'] == 100 ? 'Your ticket was cancelled and 100 points were returned.' : 'Your ticket was cancelled without an absence penalty.',
                            'booking' =>
                              d['delta'] == -100
                                  ? 'Your reward booking was confirmed. 100 points were redeemed.'
                                  : 'Your ticket is ready. View your booking details.',
                            'served' => 'Thank you for attending your turn. Your points balance has been updated.',
                            'absent' => 'Your turn was marked as missed. Check your points balance and booking eligibility.',
                            _ =>
                              d['message'] as String? ??
                                  'Your account status has been updated.',
                          };
                          final date = (d['createdAt'] as Timestamp?)?.toDate();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: citizenPanel(),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withValues(alpha: .13),
                                  child: Icon(
                                    positive
                                        ? Icons.verified_outlined
                                        : absent
                                        ? Icons.schedule
                                        : Icons.notifications_none,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              type == 'welcome'
                                                  ? 'Welcome'
                                                  : type == 'booking'
                                                  ? 'Booking confirmation'
                                                  : 'Commitment & Points',
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          if (d['read'] != true)
                                            Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: color,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF082B36),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        body,
                                        style: const TextStyle(
                                          color: Color(0xFF52647C),
                                          height: 1.5,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (date != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Text(
                                            '${date.day}/${date.month}/${date.year} • ${citizenTime(date)}',
                                            style: const TextStyle(
                                              color: Colors.blueGrey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF082B36,
                                          ),
                                          backgroundColor: const Color(
                                            0xFFD5F2FF,
                                          ),
                                        ),
                                        onPressed: () async {
                                          try {
                                            await event.reference.update({
                                              'read': true,
                                            });
                                            if (!context.mounted) return;
                                            if (type == 'booking') {
                                              final ticket =
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('bookings')
                                                      .doc(
                                                        d['bookingId']
                                                            as String,
                                                      )
                                                      .get();
                                              if (context.mounted &&
                                                  ticket.exists)
                                                await openCitizenTicket(
                                                  context,
                                                  ticket.id,
                                                  ticket.data()!,
                                                );
                                            } else if (type == 'welcome') {
                                              Navigator.pushNamed(
                                                context,
                                                'facilities_screen',
                                              );
                                            } else {
                                              Navigator.pushNamed(
                                                context,
                                                'citizen_points',
                                              );
                                            }
                                          } catch (_) {
                                            if (context.mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Unable to open this update. Please try again.',
                                                      ),
                                                    ),
                                                  );
                                          }
                                        },
                                        child: Text(
                                          type == 'booking'
                                              ? 'Ticket Details →'
                                              : type == 'welcome'
                                              ? 'Explore facilities →'
                                              : 'View points →',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }
}
