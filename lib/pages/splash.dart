import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xfffbfeff), Colors.white, Color(0xfffcf8ff)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final scale = math.min(
                    bounds.maxWidth / 393,
                    bounds.maxHeight / 786,
                  );
                  return SizedBox(
                    width: 393 * scale,
                    height: 786 * scale,
                    child: FittedBox(
                      child: SizedBox(
                        width: 393,
                        height: 786,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Positioned(
                              top: 130,
                              child: Container(
                                width: 320,
                                height: 320,
                                decoration: const BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(0, .5),
                                    colors: [
                                      Color(0xffdcf1fc),
                                      Color(0x00ffffff),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              top: 147,
                              child: CustomPaint(
                                size: Size.square(192),
                                painter: _BrandMark(),
                              ),
                            ),
                            const Positioned(
                              top: 398,
                              child: Text.rich(
                                TextSpan(
                                  text: 'DAWROK ',
                                  style: TextStyle(
                                    color: Color(0xff1e293b),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '│ دَورْك',
                                      style: TextStyle(
                                        color: Color(0xff03a9f4),
                                      ),
                                    ),
                                  ],
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            const Positioned(
                              top: 485,
                              child: _Dots([
                                Color(0xff03a9f4),
                                Color(0xff38bdf8),
                                Color(0xff10b981),
                              ]),
                            ),
                            const Positioned(
                              top: 544,
                              child: Row(
                                children: [
                                  Text(
                                    'VERIFYING SECURE CIVIL IDENTITY...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: .5,
                                      color: Color(0xff64748b),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Icon(
                                    Icons.sync,
                                    size: 15,
                                    color: Color(0xff03a9f4),
                                  ),
                                ],
                              ),
                            ),
                            const Positioned(
                              bottom: 109,
                              child: _Dots([
                                Color(0xff062367),
                                Color(0xff00695c),
                                Color(0xff004568),
                              ]),
                            ),
                            const Positioned(
                              bottom: 76,
                              child: Text(
                                'جاري تهيئة خدمات المراكز والمواعيد...',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xff454656),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 52,
                              child: SizedBox(
                                width: 192,
                                height: 6,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    color: Color(0xff09276a),
                                    backgroundColor: Color(0xffe2e7fb),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots(this.colors);
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final color in colors)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
        ),
    ],
  );
}

class _BrandMark extends CustomPainter {
  const _BrandMark();
  @override
  void paint(Canvas c, Size size) {
    final p = Paint();
    const center = Offset(96, 96);
    for (final ring in [
      (96.0, 0xffd4efff),
      (95.0, 0x77e1f3ff),
      (80.0, 0xaaffffff),
      (64.0, 0xffddf1ff),
      (63.0, 0xffffffff),
    ]) {
      c.drawCircle(center, ring.$1, p..color = Color(ring.$2));
    }
    void person(double x, double y, double r, Color color) {
      c.drawCircle(Offset(x, y), r, p..color = color);
      c.drawArc(
        Rect.fromCenter(
          center: Offset(x, y + r * 3.1),
          width: r * 3.5,
          height: r * 3.5,
        ),
        math.pi,
        math.pi,
        true,
        p,
      );
    }

    const blue = Color(0xff03a9f4), green = Color(0xff10b981);
    for (var i = 0; i < 4; i++) {
      person(
        67,
        61 + i * 20.5,
        2.8 + i * .28,
        [
          const Color(0xffbbdefb),
          const Color(0xff90caf9),
          const Color(0xff42a5f5),
          const Color(0xff0288d1),
        ][i],
      );
    }
    person(100, 89, 6, green);
    c.drawPath(
      Path()
        ..moveTo(81, 64)
        ..lineTo(96, 64)
        ..quadraticBezierTo(128, 64, 128, 97)
        ..lineTo(128, 127)
        ..lineTo(81, 127),
      Paint()
        ..color = blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      Path()
        ..moveTo(120, 131)
        ..lineTo(139, 139)
        ..lineTo(134, 121)
        ..close(),
      p..color = blue,
    );
    c.drawCircle(const Offset(109, 85), 5.5, p..color = Colors.white);
    c.drawCircle(const Offset(109, 85), 4.2, p..color = green);
    c.drawPath(
      Path()
        ..moveTo(107, 85)
        ..lineTo(108.5, 86.5)
        ..lineTo(111.5, 83),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_BrandMark oldDelegate) => false;
}
