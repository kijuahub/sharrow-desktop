import 'package:flutter/material.dart';

/// The Sharrow arrowhead mark.
class SharrowMark extends StatelessWidget {
  const SharrowMark({super.key, this.size = 32, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(color ?? DefaultTextStyle.of(context).style.color ?? Colors.white),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0.80 * w, 0.5 * h)
      ..lineTo(0.22 * w, 0.18 * h)
      ..lineTo(0.37 * w, 0.5 * h)
      ..lineTo(0.22 * w, 0.82 * h)
      ..close();
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
