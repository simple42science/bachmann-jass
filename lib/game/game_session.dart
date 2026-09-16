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
    this.canUndo = false,
    this.showingLastTrick = false,
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

  /// Der letzte eigene Zug laesst sich zuruecknehmen.
  final bool canUndo;

  /// Die Runde ist abgerechnet, aber der letzte Stich liegt noch auf dem Tisch.
  final bool showingLastTrick;

  /// Der Mensch (Sitz 0) ist an der Reihe und darf handeln.
  bool get humanTurn => state.isInteractive && state.players[state.currentPlayer].isHuman;

  GameSession copyWith({bool? paused, bool? waiting, bool? canUndo, bool? showingLastTrick}) =>
      GameSession(
        state: state,
        events: events,
        roundEvents: roundEvents,
        revision: revision,
        paused: paused ?? this.paused,
        waiting: waiting ?? this.waiting,
        canUndo: canUndo ?? this.canUndo,
        showingLastTrick: showingLastTrick ?? this.showingLastTrick,
      );
}

/// Hat der Mensch (Sitz 0) die Partie gewonnen?
bool humanWon(GameState game, GameOver event) =>
    game.isSchieber ? event.winnerTeam == game.players[0].teamId : event.winnerPlayer == 0;

/// Der Spieler, dessen Jubel in `assets/sounds/` liegt.
const String cheeringPlayer = 'Yannick';

/// Hat ein Spieler namens Yannick gewonnen, allein oder mit seinem Team?
/// Gilt fuer den Computer "Yannick" wie fuer einen Menschen dieses Namens.
bool cheeringPlayerWon(GameState game, GameOver event) {
  for (var index = 0; index < game.players.length; index += 1) {
    final player = game.players[index];
    if (player.name.trim().toLowerCase() != cheeringPlayer.toLowerCase()) {
      continue;
    }
    if (game.isSchieber ? player.teamId == event.winnerTeam : index == event.winnerPlayer) {
      return true;
    }
  }
  return false;
}
