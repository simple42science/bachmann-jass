import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../table_geometry.dart';
import 'playing_card_view.dart';

/// Leichte Versetzung je Reihenfolge im Stich, damit die Karten lebendig liegen.
const List<({double x, double y, double angle})> _trickOffsets = [
  (x: -0.12, y: 0.04, angle: -8),
  (x: 0.08, y: -0.05, angle: 6),
  (x: -0.02, y: 0.12, angle: -2),
  (x: 0.15, y: 0.08, angle: 10),
];

/// Die gespielten Karten des laufenden Stichs an ihren Sitzplaetzen.
class TrickView extends StatelessWidget {
  const TrickView({
    super.key,
    required this.geometry,
    required this.trick,
    required this.seats,
    this.winner,
  });

  final TableGeometry geometry;
  final List<TrickEntry> trick;
  final Map<int, Seat> seats;

  /// Gewinner des ausgewerteten Stichs, dessen Karte hervorgehoben wird.
  final int? winner;

  @override
  Widget build(BuildContext context) {
    final size = geometry.trickCardSize;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var index = 0; index < trick.length; index += 1)
          () {
            final entry = trick[index];
            final slot = geometry.trickSlots[seats[entry.playerIndex]]!;
            final offset = _trickOffsets[index % _trickOffsets.length];
            return Positioned(
              left: slot.dx - size.width / 2 + offset.x * size.width,
              top: slot.dy - size.height / 2 + offset.y * size.width,
              child: Transform.rotate(
                angle: offset.angle * math.pi / 180,
                child: PlayingCardView(
                  card: entry.card,
                  size: size,
                  highlighted: winner == entry.playerIndex,
                ),
              ),
            );
          }(),
      ],
    );
  }
}
