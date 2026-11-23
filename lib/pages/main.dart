import 'who_we_are_screen.dart';
import 'citizen_points_screen.dart';
import 'citizen_notifications_screen.dart';
import 'citizen_report_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'employee_join_screen.dart';
import 'employee_login_screen.dart';
import 'employee_pending_screen.dart';
import 'employee_profile_screen.dart';
import 'employee_home_screen.dart';
import 'package:first_project/firebase_options.dart';
import 'package:first_project/pages/facilities_screen.dart';
import 'package:first_project/pages/home_screen.dart';
import 'package:first_project/pages/onboarding.dart';
import 'package:first_project/pages/profile_screen.dart';
//import 'package:first_project/pages/queue_ticket_screen.dart';
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
      theme: ThemeData(fontFamily: 'Inter'),
      builder: (context, navigator) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: navigator!,
      ),
      home: const Splash(),
    // home: const FacilityHomeScreen(),

      routes: {
        'who_we_are': (_) => const WhoWeAreScreen(),
        'citizen_points': (_) => const CitizenPointsScreen(),
        'citizen_notifications': (_) => const CitizenNotificationsScreen(),
        'citizen_report': (_) => const ReportScreen(),
        'report': (_) => const ReportScreen(),
         "onboarding": (context) => const Onboarding(),
        "login": (context) => const Login(),
        'employee_join_screen': (context) => const EmployeeJoinScreen(),
        'employee_login_screen': (context) => const EmployeeLoginScreen(),
        'employee_pending_screen': (context) => const EmployeePendingScreen(),
        'employee_profile_screen': (context) => const EmployeeProfileScreen(),
        'employee_home_screen': (context) => const EmployeeHomeScreen(),
        'signup': (context) =>
    const CitizenSignUpScreen(),
    'citizen_id_verification': (context) =>
    const CitizenIdVerificationScreen(),
         "home_screen": (context) => const HomeScreen(),
         "facilities_screen":(context) => const FacilitiesScreen(),
        // "queue_ticket_screen":((context) => const QueueTicketScreen()),
        
         'active_queues_screen': (context) =>
            const ActiveQueuesScreen(),
        'profile_screen': (context) =>
            const ProfileScreen(),
        'citizen_settings': (context) =>
    const CitizenSettingsScreen(),
        // All roles share the existing settings UI. Keep the citizen route
        // for compatibility with the citizen profile.
        'app_settings': (context) => const CitizenSettingsScreen(),

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
