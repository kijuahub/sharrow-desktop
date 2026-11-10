import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import 'buttons.dart';

Future<Color?> showColorPicker(BuildContext context, Color initial) =>
    showDialog<Color>(context: context, builder: (_) => _ColorPickerDialog(initial: initial));

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: _hexOf(widget.initial));

  static String _hexOf(Color c) => (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _set(HSVColor v) {
    setState(() => _hsv = v);
    _hex.text = _hexOf(v.toColor());
  }

  void _fromHex(String text) {
    final t = text.replaceAll('#', '').trim();
    if (t.length != 6) return;
    final n = int.tryParse(t, radix: 16);
    if (n != null) setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | n)));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = _hsv.toColor();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Свой цвет', 'Custom color'), style: context.tt.titleLarge),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.45,
                child: LayoutBuilder(builder: (context, box) {
                  void pick(Offset p) => _set(_hsv
                      .withSaturation((p.dx / box.maxWidth).clamp(0.0, 1.0))
                      .withValue(1 - (p.dy / box.maxHeight).clamp(0.0, 1.0)));
                  return GestureDetector(
                    onPanDown: (d) => pick(d.localPosition),
                    onPanUpdate: (d) => pick(d.localPosition),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.md),
                      child: CustomPaint(painter: _SvPainter(_hsv), size: Size.infinite),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 22,
                child: LayoutBuilder(builder: (context, box) {
                  void pick(double x) => _set(_hsv.withHue((x / box.maxWidth).clamp(0.0, 1.0) * 360));
                  return GestureDetector(
                    onPanDown: (d) => pick(d.localPosition.dx),
                    onPanUpdate: (d) => pick(d.localPosition.dx),
                    child: CustomPaint(painter: _HuePainter(_hsv.hue), size: Size.infinite),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(children: [
                AnimatedContainer(
                  duration: Motion.fast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.borderStrong)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    onChanged: _fromHex,
                    maxLength: 7,
                    style: context.tt.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    decoration: const InputDecoration(prefixText: '#  ', counterText: '', hintText: '5B8CFF'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                AppButton.ghost(label: tr('Отмена', 'Cancel'), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                AppButton(label: tr('Применить', 'Apply'), onPressed: () => Navigator.pop(context, color)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(rect, Paint()..shader = LinearGradient(colors: [Colors.white, hue]).createShader(rect));
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xFF000000)]).createShader(rect),
    );
    final p = Offset(hsv.saturation * size.width, (1 - hsv.value) * size.height);
    canvas.drawCircle(p, 8, Paint()..color = hsv.toColor());
    canvas.drawCircle(
      p,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SvPainter old) => old.hsv != hsv;
}

class _HuePainter extends CustomPainter {
  _HuePainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bar = RRect.fromRectAndRadius(rect.deflate(3), Radius.circular(size.height / 2));
    canvas.drawRRect(
      bar,
      Paint()
        ..shader = LinearGradient(colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()]).createShader(rect),
    );
    final x = hue / 360 * size.width;
    final knob = Offset(x.clamp(size.height / 2, size.width - size.height / 2), size.height / 2);
    canvas.drawCircle(knob, size.height / 2, Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());
    canvas.drawCircle(
      knob,
      size.height / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
