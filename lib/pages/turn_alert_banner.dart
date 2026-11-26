import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:first_project/l10n/app_language.dart';

import 'queue_booking.dart';

/// Shows the citizen's turn alerts above every screen: when a window calls
/// their ticket, and when only a few people are ahead of them.
class TurnAlertHost extends StatefulWidget {
  const TurnAlertHost({super.key, required this.child});
  final Widget child;

  @override
  State<TurnAlertHost> createState() => _TurnAlertHostState();
}

class _TurnAlertHostState extends State<TurnAlertHost> {
  final _store = QueueBookingStore.instance;
  TurnAlert? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _store.alert.addListener(_onAlert);
  }

  @override
  void dispose() {
    _store.alert.removeListener(_onAlert);
    _hide?.cancel();
    super.dispose();
  }

  void _onAlert() {
    final a = _store.alert.value;
    if (a == null) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    setState(() => _shown = a);
    _hide?.cancel();
    // A call stays until dismissed; a "near" reminder hides by itself.
    if (!a.called) {
      _hide = Timer(const Duration(seconds: 12), _dismiss);
    }
  }

  void _dismiss() {
    if (mounted) setState(() => _shown = null);
  }

  @override
  Widget build(BuildContext context) {
    final a = _shown;
    return Stack(
      children: [
        widget.child,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: a == null ? const SizedBox.shrink() : _card(a),
          ),
        ),
      ],
    );
  }

  Widget _card(TurnAlert a) {
    final window = a.windowNumber;
    final title = a.called ? tr("It's your turn") : tr('Your turn is near');
    final where = a.facilityName.isEmpty ? '' : ' · ${a.facilityName}';
    final body = a.called
        ? (window == null || window == 0
                  ? tr('Go to the service point now.')
                  : tr('Go to window $window now.')) +
              where
        : tr('Only a few people are ahead of you. Make your way to the facility.') +
              where;
    return SafeArea(
      key: ValueKey(a.ticketId + a.called.toString()),
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 0),
        child: Material(
          color: a.called ? const Color(0xFF2196F3) : Colors.white,
          elevation: 8,
          shadowColor: const Color(0x332196F3),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 6, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: a.called
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    a.called
                        ? Icons.notifications_active_rounded
                        : Icons.hourglass_bottom_rounded,
                    color: a.called ? Colors.white : const Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: a.called ? Colors.white : const Color(0xFF0F1E33),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: a.called
                              ? Colors.white.withValues(alpha: 0.92)
                              : const Color(0xFF5B6B82),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  // No tooltip: this banner sits above the Navigator's Overlay.
                  onPressed: _dismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    color: a.called ? Colors.white : const Color(0xFF5B6B82),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
