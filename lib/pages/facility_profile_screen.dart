import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/facility_context.dart';
import 'package:flutter/services.dart';
import 'facility_nav.dart';
import 'package:first_project/l10n/app_language.dart';

class FacilityProfileScreen extends StatefulWidget {
  const FacilityProfileScreen({super.key});

  @override
  State<FacilityProfileScreen> createState() =>
      _FacilityProfileScreenState();
}

class _FacilityProfileScreenState extends State<FacilityProfileScreen> {
  final TextEditingController name =
      TextEditingController();
  final TextEditingController phone =
      TextEditingController();
  final TextEditingController address =
      TextEditingController();

  bool loaded = false;
  String? facilityNumber;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FacilityContext.instance.requireFacility();
      if (!mounted) return;
      setState(() {
        loaded = true;
        facilityNumber = doc.data()?['facilityNumber'] as String?;
        name.text = doc.data()?['name'] as String? ?? '';
        phone.text = doc.data()?['phone'] as String? ?? '';
        address.text = doc.data()?['address'] as String? ?? '';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(e.toString()))));
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!loaded || name.text.trim().isEmpty ||
        phone.text.trim().isEmpty || address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Please complete all required fields'))));
      return;
    }
    try {
      final fid = await FacilityContext.instance.requireFacilityId();
      await FirebaseFirestore.instance.collection('facilities').doc(fid).update({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Facility updated in Firebase.'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(e.toString()))));
    }
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: facilityNumber!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Facility number copied'))),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(26, 24, 26, 22),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                tooltip: tr('Settings'),
                onPressed: () => Navigator.pushNamed(context, 'app_settings'),
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF4B5C77),
                  size: 29,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 142,
                    height: 142,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE5F5FF),
                      border: Border.all(
                        color: const Color(0xFFABE2FF),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      size: 66,
                      color: Color(0xFF88C9F3),
                    ),
                  ),
                  PositionedDirectional(
                    end: -5,
                    bottom: 2,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFF00A7EB),
                      child: IconButton(
                        tooltip: tr('Change photo'),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showComingSoon(
                          'Photo picker is not connected yet',
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _box(
              title: tr('Name Of Facility'),
              badge: 'Required',
              child: TextField(
                controller: name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00A6EB)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFF00A6EB),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            _box(
              title: tr('Facility Number'),
              badge: facilityNumber == null ? null : '✔ Registered',
              child: Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    color: facilityMuted,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(facilityNumber ?? (loaded ? 'Awaiting number from admin' : 'Loading…')),
                      style: const TextStyle(
                        fontSize: 17,
                        color: facilityDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: facilityNumber == null ? null : _copyId,
                    child: Text(tr('Copy')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _box(
              title: tr('Phone Of Facility'),
              child: TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: Color(0xFF00A6EB),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: facilityBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00A6EB)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            _box(
              title: tr('Address Of Facility'),
              child: TextField(
                controller: address,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: Colors.redAccent,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: facilityBorder),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00A6EB)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06A9EA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('Save Changes'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const FacilityBottomNav(selected: 4),
    );
  }

  Widget _box({
    required String title,
    String? badge,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(15, 14, 15, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD3ECFC)),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0D5388),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(title),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF394962),
                    fontSize: 15,
                  ),
                ),
              ),
              if (badge != null)
                Text(
                  tr(badge),
                  style: TextStyle(
                    color: badge.contains('Registered')
                        ? const Color(0xFF009B72)
                        : const Color(0xFF008FD3),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}
