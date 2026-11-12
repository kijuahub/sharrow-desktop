import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static const fonts = {'inter': 'Inter', 'onest': 'Onest', 'manrope': 'Manrope'};
  static const mono = 'monospace';
  static const monoFallback = ['Cascadia Mono', 'Consolas', 'SF Mono', 'Menlo', 'JetBrains Mono', 'DejaVu Sans Mono'];

  static ThemeData build(
    Brightness brightness,
    Color accent, {
    bool amoled = false,
    String font = 'Inter',
    String theme = 'dark',
    bool glassStyle = false,
    int bg = 0,
    int sidebar = 0,
    int surface = 0,
    int textColor = 0,
  }) {
    final preset = themePreset(theme);
    var c = preset != null
        ? SColors.tinted(Color(preset.bg), accent)
        : brightness == Brightness.light
            ? SColors.light(accent)
            : (amoled ? SColors.black(accent) : SColors.dark(accent));
    if (glassStyle) c = c.withGlass();
    if (bg != 0 || sidebar != 0 || surface != 0 || textColor != 0) {
      c = c.recolor(
        bg: bg == 0 ? null : Color(bg),
        sidebar: sidebar == 0 ? null : Color(sidebar),
        surface: surface == 0 ? null : Color(surface),
        text: textColor == 0 ? null : Color(textColor),
      );
    }
    final sheet = glassStyle ? (c.isDark ? const Color(0xE6181A20) : const Color(0xF4FFFFFF)) : c.surface;
    final fieldRadius = glassStyle ? 16.0 : Radii.md;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.text,
      error: c.danger,
      outline: c.border,
      outlineVariant: c.border,
    );

    TextStyle s(double size, FontWeight w, {double ls = 0, Color? color, double h = 1.3}) =>
        TextStyle(fontFamily: font, fontSize: size, fontWeight: w, letterSpacing: ls, color: color ?? c.text, height: h);

    final text = TextTheme(
      displaySmall: s(30, FontWeight.w600, ls: -0.8, h: 1.15),
      headlineMedium: s(24, FontWeight.w600, ls: -0.6, h: 1.2),
      headlineSmall: s(20, FontWeight.w600, ls: -0.4, h: 1.2),
      titleLarge: s(17, FontWeight.w600, ls: -0.3),
      titleMedium: s(14.5, FontWeight.w600, ls: -0.15),
      titleSmall: s(13, FontWeight.w600, ls: -0.05),
      bodyLarge: s(14.5, FontWeight.w400, ls: -0.1, h: 1.45),
      bodyMedium: s(13, FontWeight.w400, h: 1.4),
      bodySmall: s(12, FontWeight.w400, color: c.textSec, h: 1.35),
      labelLarge: s(13, FontWeight.w500),
      labelMedium: s(12, FontWeight.w500, color: c.textSec),
      labelSmall: s(10.5, FontWeight.w600, ls: 0.4, color: c.textTer),
    );

    final hairline = BorderSide(color: c.border, width: 1);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: font,
      colorScheme: scheme,
      textTheme: text,
      extensions: [c],
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.hover,
      focusColor: c.accent.withValues(alpha: 0.18),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textSec, size: 18),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        textStyle: s(11.5, FontWeight.w500, color: c.text),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: c.surfaceHi,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: glassStyle ? null : Border.fromBorderSide(hairline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(glassStyle ? 16 : Radii.md),
          side: glassStyle ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        textStyle: text.bodyMedium,
        labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(glassStyle ? sheet : c.surfaceHi),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(glassStyle ? 16 : Radii.md), side: glassStyle ? BorderSide.none : hairline)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        elevation: glassStyle ? 0 : 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(glassStyle ? 28 : Radii.xl), side: glassStyle ? BorderSide.none : hairline),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textSec),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(glassStyle ? 28 : Radii.xl))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: glassStyle ? sheet : c.surfaceHi,
        contentTextStyle: text.bodyMedium,
        elevation: 8,
        width: 380,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(glassStyle ? 18 : Radii.md), side: glassStyle ? BorderSide.none : hairline),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(4),
        thumbColor: WidgetStatePropertyAll(c.textTer.withValues(alpha: 0.45)),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.28),
        selectionHandleColor: c.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassStyle ? c.glass : c.surfaceHi,
        isDense: true,
        hintStyle: text.bodyMedium?.copyWith(color: c.textTer),
        labelStyle: text.bodyMedium?.copyWith(color: c.textSec),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: glassStyle ? BorderSide.none : hairline),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: c.accent.withValues(alpha: 0.8), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius), borderSide: BorderSide(color: c.danger, width: 1.2)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
        thumbColor: WidgetStateProperty.resolveWith((st) {
          if (st.contains(WidgetState.disabled)) return c.textTer;
          return st.contains(WidgetState.selected) ? c.onAccent : (c.isDark ? const Color(0xFFBFC2C9) : Colors.white);
        }),
        trackColor: WidgetStateProperty.resolveWith((st) {
          if (st.contains(WidgetState.selected)) return c.accent;
          if (glassStyle) return c.isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EB);
          return c.isDark ? const Color(0xFF2A2B31) : const Color(0xFFDCDDE1);
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceHi,
        thumbColor: c.isDark ? Colors.white : c.accent,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 1),
        valueIndicatorColor: c.surfaceHi,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(color: c.text),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: c.borderStrong, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? c.accent : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onAccent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.surfaceHi, circularTrackColor: Colors.transparent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.accent, brightness: brightness),
    );
  }
}
