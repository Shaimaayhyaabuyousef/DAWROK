import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

const Color _ticketPrimary = Color(0xFF0EA5FF);
const Color _ticketDark = Color(0xFF1E2235);

class QueueTicketScreen extends StatelessWidget {
  final String ticketNumber;
  final int queueNumber;
  final int? windowNumber;
  final int? windowCount;
  final DateTime? scheduledAt;
  final String facilityName;
  final String idNumber;
  final DateTime createdAt;
  final String estimatedWaiting;
  final String qrPayload;

  const QueueTicketScreen({
    super.key,
    required this.ticketNumber,
    required this.queueNumber,
    this.windowNumber,
    this.windowCount,
    this.scheduledAt,
    required this.facilityName,
    required this.idNumber,
    required this.createdAt,
    required this.estimatedWaiting,
    required this.qrPayload,
  });

  String get _formattedDate {
    final date = scheduledAt ?? createdAt;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String get _formattedTime {
    final time = scheduledAt ?? createdAt;
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get _maskedId {
    if (idNumber.length <= 4) return idNumber;
    return '${List.filled(idNumber.length - 4, '•').join()}${idNumber.substring(idNumber.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = qrPayload.startsWith('DAWROK-DEMO|');
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF12A875),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isDemo ? 'Demo ticket created' : 'Your ticket is ready!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ticketDark,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isDemo
                          ? 'TEST ONLY — no real reservation was created.'
                          : 'Your queue reservation has been created.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTicketCard(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7FF),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFB9E6FF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: _ticketPrimary,
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isDemo
                                  ? 'DEMO MODE: this QR is NOT valid for real check-in. Do not present it at a facility.'
                                  : 'Keep this ticket and present the QR code at the facility when you arrive.',
                              style: const TextStyle(
                                color: Color(0xFF34445A),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      'home_screen',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ticketPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 16, 5),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const Expanded(
            child: Text(
              'Queue Ticket',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ticketPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy ticket number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ticketNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket number copied')),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 19,
              color: _ticketPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      color: _ticketPrimary,
                      size: 23,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        facilityName,
                        style: const TextStyle(
                          color: _ticketDark,
                          fontSize: 17,
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
                        color: const Color(0xFFE8FBF3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CONFIRMED',
                        style: TextStyle(
                          color: Color(0xFF13976D),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'YOUR QUEUE NUMBER',
                  style: TextStyle(
                    color: Color(0xFF8290A3),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  queueNumber > 0
                      ? queueNumber.toString().padLeft(2, '0')
                      : '—',
                  style: const TextStyle(
                    color: _ticketPrimary,
                    fontSize: 58,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Ticket $ticketNumber${windowNumber == null ? '' : (windowNumber == 0 ? (windowCount == 0 ? ' · Direct service' : ' · Window assigned when called') : ' · Window $windowNumber')}',
                  style: const TextStyle(
                    color: Color(0xFF66758B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildDashedDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _detailItem(
                        'DATE',
                        _formattedDate,
                        Icons.calendar_today_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _detailItem(
                        'TIME',
                        _formattedTime,
                        Icons.access_time_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _detailItem(
                        'ESTIMATED WAIT',
                        estimatedWaiting,
                        Icons.hourglass_bottom_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _detailItem(
                        'ID NUMBER',
                        _maskedId,
                        Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE6EDF4)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 176,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'SCAN YOUR TICKET AT THE CENTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF66758B),
                    fontSize: 10,
                    letterSpacing: 0.8,
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

  Widget _detailItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _ticketPrimary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A0B1),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ticketDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 10).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => Container(
              width: 5,
              height: 1.5,
              color: const Color(0xFFDCE5EF),
            ),
          ),
        );
      },
    );
  }
}
