import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/server.dart';
import '../../data/models/settings.dart';
import '../../modules/subscription/geo.dart';
import '../../modules/xray/config_builder.dart';
import '../../modules/xray/stats_service.dart';
import '../../modules/xray/vpn_core.dart';
import '../../state/connection_controller.dart';
import '../../state/scope.dart';
import '../widgets/badges.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/flag.dart';
import '../widgets/pressable.dart';
import '../widgets/segmented.dart';
import '../widgets/surface.dart';
import 'globe/globe_view.dart';

class ConnectPanel extends StatelessWidget {
  const ConnectPanel({super.key, this.compact = false, this.island = false, this.fade = false, this.fadeEnd = false, this.onServerCardTap});

  final bool compact;

  /// Planet and the connect controls only, centered. The server card lives in the island.
  final bool island;

  /// Soft edge where this panel meets the server list.
  final bool fade;

  /// The server list sits on the right.
  final bool fadeEnd;
  final VoidCallback? onServerCardTap;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.conn, app.subs, app.settings]),
      builder: (context, _) {
        final conn = app.conn;
        final s = app.settings;
        final server = conn.isConnected ? (conn.activeServer ?? app.subs.selectedServer) : app.subs.selectedServer;
        final scene = s.get(K.homeScene);
        final wallpaper = scene == 'space' || scene == 'image';
        final style = s.get(K.connectStyle);
        final lift = scene == 'planet' && s.get(K.planetBehindButton);
        final floating = style != 'compact';
        final button = ConnectButton(size: style == 'large' || lift ? 124 : 84, ring: style == 'large');
        final light = s.get(K.globeLight);
        final globeOpacity = s.get(K.globeOpacity).clamp(0.2, 1.0);
        final globe = Opacity(opacity: globeOpacity, child: _Globe(server: server, light: light));
        final withSpace = scene == 'planet' && s.get(K.globeSpace);
        final visual = switch (scene) {
          'space' => const _Space(),
          'image' => _HomeImage(path: s.get(K.homeImage)),
          'empty' => const SizedBox.shrink(),
          _ => globe,
        };
        final backdrop = wallpaper || withSpace;
        final stage = wallpaper
            ? Center(child: floating ? button : const SizedBox.shrink())
            : _GlobeStack(globe: visual, button: floating ? button : null, lift: lift);

        final controls = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Banner(),
              if (style == 'compact') ...[
                Align(alignment: island ? Alignment.center : Alignment.centerRight, child: const _CompactConnect()),
                const SizedBox(height: 8),
              ],
              _ServerCard(server: server, onTap: onServerCardTap),
              const SizedBox(height: 12),
              const _ModeSwitch(),
            ],
          ),
        );

        return LayoutBuilder(builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final short = !bounded || constraints.maxHeight < 520;
          final pad = short ? 12.0 : (compact ? 16.0 : 24.0);
          final stageHeight = short ? (constraints.maxWidth * 0.62).clamp(180.0, 320.0) : 0.0;
          final column = Padding(
            padding: EdgeInsets.fromLTRB(pad, short ? 8 : 16, pad, pad),
            child: Column(
              children: [
                const _TopRow(),
                Expanded(child: stage),
                SizedBox(height: short ? 8 : 18),
                controls,
              ],
            ),
          );
          Widget panel = column;
          if (backdrop) {
            final c = context.c;
            panel = Stack(fit: StackFit.expand, children: [
              Positioned.fill(child: scene == 'image' ? visual : const _Space()),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0x00000000), Color(0x99000000)],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: column),
              if (fade)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: fadeEnd ? Alignment.centerRight : Alignment.centerLeft,
                          end: fadeEnd ? Alignment.centerLeft : Alignment.centerRight,
                          colors: [c.bg, c.bg.withValues(alpha: 0)],
                          stops: const [0, 0.18],
                        ),
                      ),
                    ),
                  ),
                ),
            ]);
          }
          if (!bounded) return SizedBox(width: constraints.maxWidth, height: stageHeight + 280, child: panel);
          if (short) {
            return SingleChildScrollView(child: SizedBox(width: constraints.maxWidth, height: stageHeight + 280, child: panel));
          }
          return panel;
        });
      },
    );
  }
}

class _GlobeStack extends StatelessWidget {
  const _GlobeStack({required this.globe, this.button, this.lift = false});

  final Widget globe;
  final Widget? button;
  final bool lift;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(box.maxWidth, box.maxHeight);
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: globe),
          if (button != null)
            Positioned(
              bottom: lift ? math.max(12, box.maxHeight * 0.28) : math.max(0, (box.maxHeight - size) / 2 + size * 0.02),
              child: button!,
            ),
        ],
      );
    });
  }
}

class _Globe extends StatelessWidget {
  const _Globe({required this.server, this.light = false});

  final ServerProfile? server;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final sub = app.subs.selectedSub;
    final ru = L10n.isRu;
    final groups = <String, int>{};
    for (final srv in sub?.servers ?? const <ServerProfile>[]) {
      final cc = srv.countryCode;
      if (cc == null || cc == 'EU' || !Geo.countries.containsKey(cc)) continue;
      groups[cc] = (groups[cc] ?? 0) + 1;
    }
    final markers = [
      for (final e in groups.entries)
        GlobeMarker(
          id: e.key,
          lat: Geo.countries[e.key]!.$1,
          lon: Geo.countries[e.key]!.$2,
          label: '${Geo.countryName(e.key, ru: ru)}${e.value > 1 ? ' · ${e.value}' : ''}',
          count: e.value,
        ),
    ];
    return ValueListenableBuilder<bool>(
      valueListenable: app.visible,
      builder: (context, visible, _) => GlobeView(
        markers: markers,
        selectedId: server?.countryCode == 'EU' ? null : server?.countryCode,
        connected: app.conn.isConnected,
        connecting: app.conn.status == ConnStatus.connecting,
        animate: s.get(K.animations),
        rotate: s.get(K.globeRotation),
        speed: s.get(K.globeSpeed),
        lowFps: s.get(K.lowFps),
        light: light,
        active: visible,
        showFlags: s.get(K.showFlags),
        font: Theme.of(context).textTheme.bodyMedium?.fontFamily ?? 'Inter',
        onSelect: (cc) {
          final list = (sub?.servers ?? const <ServerProfile>[]).where((x) => x.countryCode == cc).toList();
          if (list.isEmpty || list.any((x) => x.id == server?.id)) return;
          list.sort((a, b) => ((a.ping ?? 0) > 0 ? a.ping! : 99999).compareTo((b.ping ?? 0) > 0 ? b.ping! : 99999));
          app.selectServer(list.first.id);
        },
      ),
    );
  }
}

class _HomeImage extends StatelessWidget {
  const _HomeImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (path.isEmpty || !file.existsSync()) return const SizedBox.expand();
    return Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.expand());
  }
}

class _Space extends StatefulWidget {
  const _Space();

  @override
  State<_Space> createState() => _SpaceState();
}

class _SpaceState extends State<_Space> with SingleTickerProviderStateMixin {
  /// x, y, radius, alpha, phase, flare, depth (0 far, 1 near).
  static final _stars = List.generate(520, (i) {
    final r = math.Random(i * 17 + 3);
    final near = r.nextDouble() < 0.22;
    final flare = r.nextDouble() < (near ? 0.08 : 0.03);
    return (
      r.nextDouble(),
      r.nextDouble(),
      flare ? 1.5 + r.nextDouble() : (near ? 0.7 + r.nextDouble() * 0.8 : 0.25 + r.nextDouble() * 0.55),
      0.28 + r.nextDouble() * 0.72,
      r.nextDouble() * math.pi * 2,
      flare,
      near ? 1.0 : 0.0,
    );
  });
  static final _lines = () {
    final out = <(int, int)>[];
    for (var i = 0; i < _stars.length && out.length < 36; i++) {
      if (_stars[i].$7 > 0) continue;
      for (var j = i + 1; j < _stars.length && out.length < 36; j++) {
        final dx = _stars[i].$1 - _stars[j].$1;
        final dy = _stars[i].$2 - _stars[j].$2;
        final d = dx * dx + dy * dy;
        if (d > 0.003 && d < 0.009) out.add((i, j));
      }
    }
    return out;
  }();

  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 36));

  @override
  void initState() {
    super.initState();
    final s = context.app.settings;
    if (s.get(K.animations) && !s.get(K.lowFps)) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (_, _) => CustomPaint(painter: _StarPainter(_stars, _lines, _drift.value), child: const SizedBox.expand()),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.lines, this.shift);

  final List<(double, double, double, double, double, bool, double)> stars;
  final List<(int, int)> lines;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF05060A));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x22142644), Color(0x0005060A)],
        ).createShader(Rect.fromCircle(center: Offset(size.width * 0.72, size.height * 0.18), radius: size.shortestSide * 0.55)),
    );
    Offset at(int i) {
      final star = stars[i];
      final speed = star.$7 > 0 ? 0.045 : 0.018;
      final x = (star.$1 + shift * speed * 0.35) % 1.0;
      final y = (star.$2 + shift * speed) % 1.0;
      return Offset(x * size.width, y * size.height);
    }

    final line = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 0.6;
    for (final (a, b) in lines) {
      canvas.drawLine(at(a), at(b), line);
    }
    for (var i = 0; i < stars.length; i++) {
      final (_, _, radius, alpha, phase, flare, depth) = stars[i];
      final tw = 0.55 + 0.45 * math.sin(shift * math.pi * 2 * (depth > 0 ? 3 : 1) + phase);
      final o = at(i);
      final color = Colors.white.withValues(alpha: (alpha * tw).clamp(0.12, 1));
      if (flare) {
        canvas.drawCircle(o, radius * 4.2, Paint()..color = Colors.white.withValues(alpha: 0.12 * tw));
        final spike = Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * tw)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;
        final arm = radius * (depth > 0 ? 11 : 8);
        canvas.drawLine(o.translate(-arm, 0), o.translate(arm, 0), spike);
        canvas.drawLine(o.translate(0, -arm), o.translate(0, arm), spike);
      }
      canvas.drawCircle(o, radius, Paint()..color = color);
    }
    final meteor = (shift * 2) % 1;
    if (meteor < 0.12) {
      final t = meteor / 0.12;
      final start = Offset(size.width * (0.62 - t * 0.28), size.height * (0.08 + t * 0.22));
      final end = start.translate(-70, 36);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0.9 * (1 - t)), const Color(0x00FFFFFF)]).createShader(Rect.fromPoints(start, end)),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.shift != shift;
}

class _TopRow extends StatelessWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(listenable: Listenable.merge([app.conn, app.settings]), builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final app = context.app;
    final conn = app.conn;
    final c = context.c;
    final (color, text) = switch (conn.status) {
      ConnStatus.connected => (c.accent, tr('Защищено', 'Protected')),
      ConnStatus.connecting => (c.warning, tr('Подключение…', 'Connecting…')),
      ConnStatus.disconnecting => (c.warning, tr('Отключение…', 'Disconnecting…')),
      ConnStatus.disconnected => (c.textTer, tr('Не защищено', 'Not protected')),
    };
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          StatusDot(color: color, glow: conn.isConnected),
          const SizedBox(width: 8),
          Text(text, style: context.tt.labelLarge?.copyWith(color: c.textSec)),
          if (conn.isConnected && conn.activeMode != null) ...[
            const SizedBox(width: 8),
            Tag(conn.activeMode == TunnelMode.tun ? 'TUN' : 'PROXY', color: c.accent),
          ],
          const Spacer(),
          if (conn.isConnected && app.settings.get(K.showSpeed)) _Speed(stats: conn.stats, delay: conn.realDelay),
        ],
      ),
    );
  }
}

class _Speed extends StatelessWidget {
  const _Speed({required this.stats, required this.delay});

  final StatsService stats;
  final int? delay;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = context.tt.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return ValueListenableBuilder<TrafficSample?>(
      valueListenable: stats,
      builder: (context, v, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (delay != null && delay! > 0) ...[
            Icon(Icons.bolt_rounded, size: 14, color: c.textTer),
            const SizedBox(width: 3),
            Text('$delay ms', style: style),
            const SizedBox(width: 14),
          ],
          if (v != null) ...[
            Icon(Icons.arrow_upward_rounded, size: 13, color: c.textTer),
            const SizedBox(width: 3),
            SizedBox(width: 74, child: Text(Fmt.speed(v.up), style: style)),
            Icon(Icons.arrow_downward_rounded, size: 13, color: c.textTer),
            const SizedBox(width: 3),
            SizedBox(width: 74, child: Text(Fmt.speed(v.down), style: style)),
          ],
        ],
      ),
    );
  }
}

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key, this.size = 84, this.ring = false});

  final double size;
  final bool ring;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with TickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _hover = false;
  bool _down = false;

  @override
  void dispose() {
    _spin.dispose();
    _ring.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    final app = context.app;
    final conn = app.conn;
    if (conn.isConnected && app.settings.get(K.confirmDisconnect)) {
      final ok = await showConfirm(context, title: tr('Отключить VPN?', 'Disconnect VPN?'), message: tr('Трафик пойдёт напрямую.', 'Traffic will go directly.'), confirm: tr('Отключить', 'Disconnect'));
      if (!ok) return;
    }
    await conn.toggle();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: context.app.conn, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.c;
    final conn = context.app.conn;
    final busy = conn.isBusy;
    final connected = conn.isConnected;
    final size = widget.size;
    final fg = connected ? c.onAccent : (busy ? c.warning : c.text);
    if (busy && !_spin.isAnimating) _spin.repeat();
    if (!busy && _spin.isAnimating) _spin.stop();
    final spinRing = widget.ring && connected && !busy;
    if (spinRing && !_ring.isAnimating) _ring.repeat();
    if (!spinRing && _ring.isAnimating) _ring.stop();

    return Semantics(
      button: true,
      label: connected ? tr('Отключить', 'Disconnect') : tr('Подключить', 'Connect'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: _onTap,
          child: AnimatedScale(
            scale: _down ? 0.94 : (_hover ? 1.04 : 1),
            duration: Motion.fast,
            curve: Motion.curve,
            child: SizedBox(
              width: size + 16,
              height: size + 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (busy)
                    RotationTransition(
                      turns: _spin,
                      child: CustomPaint(size: Size.square(size + 12), painter: _ArcPainter(c.warning)),
                    ),
                  if (spinRing)
                    RotationTransition(
                      turns: _ring,
                      child: CustomPaint(size: Size.square(size + 14), painter: _ArcPainter(c.accent, sweep: 4.4)),
                    ),
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: AnimatedContainer(
                    duration: Motion.normal,
                    curve: Motion.curve,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: connected ? c.accent.withValues(alpha: 0.72) : c.glass,
                      shape: BoxShape.circle,
                      border: c.glassStyle ? null : Border.all(color: connected ? c.accent.withValues(alpha: 0.4) : c.border, width: 1),
                      boxShadow: connected
                          ? [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.38),
                                blurRadius: 36,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : (c.glassStyle
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.1),
                                    blurRadius: 22,
                                    offset: const Offset(0, 6),
                                  ),
                                ]),
                    ),
                    child: Icon(Icons.power_settings_new_rounded, size: size * 0.4, color: fg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _toggleCompact(BuildContext context, ConnectionController conn, bool connected) async {
  if (connected && context.app.settings.get(K.confirmDisconnect)) {
    final ok = await showConfirm(context, title: tr('Отключить VPN?', 'Disconnect VPN?'), message: tr('Трафик пойдёт напрямую.', 'Traffic will go directly.'), confirm: tr('Отключить', 'Disconnect'));
    if (!ok || !context.mounted) return;
  }
  await conn.toggle();
}

class _CompactConnect extends StatelessWidget {
  const _CompactConnect();

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: context.app.conn, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.c;
    final conn = context.app.conn;
    final connected = conn.isConnected;
    final label = connected ? tr('Отключиться', 'Disconnect') : tr('Подключиться', 'Connect');
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Pressable(
      onTap: conn.isBusy ? null : () => unawaited(_toggleCompact(context, conn, connected)),
      color: connected ? c.accent.withValues(alpha: 0.72) : c.glass,
      border: c.glassStyle ? null : Border.all(color: connected ? c.accent.withValues(alpha: 0.4) : c.border),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: connected ? c.onAccent.withValues(alpha: 0.16) : c.hover, shape: BoxShape.circle),
            child: Icon(Icons.power_settings_new_rounded, size: 16, color: connected ? c.onAccent : c.text),
          ),
          const SizedBox(width: 8),
          Text(label, style: context.tt.labelLarge?.copyWith(color: connected ? c.onAccent : c.text, fontWeight: FontWeight.w600)),
        ],
      ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color, {this.sweep = math.pi * 0.6});

  final Color color;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(1.5),
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color || old.sweep != sweep;
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, this.onTap});

  final ServerProfile? server;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final conn = app.conn;
    final status = switch (conn.status) {
      ConnStatus.connected => null,
      ConnStatus.connecting => tr('Подключение…', 'Connecting…'),
      ConnStatus.disconnecting => tr('Отключение…', 'Disconnecting…'),
      ConnStatus.disconnected => tr('Отключено', 'Disconnected'),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Pressable(
      onTap: onTap,
      color: c.glass,
      border: c.glassStyle ? null : Border.all(color: c.border),
      radius: Radii.xl,
      pressScale: 0.99,
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      child: Row(
        children: [
          FlagIcon(server?.countryCode, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server == null ? tr('Сервер не выбран', 'No server selected') : Geo.cleanName(server!.name),
                  style: context.tt.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (status != null)
                  Text(status, style: context.tt.bodySmall)
                else
                  _ConnectedTimer(since: conn.connectedAt),
              ],
            ),
          ),
          if (server != null) ...[
            const SizedBox(width: 8),
            Text(server!.protocolLabel, style: context.tt.labelMedium?.copyWith(color: c.textTer)),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textTer),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

class _ConnectedTimer extends StatefulWidget {
  const _ConnectedTimer({required this.since});

  final DateTime? since;

  @override
  State<_ConnectedTimer> createState() => _ConnectedTimerState();
}

class _ConnectedTimerState extends State<_ConnectedTimer> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.app.visible.value) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.since == null ? Duration.zero : DateTime.now().difference(widget.since!);
    return Text(
      '${tr('Подключено', 'Connected')} · ${Fmt.duration(d)}',
      style: context.tt.bodySmall?.copyWith(color: context.c.accent, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch();

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: context.app.conn, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final app = context.app;
    final conn = app.conn;
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.glass, borderRadius: BorderRadius.circular(24), border: c.glassStyle ? null : Border.all(color: c.border)),
          child: PillSegmented<String>(
            values: const ['off', 'proxy', 'tun'],
            labels: const ['Off', 'Proxy', 'TUN'],
            selected: conn.modeLabel,
            height: 42,
            glass: true,
            enabled: conn.status != ConnStatus.disconnecting,
            accentFor: (v) => v != 'off' && conn.isConnected ? c.accent : null,
            onChanged: (m) => conn.setMode(m),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(listenable: Listenable.merge([app.conn, app.installer]), builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final inst = app.installer;
    Widget? content;
    if (inst.busy) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.downloading_rounded, size: 16, color: c.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(inst.stage ?? tr('Загрузка…', 'Downloading…'), style: context.tt.bodySmall?.copyWith(color: c.text))),
            if (inst.progress != null) Text('${(inst.progress! * 100).round()}%', style: context.tt.labelMedium),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: inst.progress, minHeight: 3),
          ),
        ],
      );
    } else if (app.conn.error != null) {
      final kind = app.conn.errorKind;
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.error_outline_rounded, size: 16, color: c.danger)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.conn.error!, style: context.tt.bodySmall?.copyWith(color: c.text), maxLines: 4, overflow: TextOverflow.ellipsis),
                if (kind == CoreErrorKind.permission && Plat.isWindows) ...[
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: tr('Перезапустить от администратора', 'Restart as administrator'),
                    icon: Icons.admin_panel_settings_outlined,
                    height: 32,
                    onPressed: () async {
                      final ok = await app.relaunchAsAdmin();
                      if (!ok && context.mounted) showToast(context, tr('Запуск с правами отменён', 'Elevation was cancelled'), error: true);
                    },
                  ),
                ],
                if (kind == CoreErrorKind.permission && Plat.isAndroid) ...[
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: tr('Открыть настройки VPN', 'Open VPN settings'),
                    icon: Icons.settings_outlined,
                    height: 32,
                    onPressed: () => app.conn.core.openVpnSettings(),
                  ),
                ],
                if (kind == CoreErrorKind.permission && Plat.isIOS) ...[
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: tr('Разрешить VPN', 'Allow VPN'),
                    icon: Icons.vpn_key_outlined,
                    height: 32,
                    onPressed: () => app.conn.core.openVpnSettings(),
                  ),
                ],
                if (kind == CoreErrorKind.missing && Plat.isDesktop) ...[
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: tr('Установить ядро Xray', 'Install Xray core'),
                    icon: Icons.download_rounded,
                    height: 32,
                    onPressed: () => app.installCore(),
                  ),
                ],
              ],
            ),
          ),
          IconBtn(icon: Icons.close_rounded, size: 24, iconSize: 14, onTap: app.conn.clearError),
        ],
      );
    }
    return AnimatedSize(
      duration: Motion.normal,
      curve: Motion.curve,
      alignment: Alignment.bottomCenter,
      child: content == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(padding: const EdgeInsets.all(12), radius: Radii.lg, child: content),
            ),
    );
  }
}
