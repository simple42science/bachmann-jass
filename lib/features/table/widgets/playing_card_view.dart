import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';

/// Eckenradius im Verhaeltnis zur Kartenbreite, wie bei echten Jasskarten.
double cardRadius(double width) => width * 0.07;

/// Vorderseite einer Karte. Dekodiert das Bild nur in der gebrauchten Groesse,
/// gerundet auf Stufen, damit dieselbe Karte nicht in vielen Groessen im Cache liegt.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    required this.size,
    this.highlighted = false,
    this.dimmed = false,
  });

  final JassCard card;
  final Size size;
  final bool highlighted;
  final bool dimmed;

  static String assetPath(JassCard card) => 'assets/cards/${card.id}.webp';

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    final devicePixels = size.width * MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((devicePixels / 120).ceil() * 120).clamp(120, 720);

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius(size.width)),
        border: highlighted ? Border.all(color: colors.brassGlow, width: 3) : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF140A00).withValues(alpha: highlighted ? 0.6 : 0.5),
            blurRadius: highlighted ? 18 : 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: dimmed
          ? BoxDecoration(
              color: const Color(0xFF281A0A).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(cardRadius(size.width)),
            )
          : null,
      child: Image.asset(
        assetPath(card),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Rueckseite einer Karte: Burgunderrot mit doppeltem Messingrand und dem
/// Monogramm "B" der Bachmann-Karten.
class CardBackView extends StatelessWidget {
  const CardBackView({super.key, required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    final outer = (size.width / 16).clamp(1.5, 3.0);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: colors.burgundy,
        borderRadius: BorderRadius.circular(cardRadius(size.width)),
        boxShadow: const [BoxShadow(color: Color(0x80140A00), blurRadius: 8, offset: Offset(0, 4))],
      ),
      padding: EdgeInsets.all(outer),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius(size.width) * 0.7),
          border: Border.all(color: colors.brass, width: outer * 0.8),
        ),
        padding: EdgeInsets.all(outer * 0.9),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius(size.width) * 0.45),
            border: Border.all(color: colors.brass.withValues(alpha: 0.6), width: outer * 0.4),
          ),
          alignment: Alignment.center,
          child: Text(
            'B',
            style: JassFonts.serif(size: size.width * 0.5, weight: 700, color: colors.brassLight),
          ),
        ),
      ),
    );
  }
}
