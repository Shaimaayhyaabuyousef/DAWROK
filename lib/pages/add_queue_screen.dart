import 'package:flutter/material.dart';
import 'queue_ticket_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/booking_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/citizen_identity_service.dart';

const Color _queuePrimary = Color(0xFF4AAAF0);
const Color _queueDark = Color(0xFF172033);

class AddQueueScreen extends StatefulWidget {
  final String facilityName;
  final String? facilityId;
  final bool isOpen;
  final bool verified;

  const AddQueueScreen({
    super.key,
    required this.facilityName,
    this.facilityId,
    this.isOpen = true,
    this.verified = false,
  });

  @override
  State<AddQueueScreen> createState() => _AddQueueScreenState();
}

class _AddQueueScreenState extends State<AddQueueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDemoId();
  }

  Future<void> _loadDemoId() async {
    try {
      final demo = await CitizenIdentityService.instance.demoBookingIdentity();
      if (mounted && demo != null) {
        setState(() {
          _idController.text = demo.identifier;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final id = widget.facilityId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a facility from the live directory.')));
      return;
    }
    DemoBookingIdentity? demo;
    try { demo = await CitizenIdentityService.instance.demoBookingIdentity(); }
    catch (_) {}
    if (!mounted) return;
    if (demo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete the identity demo step first.')));
      Navigator.pushNamed(context, 'citizen_id_verification');
      return;
    }
    _idController.text = demo.identifier;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final queues = await FirebaseFirestore.instance
          .collection('facilities').doc(id).collection('queues')
          .where('isActive', isEqualTo: true).get();
      final available = queues.docs.where((q) => q.data()['archived'] != true).toList();
      if (available.isEmpty) throw StateError('This facility has not opened any queues yet.');
      if (!mounted) return;
      String? queueId;
      if (available.length == 1) {
        queueId = available.single.id;
      } else {
        queueId = await showModalBottomSheet<String>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: available.map((q) => ListTile(
                title: Text(q.data()['service'] as String? ?? 'Queue'),
                subtitle: Text('Window ${q.data()['windowNumber']}'),
                onTap: () => Navigator.pop(sheetContext, q.id),
              )).toList(),
            ),
          ),
        );
      }
      if (queueId == null) return;
      final receipt = await BookingService.instance.reserve(
        facilityId: id, queueId: queueId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => QueueTicketScreen(
          ticketNumber: receipt.id,
          queueNumber: receipt.windowNumber,
          facilityName: receipt.facilityName,
          idNumber: demo!.identifier,
          createdAt: DateTime.now(),
          estimatedWaiting: 'Scheduled ${receipt.slotStart.hour.toString().padLeft(2, '0')}:${receipt.slotStart.minute.toString().padLeft(2, '0')}',
          qrPayload: 'DAWROK|ticket=${receipt.id}|facility=${receipt.facilityId}|queue=${receipt.queueId}',
        )),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 82, 20, 24),
                child: Column(
                  children: [
                    _buildFacilitySummary(),
                    const SizedBox(height: 48),
                    _buildIdForm(),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 22),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _queuePrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _queuePrimary.withValues(alpha: 0.65),
                      elevation: 3,
                      shadowColor: _queuePrimary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 13),
                              Icon(Icons.arrow_forward, size: 27),
                            ],
                          ),
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
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, size: 23),
              color: Colors.black,
            ),
            const Expanded(
              child: Text(
                'Join the queue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _queuePrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3EAF2), width: 1.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFE2F5FD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: _queuePrimary,
              size: 38,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.facilityName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _queueDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.verified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: _queuePrimary, size: 20),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isOpen
                  ? const Color(0xFFF0FFF8)
                  : const Color(0xFFFFF1F1),
              border: Border.all(
                color: widget.isOpen
                    ? const Color(0xFF91EFC5)
                    : const Color(0xFFFFB8B8),
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: widget.isOpen
                      ? const Color(0xFF079B72)
                      : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    color: widget.isOpen
                        ? const Color(0xFF079B72)
                        : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3EAF2), width: 1.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Booking ID',
              style: TextStyle(
                color: const Color(0xFF45546A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _idController,
              readOnly: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                color: _queueDark,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'DEMO ID will appear here',
                hintStyle: const TextStyle(
                  color: Color(0xFF9AAAC0),
                  fontSize: 18,
                  letterSpacing: 1,
                ),
                suffixIcon: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFF93A4BC),
                  size: 26,
                ),
                filled: true,
                fillColor: const Color(0xFFFBFCFE),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 23,
                  vertical: 21,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE0E7F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE0E7F0), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: _queuePrimary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
              validator: (value) {
                final id = value?.trim() ?? '';
                if (id.isEmpty || !id.startsWith('DEMO-')) {
                  return 'Complete the demo capture first';
                }
                return null;
              },
              onFieldSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 27),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF9FE),
                border: Border.all(color: const Color(0xFFA9E3FF), width: 1.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Color(0xFF079FE0), size: 22),
                  SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'DEMO ONLY: this uses a synthetic test ID, not a verified National ID. Tickets are local and not valid for real check-in.',
                      style: TextStyle(
                        color: Color(0xFF263448),
                        fontSize: 16,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
