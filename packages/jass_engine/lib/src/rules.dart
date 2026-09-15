import 'cards.dart';
import 'game_state.dart';
import 'model.dart';
import 'round.dart';

/// Bedienpflicht nach den offiziellen Schweizer Jassregeln, fuer alle Jassarten gleich:
///
/// - die angespielte Farbe muss bedient werden
/// - Trumpf darf jederzeit gespielt werden, auch wenn man bedienen koennte
/// - Untertrumpfen ist verboten, ausser man haelt nur noch Trumpf
/// - wird Trumpf angespielt, muss Trumpf bedient werden; einzige Ausnahme ist
///   der Puur (Trumpf-Under) als letzter verbliebener Trumpf
/// - wer nicht bedienen kann, darf abwerfen (kein Trumpfzwang)
///
/// [trickMode] ist die Spielart des laufenden Stichs. Die Reihenfolge der
/// Rueckgabe entspricht der Web-App, weil die Computergegner davon abhaengen.
List<JassCard> legalCards(List<JassCard> hand, List<TrickEntry> trick, RoundMode? trickMode) {
  if (trick.isEmpty) {
    return [...hand];
  }

  final ledSuit = trick.first.card.suit;
  final suited = hand.where((card) => card.suit == ledSuit).toList();
  final trump = trickMode?.trumpSuit;

  if (trump == null) {
    return suited.isNotEmpty ? suited : [...hand];
  }

  final trumps = hand.where((card) => card.suit == trump).toList();

  if (ledSuit == trump) {
    if (trumps.isEmpty) {
      return [...hand];
    }
    if (trumps.length == 1 && trumps.first.rank == Rank.under) {
      return [...hand];
    }
    return trumps;
  }

  final onlyTrumpsLeft = trumps.isNotEmpty && trumps.length == hand.length;
  final highestTrump = _highestTrump(trick, trickMode!);
  final playableTrumps = highestTrump == null || onlyTrumpsLeft
      ? trumps
      : trumps
            .where((card) => rankIndex(card, trickMode) > rankIndex(highestTrump, trickMode))
            .toList();

  if (suited.isNotEmpty) {
    return _unique([...suited, ...playableTrumps]);
  }

  final discardable = hand.where((card) => card.suit != trump);
  final legal = _unique([...discardable, ...playableTrumps]);
  return legal.isNotEmpty ? legal : [...hand];
}

/// Warum eine Karte gerade nicht gespielt werden darf.
enum PlayRestriction {
  notInHand,

  /// Die angespielte Farbe muss bedient werden.
  mustFollowSuit,

  /// Trumpf ist angespielt und es liegt noch Trumpf (nicht nur der Puur) auf der Hand.
  mustFollowTrump,

  /// Ein tieferer Trumpf darf nicht auf einen hoeheren gelegt werden.
  noUndertrump,
}

/// `null`, wenn [card] erlaubt ist; sonst der Grund fuer die Sperre.
PlayRestriction? playRestriction(
  List<JassCard> hand,
  List<TrickEntry> trick,
  RoundMode? trickMode,
  JassCard card,
) {
  if (!hand.contains(card)) {
    return PlayRestriction.notInHand;
  }
  if (legalCards(hand, trick, trickMode).contains(card)) {
    return null;
  }
  final trump = trickMode?.trumpSuit;
  if (trump != null && trick.first.card.suit == trump) {
    return PlayRestriction.mustFollowTrump;
  }
  if (trump != null && card.suit == trump) {
    return PlayRestriction.noUndertrump;
  }
  return PlayRestriction.mustFollowSuit;
}

/// Sitz des Spielers, der den (auch unvollstaendigen) Stich gerade haelt.
int trickWinner(List<TrickEntry> trick, RoundMode? trickMode) {
  final ledSuit = trick.first.card.suit;
  final trump = trickMode?.trumpSuit;
  var best = trick.first;

  for (var index = 1; index < trick.length; index += 1) {
    final entry = trick[index];
    final current = entry.card;
    final bestCard = best.card;

    if (trump != null) {
      final currentTrump = current.suit == trump;
      final bestTrump = bestCard.suit == trump;
      if (currentTrump && !bestTrump) {
        best = entry;
        continue;
      }
      if (!currentTrump && bestTrump) {
        continue;
      }
      if (currentTrump && bestTrump) {
        if (rankIndex(current, trickMode) > rankIndex(bestCard, trickMode)) {
          best = entry;
        }
        continue;
      }
    }

    if (current.suit != ledSuit) {
      continue;
    }
    if (bestCard.suit != ledSuit ||
        rankIndex(current, trickMode) > rankIndex(bestCard, trickMode)) {
      best = entry;
    }
  }

  return best.playerIndex;
}

int trickPoints(List<TrickEntry> trick, RoundMode? trickMode) =>
    trick.fold(0, (sum, entry) => sum + cardPoints(entry.card, trickMode));

int handValue(List<JassCard> hand, RoundMode? mode) =>
    hand.fold(0, (sum, card) => sum + cardPoints(card, mode));

/// Karten, die [playerIndex] im laufenden Stich spielen darf.
List<JassCard> playableCards(GameState state, int playerIndex) =>
    legalCards(state.players[playerIndex].hand, state.trick, state.trickMode);

/// Stapel 0/1: im Schieber das Team, im Bieterjass Bieter (0) gegen Verteidiger (1).
int pileIdForWinner(GameState state, int winner) {
  if (state.isSchieber) {
    return state.players[winner].teamId;
  }
  return winner == state.soloPlayer ? 0 : 1;
}

/// Partner im Schieber (gegenueber), sonst -1.
int partnerOf(GameState state, int playerIndex) =>
    state.isSchieber ? (playerIndex + 2) % state.players.length : -1;

int nextPlayerIndex(GameState state, int playerIndex) => (playerIndex + 1) % state.players.length;

/// Gleiches Team laut `teamId`, genau wie `sameSide` der Web-App.
///
/// Achtung: Im Bieterjass tragen die Sitze 1 und 2 immer dieselbe `teamId`,
/// auch wenn einer von ihnen Bieter ist. Die Computergegner der Web-App
/// verwenden trotzdem diese Funktion.
bool sameTeamId(GameState state, int first, int second) {
  if (first < 0 || second < 0) {
    return false;
  }
  return state.players[first].teamId == state.players[second].teamId;
}

/// Spielen zwei Sitze in der laufenden Runde zusammen?
///
/// Im Bieterjass stehen der Bieter allein und die beiden Verteidiger zusammen.
bool sameSide(GameState state, int first, int second) {
  if (first < 0 || second < 0) {
    return false;
  }
  if (state.variant == GameVariant.bieter && state.soloPlayer >= 0) {
    return (first == state.soloPlayer) == (second == state.soloPlayer);
  }
  return state.players[first].teamId == state.players[second].teamId;
}

/// Punkte eines Schieber-Teams in der laufenden Runde, auch vor dem Rundenende
/// (zum Beispiel fuer die Live-Anzeige).
TeamRoundResult schieberTeamResult(GameState state, int teamId) {
  final members = state.players.where((player) => player.teamId == teamId);
  final trickPointsWon = members.fold(0, (sum, player) => sum + player.pointsWon);
  final tricksWon = members.fold(0, (sum, player) => sum + player.tricksWon);
  final weisPoints = state.teamWeisScores[teamId];
  final stoeckPoints = state.teamStoeckPoints[teamId];
  // Match: ein Team holt alle Stiche der Runde.
  final matchPoints = tricksWon == state.variant.handSize ? state.rules.matchBonus : 0;
  final basePoints = trickPointsWon + weisPoints + stoeckPoints + matchPoints;

  return TeamRoundResult(
    teamId: teamId,
    trickPoints: trickPointsWon,
    weisPoints: weisPoints,
    stoeckPoints: stoeckPoints,
    matchPoints: matchPoints,
    basePoints: basePoints,
    roundPoints: basePoints * state.roundMultiplier,
    tricksWon: tricksWon,
  );
}

JassCard? _highestTrump(List<TrickEntry> trick, RoundMode trickMode) {
  JassCard? best;
  for (final entry in trick) {
    final card = entry.card;
    if (card.suit != trickMode.trumpSuit) {
      continue;
    }
    if (best == null || rankIndex(card, trickMode) > rankIndex(best, trickMode)) {
      best = card;
    }
  }
  return best;
}

List<JassCard> _unique(Iterable<JassCard> cards) {
  final seen = <JassCard>{};
  return [
    for (final card in cards)
      if (seen.add(card)) card,
  ];
}
