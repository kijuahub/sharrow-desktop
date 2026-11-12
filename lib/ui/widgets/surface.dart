import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../state/scope.dart';

/// Flat card with a hairline border.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.radius = Radii.lg,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final glass = c.glassStyle;
    return Frost(
      padding: padding,
      radius: glass ? radius + 6 : radius,
      color: color ?? (glass ? null : c.surface),
      border: glass ? (borderColor == null ? null : Border.all(color: borderColor!)) : Border.all(color: borderColor ?? c.border),
      child: child,
    );
  }
}

/// Frosted surface. Opaque fill when the glass interface style is off,
/// or when [color] is already nearly solid (log console, sheets).
class Frost extends StatelessWidget {
  const Frost({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 0,
    this.corners,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final BorderRadius? corners;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final glass = c.glassStyle && (color == null || color!.a < 0.92);
    final r = corners ?? BorderRadius.circular(radius);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (glass ? c.glass : c.surface),
        borderRadius: r,
        border: border,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!glass) return box;
    final sigma = context.app.settings.get(K.lowFps) ? 10.0 : 24.0;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: box),
    );
  }
}

/// Frosted surface for floating elements over rich content (globe, overlays).
/// Falls back to an opaque panel when transparency effects are disabled.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.md),
    this.radius = Radii.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (c.glassStyle) return Frost(padding: padding, radius: radius + 4, child: child);
    final glass = context.app.settings.get(K.glass);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: glass ? c.glass : c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
    if (!glass) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: box),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.vertical = false});

  final double indent;
  final bool vertical;

  @override
  Widget build(BuildContext context) => vertical
      ? Container(width: 1, color: context.c.border)
      : Container(height: 1, margin: EdgeInsets.only(left: indent), color: context.c.border);
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 8)});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.c.glassStyle ? text : text.toUpperCase(),
                style: context.c.glassStyle ? context.tt.labelMedium?.copyWith(color: context.c.textSec) : context.tt.labelSmall,
              ),
            ),
            ?trailing,
          ],
        ),
      );
}
