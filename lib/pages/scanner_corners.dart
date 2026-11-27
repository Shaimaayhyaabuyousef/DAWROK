import 'package:flutter/material.dart';

class ScannerCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF28B9FF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;
    final left = size.width * .29;
    final right = size.width * .71;
    final top = size.height * .16;
    final bottom = size.height * .84;
    const length = 23.0;
    final path = Path()
      ..moveTo(left + length, top)
      ..lineTo(left + 8, top)
      ..quadraticBezierTo(left, top, left, top + 8)
      ..lineTo(left, top + length)
      ..moveTo(right - length, top)
      ..lineTo(right - 8, top)
      ..quadraticBezierTo(right, top, right, top + 8)
      ..lineTo(right, top + length)
      ..moveTo(left + length, bottom)
      ..lineTo(left + 8, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - 8)
      ..lineTo(left, bottom - length)
      ..moveTo(right - length, bottom)
      ..lineTo(right - 8, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - 8)
      ..lineTo(right, bottom - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
