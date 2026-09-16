import 'package:collection/collection.dart';

import 'cards.dart';
import 'errors.dart';
import 'events.dart';
import 'game_state.dart';
import 'internal.dart';
import 'model.dart';
import 'round.dart';
import 'rules.dart';
import 'weis_phase.dart';

/// Spielt eine Karte aus. Ist der Stich voll, wird er sofort ausgewertet.
GameState playCard(GameState state, int playerIndex, JassCard card, List<GameEvent> events) {
  requirePhase(state, const {GamePhase.playing});
  requireTurn(state, playerIndex);

  final player = state.players[playerIndex];
  if (!player.hand.contains(card)) {
    throw GameRuleException(RuleViolation.cardNotInHand, card.id);
  }
  if (!playableCards(state, playerIndex).contains(card)) {
    throw GameRuleException(RuleViolation.cardNotAllowed, card.id);
  }

  events.add(CardPlayed(playerIndex, card));
  var next = state.copyWith(
    players: replacedAt(
      state.players,
      playerIndex,
      player.copyWith(hand: [...player.hand]..remove(card)),
    ),
    trick: [...state.trick, TrickEntry(playerIndex, card)],
    playedCards: [...state.playedCards, card],
  );

  // Stöck wird angesagt, sobald die zweite der beiden Karten gespielt ist.
  if (playerIndex == next.stoeckPlayer && !next.stoeckAnnounced) {
    final played = next.playedCards.toSet();
    if (stoeckCards(next.roundMode!).every(played.contains)) {
      next = announceStoeck(next, inWeis: false, events: events);
    }
  }

  if (next.trick.length == next.players.length) {
    return _resolveTrick(next, events);
  }
  return next.copyWith(currentPlayer: nextPlayerIndex(next, playerIndex));
}

/// Raeumt den ausgewerteten Stich ab; der Gewinner spielt aus.
GameState nextTrick(GameState state, List<GameEvent> events) {
  requirePhase(state, const {GamePhase.trickEnd});
  events.add(NextTrickStarted(state.trickLeader));
  return state.copyWith(
    trick: const [],
    currentPlayer: state.trickLeader,
    phase: GamePhase.playing,
  );
}

GameState _resolveTrick(GameState state, List<GameEvent> events) {
  // Gestochen wird nach der Spielart des Stichs (im Slalom wechselnd),
  // gezaehlt nach der angesagten Spielart der Runde: So ergeben die Karten
  // einer Runde immer 152 Punkte, mit dem letzten Stich 157.
  final winner = trickWinner(state.trick, state.trickMode);
  final pileId = pileIdForWinner(state, winner);
  final isLastTrick = state.trickNumber == state.variant.handSize - 1;
  final points =
      trickPoints(state.trick, state.roundMode) + (isLastTrick ? state.rules.lastTrickBonus : 0);
  final winningPlayer = state.players[winner];

  events.add(
    TrickWon(
      winner: winner,
      pileId: pileId,
      points: points,
      trickNumber: state.trickNumber + 1,
      cards: state.trick,
      isLastTrick: isLastTrick,
    ),
  );

  final captured = CapturedTrick(pileId: pileId, winner: winner, cards: state.trick);
  final next = state.copyWith(
    players: replacedAt(
      state.players,
      winner,
      winningPlayer.copyWith(
        tricksWon: winningPlayer.tricksWon + 1,
        pointsWon: winningPlayer.pointsWon + points,
      ),
    ),
    capturedPileOwners: replacedAt(state.capturedPileOwners, pileId, winner),
    firstCapturedTrick: state.trickNumber == 0 ? captured : state.firstCapturedTrick,
    roundTricks: [...state.roundTricks, captured],
    capturedCards: replacedAt(state.capturedCards, pileId, [
      ...state.capturedCards[pileId],
      for (final entry in state.trick) entry.card,
    ]),
    capturedTricks: replacedAt(state.capturedTricks, pileId, state.capturedTricks[pileId] + 1),
    lastCapturedPile: pileId,
    trickNumber: state.trickNumber + 1,
    trickLeader: winner,
    phase: GamePhase.trickEnd,
  );

  if (isLastTrick || _bedanken(next) || _bieterDecided(next)) {
    return _resolveRound(next, events);
  }
  return next;
}

/// Bieterjass: Die Partie endet mit dem Stich, in dem eine Seite ihr Ziel
/// erreicht - der Bieter sein Gebot oder die beiden anderen das Punkteziel.
bool _bieterDecided(GameState state) {
  if (!state.isBieter) {
    return false;
  }
  final multiplier = state.roundMultiplier;
  final solo = state.players[state.soloPlayer];
  return solo.totalScore + solo.pointsWon * multiplier >= state.soloTarget ||
      state.pairScore + state.pairRoundPoints * multiplier >= state.pairTarget;
}

/// Bedanken: Im Schieber endet die Partie sofort, sobald ein Team mit den
/// bisherigen Punkten der Runde das Ziel erreicht.
bool _bedanken(GameState state) {
  if (!state.isSchieber || !state.rules.bedanken) {
    return false;
  }
  return state.teams.any(
    (team) => team.totalScore + schieberTeamResult(state, team.id).roundPoints >= state.targetScore,
  );
}

GameState _resolveRound(GameState state, List<GameEvent> events) {
  final scored = state.isBieter ? _resolveBieterRound(state) : _resolveSchieberRound(state);
  final summary = scored.roundSummary!;
  events.add(RoundScored(summary));

  final entry = RoundHistoryEntry(
    roundNumber: scored.roundNumber,
    dealer: scored.dealer,
    totals: scored.isSchieber
        ? {for (final team in scored.teams) team.id: team.totalScore}
        : {for (final player in scored.players) player.id: player.totalScore},
    summary: summary,
  );

  if (scored.phase == GamePhase.gameOver) {
    events.add(switch (summary) {
      SchieberRoundSummary() => GameOver(
        variant: scored.variant,
        winnerTeam: maxBy(scored.teams, (Team team) => team.totalScore)!.id,
      ),
      // Der Bieter ist Team 0, die beiden anderen sind Team 1.
      BieterRoundSummary(:final soloWon, :final soloPlayer) => GameOver(
        variant: scored.variant,
        winnerPlayer: soloWon ? soloPlayer : null,
        winnerTeam: soloWon ? 0 : 1,
      ),
    });
  }
  return scored.copyWith(roundHistory: [...scored.roundHistory, entry]);
}

GameState _resolveBieterRound(GameState state) {
  final multiplier = state.roundMultiplier;
  final solo = state.players[state.soloPlayer];
  final soloPoints = solo.pointsWon * multiplier;
  final pairPoints = state.pairRoundPoints * multiplier;
  final soloTotal = solo.totalScore + soloPoints;
  final pairTotal = state.pairScore + pairPoints;

  // Die beiden anderen fuehren einen gemeinsamen Stand; er steht bei beiden.
  final players = [
    for (final player in state.players)
      player.copyWith(totalScore: player.id == state.soloPlayer ? soloTotal : pairTotal),
  ];
  final summary = BieterRoundSummary(
    roundMode: state.roundMode!,
    multiplier: multiplier,
    soloPlayer: state.soloPlayer,
    bid: state.soloTarget,
    soloPoints: soloPoints,
    pairPoints: pairPoints,
    soloTotal: soloTotal,
    pairTotal: pairTotal,
    pairTarget: state.pairTarget,
  );

  return state.copyWith(
    players: players,
    roundSummary: summary,
    phase: summary.soloWon || summary.pairWon ? GamePhase.gameOver : GamePhase.roundEnd,
  );
}

GameState _resolveSchieberRound(GameState state) {
  final multiplier = state.roundMultiplier;

  final results = [for (final team in state.teams) schieberTeamResult(state, team.id)];
  final resultByTeam = {for (final result in results) result.teamId: result};
  final teams = [
    for (final team in state.teams)
      team.copyWith(totalScore: team.totalScore + resultByTeam[team.id]!.roundPoints),
  ];

  final rankedTeams = [...teams];
  mergeSort(
    rankedTeams,
    compare: (Team first, Team second) {
      if (first.totalScore != second.totalScore) {
        return second.totalScore - first.totalScore;
      }
      return _compareRoundResults(resultByTeam[first.id]!, resultByTeam[second.id]!);
    },
  );
  final rankedResults = [...results];
  mergeSort(rankedResults, compare: _compareRoundResults);

  return state.copyWith(
    teams: teams,
    roundSummary: SchieberRoundSummary(
      roundMode: state.roundMode!,
      multiplier: multiplier,
      results: results,
      roundWinnerTeamId: rankedResults.first.teamId,
      trumpChooser: state.chooserPlayer,
      pushed: state.trumpWasPushed,
      targetScore: state.targetScore,
      weisWinnerTeamId: state.weisState?.awardedTeamId,
      highestWeis: state.weisState?.winningDeclaration?.weis,
      stoeckPlayer: state.stoeckPlayer,
      matchTeamId: results.firstWhereOrNull((result) => result.matchPoints > 0)?.teamId,
    ),
    phase: rankedTeams.first.totalScore >= state.targetScore
        ? GamePhase.gameOver
        : GamePhase.roundEnd,
  );
}

int _compareRoundResults(TeamRoundResult first, TeamRoundResult second) {
  if (first.roundPoints != second.roundPoints) {
    return second.roundPoints - first.roundPoints;
  }
  if (first.basePoints != second.basePoints) {
    return second.basePoints - first.basePoints;
  }
  if (first.tricksWon != second.tricksWon) {
    return second.tricksWon - first.tricksWon;
  }
  return first.teamId - second.teamId;
}
