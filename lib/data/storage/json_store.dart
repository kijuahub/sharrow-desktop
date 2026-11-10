import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'paths.dart';

/// Plain JSON file with debounced atomic writes (used for non-secret settings).
class JsonStore {
  JsonStore(String name) : _file = AppPaths.file(name);

  final File _file;
  Timer? _debounce;
  Map<String, Object?>? _pending;

  Map<String, Object?> read() {
    try {
      if (!_file.existsSync()) return {};
      final data = jsonDecode(_file.readAsStringSync());
      return data is Map ? Map<String, Object?>.from(data) : {};
    } catch (_) {
      return {};
    }
  }

  void write(Map<String, Object?> data, {Duration delay = const Duration(milliseconds: 400)}) {
    _pending = data;
    _debounce?.cancel();
    _debounce = Timer(delay, flush);
  }

  void flush() {
    _debounce?.cancel();
    final data = _pending;
    if (data == null) return;
    _pending = null;
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    tmp.renameSync(_file.path);
  }
}
