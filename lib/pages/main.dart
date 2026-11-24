import 'package:firebase_core/firebase_core.dart';
import 'package:first_project/firebase_options.dart';
import 'package:flutter/material.dart';

import 'active_queues_screen.dart';
import 'citizen_id_verification_screen.dart';
import 'citizen_notifications_screen.dart';
import 'citizen_points_screen.dart';
import 'citizen_report_screen.dart';
import 'citizen_settings_screen.dart';
import 'citizen_signup_screen.dart';
import 'employee_home_screen.dart';
import 'employee_join_screen.dart';
import 'employee_login_screen.dart';
import 'employee_pending_screen.dart';
import 'employee_profile_screen.dart';
import 'facilities_screen.dart';
import 'facility_home_screen.dart';
import 'facility_profile_screen.dart';
import 'facility_queues_screen.dart';
import 'facility_scan_screen.dart';
import 'facility_search_screen.dart';
import 'facility_staff_screen.dart';
import 'home_screen.dart';
import 'login.dart';
import 'onboarding.dart';
import 'profile_screen.dart';
import 'splash.dart';
import 'who_we_are_screen.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          primary: const Color(0xFF2196F3),
          surface: Colors.white,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
      ),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.0,
        child: child!,
      ),
      home: const Splash(),
      routes: {
        'who_we_are': (_) => const WhoWeAreScreen(),
        'citizen_points': (_) => const CitizenPointsScreen(),
        'citizen_notifications': (_) => const CitizenNotificationsScreen(),
        'citizen_report': (_) => const ReportScreen(),
        'report': (_) => const ReportScreen(),
        'onboarding': (_) => const Onboarding(),
        'login': (_) => const Login(),
        'employee_join_screen': (_) => const EmployeeJoinScreen(),
        'employee_login_screen': (_) => const EmployeeLoginScreen(),
        'employee_pending_screen': (_) => const EmployeePendingScreen(),
        'employee_profile_screen': (_) => const EmployeeProfileScreen(),
        'employee_home_screen': (_) => const EmployeeHomeScreen(),
        'signup': (_) => const CitizenSignUpScreen(),
        'citizen_id_verification': (_) => const CitizenIdVerificationScreen(),
        'home_screen': (_) => const HomeScreen(),
        'facilities_screen': (_) => const FacilitiesScreen(),
        'active_queues_screen': (_) => const ActiveQueuesScreen(),
        'profile_screen': (_) => const ProfileScreen(),
        'citizen_settings': (_) => const CitizenSettingsScreen(),
        'app_settings': (_) => const CitizenSettingsScreen(),
        'facility_home_screen': (_) => const FacilityHomeScreen(),
        'facility_queues_screen': (_) => const FacilityQueuesScreen(),
        'facility_scan_screen': (_) => const FacilityScanScreen(),
        'facility_staff_screen': (_) => const FacilityStaffScreen(),
        'facility_search_screen': (_) => const FacilitySearchScreen(),
        'facility_profile_screen': (_) => const FacilityProfileScreen(),
      },
    );
  }
}