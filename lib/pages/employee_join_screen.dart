import '../services/phone_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/facility_number.dart';
import 'employee_login_screen.dart';
import 'employee_register_screen.dart';
import 'package:first_project/l10n/app_language.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF243149);
const _border = Color(0xFFE0E8F1);

/// First-time employee invitation form, matching the supplied reference.
//// The pairing code only submits a request; it never grants access by itself.
class EmployeeJoinScreen extends StatefulWidget {
  const EmployeeJoinScreen({super.key});

  @override
  State<EmployeeJoinScreen> createState() => _EmployeeJoinScreenState();
}

class _EmployeeJoinScreenState extends State<EmployeeJoinScreen> {
  final _form = GlobalKey<FormState>();
  final _facility = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _facility.dispose();
    _code.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pasteCode() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text != null) _code.text = clipboard!.text!;
  }

  void _verify() {
    if (!_form.currentState!.validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeRegisterScreen(
          facilityNumber: normalizeFacilityNumber(_facility.text),
          invitationCode: _code.text.trim(),
          contactPhone: localMobile(_phone.text)!,
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {bool shaded = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA9BD)),
        filled: true,
        fillColor: shaded ? const Color(0xFFF6F8FB) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: shaded ? Colors.transparent : const Color(0xFFA7DCFA))),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: shaded ? Colors.transparent : const Color(0xFFA7DCFA))),
      );

  Widget _panel({
    required IconData icon,
    required String title,
    required Widget child,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsetsDirectional.fromSTEB(15, 15, 15, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(color: Color(0x080A355A), blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: _blue, size: 20),
        const SizedBox(width: 10),
        Text(tr(title), style: const TextStyle(
          color: Color(0xFF384960),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        )),
      ]),
      const SizedBox(height: 11),
      child,
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(builder: (context, constraints) =>
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              minHeight: constraints.maxHeight,
            ),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 23),
                ),
                SizedBox(height: constraints.maxHeight > 700 ? 77 : 34),
                _panel(
                  icon: Icons.apartment_outlined,
                  title: tr('Facility Number'),
                  child: TextFormField(
                    controller: _facility,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('Enter the 6-digit facility number'),
                    validator: (v) => validFacilityNumber(v ?? '')
                      ? null : 'Enter a six-digit facility number',
                  ),
                ),
                const SizedBox(height: 15),
                _panel(
                  icon: Icons.lock_outline,
                  title: tr('Employee Link Code'),
                  child: Row(children: [
                    Expanded(child: TextFormField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _decoration('Enter link code'),
                      validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Link code is required' : null,
                    )),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _pasteCode,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF53647E),
                        backgroundColor: const Color(0xFFF1F5F9),
                        minimumSize: const Size(66, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13))),
                      icon: const Icon(Icons.content_paste_outlined, size: 18),
                      label: Text(tr('Paste')),
                    ),
                  ]),
                ),
                const SizedBox(height: 15),
                _panel(
                  icon: Icons.phone_iphone_outlined,
                  title: tr('Phone Number'),
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration('+970 59 XXX XXXX', shaded: true),
                    validator: validateMobile,
                  ),
                ),
                const SizedBox(height: 49),
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                      elevation: 7,
                      shadowColor: const Color(0x4D03A9F4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tr('Verify & Join Facility  •  التحقق والانضمام'),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, size: 21),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                Center(child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) =>
                        const EmployeeLoginScreen()),
                  ),
                  child: Text(tr('Already joined? Sign in'),
                    style: TextStyle(color: Color(0xFF63748D))),
                )),
                const SizedBox(height: 25),
              ]),
            ),
          )),
        ),
      ),
    ),
  );
}
