import '../services/queue_schedule.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'center_details_screen.dart';

class FacilitiesScreen extends StatefulWidget {
  final String reward;
  const FacilitiesScreen({super.key, this.reward = 'none'});
  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  String? _categoryId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    hintText: 'Search facilities',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('facility_categories')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data?.docs ?? [];
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _categoryId = null),
                            child: _filterChip(
                              Icons.business,
                              'All Facilities',
                              selected: _categoryId == null,
                            ),
                          ),
                          for (final category in categories) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _categoryId = category.id),
                              child: _filterChip(
                                Icons.business_outlined,
                                category.data()['name'] as String? ??
                                    'Category',
                                selected: _categoryId == category.id,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sort: ', style: TextStyle(color: Colors.grey[600])),
                      const Text(
                        'Closest geographically',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('facilities')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Text('Unable to load facilities.');
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final filtered = snapshot.data!.docs.where((d) {
                      final info = d.data();
                      final matchesCategory =
                          _categoryId == null ||
                          info['categoryId'] == _categoryId;
                      final name = (info['name'] as String? ?? '')
                          .toLowerCase();
                      return matchesCategory && name.contains(_search);
                    }).toList();
                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Center(
                          child: Text('No facilities available yet.'),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final doc in filtered) ...[
                          _liveFacilityCard(context, doc),
                          const SizedBox(height: 15),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveFacilityCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final online = data['isOnline'] == true;
    Widget card(String from, String to) => _facilityCard(
      context,
      facilityId: doc.id,
      icon: Icons.business_outlined,
      name: data['name'] as String? ?? '',
      verified: false,
      isOpen: online,
      rating: '—',
      address: data['address'] as String? ?? '',
      from: from,
      to: to,
    );
    if (!online) return card('Closed', 'Closed');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: doc.reference
          .collection('queues')
          .where('isActive', isEqualTo: true)
          .where('archived', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return card('Unavailable', 'Unavailable');
        if (!snapshot.hasData) return card('Loading…', 'Loading…');
        final queues = snapshot.data!.docs;
        if (queues.isEmpty) return card('No queues', 'No queues');
        final starts =
            queues
                .map((q) => (q.data()['startsAtMinutes'] as num?)?.toInt())
                .whereType<int>()
                .toList()
              ..sort();
        final ends =
            queues
                .map((q) => (q.data()['endsAtMinutes'] as num?)?.toInt())
                .whereType<int>()
                .toList()
              ..sort();
        return card(
          starts.isEmpty ? 'Not set' : QueueSchedule.clock(starts.first),
          ends.isEmpty ? 'Not set' : QueueSchedule.clock(ends.last),
        );
      },
    );
  }

  Widget _filterChip(IconData icon, String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _facilityCard(
    BuildContext context, {
    required IconData icon,
    required String name,
    String? facilityId,
    bool verified = false,
    bool medicalBadge = false,
    bool isOpen = true,
    String? status,
    required String rating,
    required String address,
    required String from,
    required String to,
    int? claimed,
    int? capacity,
    int registeredCount = 48,
    int minWaitingMinutes = 15,
    int maxWaitingMinutes = 20,
    int occupancyPercent = 65,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CenterDetailsScreen(
                reward: widget.reward,
                name: name,
                facilityId: facilityId,
                address: address,
                rating: rating,
                openingFrom: from,
                openingTo: to,
                status: status,
                isOpen: isOpen,
                verified: verified,
                registeredCount: registeredCount,
                minWaitingMinutes: minWaitingMinutes,
                maxWaitingMinutes: maxWaitingMinutes,
                occupancyPercent: occupancyPercent,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (verified)
                              const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 18,
                              ),
                            if (medicalBadge) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Medical',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (status != null)
                          Text(
                            status,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(rating),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Address',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Text(
                                address,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Booking available',
                            textAlign: TextAlign.end,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (claimed != null && capacity != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Quota Capacity ($claimed/$capacity claimed)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${((claimed / capacity) * 100).round()}% Filled',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (claimed / capacity)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                          backgroundColor: Colors.blue[100],
                          color: Colors.blue,
                          minHeight: 6,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              from,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              to,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
