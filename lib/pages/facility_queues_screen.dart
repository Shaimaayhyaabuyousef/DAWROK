import 'facility_empty_state.dart';
import 'employee_scanner_screen.dart';
import 'facility_queue_window_picker.dart';
import 'workspace_style.dart';
import '../services/facility_context.dart';
import '../services/booking_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'facility_add_queue_sheet.dart';
import 'facility_queue_store.dart';
import 'facility_nav.dart';

const _primary = Color(0xFF4FAAF3);
const _brightBlue = Color(0xFF069FEA);
const _dark = Color(0xFF222E43);
const _muted = Color(0xFF92A4BE);
const _border = Color(0xFFD9EEFC);

/// Facility-side queue management. Navigation index 1 in the facility tab bar.
class FacilityQueuesScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigationTap;
  const FacilityQueuesScreen({super.key, this.onNavigationTap});

  @override
  State<FacilityQueuesScreen> createState() => _FacilityQueuesScreenState();
}

class _FacilityQueuesScreenState extends State<FacilityQueuesScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the real server list when the screen is opened. The existing
    // AnimatedBuilder will rebuild all cards as soon as it is received.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FacilityQueueStore.instance.refresh();
        final fid = await FacilityContext.instance.requireFacilityId();
        for (final queue in FacilityQueueStore.instance.queues) {
          await BookingCancellation.resume(fid, 'window_${queue.windowNumber}');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load queues: $e')),
        );
      }
    });
  }

  Future<void> _openAdd(BuildContext context) async {
    final draft = await showFacilityAddQueueSheet(context);
    if (draft == null || !context.mounted) return;
    try { await FacilityQueueStore.instance.create(draft); } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    final warning = FacilityQueueStore.instance.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(warning == null
          ? 'Queue created and verified in Firestore.'
          : 'Queue saved, but the list did not refresh: $warning')),
    );
  }

  Future<void> _edit(BuildContext context, FacilityQueue queue) async {
    final draft = await showFacilityAddQueueSheet(context, editing: queue);
    if (draft == null || !context.mounted) return;
    try { await FacilityQueueStore.instance.update(queue.windowNumber, draft); } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Queue updated')),
    );
  }

  Future<void> _delete(BuildContext context, FacilityQueue queue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete queue?'),
        content: Text('Remove Queue #${queue.windowNumber.toString().padLeft(2, '0')}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE72B50))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try { await FacilityQueueStore.instance.delete(queue.windowNumber); } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Queue deleted')),
    );
  }

  void _tab(BuildContext context, int index) {
    if (index == 1) return;
    if (widget.onNavigationTap != null) {
      widget.onNavigationTap!(index);
      return;
    }
    if (index == 0) {
      Navigator.pushReplacementNamed(context, 'facility_home_screen');
      return;
    }
    goToFacilityTab(context, index, 1);
  }

  @override
  Widget build(BuildContext context) {
    final store = FacilityQueueStore.instance;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: WorkspaceStyle(child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.only(top: 47, bottom: 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 354),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final innerWidth = c.maxWidth;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: innerWidth >= 340 ? 25 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (store.queues.isNotEmpty) _statistics(store),
                            if (store.queues.isEmpty && store.error == null)
                              if (store.hasLoadedQueues)
                                const FacilityEmptyState.queues()
                              else
                                const Center(child: CircularProgressIndicator()),
                            if (store.error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                store.error!,
                                style: const TextStyle(
                                  color: Color(0xFFB42318), fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 16),
                            for (final queue in store.queues) ...[
                              _queueCard(context, queue),
                              const SizedBox(height: 10),
                            ],
                            if (store.queues.isNotEmpty) const SizedBox(height: 45),
                            _addButton(context),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: FacilityBottomNav(selected: 1, onTap: (index) => _tab(context, index)),
      )),
    );
  }

  Widget _statistics(FacilityQueueStore store) {
    return Container(
      height: 61,
      decoration: BoxDecoration(
        color: const Color(0xFFF1FAFF),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [BoxShadow(color: Color(0x0D39719A), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          _stat('TOTAL QUEUES', store.totalQueues.toString().padLeft(2, '0'), _dark),
          Container(height: 39, width: 1, color: _border),
          _stat('IN WAITING', '${store.totalWaiting}', const Color(0xFFE48A00)),
          Container(height: 39, width: 1, color: _border),
          _stat('AVG WAIT', '~${store.averageWaitMinutes}m', const Color(0xFF00A07B)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _muted)),
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _cancelToday(BuildContext context, FacilityQueue queue) async {
            final yes = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
              title:const Text('Cancel service for today?'),
              content:const Text('Waiting and called tickets will be cancelled. Citizens will be notified and reward points returned.'),
              actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Keep service')),
                TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Cancel today’s service'))]));
            if (yes != true) return;
            try {
              await BookingCancellation.stopDay('window_${queue.windowNumber}');
              if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Service cancelled and affected tickets updated.')));
            } catch(e) {
              if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not finish. Retry to continue: $e')));
            }
            }

  Future<void> _manage(BuildContext context, FacilityQueue queue) async {
    final window = await chooseFacilityQueueWindow(context, queue.windowCount, queue.service);
    if (!context.mounted || window == null) return;
    try {
      final facilityId = await FacilityContext.instance.requireFacilityId();
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeScannerScreen(
        facilityId: facilityId, queueId: queue.documentId ?? 'window_${queue.windowNumber}',
        windowNumber: window, facilityOwner: true,
      )));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open queue: $error')));
    }
  }

  Widget _queueCard(BuildContext context, FacilityQueue queue) {
    final active = queue.isActive;
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => _manage(context, queue),
      child: Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x09296DA4), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Align(alignment: Alignment.centerLeft, child:
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFD5FAE7) : const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: active ? const Color(0xFF0EBC85) : const Color(0xFFFFAE32)),
                            const SizedBox(width: 7),
                            Flexible(child: Text(active ? 'Active' : 'Stopped',
                              style: TextStyle(color: active ? const Color(0xFF008A68) : const Color(0xFFFF9917), fontWeight: FontWeight.w600, fontSize: 11))),
                          ],
                        ),
                      ))),
                        PopupMenuButton<String>(
                          tooltip: 'Queue options',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 160),
                          iconSize: 18,
                          onSelected: (_) => _cancelToday(context, queue),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'cancel', child: Text('Cancel today’s service')),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Flexible(child: Text(queue.service, style: const TextStyle(color: _dark, fontWeight: FontWeight.w600))),
                        const Icon(Icons.chevron_right, size: 18, color: _brightBlue, semanticLabel: 'Manage queue'),
                      ]),
                      Text('Queue #${queue.windowNumber.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: _muted, fontSize: 12)),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  width: 109,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F5FF),
                    border: Border.all(color: const Color(0xFFB6E3FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const WorkspaceIcon('windows', color: Color(0xFF008EDE)),
                      const SizedBox(height: 5),
                      Text(queue.windowCount == 0 ? 'SERVICE' : 'WINDOWS', style: TextStyle(color: Color(0xFF006FAE), fontSize: 10, fontWeight: FontWeight.w700)),
                      Text(queue.windowCount == 0 ? 'Direct' : '${queue.windowCount}', style: const TextStyle(color: Color(0xFF006FAE), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFEBF0F5), height: 9),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const WorkspaceIcon('beneficiaries', color: _brightBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${queue.beneficiaries} Beneficiaries in queue',
                    softWrap: true,
                    style: const TextStyle(color: Color(0xFF35445C), fontSize: 11.5)),
                ),
                const SizedBox(width: 5),
                Text('~${queue.waitingMinutes} min wait',
                  style: const TextStyle(color: Color(0xFF008DE2), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const Divider(color: Color(0xFFEBF0F5), height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _actionButton('Delete', Icons.delete_outline_rounded, const Color(0xFFE71E49), const Color(0xFFFFF1F2), () => _delete(context, queue))),
              const SizedBox(width: 6),
              Expanded(child: _actionButton('Edit', Icons.edit_square, Colors.white, const Color(0xFF354258), () => _edit(context, queue))),
              const SizedBox(width: 6),
              Expanded(child: _actionButton(active ? 'Pause booking' : 'Open booking', null, const Color(0xFFFF9000), const Color(0xFFFFDEAF), () {
                FacilityQueueStore.instance.setActive(queue.windowNumber, !active).catchError((Object e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                });
              })),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _actionButton(String label, IconData? icon, Color color, Color background, VoidCallback pressed) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: pressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15),
                const SizedBox(width: 5),
              ],
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return SizedBox(
      height: 53,
      child: ElevatedButton.icon(
        onPressed: () => _openAdd(context),
        icon: Container(
          height: 26,
          width: 26,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x556DBEFF)),
          child: const Icon(Icons.add, size: 22),
        ),
        label: const Text('Add Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: const Color(0x4545BAF3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
    );
  }

}
