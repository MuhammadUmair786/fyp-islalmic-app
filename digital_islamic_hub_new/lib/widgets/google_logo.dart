import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint red = Paint()..color = const Color(0xFFEA4335);
    final Paint blue = Paint()..color = const Color(0xFF4285F4);
    final Paint green = Paint()..color = const Color(0xFF34A853);
    final Paint yellow = Paint()..color = const Color(0xFFFBBC05);

    final Path bluePath = Path()
      ..moveTo(w * 0.95, h * 0.5)
      ..cubicTo(w * 0.95, h * 0.45, w * 0.94, h * 0.4, w * 0.93, h * 0.35)
      ..lineTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.5, h * 0.53)
      ..lineTo(w * 0.76, h * 0.53)
      ..cubicTo(w * 0.74, h * 0.63, w * 0.68, h * 0.72, w * 0.58, h * 0.78)
      ..lineTo(w * 0.58, h * 0.96)
      ..lineTo(w * 0.73, h * 0.96)
      ..cubicTo(w * 0.88, h * 0.82, w * 0.95, h * 0.68, w * 0.95, h * 0.5);

    final Path greenPath = Path()
      ..moveTo(w * 0.5, h * 0.98)
      ..cubicTo(w * 0.67, h * 0.98, w * 0.82, h * 0.92, w * 0.92, h * 0.83)
      ..lineTo(w * 0.77, h * 0.71)
      ..cubicTo(w * 0.71, h * 0.75, w * 0.62, h * 0.78, w * 0.5, h * 0.78)
      ..cubicTo(w * 0.36, h * 0.78, w * 0.24, h * 0.68, w * 0.19, h * 0.56)
      ..lineTo(w * 0.04, h * 0.67)
      ..cubicTo(w * 0.14, h * 0.86, w * 0.31, h * 0.98, w * 0.5, h * 0.98);

    final Path yellowPath = Path()
      ..moveTo(w * 0.19, h * 0.56)
      ..cubicTo(w * 0.18, h * 0.52, w * 0.17, h * 0.48, w * 0.17, h * 0.44)
      ..cubicTo(w * 0.17, h * 0.40, w * 0.18, h * 0.36, w * 0.19, h * 0.32)
      ..lineTo(w * 0.04, h * 0.21)
      ..cubicTo(w * 0.01, h * 0.28, 0, h * 0.36, 0, h * 0.44)
      ..cubicTo(0, h * 0.52, w * 0.01, h * 0.60, w * 0.04, h * 0.67)
      ..lineTo(w * 0.19, h * 0.56);

    final Path redPath = Path()
      ..moveTo(w * 0.5, h * 0.18)
      ..cubicTo(w * 0.61, h * 0.18, w * 0.70, h * 0.22, w * 0.78, h * 0.29)
      ..lineTo(w * 0.91, h * 0.16)
      ..cubicTo(w * 0.81, h * 0.06, w * 0.67, 0, w * 0.5, 0)
      ..cubicTo(w * 0.31, 0, w * 0.14, h * 0.12, w * 0.04, h * 0.28)
      ..lineTo(w * 0.19, h * 0.4)
      ..cubicTo(w * 0.24, h * 0.28, w * 0.36, h * 0.18, w * 0.5, h * 0.18);

    canvas.drawPath(bluePath, blue);
    canvas.drawPath(greenPath, green);
    canvas.drawPath(yellowPath, yellow);
    canvas.drawPath(redPath, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
