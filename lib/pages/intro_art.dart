import 'dart:math' as math;

import 'package:flutter/material.dart';

// Artwork uses the 393 by 527 design coordinate system.
class IntroArt extends CustomPainter {
  const IntroArt(this.serving);
  final bool serving;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 393, size.height / 527);
    canvas.translate(
      (size.width - 393 * scale) / 2,
      (size.height - 527 * scale) / 2,
    );
    canvas.scale(scale);
    final p = Paint()..isAntiAlias = true;
    const white = Colors.white;
    const green = Color(0xff4caf50);
    const amber = Color(0xffffb74d);
    void dot(double x, double y, double r, Color color) =>
        canvas.drawCircle(Offset(x, y), r, p..color = color);
    void box(
      double x,
      double y,
      double w,
      double h,
      double radius,
      Color color, {
      bool shadow = false,
    }) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      );
      if (shadow)
        canvas.drawShadow(
          Path()..addRRect(rect),
          const Color(0xff83a8c5),
          10,
          true,
        );
      canvas.drawRRect(rect, p..color = color);
    }

    void glow(double x, double y, double r, Color color) {
      final area = Rect.fromCircle(center: Offset(x, y), radius: r);
      canvas.drawOval(
        area,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(area),
      );
    }

    void line(
      double x,
      double y,
      double x2,
      double y2,
      Color color,
      double width,
    ) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x2, y2),
        p
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    void text(String label, double x, double y, double font, Color color) {
      final t = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: font,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, Offset(x, y));
    }

    void person(double x, double y, double w, Color color) {
      dot(x, y, w * .38, color);
      box(x - w / 2, y + w * .5, w, w * 1.5, w / 2, color);
    }

    void clock(double x, double y, Color color) {
      dot(x, y, 19, color);
      dot(x, y, 15, white);
      line(x, y, x, y - 10, color, 3.5);
      line(x, y, x + 8, y + 5, color, 3.5);
    }

    void check(double x, double y, Color background, Color mark, double r) {
      dot(x, y, r, background);
      line(x - r * .48, y, x - r * .12, y + r * .34, mark, 3);
      line(x - r * .12, y + r * .34, x + r * .53, y - r * .36, mark, 3);
    }

    glow(82, 429, 174, const Color(0x6642a5f5));
    if (serving) {
      glow(315, 89, 178, const Color(0x554caf50));
      canvas.drawOval(
        const Rect.fromLTWH(40, 434, 340, 37),
        p..color = const Color(0xffdcefdc),
      );
      box(30, 115, 125, 60, 19, white, shadow: true);
      clock(60, 145, green);
      text('10:30', 85, 128, 15, const Color(0xff102039));
      box(85, 150, 50, 7, 4, const Color(0xffa5d6a7));
      box(220, 150, 150, 215, 22, white, shadow: true);
      box(220, 150, 150, 40, 20, green);
      box(220, 170, 150, 20, 0, green);
      text('Window 2', 252, 161, 17, white);
      box(235, 205, 120, 95, 15, const Color(0xffe8f5e9));
      person(295, 243, 26, const Color(0xff1976d2));
      box(220, 300, 150, 20, 10, const Color(0xffc8e6c9));
      check(212, 320, white, green, 15);
      person(35, 401, 25, const Color(0xffbbdefb));
      person(75, 390, 27, const Color(0xff90caf9));
      person(125, 375, 30, const Color(0xff42a5f5));
      person(190, 357, 35, green);
      for (final foot in [
        (20.0, 448.0),
        (60.0, 445.0),
        (110.0, 443.0),
        (175.0, 440.0),
      ]) {
        box(foot.$1, foot.$2, 30, 5, 3, const Color(0xffb3d8b7));
      }
      box(260, 395, 108, 46, 17, white, shadow: true);
      check(283, 418, green, white, 12);
      box(301, 410, 55, 7, 4, const Color(0xffa5d6a7));
      box(301, 422, 37, 7, 4, const Color(0xffe4eaf1));
      dot(180, 100, 4, amber);
      dot(210, 125, 3, Colors.blue);
      dot(380, 130, 2.5, Colors.blue);
      dot(165, 210, 3, green);
      dot(350, 260, 3.5, amber);
    } else {
      glow(320, 85, 149, const Color(0x99ffcc80));
      dot(320, 85, 39, amber);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        line(
          320 + 52 * math.cos(a),
          85 + 52 * math.sin(a),
          320 + 64 * math.cos(a),
          85 + 64 * math.sin(a),
          amber,
          5,
        );
      }
      box(35, 80, 95, 60, 18, white, shadow: true);
      clock(62, 110, const Color(0xffef3535));
      box(86, 100, 33, 7, 4, const Color(0xfff7c6c3));
      box(86, 112, 23, 7, 4, const Color(0xfff7c6c3));
      box(75, 150, 243, 190, 22, white, shadow: true);
      box(75, 150, 243, 43, 22, const Color(0xffcfd8e3));
      box(75, 172, 243, 21, 0, const Color(0xffcfd8e3));
      box(125, 161, 143, 20, 10, white);
      box(95, 220, 48, 43, 10, const Color(0xffe3eaf3));
      box(250, 220, 48, 43, 10, const Color(0xffe3eaf3));
      box(159, 220, 75, 120, 14, const Color(0xff90a4be));
      dot(222.5, 282.5, 3.5, white);
      dot(96, 311, 16, white);
      text('?', 91, 299, 20, Colors.orange);
      dot(298, 298, 18, white);
      text('!', 295, 284, 22, Colors.red);
      canvas.drawOval(
        const Rect.fromLTWH(35, 430, 330, 40),
        p..color = const Color(0xffe9ded3),
      );
      const light = Color(0xffa9bbd3),
          medium = Color(0xff90a4be),
          dark = Color(0xff5a7398);
      for (final v in <(double, double, double, Color)>[
        (126, 328, 26, Color(0xff6e8cb2)),
        (163.5, 316.5, 25, light),
        (236.5, 319, 25, Color(0xffbbc8da)),
        (202, 333, 26, medium),
        (276, 336, 26, medium),
        (311, 357, 27, dark),
        (148.5, 362, 28, dark),
        (229.5, 360, 28, medium),
        (193.5, 369, 28, light),
        (269, 372, 28, Color(0xff8096b5)),
        (106.5, 381, 29, light),
        (180, 396, 30, light),
        (212.5, 403, 30, light),
        (254, 398, 30, Color(0xff8096b5)),
        (298, 391, 29, medium),
      ]) {
        person(v.$1, v.$2, v.$3, v.$4);
      }
    }
  }

  @override
  bool shouldRepaint(IntroArt oldDelegate) => oldDelegate.serving != serving;
}
