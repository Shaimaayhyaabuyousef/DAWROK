import 'dart:async';

import 'package:flutter/material.dart';

import '../services/server_clock.dart';

class AbsenceButton extends StatefulWidget {
  const AbsenceButton({
    super.key,
    required this.calledAt,
    required this.onAbsent,
  });
  final DateTime? calledAt;
  final VoidCallback? onAbsent;
  @override
  State<AbsenceButton> createState() => _AbsenceButtonState();
}

class _AbsenceButtonState extends State<AbsenceButton> {
  Timer? timer;
  bool synced = false;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> refresh() async {
    try {
      await ServerClock.now();
      if (mounted) setState(() => synced = true);
    } catch (_) {
      if (mounted)
        Future<void>.delayed(const Duration(seconds: 10), () {
          if (mounted) refresh();
        });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due = widget.calledAt?.add(const Duration(minutes: 10));
    final seconds = due == null
        ? 0
        : (due.difference(ServerClock.estimate).inMilliseconds / 1000).ceil();
    return OutlinedButton(
      onPressed: due != null && synced && seconds <= 0 ? widget.onAbsent : null,
      child: Text(
        seconds > 0 && widget.onAbsent != null
            ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
            : 'Absent',
      ),
    );
  }
}
