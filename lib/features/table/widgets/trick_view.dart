import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jass_engine/jass_engine.dart';

import '../motion.dart';
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
///
/// Neue Karten fliegen vom Sitzplatz des Spielers herein; ein abgeraeumter
/// Stich gleitet zum Gewinner und verschwindet dort.
class TrickView extends StatefulWidget {
  const TrickView({
    super.key,
    required this.geometry,
    required this.trick,
    required this.seats,
    required this.motion,
    required this.collectTo,
    this.winner,
  });

  final TableGeometry geometry;
  final List<TrickEntry> trick;
  final Map<int, Seat> seats;
  final Motion motion;

  /// Sitz, zu dem ein abgeraeumter Stich fliegt (der Gewinner).
  final Seat collectTo;

  /// Gewinner des ausgewerteten Stichs, dessen Karte hervorgehoben wird.
  final int? winner;

  @override
  State<TrickView> createState() => _TrickViewState();
}

class _TrickViewState extends State<TrickView> with SingleTickerProviderStateMixin {
  late final AnimationController _collect = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _leaving = const []);
      }
    });
  List<TrickEntry> _leaving = const [];
  Seat _leaveTarget = Seat.bottom;

  @override
  void didUpdateWidget(TrickView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trick.isNotEmpty && widget.trick.isEmpty && widget.motion.enabled) {
      _leaving = oldWidget.trick;
      _leaveTarget = widget.collectTo;
      _collect
        ..duration = widget.motion.ms(520)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _collect.dispose();
    super.dispose();
  }

  Offset _seatOrigin(Seat seat) {
    final zone = widget.geometry.zones[seat]!;
    return seat == Seat.bottom ? Offset(zone.center.dx, zone.top + zone.height * 0.6) : zone.center;
  }

  Offset _restingTopLeft(TrickEntry entry, int index) {
    final size = widget.geometry.trickCardSize;
    final slot = widget.geometry.trickSlots[widget.seats[entry.playerIndex]]!;
    final offset = _trickOffsets[index % _trickOffsets.length];
    return Offset(
      slot.dx - size.width / 2 + offset.x * size.width,
      slot.dy - size.height / 2 + offset.y * size.width,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.geometry.trickCardSize;
    final target = _seatOrigin(_leaveTarget);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Abgeraeumter Stich auf dem Weg zum Gewinner.
        if (_leaving.isNotEmpty)
          AnimatedBuilder(
            animation: _collect,
            builder: (context, _) {
              final t = Curves.easeInCubic.transform(_collect.value);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < _leaving.length; index += 1)
                    () {
                      final from = _restingTopLeft(_leaving[index], index);
                      final to = Offset(target.dx - size.width / 2, target.dy - size.height / 2);
                      final position = Offset.lerp(from, to, t)!;
                      return Positioned(
                        left: position.dx,
                        top: position.dy,
                        child: Opacity(
                          opacity: 1 - Curves.easeIn.transform(_collect.value) * 0.9,
                          child: Transform.scale(
                            scale: 1 - 0.5 * t,
                            child: PlayingCardView(card: _leaving[index].card, size: size),
                          ),
                        ),
                      );
                    }(),
                ],
              );
            },
          ),
        for (var index = 0; index < widget.trick.length; index += 1)
          () {
            final entry = widget.trick[index];
            final position = _restingTopLeft(entry, index);
            final offset = _trickOffsets[index % _trickOffsets.length];
            final seat = widget.seats[entry.playerIndex]!;
            final origin = _seatOrigin(seat);
            final highlighted = widget.winner == entry.playerIndex;

            Widget card = Transform.rotate(
              angle: offset.angle * math.pi / 180,
              child: PlayingCardView(card: entry.card, size: size, highlighted: highlighted),
            );
            if (widget.motion.enabled) {
              card = card
                  .animate(key: ValueKey('fly-${entry.card.id}'))
                  .move(
                    begin: origin - position - Offset(size.width / 2, size.height / 2),
                    end: Offset.zero,
                    duration: widget.motion.ms(420),
                    curve: Curves.easeOutCubic,
                  )
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: widget.motion.ms(420),
                    curve: Curves.easeOutCubic,
                  );
              if (highlighted) {
                card = card
                    .animate(key: ValueKey('win-${entry.card.id}'))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.08, 1.08),
                      duration: widget.motion.ms(260),
                      curve: Curves.easeOut,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1 / 1.08, 1 / 1.08),
                      duration: widget.motion.ms(260),
                    );
              }
            }
            return Positioned(left: position.dx, top: position.dy, child: card);
          }(),
      ],
    );
  }
}
