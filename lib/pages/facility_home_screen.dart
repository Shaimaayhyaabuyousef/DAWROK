import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/facility_context.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'facility_queues_screen.dart';
import 'facility_nav.dart';

// Home Facility - Dawrok
// This screen is a UI prototype. Its online status and QR session are local
// until they are connected to Firebase/the facility management backend.

const Color _titleBlue = Color(0xFF69B8FB);
const Color _primaryBlue = Color(0xFF08A6EE);
const Color _pillBlue = Color(0xFF4EA9F2);
const Color _darkText = Color(0xFF232D42);
const Color _mutedText = Color(0xFF95A7C0);
const Color _softBorder = Color(0xFFE0E8F2);

class FacilityHomeScreen extends StatefulWidget {
  final String facilityId;
  final String qrTitle;

  /// Optional callback to connect the bottom tabs to later facility screens.
  /// 0: Dashboard, 1: Bookings, 2: People, 3: Search, 4: Profile.
  final ValueChanged<int>? onNavigationTap;

  const FacilityHomeScreen({
    super.key,
    this.facilityId = '',
    this.qrTitle = 'QR_Facility',
    this.onNavigationTap,
  });

  @override
  State<FacilityHomeScreen> createState() => _FacilityHomeScreenState();
}

class _FacilityHomeScreenState extends State<FacilityHomeScreen> {
  bool _online = false;
  String _facilityId = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _facilitySub;

  @override
  void initState() {
    super.initState();
    _loadFacility();
  }

  Future<void> _loadFacility() async {
    try {
      final id = await FacilityContext.instance.requireFacilityId();
      if (!mounted) return;
      setState(() => _facilityId = id);
      _facilitySub = FirebaseFirestore.instance.collection('facilities').doc(id).snapshots().listen((doc) {
        if (mounted) setState(() { _online = doc.data()?['isOnline'] == true; });
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() { _facilitySub?.cancel(); super.dispose(); }
  int _demoSession = DateTime.now().millisecondsSinceEpoch;

  // Placeholder payload. A production QR must come from a trusted server and
  // have validation, expiry, and facility authorization behind it.
  String get _qrPayload =>
      'dawrok://facility/${Uri.encodeComponent(_facilityId)}'
      '/check-in?demoSession=$_demoSession';

  Future<void> _setOnline(bool online) async {
    if (_facilityId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('facilities').doc(_facilityId)
          .update({'isOnline': online});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())));
    }
  }

  void _refreshQr() {
    setState(() => _demoSession = DateTime.now().microsecondsSinceEpoch);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR preview refreshed')),
    );
  }

  Future<void> _showEnlargedQr() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.qrTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, color: _darkText),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: _FacilityQrFrame(
                  data: _qrPayload,
                  size: math.min(MediaQuery.sizeOf(dialogContext).width - 112, 290.0),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Scan to check-in or manage queue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBottomTab(int index) {
    if (index == 0) return;
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FacilityQueuesScreen()),
      );
      return;
    }
    if (widget.onNavigationTap != null) {
      widget.onNavigationTap!(index);
      return;
    }
    goToFacilityTab(context, index, 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Home Facility',
                  style: TextStyle(
                    color: _titleBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 17),
                _buildStatusCard(),
                const SizedBox(height: 16),
                if (_facilityId.isNotEmpty) _FacilityOverview(key: ValueKey(_facilityId), id: _facilityId),
                const SizedBox(height: 16),
                Center(child: _buildActivationChip()),
                const SizedBox(height: 19),
                _buildQrCard(),
                const SizedBox(height: 25),
                _buildWorkStoppageButton(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: FacilityBottomNav(selected: 0, onTap: _onBottomTab),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _softBorder, width: 1),
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100A315B),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _online ? const Color(0xFF14B887) : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 14, color: _darkText),
                children: [
                  const TextSpan(text: 'System status: '),
                  TextSpan(
                    text: _online ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: _online
                          ? const Color(0xFF00A575)
                          : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              value: _online,
              activeTrackColor: _primaryBlue,
              onChanged: _setOnline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 6),
      decoration: BoxDecoration(
        color: _pillBlue,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4A61C9F4),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: Colors.white),
          SizedBox(width: 10),
          Text(
            'Activation & Operation',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _softBorder, width: 1),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1700A6E9),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.qrTitle,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Scan to check-in or manage queue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _mutedText),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 208.0);
              return _FacilityQrFrame(data: _qrPayload, size: size);
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _refreshQr,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF697D9A),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
              Container(
                width: 1,
                height: 15,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: _softBorder,
              ),
              TextButton.icon(
                onPressed: _showEnlargedQr,
                icon: const Icon(Icons.fullscreen_rounded, size: 19),
                label: const Text('Enlarge'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF697D9A),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkStoppageButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () => _setOnline(!_online),
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkText,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD3DFEE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1,
          shadowColor: const Color(0x14000C22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F4F8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _online ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFF62758E),
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              _online ? 'Work stoppage' : 'Resume work',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

}

class _FacilityOverview extends StatefulWidget {
  const _FacilityOverview({super.key, required this.id});
  final String id;

  @override
  State<_FacilityOverview> createState() => _FacilityOverviewState();
}

class _FacilityOverviewState extends State<_FacilityOverview> {
  late Future<List<int>> _counts = _load();

  Future<List<int>> _load() {
    final db = FirebaseFirestore.instance;
    final queues = db.collection('facilities').doc(widget.id).collection('queues');
    final bookings = db.collection('bookings').where('facilityId', isEqualTo: widget.id);
    // Older queues may have no archived field; they are still listed in Queues.
    return Future.wait([
      queues.get(const GetOptions(source: Source.server)).then(
        (snapshot) => snapshot.docs.where((doc) => doc.data()['archived'] != true).length,
      ),
      bookings.count().get().then((result) => result.count!),
      bookings.where('status', isEqualTo: 'served').count().get().then((result) => result.count!),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Queues', 'Total bookings', 'Completed'];
    const icons = [Icons.format_list_numbered, Icons.confirmation_number_outlined, Icons.task_alt];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(color: const Color(0xfff5fbff), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder)),
      child: FutureBuilder<List<int>>(future: _counts, builder: (context, snapshot) => Column(children: [
        Row(children: [
          const Expanded(child: Text('Facility overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _darkText))),
          IconButton(tooltip: 'Refresh totals', iconSize: 18, onPressed: snapshot.connectionState == ConnectionState.waiting
            ? null : () => setState(() => _counts = _load()), icon: const Icon(Icons.refresh)),
        ]),
        if (snapshot.hasError)
          const Text('Totals unavailable. Tap refresh to try again.', style: TextStyle(fontSize: 13))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(3, (i) => Expanded(
            child: Column(children: [
              Icon(icons[i], size: 19, color: const Color(0xff087cc2)),
              const SizedBox(height: 4),
              Text(snapshot.hasData ? snapshot.data![i].toString() : '—', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _darkText)),
              Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xff526780))),
            ]),
          ))),
      ])),
    );
  }
}

class _FacilityQrFrame extends StatelessWidget {
  final String data;
  final double size;

  const _FacilityQrFrame({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8EEFA), width: 2),
        borderRadius: BorderRadius.circular(17),
      ),
      child: CustomPaint(
        foregroundPainter: _QrCornerPainter(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            size: size - 42,
            backgroundColor: Colors.white,
            padding: EdgeInsets.zero,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF11192A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF11192A),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    const length = 18.0;
    const inset = 1.0;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final path = Path()
      ..moveTo(inset, inset + length)
      ..lineTo(inset, inset)
      ..lineTo(inset + length, inset)
      ..moveTo(right - length, inset)
      ..lineTo(right, inset)
      ..lineTo(right, inset + length)
      ..moveTo(inset, bottom - length)
      ..lineTo(inset, bottom)
      ..lineTo(inset + length, bottom)
      ..moveTo(right - length, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right, bottom - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
