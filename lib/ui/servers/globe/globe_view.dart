import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../widgets/buttons.dart';
import '../../widgets/flag.dart';
import 'globe_data.dart';

@immutable
class GlobeMarker {
  const GlobeMarker({required this.id, required this.lat, required this.lon, required this.label, this.count = 1});

  final String id;
  final double lat;
  final double lon;
  final String label;
  final int count;
}

/// Unit vectors of land dots, decoded once and shared by all globe instances.
final Float32List _landXyz = () {
  final bytes = base64Decode(kGlobeLandPoints);
  final data = ByteData.sublistView(bytes);
  final n = bytes.length ~/ 4;
  final out = Float32List(n * 3);
  for (var i = 0; i < n; i++) {
    final lat = data.getInt16(i * 4, Endian.little) / 10 * math.pi / 180;
    final lon = data.getInt16(i * 4 + 2, Endian.little) / 10 * math.pi / 180;
    final cl = math.cos(lat);
    out[i * 3] = cl * math.sin(lon);
    out[i * 3 + 1] = math.sin(lat);
    out[i * 3 + 2] = cl * math.cos(lon);
  }
  return out;
}();

class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.markers,
    required this.onSelect,
    this.selectedId,
    this.connected = false,
    this.connecting = false,
    this.animate = true,
    this.rotate = true,
    this.speed = 1.0,
    this.lowFps = false,
    this.active = true,
    this.showFlags = true,
    this.font = 'Inter',
    this.light = false,
  });

  final List<GlobeMarker> markers;
  final ValueChanged<String> onSelect;
  final String? selectedId;
  final bool connected;
  final bool connecting;
  final bool animate;
  final bool rotate;
  final double speed;
  final bool lowFps;

  /// False while the window is hidden/minimized — the ticker is stopped.
  final bool active;
  final bool showFlags;
  final String font;
  final bool light;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _Repaint extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _Hit {
  const _Hit(this.id, this.pos);

  final String id;
  final Offset pos;
}

/// Projects a marker onto the screen; returns null when it is on the far side.
(Offset, double)? _project(GlobeMarker m, double sinR, double cosR, double sinT, double cosT, Offset center, double r, {double horizon = 0.05}) {
  final lat = m.lat * math.pi / 180, lon = m.lon * math.pi / 180;
  final cl = math.cos(lat);
  final x = cl * math.sin(lon), y = math.sin(lat), z = cl * math.cos(lon);
  final x1 = x * cosR + z * sinR;
  final z1 = -x * sinR + z * cosR;
  final z2 = y * sinT + z1 * cosT;
  if (z2 <= horizon) return null;
  final y2 = y * cosT - z1 * sinT;
  return (Offset(center.dx + x1 * r, center.dy - y2 * r), z2);
}

class _GlobeViewState extends State<GlobeView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _repaint = _Repaint();

  static const minZoom = 1.0;
  static const maxZoom = 2.6;

  double rot = 0.6;
  double tilt = 0.38;
  double time = 0;
  double zoom = 1;
  double? _targetZoom;
  double _zoomAtStart = 1;
  double baseRadius = 100;

  double get radius => baseRadius * zoom;
  double? _targetRot;
  double? _targetTilt;
  double _velocity = 0;
  bool _dragging = false;
  DateTime _resumeAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _last = Duration.zero;
  double _frameAcc = 0;
  String? hoverId;
  List<_Hit> hits = const [];
  final Map<String, TextPainter> _labels = {};

  @override
  void initState() {
    super.initState();
    final sel = widget.markers.where((m) => m.id == widget.selectedId).firstOrNull;
    if (sel != null) {
      rot = -sel.lon * math.pi / 180;
      tilt = (sel.lat * math.pi / 180).clamp(-0.35, 0.75);
    }
    _syncTicker();
  }

  bool get _shouldTick => widget.animate && widget.active;

  void _syncTicker() {
    if (_shouldTick && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_shouldTick && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(GlobeView old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) _focusSelected();
    if (old.selectedId != widget.selectedId || old.markers.length != widget.markers.length) _labels.clear();
    _syncTicker();
    _repaint.tick();
  }

  void _focusSelected() {
    final m = widget.markers.where((m) => m.id == widget.selectedId).firstOrNull;
    if (m == null) return;
    final tr = -m.lon * math.pi / 180;
    final tt = (m.lat * math.pi / 180).clamp(-0.35, 0.75);
    _velocity = 0;
    _resumeAt = DateTime.now().add(const Duration(seconds: 6));
    if (_shouldTick) {
      _targetRot = tr;
      _targetTilt = tt;
    } else {
      rot = tr;
      tilt = tt;
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    time += dt;

    if (_targetZoom != null) {
      zoom += (_targetZoom! - zoom) * math.min(1.0, dt * 10);
      if ((_targetZoom! - zoom).abs() < 0.002) {
        zoom = _targetZoom!;
        _targetZoom = null;
      }
    }

    if (_targetRot != null) {
      final diff = ((_targetRot! - rot + math.pi) % (2 * math.pi)) - math.pi;
      final k = math.min(1.0, dt * 3.2);
      rot += diff * k;
      tilt += (_targetTilt! - tilt) * k;
      if (diff.abs() < 0.0015) _targetRot = null;
    } else if (!_dragging) {
      if (_velocity.abs() > 0.001) {
        rot += _velocity * dt;
        _velocity *= math.pow(0.04, dt).toDouble();
      } else if (widget.rotate && DateTime.now().isAfter(_resumeAt)) {
        rot += dt * 0.065 * widget.speed;
      }
    }

    if (widget.lowFps) {
      _frameAcc += dt;
      if (_frameAcc < 1 / 30) return;
      _frameAcc = 0;
    }
    _repaint.tick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    for (final l in _labels.values) {
      l.dispose();
    }
    super.dispose();
  }

  String? _hitTest(Offset p) {
    String? best;
    var bestD = 18.0 * 18.0;
    for (final h in hits) {
      final d = (h.pos - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = h.id;
      }
    }
    return best;
  }

  void zoomTo(double z) {
    final t = z.clamp(minZoom, maxZoom);
    if (_ticker.isActive) {
      _targetZoom = t;
    } else {
      zoom = t;
      _repaint.tick();
    }
    setState(() {});
  }

  TextPainter label(String text, TextStyle style) {
    return _labels.putIfAbsent('$text|${style.color?.toARGB32()}|${style.fontFamily}', () {
      return TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(builder: (context, box) {
      baseRadius = math.min(box.maxWidth, box.maxHeight) / 2 * 0.9;
      final globe = MouseRegion(
        cursor: hoverId != null ? SystemMouseCursors.click : (_dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab),
        onHover: (e) {
          final id = _hitTest(e.localPosition);
          if (id != hoverId) {
            setState(() => hoverId = id);
            _repaint.tick();
          }
        },
        onExit: (_) {
          if (hoverId != null) setState(() => hoverId = null);
        },
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) zoomTo((_targetZoom ?? zoom) * math.exp(-e.scrollDelta.dy / 500));
          },
          child: GestureDetector(
            onScaleStart: (d) {
              _dragging = true;
              _targetRot = null;
              _targetZoom = null;
              _velocity = 0;
              _zoomAtStart = zoom;
            },
            onScaleUpdate: (d) {
              final r = radius;
              rot += d.focalPointDelta.dx / r;
              tilt = (tilt + d.focalPointDelta.dy / r).clamp(-0.6, 0.95);
              if (d.pointerCount >= 2 || d.scale != 1) zoom = (_zoomAtStart * d.scale).clamp(minZoom, maxZoom);
              _repaint.tick();
            },
            onScaleEnd: (d) {
              _dragging = false;
              _velocity = (d.velocity.pixelsPerSecond.dx / radius).clamp(-4.0, 4.0);
              _resumeAt = DateTime.now().add(const Duration(seconds: 3));
              setState(() {});
            },
            onTapUp: (d) {
              final id = _hitTest(d.localPosition);
              if (id != null) widget.onSelect(id);
            },
            onDoubleTap: () => zoomTo(zoom > 1.4 ? 1 : 2),
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _GlobePainter(this, c)),
                  if (widget.showFlags)
                    Flow(
                      delegate: _FlagFlow(this),
                      children: [
                        for (final m in widget.markers) RepaintBoundary(child: FlagIcon(m.id, size: _flagSize)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            globe,
            Positioned(right: 4, top: 0, bottom: 0, child: Center(child: _ZoomControls(state: this))),
          ],
        ),
      );
    });
  }
}

const _flagSize = 20.0;

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.state});

  final _GlobeViewState state;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final z = state._targetZoom ?? state.zoom;
    final ink = c.isDark ? const Color(0xFFF4F5F7) : const Color(0xFF16181D);
    final fill = c.glassStyle ? (c.isDark ? const Color(0xE6101218) : const Color(0xF5FFFFFF)) : c.surfaceHi;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000)),
      ),
      padding: const EdgeInsets.all(3),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconBtn(icon: Icons.add_rounded, size: 30, iconSize: 16, color: ink, tooltip: tr('Приблизить', 'Zoom in'), onTap: z < _GlobeViewState.maxZoom ? () => state.zoomTo(z * 1.35) : null),
        IconBtn(icon: Icons.remove_rounded, size: 30, iconSize: 16, color: ink, tooltip: tr('Отдалить', 'Zoom out'), onTap: z > _GlobeViewState.minZoom ? () => state.zoomTo(z / 1.35) : null),
      ]),
    );
  }
}

/// Positions pre-rendered flag layers over the markers every frame without relayout.
class _FlagFlow extends FlowDelegate {
  _FlagFlow(this.s) : super(repaint: s._repaint);

  final _GlobeViewState s;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) => BoxConstraints.tight(const Size.square(_flagSize));

  @override
  void paintChildren(FlowPaintingContext context) {
    final size = context.size;
    final center = size.center(Offset.zero);
    final sinR = math.sin(s.rot), cosR = math.cos(s.rot);
    final sinT = math.sin(s.tilt), cosT = math.cos(s.tilt);
    final r = s.radius;
    final markers = s.widget.markers;
    final scale = (0.85 + 0.25 * s.zoom).clamp(1.0, 1.5);
    // Selected/hovered flags last so they stay on top.
    final order = [for (var i = 0; i < markers.length; i++) i]
      ..sort((a, b) => _rank(markers[a]).compareTo(_rank(markers[b])));
    for (final i in order) {
      if (i >= context.childCount) continue;
      final m = markers[i];
      final p = _project(m, sinR, cosR, sinT, cosT, center, r);
      if (p == null) continue;
      final (pos, z) = p;
      final fade = ((z - 0.05) / 0.25).clamp(0.0, 1.0);
      if (fade <= 0.01) continue;
      final k = scale * (m.id == s.widget.selectedId ? 1.2 : (m.id == s.hoverId ? 1.12 : 1.0));
      final half = _flagSize * k / 2;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(pos.dx - half, pos.dy - half, 0)..scaleByDouble(k, k, 1, 1),
        opacity: fade,
      );
    }
  }

  int _rank(GlobeMarker m) => m.id == s.widget.selectedId ? 2 : (m.id == s.hoverId ? 1 : 0);

  @override
  bool shouldRepaint(_FlagFlow old) => old.s != s;
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.s, this.c) : super(repaint: s._repaint);

  final _GlobeViewState s;
  final SColors c;

  static const _buckets = 6;
  static final List<Float32List> _buffers = List.generate(_buckets, (_) => Float32List(_landXyz.length ~/ 3 * 2));
  static final _counts = Int32List(_buckets);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = s.radius;
    final center = Offset(cx, cy);
    final sinR = math.sin(s.rot), cosR = math.cos(s.rot);
    final sinT = math.sin(s.tilt), cosT = math.cos(s.tilt);

    canvas.drawCircle(center, r, Paint()..color = c.isDark ? const Color(0xFF101114) : const Color(0xFFFFFFFF));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.border,
    );

    // Land dots, bucketed by depth so each bucket is a single draw call.
    for (var b = 0; b < _buckets; b++) {
      _counts[b] = 0;
    }
    final xyz = _landXyz;
    final n = xyz.length ~/ 3;
    for (var i = 0; i < n; i++) {
      final x = xyz[i * 3], y = xyz[i * 3 + 1], z = xyz[i * 3 + 2];
      final x1 = x * cosR + z * sinR;
      final z1 = -x * sinR + z * cosR;
      final z2 = y * sinT + z1 * cosT;
      if (z2 <= 0.04) continue;
      final y2 = y * cosT - z1 * sinT;
      var b = (z2 * _buckets).floor();
      if (b >= _buckets) b = _buckets - 1;
      final buf = _buffers[b];
      final k = _counts[b] * 2;
      buf[k] = cx + x1 * r;
      buf[k + 1] = cy - y2 * r;
      _counts[b]++;
    }
    final dot = (r * 0.0105).clamp(1.1, 3.6);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (var b = 0; b < _buckets; b++) {
      final cnt = _counts[b];
      if (cnt == 0) continue;
      final depth = (b + 0.5) / _buckets;
      paint
        ..color = c.dot.withValues(alpha: (0.1 + 0.75 * math.pow(depth, 0.9)).toDouble())
        ..strokeWidth = dot * (0.7 + 0.3 * depth);
      canvas.drawRawPoints(ui.PointMode.points, Float32List.sublistView(_buffers[b], 0, cnt * 2), paint);
    }
    if (s.widget.light) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
      canvas.drawRect(
        Rect.fromCircle(center: center, radius: r),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx - r, cy - r * 0.8),
            Offset(cx + r * 0.7, cy + r),
            [Colors.white.withValues(alpha: 0.30), const Color(0x00FFFFFF), Colors.black.withValues(alpha: 0.55)],
            const [0, 0.42, 1],
          ),
      );
      canvas.restore();
    }

    // Server markers.
    final hits = <_Hit>[];
    final selectedColor = c.accent;
    _Hit? selectedHit;
    GlobeMarkerProjection? selectedProj;
    final flags = s.widget.showFlags;
    final flagScale = (0.85 + 0.25 * s.zoom).clamp(1.0, 1.5);
    final flagR = _flagSize / 2 * flagScale;
    for (final m in s.widget.markers) {
      final proj = _project(m, sinR, cosR, sinT, cosT, center, r);
      if (proj == null) continue;
      final (p, z2) = proj;
      final hit = _Hit(m.id, p);
      hits.add(hit);
      final fade = ((z2 - 0.05) / 0.25).clamp(0.0, 1.0);
      final isSel = m.id == s.widget.selectedId;
      final isHover = m.id == s.hoverId;
      if (isSel) {
        selectedHit = hit;
        selectedProj = GlobeMarkerProjection(m, fade);
        continue;
      }
      if (flags) {
        final rr = flagR * (isHover ? 1.12 : 1.0);
        canvas.drawCircle(p, rr + 2.5, Paint()..color = c.bg.withValues(alpha: 0.9 * fade));
        canvas.drawCircle(
          p,
          rr + 2.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = (isHover ? c.accent : c.borderStrong).withValues(alpha: fade),
        );
      } else {
        canvas.drawCircle(p, isHover ? 7 : 5.5, Paint()..color = c.accent.withValues(alpha: 0.16 * fade));
        canvas.drawCircle(p, isHover ? 3.6 : 2.8, Paint()..color = c.accent.withValues(alpha: 0.95 * fade));
      }
      if (isHover) _drawLabel(canvas, p, m.label, fade, c.text, offset: flags ? flagR + 8 : 12);
    }

    if (selectedHit != null && selectedProj != null) {
      final p = selectedHit.pos;
      final fade = selectedProj.fade;
      final period = s.widget.connecting ? 0.9 : 2.2;
      final base = flags ? flagR * 1.2 + 3 : 5.0;
      for (var k = 0; k < 2; k++) {
        final phase = ((s.time / period) + k * 0.5) % 1.0;
        canvas.drawCircle(
          p,
          base + 20 * phase,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = selectedColor.withValues(alpha: (1 - phase) * 0.55 * fade),
        );
      }
      if (flags) {
        canvas.drawCircle(p, base, Paint()..color = selectedColor.withValues(alpha: fade));
      } else {
        canvas.drawCircle(p, 7.5, Paint()..color = selectedColor.withValues(alpha: 0.22 * fade));
        canvas.drawCircle(p, 4.6, Paint()..color = selectedColor.withValues(alpha: fade));
        canvas.drawCircle(p, 1.8, Paint()..color = Colors.white.withValues(alpha: fade));
      }
      _drawLabel(canvas, p, selectedProj.marker.label, fade, c.text, emphasized: true, offset: flags ? base + 6 : 12);
    }
    s.hits = hits;
  }

  void _drawLabel(Canvas canvas, Offset p, String text, double fade, Color color, {bool emphasized = false, double offset = 12}) {
    if (fade < 0.2) return;
    final ink = c.glassStyle ? (c.isDark ? const Color(0xFFF4F5F7) : const Color(0xFF16181D)) : color;
    final chip = c.glassStyle ? (c.isDark ? const Color(0xF2101218) : const Color(0xF5FFFFFF)) : c.surfaceHi.withValues(alpha: 0.94);
    final tp = s.label(text, TextStyle(fontFamily: s.widget.font, fontSize: 11.5, fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500, color: ink));
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(p.dx + offset, p.dy - tp.height / 2 - 5, tp.width + 16, tp.height + 10),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = chip.withValues(alpha: chip.a * fade));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.borderStrong.withValues(alpha: c.borderStrong.a * fade),
    );
    if (fade >= 0.99) {
      tp.paint(canvas, Offset(rect.left + 8, rect.top + 5));
      return;
    }
    canvas.saveLayer(rect.outerRect, Paint()..color = Colors.white.withValues(alpha: fade));
    tp.paint(canvas, Offset(rect.left + 8, rect.top + 5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobePainter old) => old.c != c || old.s != s;
}

class GlobeMarkerProjection {
  GlobeMarkerProjection(this.marker, this.fade);

  final GlobeMarker marker;
  final double fade;
}
