import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/storage/paths.dart';
import '../../modules/logs/log_service.dart';
import '../../state/scope.dart';
import '../widgets/badges.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/segmented.dart';
import '../widgets/surface.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _scroll = ScrollController();
  String _level = 'all';
  String _source = 'all';
  String _query = '';
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final atBottom = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
      if (_follow != atBottom && _scroll.position.userScrollDirection != ScrollDirection.idle) {
        setState(() => _follow = atBottom);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<LogEntry> _filter(List<LogEntry> all) {
    final q = _query.toLowerCase();
    return all.where((e) {
      if (_source != 'all' && e.source.name != _source) return false;
      if (_level == 'warning' && e.level.index < LogLevel.warning.index) return false;
      if (_level == 'error' && e.level != LogLevel.error) return false;
      if (q.isNotEmpty && !e.message.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(tr('Логи', 'Logs'), style: context.tt.headlineSmall)),
              IconBtn(
                icon: _follow ? Icons.vertical_align_bottom_rounded : Icons.pause_rounded,
                selected: _follow,
                tooltip: tr('Автопрокрутка', 'Auto-scroll'),
                onTap: () {
                  setState(() => _follow = !_follow);
                  if (_follow) _jumpToEnd();
                },
              ),
              IconBtn(
                icon: Icons.copy_rounded,
                tooltip: tr('Копировать всё', 'Copy all'),
                onTap: () async {
                  await app.copy(log.export());
                  if (context.mounted) showToast(context, tr('Логи скопированы', 'Logs copied'));
                },
              ),
              if (Plat.isDesktop) IconBtn(icon: Icons.folder_open_rounded, tooltip: tr('Папка логов', 'Logs folder'), onTap: () => app.openFolder(AppPaths.logs)),
              IconBtn(icon: Icons.delete_sweep_outlined, tooltip: tr('Очистить', 'Clear'), onTap: log.clear),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 270,
                child: PillSegmented<String>(
                  values: const ['all', 'warning', 'error'],
                  labels: [tr('Все', 'All'), tr('Важные', 'Warnings'), tr('Ошибки', 'Errors')],
                  selected: _level,
                  height: 40,
                  onChanged: (v) => setState(() => _level = v),
                ),
              ),
              SizedBox(
                width: 230,
                child: PillSegmented<String>(
                  values: const ['all', 'app', 'core'],
                  labels: [tr('Все', 'All'), tr('Клиент', 'App'), 'Xray'],
                  selected: _source,
                  height: 40,
                  onChanged: (v) => setState(() => _source = v),
                ),
              ),
              SizedBox(
                width: 240,
                height: 40,
                child: TextField(
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
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Panel(
              padding: EdgeInsets.zero,
              color: c.isDark ? const Color(0xFF0E0F12) : c.surface,
              child: ListenableBuilder(
                listenable: log,
                builder: (context, _) {
                  final items = _filter(log.entries);
                  if (_follow) _jumpToEnd();
                  if (items.isEmpty) {
                    return EmptyState(icon: Icons.receipt_long_outlined, title: tr('Записей нет', 'No entries'));
                  }
                  return Scrollbar(
                    controller: _scroll,
                    child: SelectionArea(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _LogLine(entry: items[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (entry.level) {
      LogLevel.error => c.danger,
      LogLevel.warning => c.warning,
      LogLevel.debug => c.textTer,
      LogLevel.info => c.textSec,
    };
    final mono = TextStyle(
      fontFamily: AppTheme.mono,
      fontFamilyFallback: AppTheme.monoFallback,
      fontSize: 12,
      height: 1.45,
      color: entry.level == LogLevel.info ? c.text : color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '${Fmt.time(entry.time)}  ', style: mono.copyWith(color: c.textTer)),
          TextSpan(text: entry.source == LogSource.core ? 'xray ' : 'app  ', style: mono.copyWith(color: entry.source == LogSource.core ? c.accent : c.textSec)),
          TextSpan(text: entry.message, style: mono),
        ]),
      ),
    );
  }
}
