import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../modules/subscription/geo.dart';
import '../../state/connection_controller.dart';
import '../../state/scope.dart';
import '../widgets/badges.dart';
import 'subscription_panel.dart';

/// Collapsed pill for the connection. Expands into the subscription and a server grid.
class DynamicIsland extends StatefulWidget {
  const DynamicIsland({super.key});

  @override
  State<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends State<DynamicIsland> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.conn, app.subs, app.settings]),
      builder: (context, _) {
        final c = context.c;
        final conn = app.conn;
        final server = conn.isConnected ? (conn.activeServer ?? app.subs.selectedServer) : app.subs.selectedServer;
        final status = conn.status;
        final label = switch (status) {
          ConnStatus.connected => server == null ? tr('Подключено', 'Connected') : Geo.cleanName(server.name),
          ConnStatus.connecting => tr('Подключение', 'Connecting'),
          ConnStatus.disconnecting => tr('Отключение', 'Disconnecting'),
          ConnStatus.disconnected => tr('Отключено', 'Disconnected'),
        };
        final color = switch (status) {
          ConnStatus.connected => c.accent,
          ConnStatus.connecting || ConnStatus.disconnecting => c.warning,
          ConnStatus.disconnected => c.textTer,
        };
        final collapsed = switch (status) {
          ConnStatus.connected => 248.0,
          ConnStatus.connecting || ConnStatus.disconnecting => 196.0,
          ConnStatus.disconnected => 158.0,
        };
        final motion = app.settings.get(K.animations) ? const Duration(milliseconds: 340) : Duration.zero;
        return LayoutBuilder(builder: (context, box) {
          final openWidth = math.min(920.0, box.maxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: motion,
              curve: Motion.emphasized,
              width: _open ? openWidth : collapsed,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_open ? 26 : 22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.glass,
                      borderRadius: BorderRadius.circular(_open ? 26 : 22),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.12), blurRadius: 28, offset: const Offset(0, 12))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _open = !_open),
                          child: SizedBox(
                            height: 42,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  StatusDot(color: color, glow: status == ConnStatus.connected),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: motion,
                                      child: Text(label, key: ValueKey(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.labelLarge),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _open ? 0.5 : 0,
                                    duration: motion,
                                    curve: Motion.emphasized,
                                    child: Icon(Icons.expand_more_rounded, size: 18, color: c.textTer),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: motion,
                          curve: Motion.emphasized,
                          alignment: Alignment.topCenter,
                          child: _open
                              ? SizedBox(
                                  height: 460,
                                  child: ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.topCenter,
                                      minWidth: math.max(openWidth, 720),
                                      maxWidth: math.max(openWidth, 720),
                                      child: SizedBox(
                                        width: math.max(openWidth, 720),
                                        height: 460,
                                        child: const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 12), child: SubscriptionPanel(grid: true)),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
