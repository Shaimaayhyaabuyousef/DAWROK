import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import 'workspace_style.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/employee_access_service.dart';
import 'package:first_project/l10n/app_language.dart';

const _blue = Color(0xFF03A9F4);
const _dark = Color(0xFF22334D);

/// First approval forces this page; its completion is enforced by Firestore
/// rules before employee work/queue data becomes available.
class EmployeeProfileScreen extends StatefulWidget {
  final bool embedded;
  const EmployeeProfileScreen({super.key, this.embedded = false});
  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _emergencyPhone = TextEditingController();
  Uint8List? _photo;
  Future<void> _pickPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 72,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('staff.photo.$uid', base64Encode(bytes));
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Unable to save photo on this device.'))),
        );
      }
    }
  }

  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final photo = (await SharedPreferences.getInstance()).getString(
        'staff.photo.$uid',
      );
      if (photo != null) _photo = base64Decode(photo);
      final snap = await FirebaseFirestore.instance
          .collection('staff_profiles')
          .doc(uid)
          .get();
      if (!mounted) return;
      final m = snap.data() ?? {};
      _fullName.text = m['fullName'] as String? ?? '';
      _phone.text = m['phone'] as String? ?? '';
      if (_phone.text.isEmpty) {
        final membership = await FirebaseFirestore.instance
            .collection('staff_memberships')
            .doc(uid)
            .get();
        final hash = membership.data()?['inviteHash'] as String?;
        if (hash != null) {
          final join = await FirebaseFirestore.instance
              .collection('staff_join_requests')
              .doc(hash)
              .get();
          if (!mounted) return;
          _phone.text = join.data()?['phone'] as String? ?? '';
        }
      }
      _address.text = m['address'] as String? ?? '';
      _emergencyPhone.text = m['emergencyPhone'] as String? ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('Could not load profile: $e'))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _address.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('staff_profiles')
          .doc(uid);
      final existing = await ref.get();
      final fields = <String, dynamic>{
        'uid': uid,
        'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'emergencyPhone': _emergencyPhone.text.trim(),
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (existing.exists) {
        await ref.update(fields);
      } else {
        await ref.set({...fields, 'createdAt': FieldValue.serverTimestamp()});
      }
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        _fullName.text.trim(),
      );
      final destination = await EmployeeAccessService.instance
          .currentDestination();
      if (!mounted) return;
      if (widget.embedded && destination == 'employee_home_screen') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('Changes saved.'))));
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Unable to save employee profile: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _profileCard({
    required String label,
    required Widget child,
    String? badge,
    Color badgeColor = _blue,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD2EDFD)),
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09062E4F),
          blurRadius: 5,
          offset: Offset(0, 3),
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
                tr(label),
                style: const TextStyle(
                  color: Color(0xFF3A4B62),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr(badge),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );

  Widget _valueInput(
    TextEditingController controller,
    String placeholder, {
    IconData? icon,
    TextInputType? keyboard,
    bool required = true,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      prefixIconConstraints: const BoxConstraints(minWidth: 30),
      prefixIcon: icon == null ? null : Icon(icon, color: _blue, size: 18),
      hintText: trOpt(placeholder),
      hintStyle: const TextStyle(color: Color(0xFF9EACC0)),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF64C8FC)),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFDAE6F3)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _blue, width: 2),
      ),
    ),
    validator: (value) {
      final text = (value ?? '').trim();
      if (required && text.length < 3) return 'Enter a valid $placeholder';
      if (keyboard == TextInputType.phone &&
          !RegExp(r'^\+?[0-9\s-]{8,20}$').hasMatch(text)) {
        return 'Enter a valid phone number';
      }
      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return WorkspaceStyle(
      child: PopScope(
        canPop: widget.embedded,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(22, 4, 22, 16),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: IconButton(
                              tooltip: tr('Settings'),
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      'app_settings',
                                    ),
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: Color(0xFF65768F),
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.center,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 76,
                                  backgroundColor: const Color(0xFFB3E8FD),
                                  child: CircleAvatar(
                                    radius: 73,
                                    backgroundColor: const Color(0xFFF0FAFF),
                                    backgroundImage: _photo == null
                                        ? null
                                        : MemoryImage(_photo!),
                                    child: _photo != null
                                        ? null
                                        : const Icon(
                                            Icons.person_outline,
                                            size: 81,
                                            color: _blue,
                                          ),
                                  ),
                                ),
                                PositionedDirectional(
                                  bottom: 0,
                                  end: 0,
                                  child: Container(
                                    width: 37,
                                    height: 37,
                                    decoration: BoxDecoration(
                                      color: _blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: tr('Change photo on this device'),
                                      padding: EdgeInsets.zero,
                                      onPressed: _pickPhoto,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _profileCard(
                            label: tr('Name Of Staff'),
                            badge: 'Required',
                            child: _valueInput(_fullName, 'Full Name'),
                          ),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: uid == null
                                ? const Stream.empty()
                                : FirebaseFirestore.instance
                                      .collection('staff_memberships')
                                      .doc(uid)
                                      .snapshots(),
                            builder: (context, membership) => _profileCard(
                              label: tr('ID'),
                              badge: '✓ Registered',
                              badgeColor: const Color(0xFF00A678),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    color: _blue,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      tr(membership.data?.data()?['staffId']
                                              as String? ??
                                          '—'),
                                      style: const TextStyle(
                                        color: _dark,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final id =
                                          membership.data?.data()?['staffId']
                                              as String?;
                                      if (id == null) return;
                                      await Clipboard.setData(
                                        ClipboardData(text: id),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(tr('Copied')),
                                              ),
                                            );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 16,
                                    ),
                                    label: Text(tr('Copy')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _profileCard(
                            label: tr('Phone'),
                            child: _valueInput(
                              _phone,
                              'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboard: TextInputType.phone,
                            ),
                          ),
                          _profileCard(
                            label: tr('Address'),
                            child: _valueInput(
                              _address,
                              'Address',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          if (!widget.embedded || _emergencyPhone.text.isEmpty)
                            _profileCard(
                              label: tr('Emergency Phone'),
                              child: _valueInput(
                                _emergencyPhone,
                                'Emergency Phone',
                                icon: Icons.contact_phone_outlined,
                                keyboard: TextInputType.phone,
                              ),
                            ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: _saving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      tr('Save Changes'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 23),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
