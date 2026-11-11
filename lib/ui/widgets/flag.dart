import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../modules/subscription/geo.dart';

class FlagIcon extends StatelessWidget {
  const FlagIcon(this.code, {super.key, this.size = 24});

  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cc = code;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.surfaceHi, shape: BoxShape.circle, border: Border.all(color: c.border)),
      child: Icon(Icons.public_rounded, size: size * 0.6, color: c.textTer),
    );
    if (cc == null || !Geo.countries.containsKey(cc)) return fallback;
    if (cc == 'EU') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 1)),
        child: ClipOval(child: CustomPaint(size: Size.square(size), painter: const _EuFlagPainter())),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 1)),
      child: ClipOval(
        child: CountryFlag.fromCountryCode(
          cc,
          theme: ImageTheme(width: size, height: size, shape: const Circle()),
        ),
      ),
    );
  }
}

class _EuFlagPainter extends CustomPainter {
  const _EuFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF003399));
    final star = r * 0.13;
    final orbit = r * 0.62;
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      _star(canvas, c + Offset(math.cos(a), math.sin(a)) * orbit, star);
    }
  }

  void _star(Canvas canvas, Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 4 * math.pi / 5;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFCC00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
