import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum TiloMood { hello, thinking, cheering }

/// The mascot: a rounded puzzle tile with a star for a hat (see the visual identity canvas).
class Tilo extends StatelessWidget {
  const Tilo({super.key, this.size = 120, this.mood = TiloMood.hello, this.body = AppColors.violet, this.face = Colors.white});

  final double size;
  final TiloMood mood;
  final Color body;
  final Color face;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tilo',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _TiloPainter(mood, body, face)),
  );
}

class _TiloPainter extends CustomPainter {
  _TiloPainter(this.mood, this.body, this.face);

  final TiloMood mood;
  final Color body;
  final Color face;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on the canvas's 120×120 grid, scaled to [size].
    canvas.scale(size.width / 120);
    final fill = Paint()..isAntiAlias = true;

    canvas.drawPath(_star(const Offset(88, 30), 15, 7), fill..color = AppColors.sun);
    canvas.drawRRect(RRect.fromLTRBR(14, 30, 94, 110, const Radius.circular(24)), fill..color = body);

    final stroke = Paint()
      ..color = face
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case TiloMood.hello || TiloMood.thinking:
        canvas.drawCircle(const Offset(40, 64), 10, fill..color = face);
        canvas.drawCircle(const Offset(68, 64), 10, fill..color = face);
        final look = mood == TiloMood.hello ? const Offset(2, 2) : const Offset(-4, -4);
        canvas.drawCircle(const Offset(40, 64) + look, 4.5, fill..color = AppColors.ink);
        canvas.drawCircle(const Offset(68, 64) + look, 4.5, fill..color = AppColors.ink);
        if (mood == TiloMood.hello) {
          canvas.drawPath(Path()..moveTo(42, 86)..quadraticBezierTo(54, 96, 66, 86), stroke);
        } else {
          canvas.drawLine(const Offset(46, 89), const Offset(62, 89), stroke);
        }
      case TiloMood.cheering:
        canvas.drawPath(Path()..moveTo(32, 66)..quadraticBezierTo(40, 57, 48, 66), stroke);
        canvas.drawPath(Path()..moveTo(60, 66)..quadraticBezierTo(68, 57, 76, 66), stroke);
        canvas.drawPath(Path()..moveTo(40, 80)..quadraticBezierTo(54, 100, 68, 80)..close(), fill..color = face);
        final spark = Paint()
          ..color = AppColors.coral
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(8, 22), const Offset(14, 28), spark);
        canvas.drawLine(const Offset(110, 60), const Offset(102, 62), spark);
        canvas.drawLine(const Offset(4, 70), const Offset(12, 70), spark);
    }
  }

  Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_TiloPainter old) => old.mood != mood || old.body != body || old.face != face;
}
