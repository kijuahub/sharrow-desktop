import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../widgets/mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _orbit.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final intro = CurvedAnimation(parent: _intro, curve: Motion.emphasized);
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(180),
                    painter: _OrbitPainter(_orbit, intro, c.dot, c.accent),
                  ),
                  ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(intro),
                    child: FadeTransition(opacity: intro, child: SharrowMark(size: 44, color: c.text)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: CurvedAnimation(parent: _intro, curve: const Interval(0.4, 1, curve: Curves.easeOut)),
              child: Text('Sharrow', style: context.tt.headlineSmall?.copyWith(letterSpacing: -0.2)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dotted orbits with a travelling highlight — a minimal nod to the globe.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t, this.intro, this.dot, this.accent) : super(repaint: Listenable.merge([t, intro]));

  final Animation<double> t;
  final Animation<double> intro;
  final Color dot;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width / 2;
    final p = Paint()..isAntiAlias = true;
    const rings = [(0.52, 28, 1.0), (0.74, 40, -0.7), (0.96, 54, 0.45)];
    for (var r = 0; r < rings.length; r++) {
      final (scale, count, speed) = rings[r];
      final radius = base * scale * (0.85 + 0.15 * intro.value);
      final head = (t.value * speed * 2 * math.pi) % (2 * math.pi);
      for (var i = 0; i < count; i++) {
        final a = i / count * 2 * math.pi;
        var d = (a - head) % (2 * math.pi);
        if (d < 0) d += 2 * math.pi;
        final glow = math.pow(1 - d / (2 * math.pi), 6).toDouble();
        final alpha = (0.12 + 0.88 * glow) * intro.value * (1 - r * 0.18);
        p.color = Color.lerp(dot, accent, glow * 0.8)!.withValues(alpha: alpha.clamp(0.0, 1.0));
        canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * radius, 1.3 + glow * 1.4, p);
      }
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.dot != dot || old.accent != accent;
}
