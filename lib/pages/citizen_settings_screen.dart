import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/citizen_preferences.dart';

const _primary = Color(0xFF03A9F4);
const _softBlue = Color(0xFF64B9FA);
const _ink = Color(0xFF182235);
const _muted = Color(0xFF71849F);

/// Shared settings for citizens, facilities and employees.
/// The original class name is retained for existing citizen navigation.
class CitizenSettingsScreen extends StatefulWidget {
  const CitizenSettingsScreen({super.key});

  @override
  State<CitizenSettingsScreen> createState() => _CitizenSettingsScreenState();
}

class _CitizenSettingsScreenState extends State<CitizenSettingsScreen> {
  bool _busy = false;
  bool _confirmingLogout = false;

  @override
  void initState() {
    super.initState();
    CitizenPreferences.instance.load().catchError((Object error) {
      debugPrint('Settings initialization failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not load saved settings. Check local browser storage.'),
      ));
    });
  }

  void _info() {
    showAboutDialog(
      context: context,
      applicationName: 'Dawrok',
      applicationVersion: 'Prototype',
      applicationLegalese: 'Queue booking and turn management.',
    );
  }

  void _report() => Navigator.pushNamed(context, 'report');

  Future<void> _logout() async {
    if (_busy || _confirmingLogout) return;
    _confirmingLogout = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out',
              style: TextStyle(color: Color(0xFFF04438))),
          ),
        ],
      ),
    );
    _confirmingLogout = false;
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil('login', (_) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BoxDecoration _panelStyle(bool dark) => BoxDecoration(
        color: dark ? const Color(0xFF1C2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0xFF34445A) : const Color(0xFFEDF4F8)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.09 : 0.028),
          offset: const Offset(0, 3),
          blurRadius: 13,
        )],
      );

  Widget _smallIcon(IconData icon, bool dark) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF21495B) : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? const Color(0xFF1D6478) : const Color(0xFFDDF2FE),
          ),
        ),
        child: Icon(icon, color: _primary, size: 22),
      );

  Widget _toggleRow({
    required bool dark,
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueNotifier<bool> state,
    required Future<void> Function(bool value) onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: ValueListenableBuilder<bool>(
        valueListenable: state,
        builder: (context, value, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
          children: [
            _smallIcon(icon, dark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16,
                      color: dark ? Colors.white : _ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2,
                    style: TextStyle(fontSize: 11.5,
                      color: dark ? Colors.white60 : _muted)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeColor: _primary,
              onChanged: _busy ? null : (v) async {
                try {
                  await onChanged(v);
                } catch (error) {
                  debugPrint('Preference $title could not be persisted: $error');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(
                        'Unable to save setting. Enable browser storage and restart Flutter.'
                      )),
                    );
                  }
                }
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _actionRow({
    required bool dark,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool destructive = false,
  }) => InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 65,
          child: Row(
            children: [
              _smallIcon(icon, dark),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: TextStyle(
                color: destructive ? const Color(0xFFF04438)
                    : (dark ? Colors.white : _ink),
                fontSize: 16,
              ))),
              if (_busy && destructive)
                const SizedBox(width: 19, height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2,
                    color: _primary)),
            ],
          ),
        ),
      );

  Widget _divider(bool dark) => Divider(
        height: 1,
        color: dark ? const Color(0xFF34445A) : const Color(0xFFEDF1F5),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CitizenPreferences.instance.darkMode,
      builder: (context, dark, _) {
        final bg = dark ? const Color(0xFF101B2A) : Colors.white;
        final fg = dark ? Colors.white : _ink;
        return PopScope(
          canPop: !_busy,
          child: Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 9, 24, 33),
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text('Settings', style: TextStyle(
                            fontSize: 21,
                            color: dark ? const Color(0xFF90D5FF) : _softBlue,
                          )),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Back to Profile',
                              icon: Icon(Icons.arrow_back_ios_new,
                                color: fg, size: 24),
                              onPressed: _busy ? null
                                : () => Navigator.maybePop(context),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'About Dawrok',
                              icon: Icon(Icons.info_outline, color: fg, size: 24),
                              onPressed: _info,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 41),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF24465C) : const Color(0xFFE3F4FF),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: _primary, size: 8),
                            SizedBox(width: 8),
                            Text('Dawrok Queue System', style: TextStyle(
                              color: Color(0xFF0088D1), fontSize: 12)),
                          ]),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text('Preferences', style: TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w500, color: fg)),
                    const SizedBox(height: 5),
                    Text('Customize your workflow and display options',
                      style: TextStyle(fontSize: 13,
                        color: dark ? Colors.white60 : _muted)),
                    const SizedBox(height: 52),
                    Container(
                      decoration: _panelStyle(dark),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Column(children: [
                        _toggleRow(
                          dark: dark, title: 'Dark Mode',
                          subtitle: 'Enable nighttime contrast',
                          icon: Icons.nightlight_round,
                          state: CitizenPreferences.instance.darkMode,
                          onChanged: CitizenPreferences.instance.setDarkMode,
                        ),
                        _divider(dark),
                        _toggleRow(
                          dark: dark, title: 'Save Image',
                          subtitle: 'Preference for future media saving',
                          icon: Icons.image_outlined,
                          state: CitizenPreferences.instance.saveImages,
                          onChanged: CitizenPreferences.instance.setSaveImages,
                        ),
                        _divider(dark),
                        _toggleRow(
                          dark: dark, title: 'Work with SMS',
                          subtitle: 'Preference only · SMS not enabled yet',
                          icon: Icons.sms_outlined,
                          state: CitizenPreferences.instance.smsAlerts,
                          onChanged: CitizenPreferences.instance.setSmsAlerts,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: _panelStyle(dark),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      child: Column(children: [
                        _actionRow(dark: dark, icon: Icons.chat_bubble_outline,
                          title: 'Report', onTap: _report),
                        _divider(dark),
                        _actionRow(dark: dark, icon: Icons.info_outline,
                          title: 'Who are we?', onTap: _info),
                        _divider(dark),
                        _actionRow(dark: dark, icon: Icons.logout_rounded,
                          title: 'Log out', onTap: _logout, destructive: true),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: _panelStyle(dark),
                      child: Row(children: [
                        const Icon(Icons.circle, size: 12,
                          color: Color(0xFF0EC18C)),
                        const SizedBox(width: 11),
                        Expanded(child: Text(FirebaseAuth.instance.currentUser == null
                            ? 'Not signed in' : 'Account session active',
                          style: TextStyle(fontSize: 12, color: fg))),
                        Text('DAWROK', style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white60 : const Color(0xFF93A7C2))),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
