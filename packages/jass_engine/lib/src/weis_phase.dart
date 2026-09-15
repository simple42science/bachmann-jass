import 'package:collection/collection.dart';

import 'cards.dart';
import 'errors.dart';
import 'events.dart';
import 'game_state.dart';
import 'internal.dart';
import 'model.dart';
import 'round.dart';
import 'weis.dart';

/// Fuer den Weis-Vergleich zaehlt im Slalom die Spielart des ersten Stichs.
RoundMode? weisMode(GameState state) => state.roundMode?.trickMode(0);

/// Trumpf-Koenig und -Ober der laufenden Runde.
List<JassCard> stoeckCards(RoundMode mode) => [
  JassCard(mode.trumpSuit!, Rank.koenig),
  JassCard(mode.trumpSuit!, Rank.ober),
];

/// Oeffnet die Weisrunde (nur Schieber) und merkt sich, wer Stöck haelt.
/// Angesagt wird Stöck erst spaeter.
GameState startWeisPhase(GameState state, List<GameEvent> events) {
  final mode = weisMode(state);
  final playerCount = state.players.length;
  final order = [
    for (var offset = 0; offset < playerCount; offset += 1)
      (state.forehandPlayer + offset) % playerCount,
  ];

  final possible = <int, List<Weis>>{
    for (final playerIndex in order)
      playerIndex: [
        for (final weis in detectWeis(state.players[playerIndex].hand, mode, state.rules))
          weis.withPlayer(playerIndex),
      ],
  };

  return state.copyWith(
    weisState: WeisState(
      order: order,
      currentIndex: 0,
      possibleByPlayer: possible,
      highestByPlayer: {
        for (final playerIndex in order)
          playerIndex: highestWeis(possible[playerIndex]!, mode, state.rules),
      },
      declaredByPlayer: const {},
      declaredEntries: const [],
    ),
    phase: GamePhase.announceWeis,
    currentPlayer: order.first,
    stoeckPlayer: state.players.indexWhere((player) => hasStoeck(player.hand, state.roundMode)),
    stoeckAnnounced: false,
  );
}

/// Meldet [weisId] oder, ohne ID, den hoechsten Weis des Spielers.
GameState declareWeis(GameState state, int playerIndex, String? weisId, List<GameEvent> events) {
  _requireWeisTurn(state, playerIndex);
  final weisState = state.weisState!;

  Weis? selected;
  if (weisId != null) {
    selected = weisState.possibleByPlayer[playerIndex]?.firstWhereOrNull(
      (weis) => weis.id == weisId,
    );
    if (selected == null) {
      throw GameRuleException(RuleViolation.unknownWeis, weisId);
    }
  } else {
    selected = weisState.highestByPlayer[playerIndex];
  }
  return _registerDeclaration(state, playerIndex, selected, events);
}

/// Bewusster Verzicht, auch wenn ein gueltiger Weis auf der Hand liegt.
GameState declineWeis(GameState state, int playerIndex, List<GameEvent> events) {
  _requireWeisTurn(state, playerIndex);
  return _registerDeclaration(state, playerIndex, null, events);
}

/// Schreibt Stöck gut, falls es noch nicht angesagt ist.
GameState announceStoeck(GameState state, {required bool inWeis, required List<GameEvent> events}) {
  if (state.stoeckPlayer < 0 || state.stoeckAnnounced) {
    return state;
  }
  final points = state.rules.stoeckPoints;
  final teamId = state.players[state.stoeckPlayer].teamId;
  events.add(StoeckAnnounced(playerIndex: state.stoeckPlayer, points: points, inWeis: inWeis));
  return state.copyWith(
    stoeckAnnounced: true,
    teamStoeckPoints: replacedAt(state.teamStoeckPoints, teamId, points),
  );
}

void _requireWeisTurn(GameState state, int playerIndex) {
  requirePhase(state, const {GamePhase.announceWeis});
  requireTurn(state, playerIndex);
}

GameState _registerDeclaration(
  GameState state,
  int playerIndex,
  Weis? selected,
  List<GameEvent> events,
) {
  events.add(WeisDeclared(playerIndex, selected));

  var next = state;
  // Stecken beide Stöck-Karten im gemeldeten Weis, wird Stöck gleich mit angesagt.
  if (selected != null && playerIndex == state.stoeckPlayer) {
    if (stoeckCards(state.roundMode!).every(selected.cards.contains)) {
      next = announceStoeck(next, inWeis: true, events: events);
    }
  }

  final weisState = next.weisState!;
  final currentIndex = weisState.currentIndex + 1;
  next = next.copyWith(
    weisState: weisState.copyWith(
      currentIndex: currentIndex,
      declaredByPlayer: {...weisState.declaredByPlayer, playerIndex: selected},
      declaredEntries: [
        ...weisState.declaredEntries,
        WeisDeclaration(
          playerIndex: playerIndex,
          weis: selected,
          orderIndex: weisState.currentIndex,
        ),
      ],
    ),
  );

  if (currentIndex >= weisState.order.length) {
    return _finishWeisPhase(next, events);
  }
  return next.copyWith(currentPlayer: weisState.order[currentIndex]);
}

/// Nur das Team mit dem hoechsten Weis schreibt, dann aber alle Weise seiner
/// Spieler, die gemeldet haben.
GameState _finishWeisPhase(GameState state, List<GameEvent> events) {
  final weisState = state.weisState!;
  final mode = weisMode(state);
  final declared = weisState.declaredEntries.where((entry) => entry.weis != null);

  WeisDeclaration? best;
  for (final current in declared) {
    if (best == null) {
      best = current;
      continue;
    }
    final comparison = compareWeis(current.weis, best.weis, mode, state.rules);
    if (comparison > 0 || (comparison == 0 && current.orderIndex < best.orderIndex)) {
      best = current;
    }
  }

  if (best == null) {
    events.add(const NoWeisAwarded());
    return state.copyWith(phase: GamePhase.playing, currentPlayer: state.trickLeader);
  }

  final winningTeamId = state.players[best.playerIndex].teamId;
  final team = state.teams.firstWhere((entry) => entry.id == winningTeamId);
  final awarded = [
    for (final playerIndex in team.playerIds)
      if (weisState.declaredByPlayer[playerIndex] != null)
        ...?weisState.possibleByPlayer[playerIndex],
  ];
  final points = awarded.fold(0, (sum, weis) => sum + weis.points);
  final breakdown = sortWeisDescending(awarded, mode, state.rules);

  events.add(WeisAwarded(teamId: winningTeamId, points: points, weisen: breakdown, best: best));
  return state.copyWith(
    teamWeisScores: replacedAt(state.teamWeisScores, winningTeamId, points),
    teamWeisBreakdown: replacedAt(state.teamWeisBreakdown, winningTeamId, breakdown),
    weisState: weisState.copyWith(winningDeclaration: best, awardedTeamId: winningTeamId),
    phase: GamePhase.playing,
    currentPlayer: state.trickLeader,
  );
}
