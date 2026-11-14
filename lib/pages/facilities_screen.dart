import 'package:flutter/material.dart';
import 'center_details_screen.dart';

class FacilitiesScreen extends StatelessWidget {
  const FacilitiesScreen({super.key});

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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(Icons.business, 'All Facilities (8)', selected: true),
                      const SizedBox(width: 10),
                      _filterChip(Icons.bakery_dining_outlined, 'Bakeries & Bread (3)'),
                      const SizedBox(width: 10),
                      _filterChip(Icons.local_hospital_outlined, 'Medical'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                _facilityCard(
                  context,
                  icon: Icons.account_balance,
                  name: 'Al-Nasr Humanitarian Center',
                  verified: true,
                  isOpen: true,
                  status: 'Closes 04:00 PM',
                  rating: '4.8 (340)',
                  address: 'Al-Naser Street',
                  from: '06:00 AM',
                  to: '08:00 PM',
                  registeredCount: 48,
                  minWaitingMinutes: 15,
                  maxWaitingMinutes: 20,
                  occupancyPercent: 65,
                ),
                const SizedBox(height: 15),
                _facilityCard(
                  context,
                  icon: Icons.bakery_dining_outlined,
                  name: 'Central Family Bakery & Ration',
                  verified: true,
                  isOpen: true,
                  status: 'Open until 02:00 PM',
                  rating: '4.9 (512)',
                  address: 'Al-Naser Street',
                  from: '05:00 AM',
                  to: '02:00 PM',
                  claimed: 102,
                  capacity: 150,
                  registeredCount: 102,
                  minWaitingMinutes: 15,
                  maxWaitingMinutes: 20,
                  occupancyPercent: 68,
                ),
                const SizedBox(height: 15),
                _facilityCard(
                  context,
                  icon: Icons.local_hospital_outlined,
                  name: 'Al-Shifa Relief Clinic & Dispensary',
                  verified: false,
                  medicalBadge: true,
                  isOpen: false,
                  status: 'Check availability before visiting',
                  rating: '4.7 (189)',
                  address: 'Al-Remal',
                  from: '08:00 AM',
                  to: '04:00 PM',
                  registeredCount: 32,
                  minWaitingMinutes: 10,
                  maxWaitingMinutes: 15,
                  occupancyPercent: 42,
                ),
              ],
            ),
          ),
        ),
      ),
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
          Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey[700]),
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
                name: name,
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
            border: Border.all(color: Colors.grey[200]! ),
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
                              const Icon(Icons.verified, color: Colors.blue, size: 18),
                            if (medicalBadge) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Medical',
                                  style: TextStyle(color: Colors.blue, fontSize: 11),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (status != null)
                          Text(status, style: TextStyle(color: Colors.grey[600])),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 14),
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
                        const Icon(Icons.location_on_outlined, color: Colors.blue, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Address', style: TextStyle(color: Colors.grey[600])),
                              Text(address, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                          Text(
                            '${((claimed / capacity) * 100).round()}% Filled',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (claimed / capacity).clamp(0.0, 1.0).toDouble(),
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
                            Text('From', style: TextStyle(color: Colors.grey[600])),
                            Text(from, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Container(width: 1, height: 30, color: Colors.grey[300]),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To', style: TextStyle(color: Colors.grey[600])),
                            Text(to, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
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
                  style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
