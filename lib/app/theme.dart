import 'package:flutter/material.dart';

/// Farben des Tisches. Vorlaeufig aus der Web-App uebernommen; das
/// Design-System aus AP 3.2 ersetzt die Werte.
@immutable
class JassColors extends ThemeExtension<JassColors> {
  const JassColors({
    required this.felt,
    required this.feltDark,
    required this.feltEdge,
    required this.gold,
    required this.goldLight,
    required this.accent,
    required this.cream,
    required this.text,
    required this.muted,
    required this.panel,
    required this.border,
  });

  static const JassColors standard = JassColors(
    felt: Color(0xFF1A5C35),
    feltDark: Color(0xFF12351F),
    feltEdge: Color(0xFF0B2012),
    gold: Color(0xFFD5A93A),
    goldLight: Color(0xFFF1CF6D),
    accent: Color(0xFFD86B45),
    cream: Color(0xFFF5EDD8),
    text: Color(0xFFF7F2E6),
    muted: Color(0xFFBDD0BF),
    panel: Color(0xB3071A0E),
    border: Color(0x1FFFFFFF),
  );

  final Color felt;
  final Color feltDark;
  final Color feltEdge;
  final Color gold;
  final Color goldLight;
  final Color accent;
  final Color cream;
  final Color text;
  final Color muted;
  final Color panel;
  final Color border;

  @override
  JassColors copyWith() => this;

  @override
  JassColors lerp(JassColors? other, double t) => this;
}

extension JassTheme on BuildContext {
  JassColors get jass => Theme.of(this).extension<JassColors>()!;
}

ThemeData buildTheme() {
  const colors = JassColors.standard;
  final scheme = ColorScheme.dark(
    primary: colors.gold,
    onPrimary: const Color(0xFF1D1A12),
    secondary: colors.accent,
    onSecondary: Colors.white,
    surface: colors.feltDark,
    onSurface: colors.text,
    surfaceContainerHighest: colors.felt,
    outline: colors.border,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.feltEdge,
    extensions: const [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.feltEdge,
      foregroundColor: colors.text,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.gold,
        foregroundColor: const Color(0xFF1D1A12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.muted.withValues(alpha: 0.5)),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colors.goldLight),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.cream,
      contentTextStyle: const TextStyle(color: Color(0xFF1D1A12), fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
