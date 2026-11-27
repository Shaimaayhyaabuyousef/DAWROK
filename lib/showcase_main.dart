// Showcase build: runs the real app on the web against the Firebase emulators,
// fills it with a believable day of data, and opens one screen per URL so the
// screens can be captured in Arabic. Never deployed; emulators only.
//
//   ?seed=1                         create facility data, staff, citizens, tickets
//   ?role=cit&screen=home_screen    sign in as a role and open a route
//   ?role=stf&action=callnext       the window officer calls the next ticket
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'l10n/app_language.dart';
import 'models/citizen_registration_draft.dart';
import 'pages/center_details_screen.dart';
import 'pages/employee_scanner_screen.dart';
import 'pages/facility_queue_store.dart';
import 'pages/facility_staff_store.dart';
import 'pages/main.dart' show MyApp;
import 'pages/queue_booking.dart';
import 'pages/queue_ticket_screen.dart';
import 'pages/splash.dart';
import 'services/app_auth_service.dart';
import 'services/booking_service.dart';
import 'services/citizen_signup_service.dart';
import 'services/employee_access_service.dart';
import 'services/employee_work_service.dart';
import 'services/facility_context.dart';
import 'services/national_id.dart';
import 'services/staff_pairing_service.dart';

const pass = 'Showcase-Pass-2026';
const ownerPhone = '0599100001';
const staffPeople = [('لينا خالد', '0599100011'), ('محمد سالم', '0599100012')];
const citizenPeople = [
  ('محمد عمر', '0599100021'),
  ('أحمد ياسين', '0599100022'),
  ('سارة أحمد', '0599100023'),
  ('رنا سمير', '0599100024'),
  ('يوسف حسن', '0599100025'),
];
const saraPhone = '0599100023';
const newcomer = ('ليلى محمود', '0599100026');

Future<void> say(String s) async {
  debugPrint('SHOWCASE: $s');
  await SystemChrome.setApplicationSwitcherDescription(
    ApplicationSwitcherDescription(label: s, primaryColor: 0xFF2196F3),
  );
}

String nid(int start) {
  for (var n = start; ; n++) {
    final s = n.toString().padLeft(9, '0');
    if (validNationalId(s)) return s;
  }
}

Future<void> signIn(String phone) async {
  await FirebaseAuth.instance.signOut();
  await AppAuthService.instance.signInWithPhone(phone: phone, password: pass);
}

Future<String> facilityId() => FacilityContext.instance.requireFacilityId();

Future<void> seed() async {
  // 1. The facility owner opens the facility and its queues.
  await signIn(ownerPhone);
  final fid = await facilityId();
  await FirebaseFirestore.instance.collection('facilities').doc(fid).update({'isOnline': true});
  final store = FacilityQueueStore.instance;
  await store.refresh();
  const drafts = [
    ('Customer Service', 40, 3, 10),
    ('Document Processing', 30, 1, 15),
    ('Appointments', 24, 1, 20),
  ];
  for (final (service, capacity, windows, minutes) in drafts) {
    await store.create(FacilityQueueDraft(
      service: service,
      capacity: capacity,
      windowCount: windows,
      rewardCapacity: 4,
      waitingMinutes: minutes,
      shift: FacilityQueueShift.morning,
      startsAt: const TimeOfDay(hour: 7, minute: 0),
      endsAt: const TimeOfDay(hour: 23, minute: 30),
    ));
  }
  for (var n = 1; n <= drafts.length; n++) {
    await store.setActive(n, true);
  }
  await say('seed: queues');

  // 2. Invite two staff members.
  final staffStore = FacilityStaffStore.instance;
  await staffStore.refresh();
  final invites = <StaffInviteResult>[];
  for (var i = 0; i < staffPeople.length; i++) {
    invites.add(await staffStore.add(
      name: staffPeople[i].$1,
      nationalId: nid(800100000 + i * 1000),
      window: 'Automatic',
      role: StaffRole.windowOfficer,
    ));
  }
  await say('seed: invites');

  // 3. Each staff member creates an account and asks to join.
  for (var i = 0; i < staffPeople.length; i++) {
    await FirebaseAuth.instance.signOut();
    await EmployeeAccessService.instance.authenticateForJoin(
      phone: staffPeople[i].$2,
      password: pass,
      existingAccount: false,
    );
    await StaffPairingService.instance.requestToJoin(
      invites[i].code,
      facilityNumber: invites[i].facilityNumber,
      phone: staffPeople[i].$2,
      confirm: (_) async => true,
    );
  }
  await say('seed: join requests');

  // 4. The owner approves them.
  await signIn(ownerPhone);
  await staffStore.refresh();
  for (final m in staffStore.staff) {
    await staffStore.approve(m);
  }
  await say('seed: approved');

  // 5. Staff complete their profiles.
  for (final (name, phone) in staffPeople) {
    await signIn(phone);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('staff_profiles').doc(uid).set({
      'uid': uid,
      'fullName': name,
      'phone': phone,
      'address': 'غزة',
      'emergencyPhone': '0599100099',
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
  }
  await say('seed: profiles');

  // 6. Citizens register and book.
  for (var i = 0; i < citizenPeople.length; i++) {
    final (name, phone) = citizenPeople[i];
    await FirebaseAuth.instance.signOut();
    await CitizenSignupService.instance.complete(
      pin: '1234',
      draft: CitizenRegistrationDraft(
        fullName: name,
        nationalId: nid(400200000 + i * 1000),
        phone: phone,
        password: pass,
      ),
    );
    await BookingService.instance.reserve(facilityId: fid, queueId: 'window_1');
    if (phone == saraPhone) {
      await BookingService.instance.reserve(facilityId: fid, queueId: 'window_2');
    }
  }
  // A newcomer with no tickets yet.
  await FirebaseAuth.instance.signOut();
  await CitizenSignupService.instance.complete(
    pin: '1234',
    draft: CitizenRegistrationDraft(
      fullName: newcomer.$1,
      nationalId: nid(400900000),
      phone: newcomer.$2,
      password: pass,
    ),
  );
  await say('seed: bookings');

  await FirebaseAuth.instance.signOut();
  await say('seed-done');
}

Future<Map<String, dynamic>?> myAssignment(String fid) async {
  final doc = await FirebaseFirestore.instance
      .collection('facilities').doc(fid)
      .collection('operations').doc('assignments').get();
  return (doc.data()?['assignments'] as Map?)?[FirebaseAuth.instance.currentUser!.uid] as Map<String, dynamic>?;
}

/// A window officer calls the next ticket at their own window (each window's
/// first call); with [serve] the ticket is also checked in.
Future<void> callAndServe(String fid, {required bool serve, int who = 0}) async {
  await signIn(staffPeople[who].$2);
  final a = await myAssignment(fid);
  if (a == null) throw StateError('No assignment for the window officer');
  final work = EmployeeWorkService.forEmployee(fid);
  final qid = a['queueId'] as String;
  final window = (a['windowNumber'] as num).toInt();
  final called = await work.callNext(qid, window);
  if (!called.startsWith('Calling ticket #')) throw StateError(called);
  if (serve) await work.checkIn(called.split('#').last.trim(), qid, window);
}

/// The facility owner serves at the free third window of the first queue.
Future<void> ownerCall(String fid) async {
  final called = await EmployeeWorkService.forFacilityOwner(fid).callNext('window_1', 3);
  if (!called.startsWith('Calling ticket #')) throw StateError(called);
}

Future<String> facilityOf(String phone) async {
  final snap = await FirebaseFirestore.instance
      .collection('staff_memberships').doc(FirebaseAuth.instance.currentUser!.uid).get();
  return snap.data()?['facilityId'] as String;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final web = DefaultFirebaseOptions.web;
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: web.apiKey,
      appId: web.appId,
      messagingSenderId: web.messagingSenderId,
      projectId: 'demo-dawrok',
      authDomain: web.authDomain,
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8089);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  await AppLanguage.set('ar');

  final q = Uri.base.queryParameters;
  try {
    if (q['seed'] == '1') {
      runApp(const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))));
      await seed();
      return;
    }
    final role = q['role'];
    final phone = switch (role) {
      'cit' => saraPhone,
      'cit0' => newcomer.$2,
      'fac' => ownerPhone,
      'stf' => staffPeople[0].$2,
      'stf2' => staffPeople[1].$2,
      _ => null,
    };
    if (phone != null) await signIn(phone);
    if (q['action'] != null) {
      runApp(const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))));
      switch (q['action']) {
        case 'serve': await callAndServe(await facilityOf(phone!), serve: true);
        case 'callnext': await callAndServe(await facilityOf(phone!), serve: false, who: role == 'stf2' ? 1 : 0);
        case 'ownercall': await ownerCall(await facilityId());
      }
      await say('action-done');
      return;
    }
    runApp(ShowcaseApp(screen: q['screen'] ?? 'home_screen'));
    Future.delayed(const Duration(seconds: 6), () => say('ready'));
  } catch (e, st) {
    debugPrint('$e\n$st');
    await say('failed: $e');
  }
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key, required this.screen});
  final String screen;

  @override
  Widget build(BuildContext context) {
    final base = const MyApp().app(context, const Locale('ar'));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: base.locale,
      supportedLocales: base.supportedLocales,
      localizationsDelegates: base.localizationsDelegates,
      theme: base.theme,
      builder: base.builder,
      routes: base.routes!,
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch}),
      home: switch (screen) {
        'ticket' => const _Ticket(),
        'details' => const _Details(),
        'scanner' => const _Scanner(),
        'splash' => const Splash(),
        _ => _Route(screen, base.routes!),
      },
    );
  }
}

class _Route extends StatelessWidget {
  const _Route(this.name, this.routes);
  final String name;
  final Map<String, WidgetBuilder> routes;
  @override
  Widget build(BuildContext context) => routes[name]!(context);
}

class _Ticket extends StatelessWidget {
  const _Ticket();
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: QueueBookingStore.instance,
    builder: (context, _) {
      final list = QueueBookingStore.instance.bookings;
      if (list.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final b = list.first;
      return QueueTicketScreen(
        ticketNumber: b.ticketNumber,
        queueNumber: b.queueNumber,
        windowNumber: b.windowNumber,
        windowCount: b.windowCount,
        scheduledAt: b.scheduledAt,
        facilityName: b.facilityName,
        idNumber: b.idNumber,
        createdAt: b.createdAt,
        estimatedWaiting: b.estimatedWaiting,
        qrPayload: b.qrPayload,
      );
    },
  );
}

class _Details extends StatelessWidget {
  const _Details();
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: FirebaseFirestore.instance.collection('facilities').doc('100245').get(),
    builder: (context, snap) {
      final doc = snap.data;
      if (doc == null || !doc.exists) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final d = doc.data()!;
      return CenterDetailsScreen(
        name: d['name'] as String? ?? '',
        facilityId: doc.id,
        address: d['address'] as String? ?? '',
        rating: '4.8',
        openingFrom: '07:00 ص',
        openingTo: '11:30 م',
        status: 'Open',
        verified: true,
        registeredCount: 5,
        minWaitingMinutes: 10,
        maxWaitingMinutes: 20,
        occupancyPercent: 35,
      );
    },
  );
}

class _Scanner extends StatelessWidget {
  const _Scanner();
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: () async {
      final fid = await facilityOf('');
      return (fid, await myAssignment(fid));
    }(),
    builder: (context, snap) {
      final v = snap.data;
      if (v == null || v.$2 == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return EmployeeScannerScreen(
        facilityId: v.$1,
        queueId: v.$2!['queueId'] as String,
        windowNumber: (v.$2!['windowNumber'] as num).toInt(),
      );
    },
  );
}
