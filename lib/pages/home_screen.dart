import 'citizen_bottom_nav.dart';
import '../services/booking_cancellation.dart';
import '../services/facility_time.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/citizen_account_service.dart';
import 'citizen_ui.dart';
import 'facilities_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _welcomeError;
  @override
  void initState() {
    super.initState();
    _welcome();
  }

  Future<void> _welcome() async {
    try {
      await CitizenAccountService.instance.ensureWelcome();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await BookingCancellation.settleCitizenClosures(uid);
      if (mounted) setState(() => _welcomeError = null);
    } catch (_) {
      if (mounted)
        setState(() => _welcomeError = 'Notifications could not be synced.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: CitizenAccountService.instance.account(user.uid).snapshots(),
      builder: (context, account) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('citizenId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, bookings) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: CitizenAccountService.instance
                      .events(user.uid)
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, events) {
                    final active =
                        bookings.data?.docs
                            .where(
                              (d) => [
                                'waiting',
                                'called',
                              ].contains(d.data()['status']),
                            )
                            .toList() ??
                        [];
                    active.sort(
                      (a, b) =>
                          ((b.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0)
                              .compareTo(
                                (a.data()['createdAt'] as Timestamp?)
                                        ?.millisecondsSinceEpoch ??
                                    0,
                              ),
                    );
                    final ticket = active.isEmpty ? null : active.first;
                    final raw = (user.displayName ?? '').trim();
                    return CitizenHomeView(
                      name: raw.isEmpty ? 'Citizen' : raw,
                      points: account.hasData
                          ? CitizenAccountService.policy(account.data!.data())
                                .points
                          : null,
                      booking: ticket?.data(),
                      ticketId: ticket?.id,
                      loading: !bookings.hasData && !bookings.hasError,
                      error: bookings.hasError
                          ? 'Unable to load your bookings. Please try again.'
                          : _welcomeError,
                      unread: events.hasData && events.data!.docs.isNotEmpty,
                      onSearch: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FacilitiesScreen(),
                        ),
                      ),
                      onPoints: () =>
                          Navigator.pushNamed(context, 'citizen_points'),
                      onNotifications: () =>
                          Navigator.pushNamed(context, 'citizen_notifications'),
                      onTicket: () => ticket == null
                          ? null
                          : openCitizenTicket(
                              context,
                              ticket.id,
                              ticket.data(),
                            ),
                      onBookings: () => Navigator.pushReplacementNamed(
                        context,
                        'active_queues_screen',
                      ),
                      onProfile: () => Navigator.pushReplacementNamed(
                        context,
                        'profile_screen',
                      ),
                      onRetry: () {
                        setState(() {});
                        _welcome();
                      },
                    );
                  },
                ),
          ),
    );
  }
}

/// Presentational view: no sample bookings or balances. Also used by layout tests.
class CitizenHomeView extends StatelessWidget {
  final String name;
  final int? points;
  final String? ticketId, error;
  final Map<String, dynamic>? booking;
  final bool loading, unread;
  final VoidCallback onSearch,
      onPoints,
      onNotifications,
      onTicket,
      onBookings,
      onProfile,
      onRetry;
  const CitizenHomeView({
    super.key,
    required this.name,
    this.points,
    this.ticketId,
    this.booking,
    this.error,
    this.loading = false,
    this.unread = false,
    required this.onSearch,
    required this.onPoints,
    required this.onNotifications,
    required this.onTicket,
    required this.onBookings,
    required this.onProfile,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: citizenPanel(
                          color: const Color(0xFFF5FBFF),
                          radius: 12,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: citizenBlue,
                              child: Text(
                                name.isEmpty
                                    ? 'C'
                                    : name.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      color: Color(0xFF71849F),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '$greeting, $name',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: citizenInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: onPoints,
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFB2E6FF),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.orange,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${points ?? '—'} Pts',
                                      style: const TextStyle(
                                        color: Color(0xFF008ED3),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: onNotifications,
                      icon: Badge(
                        isLabelVisible: unread,
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFF258FE0),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    decoration: citizenPanel(
                      color: const Color(0xFFF5FBFF),
                      radius: 13,
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore the facilities',
                          style: TextStyle(
                            color: citizenSoftBlue,
                            fontSize: 21,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Find a facility and book your turn',
                          style: TextStyle(color: citizenInk, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Material(
                    elevation: 3,
                    shadowColor: const Color(0x45000000),
                    borderRadius: BorderRadius.circular(13),
                    color: Colors.white,
                    child: InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(13),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: citizenBlue, size: 27),
                            SizedBox(width: 16),
                            Text(
                              'Search facilities',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    'Your active booking',
                    style: TextStyle(color: citizenSoftBlue, fontSize: 21),
                  ),
                ),
                const SizedBox(height: 16),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (booking != null)
                  _ticket()
                else if (error == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: citizenPanel(color: const Color(0xFFF5FBFF)),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.event_available_outlined,
                          color: citizenBlue,
                          size: 36,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your next turn starts here',
                          style: TextStyle(
                            color: citizenInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Explore nearby facilities and book your turn when you need it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF71849F)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: citizenBlue,
                          ),
                          onPressed: onSearch,
                          child: const Text('Explore facilities →'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CitizenBottomNav(selected: 0, onTap: (index) {
        if (index == 1) onBookings();
        if (index == 2) onProfile();
      }),
    );
  }

  Widget _ticket() {
    final data = booking!;
    final time = (data['slotStart'] as Timestamp?)?.toDate();
    return InkWell(
      onTap: onTicket,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            colors: [Color(0xFF0085BD), Color(0xFF0CA8E5)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 27),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ACTIVE RESERVATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    time == null ? '—' : citizenTime(FacilityTime.wall(time)),
                    style: const TextStyle(
                      color: Color(0xFF008ED3),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              data['service'] as String? ?? 'Your reservation',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 52),
            Text(
              'Ticket #$ticketId • ${data['facilityName'] ?? ''}',
              style: const TextStyle(color: Color(0xFFC0EDFF), fontSize: 14),
            ),
            const Divider(height: 34, color: Colors.white30),
            Row(
              children: [
                const Icon(Icons.circle, color: Color(0xFF62E7C3), size: 8),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    data['status'] == 'called'
                        ? 'Your turn • Ready'
                        : data['checkedIn'] == true
                        ? 'Checked in • Waiting'
                        : 'Scheduled • Waiting',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const Text(
                  'View',
                  style: TextStyle(color: Color(0xFFC0EDFF), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
