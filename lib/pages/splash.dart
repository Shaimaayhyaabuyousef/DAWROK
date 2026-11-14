import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/app_auth_service.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _continueToApp();
  }

  Future<void> _continueToApp() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final route = await AppAuthService.instance.destinationForCurrentSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SvgPicture.asset(
          'assets/images/logo.svg',
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
