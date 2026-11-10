import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
  const ConnectPanel({super.key, this.compact = false, this.onServerCardTap});

  final bool compact;
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
        final globe = switch (s.get(K.homeScene)) {
          'space' => const _Space(),
          'image' => _HomeImage(path: s.get(K.homeImage)),
          _ => _Globe(server: server),
        };

        final controls = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Banner(),
              _ServerCard(server: server, onTap: onServerCardTap),
              const SizedBox(height: 12),
              const _ModeSwitch(),
            ],
          ),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 8 : 16, compact ? 16 : 24, compact ? 16 : 24),
          child: Column(
            children: [
              const _TopRow(),
              if (compact)
                SizedBox(height: math.min(MediaQuery.sizeOf(context).width - 32, 340), child: _GlobeStack(globe: globe))
              else
                Expanded(child: _GlobeStack(globe: globe)),
              SizedBox(height: compact ? 8 : 18),
              controls,
            ],
          ),
        );
      },
    );
  }
}

class _GlobeStack extends StatelessWidget {
  const _GlobeStack({required this.globe});

  final Widget globe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(box.maxWidth, box.maxHeight);
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: globe),
          Positioned(
            bottom: math.max(0, (box.maxHeight - size) / 2 + size * 0.02),
            child: const ConnectButton(),
          ),
        ],
      );
    });
  }
}

class _Globe extends StatelessWidget {
  const _Globe({required this.server});

  final ServerProfile? server;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final sub = app.subs.selectedSub;
    final ru = L10n.isRu;
    final groups = <String, int>{};
    for (final srv in sub?.servers ?? const <ServerProfile>[]) {
      final cc = srv.countryCode;
      if (cc != null && Geo.countries.containsKey(cc)) groups[cc] = (groups[cc] ?? 0) + 1;
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
        selectedId: server?.countryCode,
        connected: app.conn.isConnected,
        connecting: app.conn.status == ConnStatus.connecting,
        animate: s.get(K.animations),
        rotate: s.get(K.globeRotation),
        speed: s.get(K.globeSpeed),
        lowFps: s.get(K.lowFps),
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
  static final _stars = List.generate(160, (i) {
    final r = math.Random(i);
    return (r.nextDouble(), r.nextDouble(), 0.35 + r.nextDouble() * 1.8, 0.25 + r.nextDouble() * 0.75);
  });

  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 90));

  @override
  void initState() {
    super.initState();
    if (context.app.settings.get(K.animations)) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: _drift,
      builder: (_, _) => CustomPaint(
        painter: _StarPainter(_stars, _drift.value, c.isDark ? const Color(0xFF07080C) : const Color(0xFFE7EAF2), c.text),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.shift, this.bg, this.star);

  final List<(double, double, double, double)> stars;
  final double shift;
  final Color bg;
  final Color star;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final paint = Paint();
    for (final (x, y, radius, alpha) in stars) {
      final dy = (y + shift) % 1.0;
      paint.color = star.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x * size.width, dy * size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.shift != shift || old.bg != bg;
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
  const ConnectButton({super.key, this.size = 84});

  final double size;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _hover = false;
  bool _down = false;

  @override
  void dispose() {
    _spin.dispose();
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
    if (busy && !_spin.isAnimating) _spin.repeat();
    if (!busy && _spin.isAnimating) _spin.stop();
    final connected = conn.isConnected;
    final size = widget.size;
    final bg = connected ? c.accent : (c.isDark ? const Color(0xFF17181C) : Colors.white);
    final fg = connected ? c.onAccent : (busy ? c.warning : c.text);

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
                  AnimatedContainer(
                    duration: Motion.normal,
                    curve: Motion.curve,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: connected ? Colors.transparent : c.borderStrong, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: connected ? c.accent.withValues(alpha: 0.38) : Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.1),
                          blurRadius: connected ? 36 : 22,
                          spreadRadius: connected ? 2 : 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.power_settings_new_rounded, size: size * 0.4, color: fg),
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

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(1.5),
      0,
      math.pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
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
    return Pressable(
      onTap: onTap,
      color: c.isDark ? const Color(0xFF17181C) : c.surface,
      border: Border.all(color: c.border),
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
    return PillSegmented<String>(
      values: const ['off', 'proxy', 'tun'],
      labels: const ['Off', 'Proxy', 'TUN'],
      selected: conn.modeLabel,
      height: 42,
      enabled: conn.status != ConnStatus.disconnecting,
      accentFor: (v) => v != 'off' && conn.isConnected ? c.accent : null,
      onChanged: (m) => conn.setMode(m),
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
