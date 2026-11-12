import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../state/scope.dart';
import '../widgets/buttons.dart';
import '../widgets/pressable.dart';
import '../widgets/surface.dart';
import 'settings_sections.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static bool _narrowOpen = false;

  late String _selected;
  late bool _narrowDetail;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final saved = context.app.settings.get(K.lastSettingsSection);
    _selected = kSettingsCategories.any((c) => c.id == saved) ? saved : kSettingsCategories.first.id;
    _narrowDetail = _narrowOpen;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SettingsCategory> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kSettingsCategories;
    return kSettingsCategories.where((c) => c.ru.toLowerCase().contains(q) || c.en.toLowerCase().contains(q)).toList();
  }

  Widget _nav(BuildContext context, {required bool narrow}) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          child: Text(tr('Настройки', 'Settings'), style: context.tt.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: context.tt.bodyMedium,
              decoration: InputDecoration(
                hintText: tr('Поиск', 'Search'),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: c.textTer),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _SmoothList(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              for (final cat in _filtered)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Pressable(
                    onTap: () => setState(() {
                      _selected = cat.id;
                      _narrowDetail = _narrowOpen = true;
                      context.app.settings.set(K.lastSettingsSection, cat.id);
                    }),
                    selected: !narrow && _selected == cat.id,
                    selectedColor: c.glassStyle
                        ? (c.isDark ? const Color(0x28FFFFFF) : const Color(0xB8FFFFFF))
                        : (c.isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000)),
                    radius: c.glassStyle ? 12 : Radii.sm + 2,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(children: [
                      Icon(cat.icon, size: 17, color: !narrow && _selected == cat.id ? (c.glassStyle ? c.accent : c.text) : c.textSec),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          cat.title,
                          style: context.tt.labelLarge?.copyWith(
                            color: !narrow && _selected == cat.id ? c.text : c.textSec,
                            fontWeight: !narrow && _selected == cat.id ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (narrow) Icon(Icons.chevron_right_rounded, size: 18, color: c.textTer),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, {VoidCallback? onBack}) {
    final cat = kSettingsCategories.firstWhere((c) => c.id == _selected);
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app]),
      builder: (context, _) => AnimatedSwitcher(
        duration: Motion.fast,
        child: _SmoothList(
          key: ValueKey(cat.id),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      if (onBack != null) ...[IconBtn(icon: Icons.arrow_back_rounded, onTap: onBack), const SizedBox(width: 6)],
                      Text(cat.title, style: context.tt.headlineSmall),
                    ]),
                    const SizedBox(height: 18),
                    ...cat.builder(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 720) {
        return AnimatedSwitcher(
          duration: Motion.normal,
          child: _narrowDetail
              ? KeyedSubtree(key: const ValueKey('d'), child: _detail(context, onBack: () => setState(() => _narrowDetail = _narrowOpen = false)))
              : KeyedSubtree(key: const ValueKey('n'), child: _nav(context, narrow: true)),
        );
      }
      return Row(
        children: [
          SizedBox(width: 232, child: _nav(context, narrow: false)),
          const Hairline(vertical: true),
          Expanded(child: _detail(context)),
        ],
      );
    });
  }
}

class _SmoothList extends StatefulWidget {
  const _SmoothList({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  State<_SmoothList> createState() => _SmoothListState();
}

class _SmoothListState extends State<_SmoothList> {
  final _ctrl = ScrollController();
  double? _goal;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_ctrl.hasClients || MediaQuery.disableAnimationsOf(context)) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (claimed) {
      if (claimed is! PointerScrollEvent || !_ctrl.hasClients) return;
      final p = _ctrl.position;
      final base = _goal ?? _ctrl.offset;
      _goal = (base + claimed.scrollDelta.dy).clamp(p.minScrollExtent, p.maxScrollExtent);
      _ctrl.animateTo(_goal!, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _wheel,
      child: ListView(controller: _ctrl, padding: widget.padding, children: widget.children),
    );
  }
}
