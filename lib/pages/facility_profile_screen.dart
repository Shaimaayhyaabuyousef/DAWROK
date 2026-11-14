import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'facility_nav.dart';

class FacilityProfileScreen extends StatefulWidget {
  const FacilityProfileScreen({super.key});

  @override
  State<FacilityProfileScreen> createState() =>
      _FacilityProfileScreenState();
}

class _FacilityProfileScreenState extends State<FacilityProfileScreen> {
  final TextEditingController name =
      TextEditingController(text: 'Family Bakery');
  final TextEditingController phone =
      TextEditingController(text: '059-456-7890');
  final TextEditingController address =
      TextEditingController(text: 'Al-Naser street, Zone B4');

  final String id = '479-h79-907';

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  void _save() {
    if (name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved locally (demo only)')),
    );
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facility ID copied')),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () =>
                    _showComingSoon('Settings page coming soon'),
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
                  Positioned(
                    right: -5,
                    bottom: 2,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: const Color(0xFF00A7EB),
                      child: IconButton(
                        tooltip: 'Change photo',
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
              title: 'Name Of Facility',
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
              title: 'ID Of Facility',
              badge: '✔ Registered',
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
                      id,
                      style: const TextStyle(
                        fontSize: 17,
                        color: facilityDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _copyId,
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _box(
              title: 'Phone Of Facility',
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
              title: 'Address Of Facility',
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
                child: const Text(
                  'Save Changes',
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
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
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
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF394962),
                    fontSize: 15,
                  ),
                ),
              ),
              if (badge != null)
                Text(
                  badge,
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
