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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.border),
      ),
      child: child,
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
            Expanded(child: Text(text.toUpperCase(), style: context.tt.labelSmall)),
            ?trailing,
          ],
        ),
      );
}
