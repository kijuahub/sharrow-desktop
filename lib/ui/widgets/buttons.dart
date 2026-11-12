import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'pressable.dart';

enum ButtonTone { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = ButtonTone.primary,
    this.loading = false,
    this.expand = false,
    this.height = 40,
    this.tooltip,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 40,
    this.tooltip,
  }) : tone = ButtonTone.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.height = 40,
    this.tooltip,
  }) : tone = ButtonTone.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonTone tone;
  final bool loading;
  final bool expand;
  final double height;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (tone) {
      ButtonTone.primary => (c.accent, c.onAccent, null),
      ButtonTone.secondary => (c.glassStyle ? c.glass : c.surfaceHi, c.text, c.glassStyle ? null : Border.all(color: c.border)),
      ButtonTone.ghost => (Colors.transparent, c.textSec, null),
      ButtonTone.danger => (c.danger.withValues(alpha: 0.12), c.danger, Border.all(color: c.danger.withValues(alpha: 0.25))),
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: fg))
        else if (icon != null)
          Icon(icon, size: 16, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    return Pressable(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null,
      tooltip: tooltip,
      color: bg,
      hoverColor: tone == ButtonTone.primary ? Colors.white.withValues(alpha: 0.08) : null,
      border: border,
      radius: c.glassStyle ? 999 : Radii.md,
      pressScale: c.glassStyle ? 0.96 : 0.98,
      padding: EdgeInsets.symmetric(horizontal: tone == ButtonTone.ghost ? 10 : 16),
      child: SizedBox(height: height - 2, child: Center(widthFactor: 1, child: content)),
    );
  }
}

class IconBtn extends StatefulWidget {
  const IconBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 32,
    this.iconSize = 17,
    this.spinning = false,
    this.color,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool spinning;
  final Color? color;
  final bool selected;

  @override
  State<IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<IconBtn> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(IconBtn old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_spin.isAnimating) _spin.repeat();
    if (!widget.spinning && _spin.isAnimating) _spin.animateTo(1).then((_) => _spin.reset());
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: widget.onTap,
      tooltip: widget.tooltip,
      radius: c.glassStyle ? widget.size : Radii.sm + 1,
      color: c.glassStyle ? c.glass : null,
      selected: widget.selected,
      pressScale: c.glassStyle ? 0.96 : 0.92,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RotationTransition(
          turns: _spin,
          child: Icon(widget.icon, size: widget.iconSize, color: widget.color ?? (widget.selected ? c.accent : c.textSec)),
        ),
      ),
    );
  }
}

/// Small rounded chip-like action button.
class ChipButton extends StatelessWidget {
  const ChipButton({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      color: c.glassStyle ? c.glass : c.surfaceHi,
      border: c.glassStyle ? null : Border.all(color: c.border),
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c.textSec), const SizedBox(width: 6)],
          Text(label, style: context.tt.labelMedium?.copyWith(color: c.text)),
        ],
      ),
    );
  }
}
