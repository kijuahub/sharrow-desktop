import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

class PingBadge extends StatelessWidget {
  const PingBadge({super.key, required this.ping, this.loading = false, this.udp = false});

  final int? ping;
  final bool loading;

  /// QUIC servers have no TCP ping; latency appears after connecting.
  final bool udp;

  static Color colorFor(BuildContext context, int? ping) {
    final c = context.c;
    if (ping == null) return c.textTer;
    if (ping < 0) return c.danger;
    if (ping < 150) return c.success;
    if (ping < 350) return c.warning;
    return c.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, ping);
    final text = ping == null ? (udp ? 'UDP' : '—') : (ping! < 0 ? '×' : '$ping');
    return AnimatedSwitcher(
      duration: Motion.fast,
      child: loading && ping == null && !udp
          ? SizedBox(key: const ValueKey('l'), width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: context.c.textTer))
          : Row(
              key: ValueKey(text),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  ping != null && ping! > 0 ? '$text ms' : text,
                  style: context.tt.labelMedium?.copyWith(color: ping == null ? context.c.textTer : context.c.textSec, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = color ?? c.textSec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: context.tt.labelSmall?.copyWith(color: col, letterSpacing: 0.2)),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8, this.glow = false});

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.normal,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: size)] : null,
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.surfaceHi, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
              child: Icon(icon, size: 22, color: c.textSec),
            ),
            const SizedBox(height: 14),
            Text(title, style: context.tt.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(message!, style: context.tt.bodySmall, textAlign: TextAlign.center),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
