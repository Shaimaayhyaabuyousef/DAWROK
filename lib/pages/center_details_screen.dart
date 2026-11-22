import 'dart:async';
import '../services/server_clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/queue_schedule.dart';
import 'add_queue_screen.dart';

const _blue = Color(0xFF008DD2);
const _ink = Color(0xFF141C2F);
const _muted = Color(0xFF687B96);

class CenterDetailsScreen extends StatelessWidget {
  final String name, address, rating, openingFrom, openingTo;
  final String? facilityId, status;
  final String reward;
  final bool isOpen, verified;
  final int registeredCount,
      minWaitingMinutes,
      maxWaitingMinutes,
      occupancyPercent;
  const CenterDetailsScreen({
    super.key,
    this.reward = 'none',
    required this.name,
    this.facilityId,
    required this.address,
    required this.rating,
    required this.openingFrom,
    required this.openingTo,
    this.status,
    this.isOpen = true,
    this.verified = false,
    this.registeredCount = 0,
    this.minWaitingMinutes = 0,
    this.maxWaitingMinutes = 0,
    this.occupancyPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final id = facilityId;
    if (id == null || id.isEmpty) {
      return _layout(context, message: 'Choose a facility from the directory.');
    }
    return _FacilityClockView(builder: (context) => _liveDetails(context,id));
  }

  Widget _liveDetails(BuildContext context,String id) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('facilities')
          .doc(id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _layout(
            context,
            message: 'Unable to load facility details. Please try again.',
          );
        if (!snapshot.hasData) return _layout(context, loading: true);
        final facility = snapshot.data!.data();
        if (facility == null || facility['isActive'] != true) {
          return _layout(
            context,
            message: 'This facility is no longer available.',
          );
        }
        if (facility['isOnline'] != true) {
          return _layout(
            context,
            facility: facility,
            message: 'Bookings are currently closed.',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: snapshot.data!.reference
              .collection('queues')
              .where('isActive', isEqualTo: true)
              .where('archived', isEqualTo: false)
              .snapshots(),
          builder: (context, queues) {
            if (queues.hasError)
              return _layout(
                context,
                facility: facility,
                message: 'Unable to load queue statistics. Please try again.',
              );
            if (!queues.hasData)
              return _layout(context, facility: facility, loading: true);
            final docs = queues.data!.docs;
            if (docs.isEmpty)
              return _layout(
                context,
                facility: facility,
                total: 0,
                occupancy: 0,
                message: 'No active queues are available.',
              );
            return _dailyTotals(context, facility, docs, 0, 0, const []);
          },
        );
      },
    );
  }

  // Read only aggregate counters, never other citizens' booking documents.
  Widget _dailyTotals(
    BuildContext context,
    Map<String, dynamic> facility,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> queues,
    int index,
    int total,
    List<String> eligible,
  ) {
    final canBook = eligible.isNotEmpty;
    if (index == queues.length) {
      final capacity = queues.fold<int>(
        0,
        (sum, q) => sum + ((q.data()['capacity'] as num?)?.toInt() ?? 0),
      );
      return _layout(
        context,
        facility: facility,
        queues: queues,
        total: total,
        occupancy: capacity > 0
            ? (total * 100 / capacity).round().clamp(0, 100).toInt()
            : 0,
        canBook: canBook,
        eligible: eligible,
        message: canBook
            ? null
            : reward == 'priority' ? 'No eligible waiting ticket for priority today. No points were charged.'
            : 'No available booking times or capacity today.',
      );
    }
    final queue = queues[index];
    final row = queue.data();
    final slots = QueueSchedule.availableSlots(
      (row['startsAtMinutes'] as num?)?.toInt() ?? 0,
      (row['endsAtMinutes'] as num?)?.toInt() ?? 0,
      ServerClock.estimate,
    );
    final day = QueueSchedule.dayKey(
      slots.isEmpty ? ServerClock.estimate : slots.first,
    );
    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: queue.reference.collection('closures').doc(day).snapshots(),
      builder: (context, closure) {
        if (closure.hasError) return _layout(context,facility:facility,queues:queues,message:'Could not verify service availability.');
        if (!closure.hasData) return _layout(context,facility:facility,queues:queues,loading:true);
        if (closure.data!.exists) return _dailyTotals(context, facility, queues,index+1,total,eligible);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: queue.reference.collection('days').doc(day).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _layout(
            context,
            facility: facility,
            queues: queues,
            message: 'Unable to load queue statistics. Please try again.',
          );
        if (!snapshot.hasData)
          return _layout(
            context,
            facility: facility,
            queues: queues,
            loading: true,
          );
        final reserved =
            ((snapshot.data!.data()?['reserved'] as num?)?.toInt() ?? 0) - ((snapshot.data!.data()?['cancelled'] as num?)?.toInt() ?? 0);
        final capacity = (row['capacity'] as num?)?.toInt() ?? 0;
        final extra = (snapshot.data!.data()?['rewardReserved'] as num?)?.toInt() ?? 0;
        final room = reward == 'extra' ? reserved-extra >= capacity && extra < (row['rewardCapacity'] ?? 0)
            : reserved-extra < capacity;
        Widget next(bool available) => _dailyTotals(context,facility,queues,index+1,total+reserved,
            available ? [...eligible,queue.id] : eligible);
        if (slots.isEmpty || !room) return next(false);
        if (reward != 'priority') return next(true);
        var slot = QueueSchedule.nextBooking(start:row['startsAtMinutes'],end:row['endsAtMinutes'],
            capacity:capacity,reserved:reserved,now:ServerClock.estimate);
        if (slot == null) return next(false);
        final last = (snapshot.data!.data()?['lastSlotStart'] as Timestamp?)?.toDate();
        if(last != null && last.isAfter(slot)) slot = last;
        return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream:queue.reference.collection('priority_offers').where('slotStart',isEqualTo:Timestamp.fromDate(slot)).limit(1).snapshots(),
          builder:(context,offers) => next(offers.data?.docs.isNotEmpty ?? false));
      },
    );
      },
    );
  }

  String _clock(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    return '${(hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _layout(
    BuildContext context, {
    Map<String, dynamic>? facility,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> queues = const [],
    int? total,
    int? occupancy,
    List<String>? eligible,
    bool canBook = false,
    bool loading = false,
    String? message,
  }) {
    final title = facility?['name'] as String? ?? name;
    final location = facility?['address'] as String? ?? address;
    final open = facility?['isOnline'] == true;
    final starts =
        queues
            .map((q) => q.data()['startsAtMinutes'])
            .whereType<num>()
            .map((v) => v.toInt())
            .toList()
          ..sort();
    final ends =
        queues
            .map((q) => q.data()['endsAtMinutes'])
            .whereType<num>()
            .map((v) => v.toInt())
            .toList()
          ..sort();
    final waits =
        queues
            .map((q) => q.data()['waitingMinutes'])
            .whereType<num>()
            .map((v) => v.toInt())
            .toList()
          ..sort();
    final from = starts.isEmpty ? '—' : _clock(starts.first);
    final to = ends.isEmpty ? '—' : _clock(ends.last);
    final waiting = waits.isEmpty
        ? '—'
        : waits.first == waits.last
        ? '${waits.first}'
        : '${waits.first}-${waits.last}';
    final load = occupancy == null
        ? '—'
        : occupancy < 40
        ? 'Low Load'
        : occupancy < 75
        ? 'Moderate Load'
        : 'High Load';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Text(
                                'Center Details',
                                style: TextStyle(
                                  color: Color(0xFF64B9FA),
                                  fontSize: 21,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.maybePop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.black,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          decoration: _panel(24),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Container(
                                height: 6,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF35C4FA),
                                      Color(0xFF008CCB),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'NAME OF FACILITY',
                                            style: TextStyle(
                                              color: _blue,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: .35,
                                            ),
                                          ),
                                        ),
                                        _badge(
                                          open ? 'Open' : 'Closed',
                                          checked: true,
                                          active: open,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: Color(0xFFEDF2F7),
                                      ),
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FAFF),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.location_on_outlined,
                                            color: _blue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Address',
                                                style: TextStyle(
                                                  color: _muted,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                location,
                                                style: const TextStyle(
                                                  color: Color(0xFF263247),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Booking available',
                                                style: TextStyle(
                                                  color: _muted,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _time(
                                                      'From',
                                                      from,
                                                      _blue,
                                                    ),
                                                  ),
                                                  Container(
                                                    height: 24,
                                                    width: 1,
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    color: const Color(
                                                      0xFFCDEBFB,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: _time(
                                                      'to',
                                                      to,
                                                      _ink,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F9FB),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFEEF3F8),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: open
                                                ? const Color(0xFF0FBC87)
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'HOURS',
                                                  style: TextStyle(
                                                    color: Color(0xFF92A3BB),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$from - $to',
                                                  style: const TextStyle(
                                                    color: Color(0xFF3D4D64),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Queue statistics',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _badge(
                              loading
                                  ? '…'
                                  : total == null
                                  ? '—'
                                  : 'LIVE',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _stat(
                          'Total registered:',
                          total?.toString() ?? '—',
                          'PEOPLE',
                          Icons.groups_outlined,
                          false,
                        ),
                        const SizedBox(height: 12),
                        _stat(
                          'Approximate waiting\ntime:',
                          waiting,
                          'MINS',
                          Icons.schedule_outlined,
                          true,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: _panel(16, shadow: false),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Center Occupancy',
                                      style: TextStyle(
                                        color: Color(0xFF52627B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    occupancy == null
                                        ? '—'
                                        : '$occupancy% $load',
                                    style: const TextStyle(
                                      color: _blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: occupancy == null
                                      ? 0
                                      : occupancy / 100,
                                  minHeight: 8,
                                  color: const Color(0xFF00ACED),
                                  backgroundColor: const Color(0xFFF0F4F8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 38),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: canBook
                                ? [
                                    const BoxShadow(
                                      color: Color(0x3500ACEB),
                                      offset: Offset(0, 7),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: canBook
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddQueueScreen(
                                        reward: reward,
                                        availableQueueIds: eligible,
                                        facilityName: title,
                                        facilityId: facilityId,
                                        isOpen: open,
                                      ),
                                    ),
                                  )
                                : null,
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                              size: 22,
                            ),
                            label: const Text(
                              'Book Appointment',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: const Color(0xFF49AAF2),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFADD8F7),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _panel(double radius, {bool shadow = true}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE5ECF4)),
    boxShadow: shadow
        ? [
            const BoxShadow(
              color: Color(0x0B182D4A),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ]
        : [],
  );

  Widget _time(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF92A3BB), fontSize: 10),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _badge(String text, {bool checked = false, bool active = true}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F1),
          border: Border.all(
            color: active ? const Color(0xFFB3F4D9) : const Color(0xFFFFD3D3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? Icons.check_circle : Icons.circle,
              size: checked ? 12 : 8,
              color: active ? const Color(0xFF0DBB87) : Colors.redAccent,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: active ? const Color(0xFF008765) : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _stat(
    String title,
    String value,
    String unit,
    IconData icon,
    bool amber,
  ) {
    final tint = amber ? const Color(0xFFDF8500) : _blue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(24),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: amber ? const Color(0xFFFFFBEC) : const Color(0xFFECF8FF),
              border: amber ? Border.all(color: const Color(0xFFFFEDB0)) : null,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF273247),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 95,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: amber ? const Color(0xFFFFFDF6) : const Color(0xFFF7FBFE),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: amber
                    ? const Color(0xFFF7DE8A)
                    : const Color(0xFFAFE2FF),
              ),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: amber ? const Color(0xFFB75E00) : _blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityClockView extends StatefulWidget {
  const _FacilityClockView({required this.builder});
  final WidgetBuilder builder;
  @override
  State<_FacilityClockView> createState() => _FacilityClockViewState();
}

class _FacilityClockViewState extends State<_FacilityClockView> {
  Timer? timer;
  bool ready = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds:30), (_) => refresh());
  }
  Future<void> refresh() async {
    try {
      await ServerClock.now();
      if (mounted) setState(() { ready = true; error = null; });
    } catch (e) {
      if (mounted) setState(() { error = e; });
    }
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (ready) return widget.builder(context);
    return Scaffold(appBar:AppBar(),body:Center(child: error == null
        ? const CircularProgressIndicator()
        : TextButton(onPressed:refresh,child:const Text('Reconnect to check availability'))));
  }
}
