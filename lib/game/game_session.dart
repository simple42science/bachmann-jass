import 'package:flutter/foundation.dart';
import 'package:jass_engine/jass_engine.dart';

/// Die laufende Partie aus Sicht der Oberflaeche.
@immutable
final class GameSession {
  const GameSession({
    required this.state,
    required this.events,
    required this.revision,
    this.roundEvents = const [],
    this.paused = false,
    this.waiting = false,
  });

  final GameState state;

  /// Ereignisse der letzten Aktion, fuer Animationen und Hinweise.
  final List<GameEvent> events;

  /// Alle Ereignisse seit dem Start der laufenden Runde, fuer den Verlauf.
  final List<GameEvent> roundEvents;

  /// Zaehlt jede Aktion; damit lassen sich Animationen eindeutig zuordnen.
  final int revision;

  /// Vom Spieler oder vom System angehalten; Computerzuege warten.
  final bool paused;

  /// Ein Computerzug oder das Abraeumen des Stichs ist geplant.
  final bool waiting;

  /// Der Mensch (Sitz 0) ist an der Reihe und darf handeln.
  bool get humanTurn => state.isInteractive && state.players[state.currentPlayer].isHuman;

  GameSession copyWith({bool? paused, bool? waiting}) => GameSession(
    state: state,
    events: events,
    roundEvents: roundEvents,
    revision: revision,
    paused: paused ?? this.paused,
    waiting: waiting ?? this.waiting,
  );
}
