import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';

/// Eckenradius im Verhaeltnis zur Kartenbreite, wie bei echten Jasskarten.
double cardRadius(double width) => width * 0.08;

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
        border: highlighted ? Border.all(color: colors.goldLight, width: 3) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: highlighted ? 0.45 : 0.3),
            blurRadius: highlighted ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: dimmed
          ? BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
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

/// Rueckseite einer Karte: rot mit Diagonalstreifen, wie in der Web-App.
class CardBackView extends StatelessWidget {
  const CardBackView({super.key, required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius(size.width)),
        border: Border.all(color: const Color(0xFFA62D2D), width: math1_5(size.width)),
        boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _StripesPainter(stripe: (size.width / 12).clamp(2.0, 6.0))),
    );
  }

  static double math1_5(double width) => (width / 40).clamp(1.0, 2.5);
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter({required this.stripe});

  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF8D2323));
    final paint = Paint()
      ..color = const Color(0xFF751D1D)
      ..strokeWidth = stripe;
    final extent = size.width + size.height;
    for (var x = -size.height; x < extent; x += stripe * 2) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => oldDelegate.stripe != stripe;
}
