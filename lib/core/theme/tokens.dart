import 'package:flutter/material.dart';

abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0.0, 0, 1.0);
}

class ThemePreset {
  const ThemePreset(this.id, this.bg, this.accent, this.ru, this.en);

  final String id;
  final int bg;
  final int accent;
  final String ru;
  final String en;
}

/// Tinted dark themes: deep background plus a matching accent.
const kThemePresets = <ThemePreset>[
  ThemePreset('green', 0xFF0C1610, 0xFFB6F25C, 'Зелёная', 'Green'),
  ThemePreset('blue', 0xFF0C121C, 0xFF6CB6FF, 'Синяя', 'Blue'),
  ThemePreset('lavender', 0xFF14111C, 0xFFCDB4FF, 'Лавандовая', 'Lavender'),
  ThemePreset('banana', 0xFF16140C, 0xFFFFE14A, 'Банановая', 'Banana'),
  ThemePreset('peach', 0xFF1A1210, 0xFFFFB088, 'Персиковая', 'Peach'),
];

ThemePreset? themePreset(String id) {
  for (final p in kThemePresets) {
    if (p.id == id) return p;
  }
  return null;
}

const kAccents = <int>[
  0xFF5B8CFF, // blue
  0xFF34C38F, // green
  0xFF8B7CF6, // violet
  0xFFFF8A4C, // orange
  0xFFFF5C8A, // pink
  0xFF2EC5D3, // cyan
  0xFFE7E8EA, // graphite
];

@immutable
class SColors extends ThemeExtension<SColors> {
  const SColors({
    required this.brightness,
    required this.bg,
    required this.sidebar,
    required this.surface,
    required this.surfaceHi,
    required this.hover,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSec,
    required this.textTer,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.glass,
    required this.dot,
    this.amoled = false,
    this.glassStyle = false,
  });

  final Brightness brightness;
  final bool amoled;

  /// Full frosted interface, not the floating-panel blur toggle.
  final bool glassStyle;
  final Color bg;
  final Color sidebar;
  final Color surface;
  final Color surfaceHi;
  final Color hover;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSec;
  final Color textTer;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color glass;
  final Color dot;

  bool get isDark => brightness == Brightness.dark;

  static Color _onAccent(Color accent) =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark ? Colors.white : const Color(0xFF0B0C0E);

  factory SColors.dark(Color accent) => SColors(
        brightness: Brightness.dark,
        bg: const Color(0xFF0B0C0E),
        sidebar: const Color(0xFF0E0F12),
        surface: const Color(0xFF141519),
        surfaceHi: const Color(0xFF1C1D22),
        hover: const Color(0x0DFFFFFF),
        border: const Color(0x12FFFFFF),
        borderStrong: const Color(0x22FFFFFF),
        text: const Color(0xFFF3F4F6),
        textSec: const Color(0xFF9A9DA5),
        textTer: const Color(0xFF61646C),
        accent: accent,
        onAccent: _onAccent(accent),
        success: const Color(0xFF34D399),
        warning: const Color(0xFFFBBF24),
        danger: const Color(0xFFF87171),
        glass: const Color(0xB8141519),
        dot: const Color(0xFFDADDE3),
      );

  /// Dark palette washed with [bg], used by the named color themes.
  factory SColors.tinted(Color bg, Color accent) {
    Color lift(double amount) => Color.alphaBlend(Colors.white.withValues(alpha: amount), bg);
    return SColors(
      brightness: Brightness.dark,
      bg: bg,
      sidebar: lift(0.03),
      surface: lift(0.06),
      surfaceHi: lift(0.1),
      hover: const Color(0x14FFFFFF),
      border: const Color(0x1AFFFFFF),
      borderStrong: const Color(0x30FFFFFF),
      text: const Color(0xFFF5F6F4),
      textSec: const Color(0xFFA8AFA8),
      textTer: const Color(0xFF6E756F),
      accent: accent,
      onAccent: _onAccent(accent),
      success: const Color(0xFF34D399),
      warning: const Color(0xFFFBBF24),
      danger: const Color(0xFFF87171),
      glass: bg.withValues(alpha: 0.9),
      dot: accent,
    );
  }

  /// Pure-black AMOLED variant of the dark palette.
  factory SColors.black(Color accent) => SColors(
        brightness: Brightness.dark,
        amoled: true,
        bg: const Color(0xFF000000),
        sidebar: const Color(0xFF000000),
        surface: const Color(0xFF0A0A0C),
        surfaceHi: const Color(0xFF151518),
        hover: const Color(0x0FFFFFFF),
        border: const Color(0x17FFFFFF),
        borderStrong: const Color(0x28FFFFFF),
        text: const Color(0xFFF5F5F7),
        textSec: const Color(0xFF999CA4),
        textTer: const Color(0xFF5E6168),
        accent: accent,
        onAccent: _onAccent(accent),
        success: const Color(0xFF34D399),
        warning: const Color(0xFFFBBF24),
        danger: const Color(0xFFF87171),
        glass: const Color(0xC00A0A0C),
        dot: const Color(0xFFDADDE3),
      );

  factory SColors.light(Color accent) {
    final a = accent.toARGB32() == 0xFFE7E8EA ? const Color(0xFF1D1E22) : accent;
    return SColors(
      brightness: Brightness.light,
      bg: const Color(0xFFF4F4F6),
      sidebar: const Color(0xFFEDEDF0),
      surface: const Color(0xFFFFFFFF),
      surfaceHi: const Color(0xFFF0F0F3),
      hover: const Color(0x0A000000),
      border: const Color(0x14000000),
      borderStrong: const Color(0x24000000),
      text: const Color(0xFF111215),
      textSec: const Color(0xFF6A6D75),
      textTer: const Color(0xFFA0A3AA),
      accent: a,
      onAccent: _onAccent(a),
      success: const Color(0xFF10B981),
      warning: const Color(0xFFD97706),
      danger: const Color(0xFFE5484D),
      glass: const Color(0xCCFFFFFF),
      dot: const Color(0xFF2A2C31),
    );
  }

  /// Replaces the containers a custom theme paints itself.
  SColors recolor({Color? bg, Color? sidebar, Color? surface, Color? text}) {
    final nextText = text ?? this.text;
    final nextSurface = surface ?? this.surface;
    return SColors(
      brightness: brightness,
      amoled: amoled,
      glassStyle: glassStyle,
      bg: bg ?? this.bg,
      sidebar: sidebar ?? this.sidebar,
      surface: nextSurface,
      surfaceHi: surface == null ? surfaceHi : Color.alphaBlend(Colors.white.withValues(alpha: isDark ? 0.08 : 0.4), nextSurface),
      hover: hover,
      border: border,
      borderStrong: borderStrong,
      text: nextText,
      textSec: text == null ? textSec : nextText.withValues(alpha: 0.68),
      textTer: text == null ? textTer : nextText.withValues(alpha: 0.42),
      accent: accent,
      onAccent: onAccent,
      success: success,
      warning: warning,
      danger: danger,
      glass: surface == null ? glass : nextSurface.withValues(alpha: isDark ? 0.82 : 0.92),
      dot: dot,
    );
  }

  /// Translucent surfaces so a backdrop blur reads as glass.
  SColors withGlass() => SColors(
        brightness: brightness,
        amoled: amoled,
        glassStyle: true,
        bg: bg,
        sidebar: sidebar,
        surface: isDark ? const Color(0x14FFFFFF) : const Color(0xA6FFFFFF),
        surfaceHi: isDark ? const Color(0x1FFFFFFF) : const Color(0xD6FFFFFF),
        hover: hover,
        border: const Color(0x00000000),
        borderStrong: isDark ? const Color(0x24FFFFFF) : const Color(0x24000000),
        text: text,
        textSec: textSec,
        textTer: textTer,
        accent: accent,
        onAccent: onAccent,
        success: success,
        warning: warning,
        danger: danger,
        glass: isDark ? const Color(0x1AFFFFFF) : const Color(0xB3FFFFFF),
        dot: dot,
      );

  @override
  SColors copyWith({Color? accent}) {
    final a = accent ?? this.accent;
    final base = amoled ? SColors.black(a) : (isDark ? SColors.dark(a) : SColors.light(a));
    return glassStyle ? base.withGlass() : base;
  }

  @override
  SColors lerp(ThemeExtension<SColors>? other, double t) {
    if (other is! SColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      amoled: t < 0.5 ? amoled : other.amoled,
      glassStyle: t < 0.5 ? glassStyle : other.glassStyle,
      bg: l(bg, other.bg),
      sidebar: l(sidebar, other.sidebar),
      surface: l(surface, other.surface),
      surfaceHi: l(surfaceHi, other.surfaceHi),
      hover: l(hover, other.hover),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text),
      textSec: l(textSec, other.textSec),
      textTer: l(textTer, other.textTer),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      glass: l(glass, other.glass),
      dot: l(dot, other.dot),
    );
  }
}

extension ThemeContextX on BuildContext {
  SColors get c => Theme.of(this).extension<SColors>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}
