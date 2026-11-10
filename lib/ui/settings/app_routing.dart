import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../modules/system/process_list.dart';
import '../../state/scope.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import 'settings_widgets.dart';

/// Per-application routing (split tunnelling by process name).
class AppRoutingGroup extends StatelessWidget {
  const AppRoutingGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final mode = s.get(K.appRouting);
    final apps = s.get(K.appList);
    final c = context.c;
    return SettingsGroup(
      title: tr('Приложения', 'Applications'),
      footer: tr(
        'Правило применяется к процессам по имени файла (например, chrome.exe). Надёжнее всего работает в режиме TUN: в режиме Proxy через VPN идут только приложения, которые используют системный прокси.',
        'Rules match processes by executable name (e.g. chrome.exe). Works best in TUN mode: in Proxy mode only apps that honour the system proxy go through the VPN.',
      ),
      children: [
        ChoiceTile(K.appRouting, title: tr('Маршрутизация приложений', 'App routing'), segmented: false, options: {
          'off': tr('Выключена', 'Off'),
          'proxy': tr('Только выбранные — через VPN', 'Only selected apps use VPN'),
          'direct': tr('Выбранные — в обход VPN', 'Selected apps bypass VPN'),
        }),
        Opacity(
          opacity: mode == 'off' ? 0.45 : 1,
          child: IgnorePointer(
            ignoring: mode == 'off',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Список приложений', 'Applications'), style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        Text(apps.isEmpty ? tr('Ничего не выбрано', 'Nothing selected') : '${apps.length} ${tr('выбрано', 'selected')}', style: context.tt.bodySmall),
                      ]),
                    ),
                    AppButton.secondary(
                      label: tr('Выбрать', 'Choose'),
                      icon: Icons.apps_rounded,
                      height: 34,
                      onPressed: () => showAppPicker(context),
                    ),
                  ]),
                  if (apps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final a in apps)
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
                          decoration: BoxDecoration(color: c.surfaceHi, borderRadius: BorderRadius.circular(Radii.sm), border: Border.all(color: c.border)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(a, style: context.tt.labelMedium?.copyWith(color: c.text)),
                            const SizedBox(width: 2),
                            IconBtn(icon: Icons.close_rounded, size: 20, iconSize: 12, onTap: () => s.set(K.appList, [...apps]..remove(a))),
                          ]),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showAppPicker(BuildContext context) async {
  final s = context.app.settings;
  final picked = await showDialog<List<String>>(
    context: context,
    builder: (_) => _AppPickerDialog(initial: s.get(K.appList)),
  );
  if (picked != null) s.set(K.appList, picked);
}

class _AppPickerDialog extends StatefulWidget {
  const _AppPickerDialog({required this.initial});

  final List<String> initial;

  @override
  State<_AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<_AppPickerDialog> {
  late final Set<String> _selected = {...widget.initial};
  List<String>? _running;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _running = null);
    final list = await ProcessList.running();
    if (mounted) setState(() => _running = list);
  }

  Future<void> _addManual() async {
    final name = await showTextInput(
      context,
      title: tr('Добавить приложение', 'Add application'),
      hint: Plat.isWindows ? 'telegram.exe' : 'firefox',
      message: tr('Имя исполняемого файла или полный путь к нему.', 'Executable name or its full path.'),
      confirm: tr('Добавить', 'Add'),
    );
    final v = name?.trim() ?? '';
    if (v.isNotEmpty) setState(() => _selected.add(v));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _query.toLowerCase();
    final all = {..._selected, ...?_running}.toList()
      ..sort((a, b) {
        final sa = _selected.contains(a), sb = _selected.contains(b);
        if (sa != sb) return sa ? -1 : 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    final items = q.isEmpty ? all : all.where((e) => e.toLowerCase().contains(q)).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(tr('Выбор приложений', 'Choose applications'), style: context.tt.titleLarge)),
                IconBtn(icon: Icons.refresh_rounded, tooltip: tr('Обновить список', 'Refresh'), spinning: _running == null, onTap: _load),
              ]),
              const SizedBox(height: 4),
              Text(tr('Запущенные сейчас приложения. Отметьте нужные.', 'Currently running applications. Tick the ones you need.'), style: context.tt.bodySmall),
              const SizedBox(height: 14),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: tr('Поиск', 'Search'),
                  prefixIcon: Icon(Icons.search_rounded, size: 17, color: c.textTer),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  contentPadding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: _running == null && items.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemExtent: 44,
                        itemBuilder: (context, i) {
                          final name = items[i];
                          final on = _selected.contains(name);
                          return InkWell(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            onTap: () => setState(() => on ? _selected.remove(name) : _selected.add(name)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(children: [
                                Icon(Icons.window_rounded, size: 17, color: on ? c.accent : c.textTer),
                                const SizedBox(width: 12),
                                Expanded(child: Text(name, style: context.tt.bodyMedium, overflow: TextOverflow.ellipsis)),
                                Checkbox(value: on, onChanged: (_) => setState(() => on ? _selected.remove(name) : _selected.add(name))),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                AppButton.ghost(label: tr('Добавить вручную', 'Add manually'), icon: Icons.add_rounded, onPressed: _addManual),
                const Spacer(),
                AppButton.ghost(label: tr('Отмена', 'Cancel'), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                AppButton(label: '${tr('Готово', 'Done')}${_selected.isEmpty ? '' : ' · ${_selected.length}'}', onPressed: () => Navigator.pop(context, _selected.toList())),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
