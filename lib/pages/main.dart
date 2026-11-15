import 'package:firebase_core/firebase_core.dart';
import 'package:first_project/firebase_options.dart';
import 'package:first_project/pages/facilities_screen.dart';
import 'package:first_project/pages/home_screen.dart';
import 'package:first_project/pages/onboarding.dart';
import 'package:first_project/pages/profile_screen.dart';
//import 'package:first_project/pages/queue_ticket_screen.dart';
//import 'package:first_project/pages/add_queue_screen.dart';
import 'active_queues_screen.dart';
import 'package:first_project/pages/splash.dart';
import 'package:first_project/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:first_project/pages/facility_home_screen.dart';
import 'package:first_project/pages/facility_queues_screen.dart';
import 'package:first_project/pages/facility_scan_screen.dart';

import 'package:first_project/pages/facility_staff_screen.dart';
import 'package:first_project/pages/facility_search_screen.dart';
import 'package:first_project/pages/facility_profile_screen.dart';

import 'package:first_project/pages/citizen_id_verification_screen.dart';
import 'package:first_project/pages/citizen_signup_screen.dart';
import 'package:first_project/pages/citizen_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Splash(),
    // home: const FacilityHomeScreen(),

      routes: {
         "onboarding": (context) => const Onboarding(),
        "login": (context) => const Login(),
        'signup': (context) =>
    const CitizenSignUpScreen(),
    'citizen_id_verification': (context) =>
    const CitizenIdVerificationScreen(),
         "home_screen": (context) => const HomeScreen(),
         "facilities_screen":(context) => const FacilitiesScreen(),
        // "add_queue_ticket":((context) => const AddQueueScreen()),
        // "queue_ticket_screen":((context) => const QueueTicketScreen()),
        
         'active_queues_screen': (context) =>
            const ActiveQueuesScreen(),
        'profile_screen': (context) =>
            const ProfileScreen(),
        'citizen_settings': (context) =>
    const CitizenSettingsScreen(),

          'facility_home_screen': (context) =>
    const FacilityHomeScreen(),
    
'facility_queues_screen': (context) => const FacilityQueuesScreen(),
'facility_scan_screen': (context) => const FacilityScanScreen(),
'facility_staff_screen': (context) =>
    const FacilityStaffScreen(),

'facility_search_screen': (context) =>
    const FacilitySearchScreen(),

'facility_profile_screen': (context) =>
    const FacilityProfileScreen(),



      },
    );
  }
}