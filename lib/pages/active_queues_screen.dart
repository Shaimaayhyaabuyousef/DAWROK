import 'citizen_bottom_nav.dart';

import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'queue_booking.dart';
import 'queue_ticket_screen.dart';

// Colors
const Color pageBlue = Color(0xFF62B4F8);
const Color accentBlue = Color(0xFF079FE5);
const Color darkText = Color(0xFF172033);
const Color mutedText = Color(0xFF344258);
const Color softBorder = Color(0xFFDDE6F0);
const Color softPanel = Color(0xFFF7FAFD);

class ActiveQueuesScreen extends StatefulWidget {
  const ActiveQueuesScreen({super.key});

  @override
  State<ActiveQueuesScreen> createState() =>
      _ActiveQueuesScreenState();
}

class _ActiveQueuesScreenState extends State<ActiveQueuesScreen> {
  final QueueBookingStore store = QueueBookingStore.instance;

  @override
  void initState() {
    super.initState();
    store.addListener(refreshBookings);
  }

  @override
  void dispose() {
    store.removeListener(refreshBookings);
    super.dispose();
  }

  void refreshBookings() {
    if (mounted) {
      setState(() {});
    }
  }

  // Open booking ticket
  void openTicket(QueueBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QueueTicketScreen(
          ticketNumber: booking.ticketNumber,
          queueNumber: booking.queueNumber,
          windowNumber: booking.windowNumber,
          windowCount: booking.windowCount,
          scheduledAt: booking.scheduledAt,
          facilityName: booking.facilityName,
          idNumber: booking.idNumber,
          createdAt: booking.createdAt,
          estimatedWaiting: booking.estimatedWaiting,
          qrPayload: booking.qrPayload,
        ),
      ),
    );
  }

  // Bottom navigation
  void onNavigationTap(int index) {
    if (index == 0) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(
          context,
          'home_screen',
        );
      }
    }

    if (index == 1) {
      // Already on My Queue
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = store.bookings;

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [

            const SizedBox(height: 16),

            // Page title
            const Text(
              'Active queues',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: pageBlue,
                fontSize: 21,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 20),

            // Section title and ticket count
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 27,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your active tickets',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F9FF),
                      border: Border.all(
                        color: const Color(0xFFA9E2FF),
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      '${bookings.length} tickets',
                      style: const TextStyle(
                        color: Color(0xFF0789CE),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tickets list
            Expanded(
              child: bookings.isEmpty
                  ? buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        20, 0, 20, 18,
                      ),
                      itemCount: bookings.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 19),
                      itemBuilder: (context, index) {
                        return buildBookingCard(
                          bookings[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // Custom bottom navigation
      bottomNavigationBar: CitizenBottomNav(selected: 1, onTap: onNavigationTap),
    );
  }

  // Empty state
  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 58,
              color: Colors.blue.shade200,
            ),

            const SizedBox(height: 14),

            const Text(
              'No active tickets yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: darkText,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Your bookings will appear here after you join a queue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Select card according to booking status
  Widget buildBookingCard(QueueBooking booking) {
    switch (booking.status) {
      case QueueBookingStatus.yourTurnSoon:
        return buildYourTurnSoonCard(booking);

      case QueueBookingStatus.scheduled:
        return buildScheduledCard(booking);

      case QueueBookingStatus.inQueue:
        return buildInQueueCard(booking);
    }
  }

  // Common card decoration
  BoxDecoration cardDecoration({
    required bool highlighted,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: highlighted
            ? const Color(0xFFA8E1FF)
            : softBorder,
        width: highlighted ? 1.2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: highlighted
              ? const Color(0xFF4AAAF0).withValues(alpha: 0.09)
              : const Color(0xFF26364B).withValues(alpha: 0.025),
          blurRadius: highlighted ? 18 : 13,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // First card: Your turn soon
  Widget buildYourTurnSoonCard(QueueBooking booking) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(highlighted: true),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Blue top line
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF38C5F7),
                  Color(0xFF0087CC),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16, 15, 16, 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Ticket information and QR
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          ticketNumberBadge(
                            booking.ticketNumber,
                            dark: true,
                          ),

                          const SizedBox(height: 6),

                          yourTurnBadge(),

                          const SizedBox(height: 6),

                          facilityName(
                            booking.facilityName,
                            verified: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    qrReadyBadge(),
                  ],
                ),

                const SizedBox(height: 11),

                // Waiting time and people ahead
                queueStats(booking),

                const SizedBox(height: 12),

                // Beneficiary
                beneficiaryRow(booking.beneficiaryName),

                const Padding(
                  padding: EdgeInsets.only(
                    top: 9,
                    bottom: 9,
                  ),
                  child: Divider(
                    height: 1,
                    color: Color(0xFFE7EDF4),
                  ),
                ),

                // View ticket button
                viewButton(
                  label: 'View Ticket',
                  filled: true,
                  onPressed: () => openTicket(booking),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Second card: Scheduled
  Widget buildScheduledCard(QueueBooking booking) {
    return Container(
      decoration: cardDecoration(highlighted: false),
      padding: const EdgeInsets.fromLTRB(
        15, 15, 15, 15,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Ticket number and scheduled time
          Row(
            children: [
              ticketNumberBadge(booking.ticketNumber),

              const SizedBox(width: 6),

              Expanded(
                child: scheduledBadge(
                  booking.scheduledTime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          facilityName(booking.facilityName),

          const SizedBox(height: 11),

          // Window opens
          windowOpensPanel(booking.windowOpensIn),

          const SizedBox(height: 12),

          beneficiaryRow(booking.beneficiaryName),

          const Padding(
            padding: EdgeInsets.only(
              top: 9,
              bottom: 9,
            ),
            child: Divider(
              height: 1,
              color: Color(0xFFE7EDF4),
            ),
          ),

          viewButton(
            label: 'View Details',
            filled: false,
            onPressed: () => openTicket(booking),
          ),
        ],
      ),
    );
  }

  // Third card: In Queue
  Widget buildInQueueCard(QueueBooking booking) {
    return Container(
      decoration: cardDecoration(highlighted: false),
      padding: const EdgeInsets.fromLTRB(
        15, 15, 15, 15,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              ticketNumberBadge(booking.ticketNumber),

              const Spacer(),

              inQueueBadge(),
            ],
          ),

          const SizedBox(height: 8),

          facilityName(booking.facilityName),

          const SizedBox(height: 23),

          queueStats(booking),

          const SizedBox(height: 12),

          beneficiaryRow(booking.beneficiaryName),

          const Padding(
            padding: EdgeInsets.only(
              top: 9,
              bottom: 9,
            ),
            child: Divider(
              height: 1,
              color: Color(0xFFE7EDF4),
            ),
          ),

          viewButton(
            label: 'View Details',
            filled: false,
            onPressed: () => openTicket(booking),
          ),
        ],
      ),
    );
  }

  // Ticket number badge
  Widget ticketNumberBadge(
    String number, {
    bool dark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF111A2E)
            : const Color(0xFFF0F4F8),
        border: dark
            ? null
            : Border.all(
                color: const Color(0xFFDCE5EF),
              ),
        borderRadius: BorderRadius.circular(7),
      ),

      child: Text(
        '#$number',
        style: TextStyle(
          color: dark ? Colors.white : darkText,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }

  // Your turn soon badge
  Widget yourTurnBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF9FF),
        border: Border.all(
          color: const Color(0xFFA9E2FF),
        ),
        borderRadius: BorderRadius.circular(7),
      ),

      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            color: Color(0xFF08A9E8),
            size: 8,
          ),

          SizedBox(width: 5),

          Text(
            'Your turn soon',
            style: TextStyle(
              color: Color(0xFF0089CD),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Scheduled badge
  Widget scheduledBadge(String? time) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        border: Border.all(
          color: const Color(0xFFDCE5EF),
        ),
        borderRadius: BorderRadius.circular(7),
      ),

      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time,
              color: Color(0xFF6E8198),
              size: 13,
            ),

            const SizedBox(width: 5),

            Text(
              'Scheduled • ${time ?? '2:30 PM'}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // In Queue badge
  Widget inQueueBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEF),
        border: Border.all(
          color: const Color(0xFFFFD66C),
        ),
        borderRadius: BorderRadius.circular(7),
      ),

      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            color: Color(0xFFF59E0B),
            size: 8,
          ),

          SizedBox(width: 5),

          Text(
            'In Queue',
            style: TextStyle(
              color: Color(0xFFB85B00),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Facility name and verified icon
  Widget facilityName(
    String name, {
    bool verified = false,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        if (verified) ...[
          const SizedBox(width: 6),

          const Icon(
            Icons.verified,
            color: Color(0xFF05A9E8),
            size: 17,
          ),
        ],
      ],
    );
  }

  // QR Ready box
  Widget qrReadyBadge() {
    return Container(
      width: 87,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAFE),
        border: Border.all(
          color: const Color(0xFFD9EDF9),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(14),
      ),

      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            color: Color(0xFF0789CE),
            size: 35,
          ),

          SizedBox(height: 1),

          Text(
            'QR READY',
            style: TextStyle(
              color: Color(0xFF086CA6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Waiting statistics
  Widget queueStats(QueueBooking booking) {
    final waiting =
        booking.estimatedWaiting.toLowerCase().contains('left')
            ? booking.estimatedWaiting
            : '${booking.estimatedWaiting} left';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
      ),
      decoration: BoxDecoration(
        color: softPanel,
        border: Border.all(
          color: const Color(0xFFEDF2F7),
        ),
        borderRadius: BorderRadius.circular(15),
      ),

      child: Row(
        children: [

          const Icon(
            Icons.access_time,
            color: Color(0xFF55B7F7),
            size: 17,
          ),

          const SizedBox(width: 6),

          const Text(
            'Wait:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              waiting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: mutedText,
              ),
            ),
          ),

          const Icon(
            Icons.groups_2_outlined,
            color: Color(0xFF55B7F7),
            size: 17,
          ),

          const SizedBox(width: 5),

          const Text(
            'Ahead:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 5),

          Flexible(
            child: Text(
              '${booking.peopleAhead} people',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF168CCF),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Window opens panel
  Widget windowOpensPanel(String? timeLeft) {
    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration: BoxDecoration(
        color: softPanel,
        border: Border.all(
          color: const Color(0xFFEDF2F7),
        ),
        borderRadius: BorderRadius.circular(15),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: Color(0xFF26B6F4),
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Window opens in ${timeLeft ?? 'soon'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Beneficiary information
  Widget beneficiaryRow(String name) {
    return Row(
      children: [
        const Icon(
          Icons.person,
          color: Color(0xFF69B7F5),
          size: 17,
        ),

        const SizedBox(width: 6),

        const Text(
          'Beneficiary:',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: mutedText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // View Ticket / View Details button
  Widget viewButton({
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: filled ? 33 : 36,

      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.visibility_outlined,
                size: 17,
              ),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4AAAF0),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: mutedText,
                side: const BorderSide(
                  color: softBorder,
                  width: 1.2,
                ),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(label),
            ),
    );
  }
}
