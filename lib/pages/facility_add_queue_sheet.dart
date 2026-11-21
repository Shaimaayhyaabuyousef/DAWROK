import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'facility_queue_store.dart';

const _blue = Color(0xFF04A7EF);
const _lightBlue = Color(0xFF4FAAF3);
const _dark = Color(0xFF192337);
const _muted = Color(0xFF94A5BE);
const _border = Color(0xFFDEE6F0);
const _field = Color(0xFFF7F9FC);

/// Modal used for both Add Queue and Edit Queue.
/// On a phone wide enough for the reference it is 393 x 753 logical pixels.
Future<FacilityQueueDraft?> showFacilityAddQueueSheet(
  BuildContext context, {
  FacilityQueue? editing,
  List<String> services = const [
    'General Service',
    'Appointments',
    'Customer Service',
    'Document Processing',
    'Other Service',
  ],
}) {
  return showModalBottomSheet<FacilityQueueDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x55000000),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final maxHeight = math.max(0.0, media.size.height - media.padding.top - 8);
      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: math.min(393.0, media.size.width),
          height: math.min(753.0, maxHeight),
          child: _QueueSheetContent(editing: editing, services: services),
        ),
      );
    },
  );
}

class _QueueSheetContent extends StatefulWidget {
  final FacilityQueue? editing;
  final List<String> services;

  const _QueueSheetContent({required this.editing, required this.services});

  @override
  State<_QueueSheetContent> createState() => _QueueSheetContentState();
}

class _QueueSheetContentState extends State<_QueueSheetContent> {
  String? _service;
  int _capacity = 50;
  int _rewardCapacity = 0;
  int _waitingMinutes = 15;
  int _windowCount = 0;
  FacilityQueueShift _shift = FacilityQueueShift.morning;
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 13, minute: 30);
  bool _saving = false;
  bool _showServiceError = false;

  @override
  void initState() {
    super.initState();
    final queue = widget.editing;
    if (queue != null) {
      _service = queue.service;
      _capacity = queue.capacity;
      _rewardCapacity = queue.rewardCapacity;
      _waitingMinutes = queue.waitingMinutes;
      _windowCount = queue.windowCount;
      _shift = queue.shift;
      _from = queue.startsAt;
      _to = queue.endsAt;
    }
  }

  void _selectShift(FacilityQueueShift shift) {
    setState(() {
      _shift = shift;
      if (shift == FacilityQueueShift.morning) {
        _from = const TimeOfDay(hour: 8, minute: 0);
        _to = const TimeOfDay(hour: 13, minute: 30);
      } else {
        _from = const TimeOfDay(hour: 14, minute: 0);
        _to = const TimeOfDay(hour: 19, minute: 0);
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: start ? _from : _to,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (start) {
        _from = chosen;
      } else {
        _to = chosen;
      }
    });
  }

  void _save() {
    if (_saving) return;
    if (_service == null) {
      setState(() => _showServiceError = true);
      return;
    }
    if (facilityTimeInMinutes(_to) <= facilityTimeInMinutes(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be later than start time')),
      );
      return;
    }
    setState(() => _saving = true);
    Navigator.of(context).pop(FacilityQueueDraft(
      service: _service!,
      windowCount: _windowCount,
      capacity: _capacity,
      rewardCapacity: _rewardCapacity,
      waitingMinutes: _waitingMinutes,
      shift: _shift,
      startsAt: _from,
      endsAt: _to,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final availableServices = <String>{...widget.services};
    if (_service != null) availableServices.add(_service!);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 21),
            Container(
              width: 100,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 34),
            Text(
              widget.editing == null ? 'Add Queue' : 'Edit Queue',
              style: const TextStyle(
                color: Color(0xFF6BB8FA),
                fontSize: 21,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(35, 0, 35, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _servicePicker(availableServices.toList()),
                    if (_showServiceError) ...[
                      const SizedBox(height: 5),
                      const Text('Please choose a service',
                        style: TextStyle(fontSize: 11, color: Color(0xFFD73E4B))),
                    ],
                    const SizedBox(height: 17),
                    const Text('Capacity:', style: TextStyle(fontSize: 14.5, color: Colors.black)),
                    const SizedBox(height: 8),
                    _capacityCard(),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Expanded(child: Text('Service windows')),
                      _stepButton(Icons.remove, () => setState(() => _windowCount = math.max(0, _windowCount - 1))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('$_windowCount')),
                      _stepButton(Icons.add, () => setState(() => _windowCount = math.min(20, _windowCount + 1)), blue: true),
                    ]),
                    Text(_windowCount == 0 ? 'No windows — direct queue service' : 'Employees are assigned automatically to vacant windows', style: const TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Expanded(child: Text('Extra reward places', style: TextStyle(color: _muted))),
                      _stepButton(Icons.remove, () => setState(() => _rewardCapacity = math.max(0, _rewardCapacity - 1))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('$_rewardCapacity')),
                      _stepButton(Icons.add, () => setState(() => _rewardCapacity = math.min(1000, _rewardCapacity + 1)), blue: true),
                    ]),
                    const SizedBox(height: 17),
                    const Text(
                      'Approximate waiting time:',
                      style: TextStyle(fontSize: 14.5, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    _waitingTimeCard(),
                    const SizedBox(height: 8),
                    _bookingWindowCard(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(35, 13, 35, keyboard > 0 ? 12 : 30),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: Icon(widget.editing == null ? Icons.add : Icons.check, size: 23),
                  label: Text(
                    widget.editing == null ? 'Create Queue' : 'Save Changes',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _lightBlue,
                    elevation: 8,
                    shadowColor: const Color(0x4542BAE9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _servicePicker(List<String> services) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _showServiceError ? const Color(0xFFD73E4B) : _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _service,
          hint: const Text(
            'choose the service to be organized',
            style: TextStyle(color: _dark, fontSize: 14, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF607087)),
          items: services.map((service) => DropdownMenuItem(
            value: service,
            child: Text(service, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) => setState(() {
            _service = value;
            _showServiceError = false;
          }),
        ),
      ),
    );
  }

  Widget _capacityCard() {
    return _roundedField(
      height: 70,
      child: Row(
        children: [
          _circleIcon(Icons.groups_outlined),
          const SizedBox(width: 14),
          Text('$_capacity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _dark)),
          const Spacer(),
          const Flexible(
            flex: 2,
            child: Text('Beneficiaries', style: TextStyle(fontSize: 13, color: _muted), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _stepButton(Icons.remove, () => setState(() => _capacity = math.max(1, _capacity - 1))),
                Container(height: 20, width: 1, color: _border),
                _stepButton(Icons.add, () => setState(() => _capacity = math.min(9999, _capacity + 1)), blue: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed, {bool blue = false}) {
    return SizedBox(
      height: 33,
      width: 33,
      child: IconButton(
        icon: Icon(icon, size: 19, color: blue ? _blue : const Color(0xFF536179)),
        padding: EdgeInsets.zero,
        splashRadius: 19,
        onPressed: onPressed,
        tooltip: blue ? 'Increase' : 'Decrease',
      ),
    );
  }

  Widget _waitingTimeCard() {
    return _roundedField(
      height: 60,
      child: Row(
        children: [
          _circleIcon(Icons.access_time_rounded),
          const SizedBox(width: 13),
          Text('$_waitingMinutes', style: const TextStyle(color: _dark, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Text('mins', style: TextStyle(fontSize: 13, color: Color(0xFF63748E))),
          const SizedBox(width: 7),
          for (final minutes in [10, 15, 30]) ...[
            _quickTimeButton(minutes),
            if (minutes != 30) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _quickTimeButton(int minutes) {
    final selected = _waitingMinutes == minutes;
    return InkWell(
      onTap: () => setState(() => _waitingMinutes = minutes),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        alignment: Alignment.center,
        height: 29,
        width: 39,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF8FF) : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? const Color(0xFFADE1FD) : _border),
        ),
        child: Text(
          '${minutes}m',
          style: TextStyle(fontSize: 12, color: selected ? _blue : const Color(0xFF4D5C76), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _bookingWindowCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFA9E5FD), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x0E00B7FF), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE2F5FE), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.punch_clock_rounded, color: Color(0xFF008BD3), size: 18),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Available Booking Window (Hourly)',
                  style: TextStyle(fontSize: 12.5, color: _dark, fontWeight: FontWeight.bold),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _shiftButton(FacilityQueueShift.morning, 'Morning Shift', '08:00 - 01:30', Icons.wb_sunny_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _shiftButton(FacilityQueueShift.evening, 'Evening Shift', '02:00 - 07:00', Icons.nightlight_round)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9EEFA)),
            ),
            child: Row(
              children: [
                Expanded(child: _timeBox('From Time', _from, () => _pickTime(start: true))),
                Padding(
                  padding: const EdgeInsets.only(left: 0, right: 0, top: 22),
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(color: const Color(0xFFF3FAFF), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFA4E2FB))),
                    child: const Icon(Icons.arrow_forward_rounded, color: _lightBlue, size: 19),
                  ),
                ),
                Expanded(child: _timeBox('To Time', _to, () => _pickTime(start: false))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String title, TimeOfDay time, VoidCallback onTap) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF657690))),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 59,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _field,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(facilityTimeText(time), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _dark)),
                ),
                const SizedBox(height: 3),
                Text(facilityTimeText(time), style: const TextStyle(fontSize: 10, color: Color(0xFF008FE2))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shiftButton(FacilityQueueShift shift, String label, String hours, IconData icon) {
    final selected = _shift == shift;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectShift(shift),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 47,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _blue : _border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : const Color(0xFF53637D)),
              const SizedBox(width: 4),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF52627A))),
                    Text(hours, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF52627A))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(color: Color(0xFFE8F6FE), shape: BoxShape.circle),
      child: Icon(icon, color: _blue, size: 19),
    );
  }

  Widget _roundedField({required double height, required Widget child}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x0B334E68), offset: Offset(0, 2), blurRadius: 3)],
      ),
      child: child,
    );
  }
}
