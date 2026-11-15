import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/queue_schedule.dart';
import 'add_queue_screen.dart';

const _primary = Color(0xFF0EA5FF);

class CenterDetailsScreen extends StatelessWidget {
  // Retain the existing caller API; live documents are authoritative.
  final String name, address, rating, openingFrom, openingTo;
  final String? facilityId, status;
  final bool isOpen, verified;
  final int registeredCount,
      minWaitingMinutes,
      maxWaitingMinutes,
      occupancyPercent;
  const CenterDetailsScreen({
    super.key,
    required this.name,
    this.facilityId,
    required this.address,
    required this.rating,
    required this.openingFrom,
    required this.openingTo,
    this.status,
    this.isOpen = true,
    this.verified = false,
    this.registeredCount = 0,
    this.minWaitingMinutes = 0,
    this.maxWaitingMinutes = 0,
    this.occupancyPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final id = facilityId;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Facility Details'),
        foregroundColor: _primary,
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: id == null || id.isEmpty
          ? const Center(child: Text('Choose a facility from the directory.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('facilities')
                  .doc(id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return _message(
                    'Unable to load facility details. Check your connection and try again.',
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!.data();
                if (data == null || data['isActive'] != true)
                  return _message('This facility is no longer available.');
                final online = data['isOnline'] == true;
                final facilityName = data['name'] as String? ?? name;
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              facilityName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(data['address'] as String? ?? address),
                            if ((data['phone'] as String? ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(data['phone'] as String),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              online
                                  ? 'Accepting bookings'
                                  : 'Bookings are currently closed',
                              style: TextStyle(
                                color: online ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Available queues',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!online)
                      const Text(
                        'The facility must enable bookings before its queues are available.',
                      )
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('facilities')
                            .doc(id)
                            .collection('queues')
                            .where('isActive', isEqualTo: true)
                            .where('archived', isEqualTo: false)
                            .snapshots(),
                        builder: (context, queues) {
                          if (queues.hasError)
                            return const Text(
                              'Unable to load queues. Check your connection or contact support.',
                            );
                          if (!queues.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          final docs = queues.data!.docs.toList()
                            ..sort(
                              (a, b) =>
                                  ((a.data()['windowNumber'] as num?)
                                              ?.toInt() ??
                                          0)
                                      .compareTo(
                                        (b.data()['windowNumber'] as num?)
                                                ?.toInt() ??
                                            0,
                                      ),
                            );
                          if (docs.isEmpty)
                            return const Text(
                              'No active queues. The facility needs to create and activate a queue first.',
                            );
                          return Column(
                            children: docs
                                .map(
                                  (doc) => _queueCard(
                                    context,
                                    id,
                                    facilityName,
                                    doc,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  Widget _queueCard(
    BuildContext context,
    String fid,
    String facilityName,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final start = (data['startsAtMinutes'] as num?)?.toInt() ?? 0;
    final end = (data['endsAtMinutes'] as num?)?.toInt() ?? 0;
    final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
    final slots = QueueSchedule.availableSlots(start, end, DateTime.now());
    // The same UTC day bucket used by BookingService.reserve.
    final day = QueueSchedule.dayKey(
      slots.isEmpty ? DateTime.now() : slots.first,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['service'] as String? ?? 'Queue',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Window ${data['windowNumber'] ?? '—'}'),
            Text(
              'Hours: ${QueueSchedule.clock(start)} – ${QueueSchedule.clock(end)}',
            ),
            Text('Daily capacity: $capacity'),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: doc.reference.collection('days').doc(day).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Text(
                    'Unable to load reservation availability. Please try again later.',
                  );
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final reserved =
                    (snapshot.data!.data()?['reserved'] as num?)?.toInt() ?? 0;
                final remaining = (capacity - reserved).clamp(
                  0,
                  capacity > 0 ? capacity : 0,
                );
                final available = remaining > 0 && slots.isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Reservations today: $reserved · Remaining: $remaining',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: capacity > 0
                          ? (reserved / capacity).clamp(0.0, 1.0).toDouble()
                          : 0,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: available
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddQueueScreen(
                                  facilityName: facilityName,
                                  facilityId: fid,
                                  queueId: doc.id,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        remaining <= 0
                            ? 'Queue is full'
                            : slots.isEmpty
                            ? 'No booking times left today'
                            : 'Book this queue',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
