import 'package:flutter/material.dart';
import 'add_queue_screen.dart';
const Color _primary = Color(0xFF0EA5FF);
const Color _dark = Color(0xFF1E2235);
const Color _pageBackground = Color(0xFFF7FAFD);

class CenterDetailsScreen extends StatelessWidget {
  final String name;
  final String? facilityId;
  final String address;
  final String rating;
  final String openingFrom;
  final String openingTo;
  final String? status;
  final bool isOpen;
  final bool verified;
  final int registeredCount;
  final int minWaitingMinutes;
  final int maxWaitingMinutes;
  final int occupancyPercent;

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
    this.registeredCount = 48,
    this.minWaitingMinutes = 15,
    this.maxWaitingMinutes = 20,
    this.occupancyPercent = 65,
  });

  @override
  Widget build(BuildContext context) {
    final int safeOccupancy = occupancyPercent.clamp(0, 100).toInt();
    final occupancyLabel = safeOccupancy < 40
        ? 'Low Load'
        : safeOccupancy < 75
            ? 'Moderate Load'
            : 'High Load';

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFacilityCard(),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Queue statistics',
                          style: TextStyle(
                            color: _dark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6FBF3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF19B981), size: 8),
                              SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Color(0xFF159B6C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatisticCard(
                      icon: Icons.groups_rounded,
                      iconBackground: const Color(0xFFE8F6FF),
                      iconColor: _primary,
                      title: 'Total registered:',
                      value: '$registeredCount',
                      valueLabel: 'PEOPLE',
                    ),
                    const SizedBox(height: 12),
                    _buildStatisticCard(
                      icon: Icons.access_time_rounded,
                      iconBackground: const Color(0xFFFFF6E5),
                      iconColor: const Color(0xFFE8A12A),
                      title: 'Approximate waiting time:',
                      value: '$minWaitingMinutes-$maxWaitingMinutes',
                      valueLabel: 'MIN',
                    ),
                    const SizedBox(height: 12),
                    _buildOccupancyCard(safeOccupancy, occupancyLabel),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddQueueScreen(
        facilityName: name,
        facilityId: facilityId,
        isOpen: isOpen,
        verified: verified,
      ),
    ),
  );
},
              icon: const Icon(Icons.event_available_outlined, size: 19),
              label: const Text(
                'Book Appointment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _dark),
          ),
          const Expanded(
            child: Text(
              'Distribution Center Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildFacilityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NAME OF FACILITY',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFB43B), size: 15),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 7),
                          const Icon(Icons.verified, color: _primary, size: 15),
                          const Text(
                            'Verified',
                            style: TextStyle(color: _primary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFE6FBF3) : const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: isOpen ? const Color(0xFF19B981) : Colors.red,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        color: isOpen ? const Color(0xFF159B6C) : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEDF1F5)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: _primary, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Address', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(
                      address,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.event_available_outlined, color: _primary, size: 18),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Booking available',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF18B98A), size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$openingFrom - $openingTo${status == null ? '' : '  •  $status'}',
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String value,
    required String valueLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEAF0F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _dark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 70),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBFE),
              border: Border.all(color: const Color(0xFFDCEFFA)),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  valueLabel,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyCard(int value, String label) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAF0F5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Center Occupancy',
                style: TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '$value% $label',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFEAF2F8),
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }
}
