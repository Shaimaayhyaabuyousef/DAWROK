import 'citizen_bottom_nav.dart';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/citizen_preferences.dart';
import 'package:first_project/l10n/app_language.dart';

const _primary = Color(0xFF03A9F4);
const _sky = Color(0xFF4EAAF3);
const _outline = Color(0xFFD9F0FF);
const _ink = Color(0xFF344258);

/// Citizen-only profile. It reads users/{uid} and updates editable fields only.
/// Missing IDs can be added once to the private citizen_identity document.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _idInput = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _uid;
  String? _originalId;
  String? _photoUrl;
  Uint8List? _localPreview;
  String? _identityError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _idInput.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Please sign in to view your profile.');

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data();
      if (data == null || data['role'] != 'citizen') {
        throw StateError('Citizen profile was not found.');
      }

      if (!mounted) return;
      _uid = user.uid;
      _name.text = (data['displayName'] as String?) ?? user.displayName ?? '';
      _phone.text = (data['phone'] as String?) ?? user.phoneNumber ?? '';
      _address.text = (data['address'] as String?) ?? '';
      _photoUrl = (data['photoUrl'] as String?) ?? user.photoURL;
      // Older builds may have put an ID in users/{uid}. New builds keep it in
      // a separate, owner-readable citizen_identity/{uid} document.
      _originalId = (data['nationalId'] as String?) ??
          (data['nationalIdMasked'] as String?);
      try {
        final identity = await FirebaseFirestore.instance
            .collection('citizen_identity').doc(user.uid).get();
        if (!mounted) return;
        final value = identity.data()?['nationalId'];
        if (value is String && value.isNotEmpty) _originalId = value;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          _identityError = 'Publish the citizen_identity Firestore rules to read/save your ID.';
        } else {
          _identityError = 'Could not load your saved ID (${e.code}).';
        }
      }
    } catch (e) {
      if (!mounted) return;
      _error = e.toString().replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _maskedId {
    final value = _originalId?.trim() ?? '';
    if (value.isEmpty) return 'Not available';
    if (value.contains('•') || value.contains('*')) return value;
    if (value.length <= 4) return '••••';
    return '••• ••• ${value.substring(value.length - 4)}';
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(message))),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        imageQuality: 72,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _localPreview = bytes);
      _message('Photo preview only. Upload is not enabled on this demo plan.');
    } catch (_) {
      if (mounted) _message('Unable to select this image.');
    }
  }

  Future<void> _copyId() async {
    final id = _originalId?.trim();
    if (id == null || id.isEmpty) return;
    if (id.contains('•') || id.contains('*')) {
      _message('Only a stored full ID can be copied.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: id));
    if (mounted) _message('ID copied.');
  }

  Future<void> _save() async {
    final uid = _uid;
    if (_saving || uid == null) return;
    final name = _name.text.trim();
    final phone = _phone.text.trim().replaceAll(' ', '').replaceAll('-', '');
    final address = _address.text.trim();
    final newId = _idInput.text.trim();
    if (name.isEmpty || name.length > 120) {
      _message('Enter a name (1–120 characters).');
      return;
    }
    if (phone.isNotEmpty &&
        !RegExp(r'^(0(?:59|56)\d{7}|\+?970(?:59|56)\d{7})$')
            .hasMatch(phone)) {
      _message('Enter a valid 059/056 mobile number, or leave it blank.');
      return;
    }
    if (address.length > 200) {
      _message('Address must be 200 characters or fewer.');
      return;
    }
    // Existing users may register their missing ID once. This is self-reported;
    // no scan, OTP, or formal identity verification takes place here.
    if ((_originalId?.trim().isNotEmpty != true) && newId.isNotEmpty &&
        !RegExp(r'^\d{9}$').hasMatch(newId)) {
      _message('Enter a 9-digit ID number.');
      return;
    }

    setState(() => _saving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'displayName': name,
        'phone': phone,
        'address': address,
      });
      final savingId = (_originalId?.trim().isNotEmpty != true) && newId.isNotEmpty;
      if (savingId) {
        batch.set(FirebaseFirestore.instance.collection('citizen_identity').doc(uid), {
          'userId': uid,
          'nationalId': newId,
          'status': 'self_reported',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (savingId) {
        _originalId = newId;
        _idInput.clear();
        _identityError = null;
      }
      // The Firestore document is the profile source of truth. The Firebase
      // Auth displayName is updated as a convenience for other app screens.
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      } catch (_) {
        // Profile changes were already saved to Firestore successfully.
      }
      if (!mounted) return;
      _message(_localPreview == null
          ? 'Profile updated successfully.'
          : 'Details saved. Profile photo is a local preview only.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _message(e.code == 'permission-denied'
          ? 'Permission denied. Publish updated Firestore rules for users and citizen_identity.'
          : 'Could not save changes: ${e.message ?? e.code}');
    } catch (_) {
      if (mounted) _message('Could not save profile changes.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _navigate(int item) {
    if (item == 0) {
      Navigator.of(context).pushReplacementNamed('home_screen');
    } else if (item == 1) {
      Navigator.of(context).pushReplacementNamed('active_queues_screen');
    }
  }

  Widget _avatar() {
    Widget picture;
    if (_localPreview != null) {
      picture = Image.memory(_localPreview!, fit: BoxFit.cover);
    } else if (_photoUrl != null && _photoUrl!.startsWith('https://')) {
      picture = Image.network(
        _photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    } else {
      picture = _avatarFallback();
    }

    return Center(
      child: SizedBox(
        width: 156,
        height: 156,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              child: Container(
                width: 146,
                height: 146,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA5E1FF), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: picture,
              ),
            ),
            PositionedDirectional(
              end: 1,
              bottom: 7,
              child: Material(
                color: _primary,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 2),
                ),
                elevation: 3,
                child: InkWell(
                  onTap: _pickAvatar,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 43,
                    height: 43,
                    child: Icon(Icons.edit_outlined,
                        color: Colors.white, size: 23),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() => const ColoredBox(
        color: Color(0xFFE6F6FF),
        child: Center(
          child: Icon(Icons.person_outline, size: 88, color: _sky),
        ),
      );

  BoxDecoration _cardDecoration(bool dark) => BoxDecoration(
        color: dark ? const Color(0xFF1C2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF34445A) : _outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.08 : 0.045),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      );

  InputDecoration _fieldDecoration(bool dark, {IconData? icon}) =>
      InputDecoration(
        isDense: true,
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _primary),
        prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 30),
        hintText: tr('Tap to edit'),
        hintStyle: TextStyle(
          color: dark ? Colors.white54 : const Color(0xFF9AA9BD),
          fontSize: 16,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      );

  /// Flexible height instead of an 84px Column with Spacer, fixing the 13px
  /// BOTTOM OVERFLOWED warnings in the 400 x 650 Chrome preview.
  Widget _editableCard({
    required String label,
    required TextEditingController controller,
    required bool dark,
    required IconData icon,
    bool requiredField = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    final fg = dark ? Colors.white : _ink;
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 9),
      decoration: _cardDecoration(dark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(tr(label), style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: fg,
              ))),
              if (requiredField)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF25455B) : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(tr('Required'),
                    style: TextStyle(color: _primary, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: !_saving,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(color: fg, fontSize: 16,
              fontWeight: requiredField ? FontWeight.w600 : FontWeight.w500),
            keyboardType: keyboard,
            maxLines: 1,
            decoration: _fieldDecoration(dark, icon: requiredField ? null : icon),
          ),
          Divider(height: 1, thickness: requiredField ? 1.8 : 1,
            color: requiredField ? _primary :
              (dark ? const Color(0xFF45536B) : const Color(0xFFDDE7F0))),
        ],
      ),
    );
  }

  Widget _idCard(bool dark) {
    final fg = dark ? Colors.white : _ink;
    final exists = (_originalId ?? '').isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
      decoration: _cardDecoration(dark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(tr('ID'), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: fg))),
            Icon(Icons.info_outline, color: _primary, size: 16),
            const SizedBox(width: 5),
            Text(tr('Not verified'), style: TextStyle(
              color: _primary, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          if (exists)
            Row(children: [
              const Icon(Icons.badge_outlined, size: 19, color: Color(0xFF95A9C4)),
              const SizedBox(width: 7),
              Expanded(child: Text(tr(_maskedId), style: TextStyle(color: fg, fontSize: 15))),
              TextButton(onPressed: _copyId,
                child: Text(tr('Copy'), style: TextStyle(color: _primary))),
            ])
          else
            TextField(
              controller: _idInput,
              keyboardType: TextInputType.number,
              maxLength: 9,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_saving,
              style: TextStyle(color: fg, fontSize: 16),
              decoration: _fieldDecoration(dark, icon: Icons.badge_outlined)
                  .copyWith(hintText: tr('Add your 9-digit ID once'), counterText: ''),
            ),
          if (_identityError != null) ...[
            const SizedBox(height: 3),
            Text(tr(_identityError!), style: const TextStyle(
              fontSize: 11, color: Color(0xFFCC4D34))),
          ],
          const Divider(height: 1, color: Color(0xFFDDE7F0)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CitizenPreferences.instance.darkMode,
      builder: (context, dark, _) {
        final bg = dark ? const Color(0xFF101B2A) : Colors.white;
        final fg = dark ? Colors.white : _ink;
        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            bottom: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _error != null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(25),
                        child: Text(tr(_error!), textAlign: TextAlign.center,
                          style: TextStyle(color: fg)),
                      ))
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: ListView(
                            padding: const EdgeInsetsDirectional.fromSTEB(26, 10, 26, 19),
                            children: [
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: IconButton(
                                  tooltip: tr('Settings'),
                                  onPressed: () => Navigator.pushNamed(
                                    context, 'citizen_settings'),
                                  icon: Icon(Icons.settings_outlined,
                                    size: 29, color: fg),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _avatar(),
                              const SizedBox(height: 20),
                              _editableCard(label: tr('Name Of citizen'),
                                controller: _name, dark: dark, icon: Icons.person_outline,
                                requiredField: true),
                              const SizedBox(height: 16),
                              _idCard(dark),
                              const SizedBox(height: 16),
                              _editableCard(label: tr('Contact phone'), controller: _phone,
                                dark: dark, icon: Icons.phone_outlined,
                                keyboard: TextInputType.phone),
                              const SizedBox(height: 16),
                              _editableCard(label: tr('Address'), controller: _address,
                                dark: dark, icon: Icons.location_on_outlined),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(width: 21, height: 21,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5, color: Colors.white))
                                      : Text(tr('Save Changes'),
                                          style: TextStyle(fontSize: 18,
                                            fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          bottomNavigationBar: CitizenBottomNav(selected: 2, onTap: _navigate, dark: dark),
        );
      },
    );
  }
}
