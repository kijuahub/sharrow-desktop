import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../state/scope.dart';
import '../../state/settings_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/color_picker.dart';
import '../widgets/feedback.dart';
import '../widgets/pressable.dart';
import '../widgets/surface.dart';

class SavedTheme {
  SavedTheme({
    required this.id,
    required this.name,
    required this.uiStyle,
    required this.themeMode,
    required this.accent,
    required this.font,
    required this.textScale,
    required this.sidebarSize,
    required this.sidebarIcons,
    required this.sidebarRadius,
    required this.sidebarBorder,
    required this.sidebarInset,
    required this.sidebarPlace,
    required this.sidebarWidth,
    required this.serversLayout,
    required this.connectStyle,
    required this.colorBg,
    required this.colorSidebar,
    required this.colorSurface,
    required this.colorText,
    required this.colorTitle,
  });

  final String id;
  String name;
  String uiStyle;
  String themeMode;
  int accent;
  String font;
  double textScale;
  String sidebarSize;
  String sidebarIcons;
  double sidebarRadius;
  bool sidebarBorder;
  double sidebarInset;
  String sidebarPlace;
  double sidebarWidth;
  String serversLayout;
  String connectStyle;
  int colorBg;
  int colorSidebar;
  int colorSurface;
  int colorText;
  int colorTitle;

  factory SavedTheme.fromCurrent(Settings s, {String? id, String name = ''}) => SavedTheme(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        uiStyle: s.get(K.uiStyle),
        themeMode: s.get(K.themeMode),
        accent: s.get(K.accent),
        font: s.get(K.font),
        textScale: s.get(K.textScale),
        sidebarSize: s.get(K.sidebarSize),
        sidebarIcons: s.get(K.sidebarIcons),
        sidebarRadius: s.get(K.sidebarRadius),
        sidebarBorder: s.get(K.sidebarBorder),
        sidebarInset: s.get(K.sidebarInset),
        sidebarPlace: s.get(K.sidebarPlace),
        sidebarWidth: sidebarRail(s),
        serversLayout: s.get(K.serversLayout),
        connectStyle: s.get(K.connectStyle),
        colorBg: s.get(K.colorBg),
        colorSidebar: s.get(K.colorSidebar),
        colorSurface: s.get(K.colorSurface),
        colorText: s.get(K.colorText),
        colorTitle: s.get(K.colorTitle),
      );

  factory SavedTheme.fromJson(Map raw) => SavedTheme(
        id: '${raw['id'] ?? ''}',
        name: '${raw['name'] ?? ''}',
        uiStyle: '${raw['uiStyle'] ?? 'classic'}',
        themeMode: '${raw['themeMode'] ?? 'dark'}',
        accent: (raw['accent'] as num?)?.toInt() ?? kAccents.first,
        font: '${raw['font'] ?? 'inter'}',
        textScale: (raw['textScale'] as num?)?.toDouble() ?? 1,
        sidebarSize: '${raw['sidebarSize'] ?? 'medium'}',
        sidebarIcons: '${raw['sidebarIcons'] ?? 'start'}',
        sidebarRadius: (raw['sidebarRadius'] as num?)?.toDouble() ?? 0,
        sidebarBorder: raw['sidebarBorder'] == true,
        sidebarInset: (raw['sidebarInset'] as num?)?.toDouble() ?? 0,
        sidebarPlace: '${raw['sidebarPlace'] ?? 'left'}',
        sidebarWidth: (raw['sidebarWidth'] as num?)?.toDouble() ?? 0,
        serversLayout: '${raw['serversLayout'] ?? 'standard'}',
        connectStyle: '${raw['connectStyle'] ?? 'standard'}',
        colorBg: (raw['colorBg'] as num?)?.toInt() ?? 0,
        colorSidebar: (raw['colorSidebar'] as num?)?.toInt() ?? 0,
        colorSurface: (raw['colorSurface'] as num?)?.toInt() ?? 0,
        colorText: (raw['colorText'] as num?)?.toInt() ?? 0,
        colorTitle: (raw['colorTitle'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'uiStyle': uiStyle,
        'themeMode': themeMode,
        'accent': accent,
        'font': font,
        'textScale': textScale,
        'sidebarSize': sidebarSize,
        'sidebarIcons': sidebarIcons,
        'sidebarRadius': sidebarRadius,
        'sidebarBorder': sidebarBorder,
        'sidebarInset': sidebarInset,
        'sidebarPlace': sidebarPlace,
        'sidebarWidth': sidebarWidth,
        'serversLayout': serversLayout,
        'connectStyle': connectStyle,
        'colorBg': colorBg,
        'colorSidebar': colorSidebar,
        'colorSurface': colorSurface,
        'colorText': colorText,
        'colorTitle': colorTitle,
      };

  void apply(SettingsController settings) {
    settings.set(K.uiStyle, uiStyle);
    settings.set(K.themeMode, themeMode);
    settings.set(K.accent, accent);
    settings.set(K.font, font);
    settings.set(K.textScale, textScale);
    settings.set(K.sidebarSize, sidebarSize);
    settings.set(K.sidebarIcons, sidebarIcons);
    settings.set(K.sidebarRadius, sidebarRadius);
    settings.set(K.sidebarBorder, sidebarBorder);
    settings.set(K.sidebarInset, sidebarInset);
    settings.set(K.sidebarPlace, sidebarPlace);
    if (sidebarWidth > 0) settings.set(K.sidebarWidth, sidebarWidth);
    settings.set(K.serversLayout, serversLayout);
    settings.set(K.connectStyle, connectStyle);
    settings.set(K.colorBg, colorBg);
    settings.set(K.colorSidebar, colorSidebar);
    settings.set(K.colorSurface, colorSurface);
    settings.set(K.colorText, colorText);
    settings.set(K.colorTitle, colorTitle);
  }
}

List<SavedTheme> loadThemes(Settings s) {
  try {
    final raw = jsonDecode(s.get(K.customThemes));
    if (raw is! List) return [];
    return [for (final item in raw) if (item is Map) SavedTheme.fromJson(item)];
  } catch (_) {
    return [];
  }
}

class ThemeStudioController extends ChangeNotifier {
  SavedTheme? draft;
  SavedTheme? _backup;
  int section = 0;

  void open(SettingsController settings, {SavedTheme? existing}) {
    _backup = SavedTheme.fromCurrent(settings.snapshot);
    draft = existing == null
        ? SavedTheme.fromCurrent(settings.snapshot, name: tr('Моя тема', 'My theme'))
        : SavedTheme.fromJson(existing.toJson());
    section = 0;
    draft!.apply(settings);
    notifyListeners();
  }

  void edit(SettingsController settings, void Function(SavedTheme draft) change) {
    final draft = this.draft;
    if (draft == null) return;
    change(draft);
    draft.apply(settings);
    notifyListeners();
  }

  void cancel(SettingsController settings) {
    _backup?.apply(settings);
    draft = null;
    notifyListeners();
  }

  void save(BuildContext context, SettingsController settings) {
    final draft = this.draft;
    if (draft == null) return;
    draft.name = draft.name.trim().isEmpty ? tr('Моя тема', 'My theme') : draft.name.trim();
    final themes = loadThemes(settings.snapshot);
    final index = themes.indexWhere((item) => item.id == draft.id);
    if (index >= 0) {
      themes[index] = draft;
    } else {
      themes.add(draft);
    }
    settings.set(K.customThemes, jsonEncode([for (final theme in themes) theme.toJson()]));
    this.draft = null;
    notifyListeners();
    if (context.mounted) showToast(context, tr('Тема сохранена', 'Theme saved'));
  }
}

final themeStudio = ThemeStudioController();

List<Widget> customThemeTiles(BuildContext context) {
  final settings = context.app.settings;
  final themes = loadThemes(settings.snapshot);
  return [
    for (final theme in themes)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(theme.accent), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodyLarge)),
          AppButton.ghost(label: tr('Применить', 'Apply'), onPressed: () => theme.apply(settings)),
          IconButton(
            tooltip: tr('Изменить', 'Edit'),
            onPressed: () => themeStudio.open(settings, existing: theme),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: tr('Удалить', 'Delete'),
            onPressed: () {
              final next = loadThemes(settings.snapshot)..removeWhere((item) => item.id == theme.id);
              settings.set(K.customThemes, jsonEncode([for (final item in next) item.toJson()]));
            },
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.c.danger),
          ),
        ]),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: AppButton.secondary(
        label: tr('Создать тему', 'Create theme'),
        icon: Icons.add_rounded,
        onPressed: () => themeStudio.open(settings),
      ),
    ),
  ];
}

/// Constructor pinned to the right. The app on the left is a live, non-interactive preview.
class ThemeStudioPane extends StatefulWidget {
  const ThemeStudioPane({super.key});

  @override
  State<ThemeStudioPane> createState() => _ThemeStudioPaneState();
}

class _ThemeStudioPaneState extends State<ThemeStudioPane> {
  late final _name = TextEditingController(text: themeStudio.draft?.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = themeStudio.draft;
    if (draft == null) return const SizedBox.shrink();
    final settings = context.app.settings;
    final c = context.c;
    return Material(
      color: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: Frost(
        radius: 20,
        color: c.surface.withValues(alpha: c.glassStyle ? 0.86 : 0.98),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(tr('Конструктор темы', 'Theme builder'), style: context.tt.titleMedium),
            ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 132,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        children: [
                          for (final (i, label) in [
                            (0, tr('Основное', 'General')),
                            (1, tr('Цвета', 'Colors')),
                            (2, tr('Панель', 'Sidebar')),
                            (3, tr('Серверы', 'Servers')),
                            (4, tr('Кнопка', 'Button')),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Pressable(
                                onTap: () => setState(() => themeStudio.section = i),
                                selected: themeStudio.section == i,
                                radius: 10,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                child: Text(label, style: context.tt.labelLarge?.copyWith(color: themeStudio.section == i ? c.text : c.textSec)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        switchInCurve: Motion.emphasized,
                        child: ListView(
                          key: ValueKey(themeStudio.section),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          children: [
                          if (themeStudio.section == 0) ...[
                            TextField(
                              controller: _name,
                              decoration: InputDecoration(labelText: tr('Название', 'Name')),
                              onChanged: (v) => themeStudio.edit(settings, (d) => d.name = v),
                            ),
                            const SizedBox(height: 14),
                            _chips(tr('Тип', 'Type'), draft.uiStyle, {'classic': tr('Классический', 'Classic'), 'glass': 'Glass'}, (v) => themeStudio.edit(settings, (d) => d.uiStyle = v)),
                            _chips(tr('Шрифт', 'Font'), draft.font, const {'inter': 'Inter', 'onest': 'Onest', 'manrope': 'Manrope'}, (v) => themeStudio.edit(settings, (d) => d.font = v)),
                            _slider(tr('Размер шрифта', 'Font size'), draft.textScale, 0.85, 1.25, (v) => themeStudio.edit(settings, (d) => d.textScale = v), '${(draft.textScale * 100).round()}%'),
                          ],
                          if (themeStudio.section == 1) ...[
                            _swatch(tr('Фон', 'Background'), draft.colorBg, const Color(0xFF0B0C0E), (v) => themeStudio.edit(settings, (d) => d.colorBg = v)),
                            _swatch(tr('Боковая панель', 'Sidebar'), draft.colorSidebar, const Color(0xFF0E0F12), (v) => themeStudio.edit(settings, (d) => d.colorSidebar = v)),
                            _swatch(tr('Карточки', 'Cards'), draft.colorSurface, const Color(0xFF141519), (v) => themeStudio.edit(settings, (d) => d.colorSurface = v)),
                            _swatch(tr('Текст', 'Text'), draft.colorText, const Color(0xFFF3F4F6), (v) => themeStudio.edit(settings, (d) => d.colorText = v)),
                            _swatch(tr('Заголовок', 'Title bar'), draft.colorTitle, c.bg, (v) => themeStudio.edit(settings, (d) => d.colorTitle = v)),
                            _swatch(tr('Акцент', 'Accent'), draft.accent, Color(draft.accent), (v) => themeStudio.edit(settings, (d) => d.accent = v), allowClear: false),
                          ],
                          if (themeStudio.section == 2) ...[
                            _slider(tr('Размер', 'Size'), draft.sidebarWidth == 0 ? 56 : draft.sidebarWidth.clamp(48, 128), 48, 128, (v) => themeStudio.edit(settings, (d) => d.sidebarWidth = v), '${(draft.sidebarWidth == 0 ? 56 : draft.sidebarWidth).round()}'),
                            _chips(tr('Кнопки', 'Buttons'), draft.sidebarIcons, {
                              'start': tr('Сверху', 'Top'),
                              'center': tr('По центру', 'Centered'),
                            }, (v) => themeStudio.edit(settings, (d) => d.sidebarIcons = v)),
                            _chips(tr('Положение', 'Placement'), draft.sidebarPlace, {
                              'left': tr('Слева', 'Left'),
                              'right': tr('Справа', 'Right'),
                              'title': tr('В заголовке', 'In the title'),
                            }, (v) => themeStudio.edit(settings, (d) => d.sidebarPlace = v)),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(tr('Обводка', 'Border')),
                              value: draft.sidebarBorder,
                              onChanged: (v) => themeStudio.edit(settings, (d) => d.sidebarBorder = v),
                            ),
                            _slider(tr('Закругление', 'Corner radius'), draft.sidebarRadius, 0, 24, (v) => themeStudio.edit(settings, (d) => d.sidebarRadius = v), '${draft.sidebarRadius.round()}'),
                            _slider(tr('Отступ', 'Inset'), draft.sidebarInset, 0, 16, (v) => themeStudio.edit(settings, (d) => d.sidebarInset = v), '${draft.sidebarInset.round()}'),
                          ],
                          if (themeStudio.section == 3)
                            _chips(tr('Расположение', 'Layout'), draft.serversLayout, {
                              'standard': tr('Стандартный', 'Standard'),
                              'island': 'Dynamic Island',
                              'right': 'Right',
                            }, (v) => themeStudio.edit(settings, (d) => d.serversLayout = v)),
                          if (themeStudio.section == 4)
                            _chips(tr('Кнопка подключения', 'Connect button'), draft.connectStyle, {
                              'compact': tr('Компактная', 'Compact'),
                              'standard': tr('Стандартная', 'Standard'),
                              'large': tr('Большая', 'Large'),
                            }, (v) => themeStudio.edit(settings, (d) => d.connectStyle = v)),
                        ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: AppButton.secondary(label: tr('Отмена', 'Cancel'), onPressed: () => themeStudio.cancel(settings))),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: tr('Сохранить', 'Save'), onPressed: () => themeStudio.save(context, settings))),
                ]),
              ),
            ],
        ),
      ),
    );
  }

  Widget _chips(String title, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in options.entries)
                ChoiceChip(label: Text(entry.value), selected: value == entry.key, onSelected: (_) => onChanged(entry.key)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slider(String title, double value, double min, double max, ValueChanged<double> onChanged, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title · $label'),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _swatch(String title, int value, Color fallback, ValueChanged<int> onChanged, {bool allowClear = true}) {
    final color = value == 0 ? fallback : Color(value);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: allowClear && value == 0 ? Text(tr('Из темы', 'From the theme')) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowClear && value != 0)
            IconButton(tooltip: tr('Сбросить', 'Reset'), onPressed: () => onChanged(0), icon: const Icon(Icons.restart_alt_rounded, size: 18)),
          GestureDetector(
            onTap: () async {
              final picked = await showColorPicker(context, color);
              if (picked != null) onChanged(picked.toARGB32());
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: const Color(0x33FFFFFF))),
            ),
          ),
        ],
      ),
    );
  }
}
