import 'dart:ui' show PlatformDispatcher;

/// Lightweight bilingual strings: every call site carries both variants,
/// so there is no lookup table to keep in sync.
abstract final class L10n {
  static String _lang = 'ru';

  static String get lang => _lang;

  static void apply(String setting) {
    if (setting == 'system') {
      final code = PlatformDispatcher.instance.locale.languageCode;
      _lang = const {'ru', 'uk', 'be', 'kk'}.contains(code) ? 'ru' : 'en';
    } else {
      _lang = setting == 'en' ? 'en' : 'ru';
    }
  }

  static bool get isRu => _lang == 'ru';
}

String tr(String ru, String en) => L10n.isRu ? ru : en;
