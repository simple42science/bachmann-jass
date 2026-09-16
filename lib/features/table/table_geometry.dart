import 'dart:math' as math;
import 'dart:ui';

import 'package:jass_engine/jass_engine.dart';

/// Sitzplatz am Tisch, aus Sicht des Menschen (Sitz 0 unten).
enum Seat { bottom, left, top, right }

/// Sitzplaetze je Jassart, wie in der Web-App: der Partner sitzt gegenueber.
Map<int, Seat> seatsFor(GameVariant variant) => switch (variant) {
  GameVariant.bieter => const {0: Seat.bottom, 1: Seat.left, 2: Seat.right},
  GameVariant.schieber => const {0: Seat.bottom, 1: Seat.left, 2: Seat.top, 3: Seat.right},
};

/// Seitenverhaeltnis der Kartenbilder (720 x 1124 Pixel).
const double cardAspect = 1124 / 720;

/// Faecher-Neigung (Bogenmass) und Absenkung einer Karte, wie in der Web-App.
({double angle, double drop}) fanTransform(int index, int count) {
  final offset = index - (count - 1) / 2;
  final angle = (offset * 4.2).clamp(-22.0, 22.0) * math.pi / 180;
  return (angle: angle, drop: offset.abs() * 2.8);
}

/// Berechnet aus der verfuegbaren Flaeche alle Groessen und Positionen des
/// Tisches: Handkarten, Sitzplaetze der Computer, Stichmitte und Panelbereich.
///
/// Ersetzt die CSS-Breakpoints der Web-App durch eine einzige Rechnung, die
/// 3er- und 4er-Tisch, Hoch- und Querformat und alle Bildschirmgroessen abdeckt.
final class TableGeometry {
  TableGeometry._({
    required this.size,
    required this.variant,
    required this.compact,
    required this.cardSize,
    required this.handStep,
    required this.handRect,
    required this.aiCardSize,
    required this.aiStep,
    required this.zones,
    required this.center,
    required this.statusRect,
    required this.panelRect,
    required this.trickCardSize,
    required this.trickSlots,
  });

  factory TableGeometry.compute({required Size size, required GameVariant variant}) {
    const pad = 8.0;
    final handSize = variant.handSize;
    final landscape = size.width > size.height;
    final compact = size.height < 420;
    // Zwei Zeilen Hinweistext brauchen Platz; im Querformat auf dem Handy nur eine.
    final statusHeight = compact ? 30.0 : 62.0;

    // Eigene Hand: so breit, dass alle Karten mit Ueberlappung Platz haben,
    // aber nie hoeher als ein Fuenftel (hoch) bzw. knapp ein Drittel (quer).
    final visible = handSize >= 12 ? 0.38 : 0.44;
    final widthBound = (size.width - 2 * pad - 12) / (1 + (handSize - 1) * visible);
    final heightBound = size.height * (landscape ? (compact ? 0.26 : 0.30) : 0.21) / cardAspect;
    final cardWidth = math.min(widthBound, heightBound).clamp(40.0, 150.0);
    final cardSize = Size(cardWidth, cardWidth * cardAspect);
    final lift = cardSize.height * 0.12;
    // Die aeusseren Karten sind geneigt und abgesenkt; ihre unteren Ecken
    // ragen darum unter die Kartenhoehe hinaus.
    final fan = fanTransform(0, handSize);
    final fanExtra = fan.drop + cardWidth / 2 * math.sin(fan.angle.abs());
    final handHeight = labelHeight + cardSize.height + lift + fanExtra + pad;
    final handRect = Rect.fromLTWH(0, size.height - handHeight, size.width, handHeight);

    // Verdeckte Haende der Computer.
    final aiCardWidth = (cardWidth * (compact ? 0.42 : 0.5)).clamp(22.0, 60.0);
    final aiCardSize = Size(aiCardWidth, aiCardWidth * cardAspect);

    final seats = seatsFor(variant);
    final hasTop = seats.containsValue(Seat.top);
    final zones = <Seat, Rect>{};
    var zoneTop = pad;
    if (hasTop) {
      // Bei wenig Hoehe steht das Namensschild neben dem Faecher statt darueber.
      final topHeight = compact
          ? math.max(labelHeight, aiCardSize.height + 8)
          : labelHeight + 4 + aiCardSize.height + 8;
      final topZone = Rect.fromLTWH(0, pad, size.width, topHeight);
      zones[Seat.top] = topZone;
      zoneTop = topZone.bottom + 4;
    }
    final sideWidth = math.max(aiCardSize.height, 64.0) + pad;
    final sideHeight = math.max(0.0, handRect.top - zoneTop - 4);
    // Der seitliche Faecher steht senkrecht unter dem Namensschild; bei wenig
    // Hoehe ruecken seine Karten enger zusammen, notfalls zu einem Stapel.
    final fanRoom = sideHeight - labelHeight - 8 - aiCardWidth;
    final aiStep = (fanRoom / math.max(1, handSize - 1)).clamp(0.0, aiCardWidth * 0.3);
    zones[Seat.left] = Rect.fromLTWH(pad, zoneTop, sideWidth, sideHeight);
    zones[Seat.right] = Rect.fromLTWH(size.width - pad - sideWidth, zoneTop, sideWidth, sideHeight);
    zones[Seat.bottom] = handRect;

    final center = Rect.fromLTRB(
      zones[Seat.left]!.right + pad,
      zoneTop,
      zones[Seat.right]!.left - pad,
      handRect.top - 4,
    );
    final statusRect = Rect.fromLTWH(center.left, center.top, center.width, statusHeight);
    // Bei wenig Hoehe darf ein Panel den Sitz gegenueber verdecken; die eigene
    // Hand bleibt frei, damit man beim Entscheiden die Karten sieht.
    final panelRect = Rect.fromLTRB(
      pad,
      compact ? pad + 2 : zoneTop,
      size.width - pad,
      handRect.top - 4,
    );

    // Stich in der Mitte: drei Karten nebeneinander, gut zwei uebereinander.
    // Reicht die Hoehe nicht, ruecken die Karten zusammen und ueberlappen.
    final trickArea = Rect.fromLTRB(center.left, statusRect.bottom, center.right, center.bottom);
    final trickWidth = math
        .min(trickArea.width / 3.4, trickArea.height / (cardAspect * 2.2))
        .clamp(30.0, cardWidth * 1.1);
    final trickCardSize = Size(trickWidth, trickWidth * cardAspect);
    final c = trickArea.center;
    final d = trickCardSize.height * 0.62;
    final vy = math.min(d * 0.9, math.max(0.0, (trickArea.height - trickCardSize.height) / 2));
    final vx = math.min(d * 1.1, math.max(0.0, (trickArea.width - trickCardSize.width) / 2));
    final trickSlots = hasTop
        ? {
            Seat.bottom: c + Offset(0, vy),
            Seat.top: c + Offset(0, -vy),
            Seat.left: c + Offset(-vx, 0),
            Seat.right: c + Offset(vx, 0),
          }
        : {
            Seat.bottom: c + Offset(0, vy * 0.9),
            Seat.left: c + Offset(-vx * 0.9, -vy * 0.5),
            Seat.right: c + Offset(vx * 0.9, -vy * 0.5),
          };

    return TableGeometry._(
      size: size,
      variant: variant,
      compact: compact,
      cardSize: cardSize,
      handStep: cardWidth * visible,
      handRect: handRect,
      aiCardSize: aiCardSize,
      aiStep: aiStep,
      zones: zones,
      center: center,
      statusRect: statusRect,
      panelRect: panelRect,
      trickCardSize: trickCardSize,
      trickSlots: trickSlots,
    );
  }

  /// Hoehe eines Namensschilds.
  static const double labelHeight = 28;

  final Size size;
  final GameVariant variant;

  /// Wenig Hoehe (Handy im Querformat): engere Abstaende, Schilder neben den Faechern.
  final bool compact;

  /// Handkarte des Menschen.
  final Size cardSize;

  /// Abstand zwischen zwei Handkarten (sichtbarer Teil).
  final double handStep;

  /// Eigener Bereich unten: Namensschild plus Hand.
  final Rect handRect;

  /// Verdeckte Karte eines Computers.
  final Size aiCardSize;
  final double aiStep;

  /// Bereich je Sitzplatz (unten: die eigene Hand).
  final Map<Seat, Rect> zones;

  /// Freie Mitte zwischen den Sitzplaetzen.
  final Rect center;

  /// Hinweiszeile am oberen Rand der Mitte.
  final Rect statusRect;

  /// Bereich fuer Bedien-Panels (ueber die ganze Breite).
  final Rect panelRect;

  final Size trickCardSize;

  /// Mittelpunkt der gespielten Karte je Sitzplatz.
  final Map<Seat, Offset> trickSlots;

  bool get landscape => size.width > size.height;

  /// Hoehe der Hand ohne Namensschild.
  double get handHeight => handRect.height - labelHeight;

  /// Breite der eigenen Hand mit allen Karten.
  double handWidth(int cards) => cards == 0 ? 0 : cardSize.width + (cards - 1) * handStep;

  /// Laenge eines verdeckten Faechers mit [cards] Karten.
  double aiFanLength(int cards) => cards == 0 ? 0 : aiCardSize.width + (cards - 1) * aiStep;
}
