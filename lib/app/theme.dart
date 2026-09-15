import 'package:flutter/material.dart';

/// Farben der Richtung "Stammtisch": Holz, Filz, Messing, Tischkarten aus
/// Karton und eine Schiefertafel mit Kreide.
@immutable
class JassColors extends ThemeExtension<JassColors> {
  const JassColors({
    required this.wood,
    required this.woodDark,
    required this.woodLight,
    required this.felt,
    required this.feltMid,
    required this.feltEdge,
    required this.brass,
    required this.brassLight,
    required this.brassGlow,
    required this.cream,
    required this.ink,
    required this.inkSoft,
    required this.text,
    required this.muted,
    required this.burgundy,
    required this.slate,
    required this.chalk,
    required this.danger,
  });

  static const JassColors stammtisch = JassColors(
    wood: Color(0xFF4A2E17),
    woodDark: Color(0xFF2F1C0D),
    woodLight: Color(0xFF6B4626),
    felt: Color(0xFF2F7A45),
    feltMid: Color(0xFF1F5C34),
    feltEdge: Color(0xFF174A2A),
    brass: Color(0xFFC9973A),
    brassLight: Color(0xFFE0B45A),
    brassGlow: Color(0xFFFFD982),
    cream: Color(0xFFF3E9D2),
    ink: Color(0xFF3A2410),
    inkSoft: Color(0xFF8A5A1A),
    text: Color(0xFFF3E9D2),
    muted: Color(0xFFD8C7A3),
    burgundy: Color(0xFF7A1F1F),
    slate: Color(0xFF262B2A),
    chalk: Color(0xFFF4F1E6),
    danger: Color(0xFFB8432E),
  );

  final Color wood;
  final Color woodDark;
  final Color woodLight;
  final Color felt;
  final Color feltMid;
  final Color feltEdge;
  final Color brass;
  final Color brassLight;
  final Color brassGlow;

  /// Karton der Tischkarten und heller Text.
  final Color cream;

  /// Dunkle Schrift auf Karton und Messing.
  final Color ink;
  final Color inkSoft;
  final Color text;
  final Color muted;

  /// Kartenruecken.
  final Color burgundy;

  /// Jasstafel.
  final Color slate;
  final Color chalk;
  final Color danger;

  /// Halbtransparente Holzflaeche fuer Panels ueber dem Tisch.
  Color get panel => woodDark.withValues(alpha: 0.96);

  Color get border => brass.withValues(alpha: 0.55);

  /// Holzmaserung als Farbverlauf von oben nach unten.
  LinearGradient get woodGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [wood, woodDark],
  );

  /// Messingplatte (Kopfzeile, Knoepfe).
  LinearGradient get brassGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [brassLight, const Color(0xFFB8842C)],
  );

  @override
  JassColors copyWith() => this;

  @override
  JassColors lerp(JassColors? other, double t) => this;
}

extension JassTheme on BuildContext {
  JassColors get jass => Theme.of(this).extension<JassColors>()!;
}

/// Schriften: Vollkorn (Serife fuer Namen, Zahlen und Titel), Alegreya Sans
/// (Bedienung) und Caveat (Kreide auf der Jasstafel).
abstract final class JassFonts {
  static const String display = 'Vollkorn';
  static const String body = 'AlegreyaSans';
  static const String chalk = 'Caveat';

  /// Vollkorn ist eine variable Schrift; das Gewicht laeuft ueber die wght-Achse.
  static TextStyle serif({
    double size = 16,
    double weight = 700,
    bool italic = false,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: display,
    fontSize: size,
    fontWeight: _nearest(weight),
    fontVariations: [FontVariation('wght', weight)],
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle handwriting({double size = 24, double weight = 700, Color? color}) => TextStyle(
    fontFamily: chalk,
    fontSize: size,
    fontWeight: _nearest(weight),
    fontVariations: [FontVariation('wght', weight)],
    color: color,
  );

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: body,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static FontWeight _nearest(double weight) =>
      FontWeight.values[((weight / 100).round().clamp(1, 9)) - 1];
}

ThemeData buildTheme() {
  const colors = JassColors.stammtisch;
  final scheme = ColorScheme.dark(
    primary: colors.brassLight,
    onPrimary: colors.ink,
    secondary: colors.cream,
    onSecondary: colors.ink,
    surface: colors.woodDark,
    onSurface: colors.text,
    surfaceContainerHighest: colors.wood,
    outline: colors.border,
    error: colors.danger,
  );

  final base = ThemeData(colorScheme: scheme, fontFamily: JassFonts.body);
  return base.copyWith(
    scaffoldBackgroundColor: colors.woodDark,
    extensions: const [colors],
    textTheme: base.textTheme.apply(bodyColor: colors.text, displayColor: colors.text),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.wood,
      foregroundColor: colors.text,
      elevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: colors.brass.withValues(alpha: 0.7), width: 2)),
      titleTextStyle: JassFonts.serif(size: 22, weight: 700, color: colors.brassGlow),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.brassLight,
        foregroundColor: colors.ink,
        textStyle: JassFonts.ui(size: 15, weight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 2,
        shadowColor: Colors.black,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.cream,
        textStyle: JassFonts.ui(size: 15, weight: FontWeight.w700),
        side: BorderSide(color: colors.brass.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.brassGlow,
        textStyle: JassFonts.ui(size: 14, weight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      hintStyle: JassFonts.ui(color: colors.muted.withValues(alpha: 0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.brassGlow, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.cream,
      contentTextStyle: JassFonts.ui(color: colors.ink, weight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.woodDark,
      titleTextStyle: JassFonts.serif(size: 20, color: colors.brassGlow),
      contentTextStyle: JassFonts.ui(size: 15, color: colors.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.woodDark,
      textStyle: JassFonts.ui(size: 15, color: colors.text, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
  );
}

/// Holzmaserung: feine senkrechte Linien ueber dem Holzverlauf.
class WoodGrainPainter extends CustomPainter {
  const WoodGrainPainter({required this.colors, this.spacing = 11});

  final JassColors colors;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = colors.woodGradient.createShader(Offset.zero & size),
    );
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 2;
    for (var x = 1.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grain);
    }
  }

  @override
  bool shouldRepaint(WoodGrainPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.spacing != spacing;
}

/// Hintergrund fuer alle Screens ausser dem Tisch.
class WoodBackground extends StatelessWidget {
  const WoodBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WoodGrainPainter(colors: context.jass),
      child: child,
    );
  }
}
