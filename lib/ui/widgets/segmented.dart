import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Pill segmented control with a sliding thumb (Off / Proxy / TUN style).
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 40,
    this.enabled = true,
    this.accentFor,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final bool enabled;

  /// Optional thumb color per value (e.g. green for an active tunnel).
  final Color? Function(T value)? accentFor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    final thumbColor = accentFor?.call(selected) ?? c.accent;
    final onThumb = ThemeData.estimateBrightnessForColor(thumbColor) == Brightness.dark ? Colors.white : const Color(0xFF111215);
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF1E1F24) : const Color(0xFFE6E6EA),
        borderRadius: BorderRadius.circular(height),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / values.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: Motion.normal,
              curve: Motion.emphasized,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: AnimatedContainer(
                duration: Motion.normal,
                decoration: BoxDecoration(
                  color: thumbColor,
                  borderRadius: BorderRadius.circular(height),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.4 : 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: MouseRegion(
                      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled && i != index ? () => onChanged(values[i]) : null,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Motion.fast,
                            style: context.tt.labelLarge!.copyWith(
                              fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                              color: i == index ? onThumb : c.textSec,
                            ),
                            child: Text(labels[i], maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
