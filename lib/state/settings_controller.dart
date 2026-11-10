import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/models/settings.dart';
import '../data/storage/json_store.dart';

class SettingsController extends ChangeNotifier {
  final _store = JsonStore('settings.json');
  Settings _s = const Settings({});

  /// Called after a key changes, with its id.
  void Function(String id)? onChanged;

  Settings get snapshot => _s;

  T get<T>(SettingKey<T> key) => _s.get(key);

  void load() => _s = Settings(_store.read());

  void set<T>(SettingKey<T> key, T value) {
    final cur = get(key);
    if (cur == value || (cur is List && value is List && listEquals(cur, value))) return;
    _s = _s.copyWith(key.id, value);
    _store.write(_s.values);
    if (!key.id.startsWith('_')) notifyListeners();
    onChanged?.call(key.id);
  }

  void flush() => _store.flush();

  Map<String, Object?> get _userValues => Map.fromEntries(_s.values.entries.where((e) => !e.key.startsWith('_')));

  String exportJson() => const JsonEncoder.withIndent('  ').convert({'sharrowSettings': 1, 'values': _userValues});

  bool importJson(String text) {
    try {
      final data = jsonDecode(text) as Map;
      final values = Map<String, Object?>.from((data['values'] ?? data) as Map)..removeWhere((k, _) => k.startsWith('_'));
      final internal = Map.fromEntries(_s.values.entries.where((e) => e.key.startsWith('_')));
      _s = Settings({...internal, ...values});
      _store.write(_s.values);
      notifyListeners();
      onChanged?.call('*');
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    _s = Settings(Map.fromEntries(_s.values.entries.where((e) => e.key.startsWith('_'))));
    _store.write(_s.values);
    notifyListeners();
    onChanged?.call('*');
  }
}
