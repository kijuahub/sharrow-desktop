import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../state/scope.dart';
import '../widgets/buttons.dart';
import '../widgets/color_picker.dart';
import '../widgets/feedback.dart';
import '../widgets/pressable.dart';
import '../widgets/segmented.dart';
import '../widgets/surface.dart';

/// Material switch in the classic style, Cupertino switch in Glass.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!c.glassStyle) return Switch(value: value, onChanged: onChanged);
    return CupertinoSwitch(
      value: value,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EB),
      onChanged: onChanged,
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, this.footer, required this.children});

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionLabel(title!),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Hairline(indent: 16),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!, style: context.tt.bodySmall?.copyWith(color: context.c.textTer)),
            ),
        ],
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.title, this.subtitle, this.trailing, this.below, this.enabled = true});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle!, style: context.tt.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 16), trailing!],
                ],
              ),
              if (below != null) ...[const SizedBox(height: 10), below!],
            ],
          ),
        ),
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile(this.k, {super.key, required this.title, this.subtitle, this.enabled = true, this.onChanged});

  final SettingKey<bool> k;
  final String title;
  final String? subtitle;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final v = s.get(k);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              s.set(k, !v);
              onChanged?.call(!v);
            }
          : null,
      child: _TileFrame(
        title: title,
        subtitle: subtitle,
        enabled: enabled,
        trailing: Transform.scale(
          scale: context.c.glassStyle ? 0.9 : 0.82,
          child: AppSwitch(
            value: v,
            onChanged: (nv) {
              s.set(k, nv);
              onChanged?.call(nv);
            },
          ),
        ),
      ),
    );
  }
}

class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile(this.k, {super.key, required this.title, this.subtitle, required this.options, this.enabled = true, this.segmented});

  final SettingKey<T> k;
  final String title;
  final String? subtitle;
  final Map<T, String> options;
  final bool enabled;
  final bool? segmented;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wanted = segmented ?? (options.length <= 3 && options.values.every((l) => l.length <= 10));
      return _build(context, wanted && box.maxWidth >= 82.0 * options.length + 180);
    });
  }

  Widget _build(BuildContext context, bool useSeg) {
    final s = context.app.settings;
    final v = s.get(k);
    if (useSeg) {
      return _TileFrame(
        title: title,
        subtitle: subtitle,
        enabled: enabled,
        trailing: SizedBox(
          width: 82.0 * options.length,
          child: PillSegmented<T>(
            values: options.keys.toList(),
            labels: options.values.toList(),
            selected: options.containsKey(v) ? v : options.keys.first,
            height: 32,
            onChanged: (nv) => s.set(k, nv),
          ),
        ),
      );
    }
    return _TileFrame(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: Builder(
        builder: (ctx) => Pressable(
          color: context.c.glass,
          border: Border.all(color: context.c.border),
          radius: Radii.sm + 2,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          onTap: () async {
            final box = ctx.findRenderObject() as RenderBox;
            final pos = box.localToGlobal(Offset(0, box.size.height + 4));
            final picked = await showContextMenuAt<T>(ctx, pos, [
              for (final e in options.entries) menuItem<T>(ctx, e.key, e.key == v ? Icons.check_rounded : Icons.circle_outlined, e.value),
            ]);
            if (picked != null) s.set(k, picked);
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(options[v] ?? '$v', style: context.tt.labelLarge, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Icon(Icons.unfold_more_rounded, size: 15, color: context.c.textTer),
          ]),
        ),
      ),
    );
  }
}

class NumberTile extends StatelessWidget {
  const NumberTile(this.k, {super.key, required this.title, this.subtitle, required this.min, required this.max, this.step = 1, this.suffix, this.enabled = true});

  final SettingKey<int> k;
  final String title;
  final String? subtitle;
  final int min;
  final int max;
  final int step;
  final String? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final v = s.get(k);
    final c = context.c;
    return _TileFrame(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: Container(
        decoration: BoxDecoration(color: c.surfaceHi, borderRadius: BorderRadius.circular(Radii.sm + 2), border: Border.all(color: c.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconBtn(icon: Icons.remove_rounded, size: 30, iconSize: 15, onTap: v - step >= min ? () => s.set(k, v - step) : null),
          Pressable(
            radius: 6,
            onTap: () async {
              final text = await showTextInput(context, title: title, initial: '$v', message: '$min – $max${suffix != null ? ' $suffix' : ''}');
              final n = int.tryParse(text?.trim() ?? '');
              if (n != null) s.set(k, n.clamp(min, max));
            },
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44),
              child: Text(
                '$v${suffix != null ? ' $suffix' : ''}',
                textAlign: TextAlign.center,
                style: context.tt.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          IconBtn(icon: Icons.add_rounded, size: 30, iconSize: 15, onTap: v + step <= max ? () => s.set(k, v + step) : null),
        ]),
      ),
    );
  }
}

class SliderTile extends StatelessWidget {
  const SliderTile(this.k, {super.key, required this.title, this.subtitle, required this.min, required this.max, this.divisions, required this.format, this.enabled = true});

  final SettingKey<double> k;
  final String title;
  final String? subtitle;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) format;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final v = s.get(k).clamp(min, max);
    return _TileFrame(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: Text(format(v), style: context.tt.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      below: Slider(value: v, min: min, max: max, divisions: divisions, label: format(v), onChanged: (nv) => s.set(k, nv)),
    );
  }
}

class TextTile extends StatefulWidget {
  const TextTile(this.k, {super.key, required this.title, this.subtitle, this.hint, this.obscure = false, this.mono = false, this.validator, this.enabled = true, this.wide = false});

  final SettingKey<String> k;
  final String title;
  final String? subtitle;
  final String? hint;
  final bool obscure;
  final bool mono;
  final bool enabled;

  /// Full-width field below the title instead of a trailing field.
  final bool wide;

  /// Returns an error message or null.
  final String? Function(String value)? validator;

  @override
  State<TextTile> createState() => _TextTileState();
}

class _TextTileState extends State<TextTile> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: context.app.settings.get(widget.k));
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    final v = _ctrl.text.trim();
    final err = widget.validator?.call(v);
    setState(() => _error = err);
    if (err == null) context.app.settings.set(widget.k, v);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _ctrl,
      focusNode: _focus,
      obscureText: widget.obscure,
      onSubmitted: (_) => _save(),
      style: widget.mono
          ? context.tt.bodyMedium?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Consolas', 'Menlo'], fontSize: 12.5)
          : context.tt.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: _error,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
    return LayoutBuilder(builder: (context, box) {
      final below = widget.wide || box.maxWidth < 520;
      return _TileFrame(
        title: widget.title,
        subtitle: widget.subtitle,
        enabled: widget.enabled,
        trailing: below ? null : SizedBox(width: 260, child: field),
        below: below ? field : null,
      );
    });
  }
}

class ListEditTile extends StatelessWidget {
  const ListEditTile(this.k, {super.key, required this.title, this.subtitle, this.hint, this.enabled = true});

  final SettingKey<List<String>> k;
  final String title;
  final String? subtitle;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final list = s.get(k);
    return _TileFrame(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(list.isEmpty ? tr('пусто', 'empty') : '${list.length}', style: context.tt.labelMedium),
        const SizedBox(width: 10),
        AppButton.secondary(
          label: tr('Изменить', 'Edit'),
          height: 32,
          onPressed: () async {
            final text = await showTextInput(
              context,
              title: title,
              initial: list.join('\n'),
              hint: hint,
              message: tr('По одному значению на строку. Строки с # игнорируются.', 'One entry per line. Lines starting with # are ignored.'),
              multiline: true,
              monospace: true,
            );
            if (text != null) {
              s.set(k, text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
            }
          },
        ),
      ]),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.title, this.subtitle, required this.label, required this.onTap, this.icon, this.danger = false, this.loading = false, this.enabled = true});

  final String title;
  final String? subtitle;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) => _TileFrame(
        title: title,
        subtitle: subtitle,
        enabled: enabled,
        trailing: AppButton(
          label: label,
          icon: icon,
          height: 32,
          loading: loading,
          tone: danger ? ButtonTone.danger : ButtonTone.secondary,
          onPressed: onTap,
        ),
      );
}

class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.title, required this.value, this.copyable = false});

  final String title;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) => _TileFrame(
        title: title,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(value, style: context.tt.bodyMedium?.copyWith(color: context.c.textSec), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
          ),
          if (copyable) ...[
            const SizedBox(width: 4),
            IconBtn(
              icon: Icons.copy_rounded,
              size: 28,
              iconSize: 14,
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                showToast(context, tr('Скопировано', 'Copied'));
              },
            ),
          ],
        ]),
      );
}

class AccentTile extends StatelessWidget {
  const AccentTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final current = s.get(K.accent);
    final custom = !kAccents.contains(current);
    return _TileFrame(
      title: tr('Акцентный цвет', 'Accent color'),
      trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Tooltip(
          message: tr('Свой цвет', 'Custom color'),
          child: GestureDetector(
            onTap: () async {
              final picked = await showColorPicker(context, Color(current));
              if (picked != null) s.set(K.accent, picked.toARGB32() | 0xFF000000);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: custom ? Color(current) : context.c.surfaceHi,
                  shape: BoxShape.circle,
                  border: Border.all(color: custom ? context.c.text : context.c.borderStrong, width: custom ? 2 : 1),
                ),
                child: Icon(
                  custom ? Icons.check_rounded : Icons.colorize_rounded,
                  size: 12,
                  color: custom ? (ThemeData.estimateBrightnessForColor(Color(current)) == Brightness.dark ? Colors.white : Colors.black) : context.c.textSec,
                ),
              ),
            ),
          ),
        ),
        for (final a in kAccents)
          GestureDetector(
            onTap: () => s.set(K.accent, a),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Color(a),
                  shape: BoxShape.circle,
                  border: Border.all(color: current == a ? context.c.text : Colors.transparent, width: 2),
                ),
                child: current == a ? Icon(Icons.check_rounded, size: 12, color: ThemeData.estimateBrightnessForColor(Color(a)) == Brightness.dark ? Colors.white : Colors.black) : null,
              ),
            ),
          ),
      ]),
    );
  }
}

String? validatePort(String v) {
  final n = int.tryParse(v);
  return n == null || n < 1 || n > 65535 ? tr('Порт 1–65535', 'Port 1–65535') : null;
}
