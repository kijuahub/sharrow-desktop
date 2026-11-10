import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/storage/paths.dart';

enum LogLevel { debug, info, warning, error }

enum LogSource { app, core }

@immutable
class LogEntry {
  const LogEntry(this.time, this.level, this.source, this.message);

  final DateTime time;
  final LogLevel level;
  final LogSource source;
  final String message;
}

/// Ring buffer of log lines. UI notifications are coalesced to at most
/// ~4 per second so a chatty core never floods the frame pipeline.
class LogService extends ChangeNotifier {
  LogService._();

  static final LogService instance = LogService._();

  final _entries = ListQueue<LogEntry>();
  int maxLines = 2000;
  LogLevel minAppLevel = LogLevel.info;
  bool maskAddresses = true;
  Timer? _notifyTimer;
  IOSink? _sink;
  int _version = 0;

  int get version => _version;
  List<LogEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;

  static final _ipv4 = RegExp(r'\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b');
  static final _uuid = RegExp(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b');

  String _mask(String s) {
    if (!maskAddresses) return s;
    return s
        .replaceAllMapped(_ipv4, (m) {
          final a = m[1]!;
          if (a == '127' || a == '10' || a == '192' || a == '172' || a == '0') return m[0]!;
          return '$a.*.*.${m[4]}';
        })
        .replaceAll(_uuid, '********-****');
  }

  void d(String msg) => add(LogLevel.debug, LogSource.app, msg);
  void i(String msg) => add(LogLevel.info, LogSource.app, msg);
  void w(String msg) => add(LogLevel.warning, LogSource.app, msg);
  void e(String msg, [Object? err]) => add(LogLevel.error, LogSource.app, err == null ? msg : '$msg: $err');

  void core(String line) {
    final lower = line.toLowerCase();
    final level = lower.contains('[error]') || lower.contains('failed')
        ? LogLevel.error
        : lower.contains('[warning]')
            ? LogLevel.warning
            : lower.contains('[debug]')
                ? LogLevel.debug
                : LogLevel.info;
    add(level, LogSource.core, line);
  }

  void add(LogLevel level, LogSource source, String message) {
    if (source == LogSource.app && level.index < minAppLevel.index) return;
    final entry = LogEntry(DateTime.now(), level, source, _mask(message.trimRight()));
    _entries.addLast(entry);
    while (_entries.length > maxLines) {
      _entries.removeFirst();
    }
    _sink?.writeln('${entry.time.toIso8601String()} [${level.name.toUpperCase()}] [${source.name}] ${entry.message}');
    if (kDebugMode && source == LogSource.app) debugPrint('[sharrow] ${entry.message}');
    _version++;
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  void clear() {
    _entries.clear();
    _version++;
    notifyListeners();
  }

  String export() => _entries
      .map((e) => '${e.time.toIso8601String()} [${e.level.name.toUpperCase()}] [${e.source.name}] ${e.message}')
      .join('\n');

  Future<void> setFileLogging(bool enabled, {int keepDays = 7}) async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    if (!enabled) return;
    _cleanup(keepDays);
    final now = DateTime.now();
    final name = 'sharrow-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.log';
    _sink = File(AppPaths.join(AppPaths.logs, name)).openWrite(mode: FileMode.append);
  }

  void _cleanup(int keepDays) {
    try {
      final limit = DateTime.now().subtract(Duration(days: keepDays));
      for (final f in AppPaths.logs.listSync().whereType<File>()) {
        if (f.statSync().modified.isBefore(limit)) f.deleteSync();
      }
    } catch (_) {}
  }

  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
  }
}

final log = LogService.instance;
