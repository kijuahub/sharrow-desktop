import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Hover + press feedback surface used for every custom interactive element.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTapAt,
    this.onLongPress,
    this.radius = Radii.md,
    this.padding = EdgeInsets.zero,
    this.color,
    this.hoverColor,
    this.selected = false,
    this.selectedColor,
    this.border,
    this.pressScale = 0.98,
    this.tooltip,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final void Function(Offset globalPosition)? onSecondaryTapAt;
  final VoidCallback? onLongPress;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? hoverColor;
  final bool selected;
  final Color? selectedColor;
  final BoxBorder? border;
  final double pressScale;
  final String? tooltip;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = widget.enabled && (widget.onTap != null || widget.onSecondaryTapAt != null || widget.onLongPress != null);
    final base = widget.selected ? (widget.selectedColor ?? c.accent.withValues(alpha: 0.12)) : (widget.color ?? Colors.transparent);
    final bg = _hover && active && !widget.selected ? Color.alphaBlend(widget.hoverColor ?? c.hover, base) : base;

    Widget child = AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.radius),
        border: widget.border,
      ),
      child: widget.child,
    );

    child = AnimatedScale(
      scale: _down && active ? widget.pressScale : 1,
      duration: Motion.fast,
      curve: Motion.curve,
      child: child,
    );

    child = MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onSecondaryTapUp: widget.enabled && widget.onSecondaryTapAt != null ? (d) => widget.onSecondaryTapAt!(d.globalPosition) : null,
        child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: child),
      ),
    );

    if (widget.tooltip != null) child = Tooltip(message: widget.tooltip!, child: child);
    return child;
  }
}
