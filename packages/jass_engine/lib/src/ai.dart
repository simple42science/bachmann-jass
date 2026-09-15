import 'dart:math' as math;

import 'actions.dart';
import 'cards.dart';
import 'engine.dart';
import 'game_state.dart';
import 'model.dart';
import 'rule_set.dart';
import 'rules.dart';

/// Spielstrategie der Computergegner, portiert aus `ai.js` der Web-App.
///
/// Reine lokale Heuristik ohne Netzwerk. Stufen:
/// - einfach: spielt geradeaus, ohne Plan
/// - normal:  Stellungsspiel (Trumpf ziehen, schmieren, billig stechen, sparsam abwerfen)
/// - schwer:  zusaetzlich Kartengedaechtnis (sichere Stiche und sicheres Schmieren)

/// Einzeln schaltbare Abweichungen von der KI der Web-App.
final class AiTuning {
  const AiTuning({required this.correctBieterSides});

  /// Verhalten exakt wie die Web-App (fuer den Paritaetstest und Vergleiche).
  static const AiTuning webApp = AiTuning(correctBieterSides: false);

  /// Standard der App.
  static const AiTuning standard = AiTuning(correctBieterSides: true);

  /// Im Bieterjass Bieter gegen Verteidiger unterscheiden statt nach `teamId`.
  ///
  /// Die Web-App gibt den Sitzen 1 und 2 immer dieselbe `teamId`. Ihre KI
  /// schmiert darum auch dann Punkte, wenn der vermeintliche Partner der Bieter
  /// ist. Gemessen mit tool/benchmark_bieter.dart (200 Verteilungen x 3 Sitze):
  /// Siegquote 62.8 % (Zaehlweise wie im Schieber) und 66.7 % (einfach) statt 33.3 %.
  final bool correctBieterSides;
}

/// Standard fuer die App.
const AiTuning defaultAiTuning = AiTuning.standard;

/* ------------------------------------------------------------------ *
 * Handbewertung
 * ------------------------------------------------------------------ */

// Indexiert mit Rank.index: 6, 7, 8, 9, 10, Under, Ober, Koenig, Ass.
const List<int> _trumpStrength = [1, 1, 1, 14, 3, 20, 5, 7, 11];
const List<int> _sideStrength = [0, 0, 0, 1, 2, 2, 3, 5, 9];

const List<Rank> _obeAbeOrder = [
  Rank.ass,
  Rank.koenig,
  Rank.ober,
  Rank.under,
  Rank.ten,
  Rank.nine,
  Rank.eight,
  Rank.seven,
  Rank.six,
];

const int _halfRoundPoints = 78;

/// Bewertet eine Trumpffarbe aus Sicht des Ansagers.
int evaluateTrumpSuit(List<JassCard> hand, Suit suit) {
  final trumps = hand.where((card) => card.suit == suit).toList();
  var score = trumps.fold(0, (sum, card) => sum + _trumpStrength[card.rank.index]);

  if (trumps.length > 3) {
    score += (trumps.length - 3) * 6;
  } else if (trumps.length < 3) {
    score -= (3 - trumps.length) * 12;
  }

  for (final other in Suit.values.where((entry) => entry != suit)) {
    final cards = hand.where((card) => card.suit == other).toList();
    score += cards.fold(0, (sum, card) => sum + _sideStrength[card.rank.index]);
    if (cards.isEmpty) {
      score += 6;
    } else if (cards.length == 1) {
      score += 3;
    }
  }

  return math.max(0, score);
}

/// Bewertet Obe-Abe und Une-Ufe ueber die von oben bzw. unten sicheren Stiche.
int evaluateNoTrumpMode(List<JassCard> hand, RoundMode mode) {
  final order = mode == RoundMode.uneUfe ? _obeAbeOrder.reversed : _obeAbeOrder;
  var score = 0;

  for (final suit in Suit.values) {
    final ranks = {
      for (final card in hand)
        if (card.suit == suit) card.rank,
    };
    if (ranks.isEmpty) {
      continue;
    }

    var sure = 0;
    for (final rank in order) {
      if (!ranks.contains(rank)) {
        break;
      }
      sure += 1;
    }

    score += sure * 14;
    score += math.max(0, ranks.length - sure);
    if (sure == 0) {
      score -= 4;
    }
  }

  return math.max(0, score);
}

int evaluateRoundMode(List<JassCard> hand, RoundMode mode) {
  if (mode.isTrump) {
    return evaluateTrumpSuit(hand, mode.trumpSuit!);
  }
  if (mode == RoundMode.slalom) {
    // Slalom braucht beides: hohe Karten fuer Obenabe und tiefe fuer Une-Ufe.
    return ((evaluateNoTrumpMode(hand, RoundMode.obeAbe) +
                evaluateNoTrumpMode(hand, RoundMode.uneUfe)) /
            2)
        .round();
  }
  return evaluateNoTrumpMode(hand, mode);
}

/// Uebersetzt eine Handbewertung in erwartete Stichpunkte.
int estimateRoundPoints(int evaluation) => math.max(0, math.min(157, (evaluation * 1.15).round()));

/// Vorteil gegenueber einer ausgeglichenen Runde. Der Multiplikator vervielfacht
/// die Punkte beider Teams, darum zaehlt er auf die Differenz.
int modeAdvantage(List<JassCard> hand, RoundMode mode, RuleSet rules, {bool multipliers = true}) {
  final estimate = estimateRoundPoints(evaluateRoundMode(hand, mode));
  return (estimate - _halfRoundPoints) * (multipliers ? rules.multiplierFor(mode) : 1);
}

/// Beste Spielart aus einer Auswahl; bei Gleichstand die zuerst genannte.
RoundMode bestModeFrom(
  List<JassCard> hand,
  List<RoundMode> allowedModes,
  RuleSet rules, {
  bool multipliers = true,
}) => allowedModes.reduce(
  (best, mode) =>
      modeAdvantage(hand, mode, rules, multipliers: multipliers) >
          modeAdvantage(hand, best, rules, multipliers: multipliers)
      ? mode
      : best,
);

Suit bestTrumpSuit(List<JassCard> hand) => Suit.values.reduce(
  (best, suit) => evaluateTrumpSuit(hand, suit) > evaluateTrumpSuit(hand, best) ? suit : best,
);

RoundMode bestSchieberMode(List<JassCard> hand, RuleSet rules) =>
    bestModeFrom(hand, RoundMode.values, rules);

/// Geschoben wird, wenn die eigene Hand keinen Vorteil verspricht.
bool shouldPushTrump(List<JassCard> hand, RuleSet rules) =>
    modeAdvantage(hand, bestSchieberMode(hand, rules), rules) <= 0;

/// Gebot fuer den Bieterjass; `0` bedeutet passen.
int aiBidDecision(GameState state, int seat) {
  final hand = state.players[seat].hand;
  // Bewusst nur mit Trumpffarben geschaetzt, auch wenn Obe-Abe, Une-Ufe oder
  // Slalom erlaubt sind: Mit allen Spielarten bot die KI zu hoch und gewann nur
  // noch 27.2 statt 33.3 Prozent (tool/benchmark_bieter.dart, Zaehlweise wie im Schieber).
  final expectedPoints = estimateRoundPoints(evaluateTrumpSuit(hand, bestTrumpSuit(hand)));

  // Kalibriert in der Web-App: mit Faktor 1.1 liegt die Erfuellungsquote bei rund 70 Prozent.
  final estimate = (expectedPoints * 1.1).round();
  final proposed = math.min(140, (estimate ~/ 10) * 10);
  final allowed = state.rules.bidValues.where((value) => value <= proposed);
  if (allowed.isEmpty) {
    return 0;
  }
  final bid = allowed.reduce(math.max);
  return bid <= state.highestBid ? 0 : bid;
}

/* ------------------------------------------------------------------ *
 * Kartenspiel
 * ------------------------------------------------------------------ */

typedef _SideCheck = bool Function(GameState state, int first, int second);

final class _Play {
  _Play(this.state, this.seat, this.legal, this.sameSide)
    : mode = state.trickMode,
      hand = state.players[seat].hand;

  final GameState state;
  final int seat;
  final List<JassCard> legal;
  final _SideCheck sameSide;
  final RoundMode? mode;
  final List<JassCard> hand;

  bool isTrump(JassCard card) => mode?.trumpSuit != null && card.suit == mode!.trumpSuit;

  int points(JassCard card) => cardPoints(card, mode);

  int rank(JassCard card) => rankIndex(card, mode);

  int suitLength(Suit suit) => hand.where((card) => card.suit == suit).length;

  bool wouldWin(JassCard card) =>
      trickWinner([...state.trick, TrickEntry(seat, card)], mode) == seat;

  /// Karten, die weder gespielt wurden noch auf der eigenen Hand liegen.
  late final List<JassCard> unseen = [
    for (final card in JassCard.deck)
      if (!state.playedCards.contains(card) && !hand.contains(card)) card,
  ];

  /// Konservative Pruefung, ob der Stich nach dieser Karte nicht mehr zu holen ist.
  bool isTrickSafe(JassCard card, int leadingSeat) {
    final simulated = [...state.trick, TrickEntry(seat, card)];
    if (state.players.length - simulated.length <= 0) {
      return trickWinner(simulated, mode) == leadingSeat;
    }
    return unseen.every((other) => trickWinner([...simulated, TrickEntry(-1, other)], mode) != -1);
  }

  bool isHighestRemaining(JassCard card) =>
      !unseen.any((other) => other.suit == card.suit && rank(other) > rank(card));

  int pointsAscending(JassCard first, JassCard second) => points(first) - points(second);

  int pointsDescending(JassCard first, JassCard second) => points(second) - points(first);

  int rankAscending(JassCard first, JassCard second) => rank(first) - rank(second);

  int rankDescending(JassCard first, JassCard second) => rank(second) - rank(first);
}

/// Erstes Element nach stabiler Sortierung, wie `[...cards].sort(compare)[0]` in JavaScript.
JassCard _firstBy(Iterable<JassCard> cards, int Function(JassCard first, JassCard second) compare) {
  JassCard? best;
  for (final card in cards) {
    if (best == null || compare(card, best) < 0) {
      best = card;
    }
  }
  return best!;
}

JassCard _chooseLead(_Play play, {required bool useMemory}) {
  final legal = play.legal;
  final trumps = legal.where(play.isTrump).toList();

  // Als Ansager zuerst Trumpf ziehen, solange man die Kontrolle hat.
  final isChooser = play.state.chooserPlayer == play.seat || play.state.soloPlayer == play.seat;
  final strongTrump = trumps.any((card) => card.rank == Rank.under || card.rank == Rank.nine);
  if (trumps.length >= 3 || (isChooser && trumps.length >= 2 && strongTrump)) {
    return _firstBy(trumps, play.rankDescending);
  }

  if (useMemory) {
    final sureWinners = legal.where((card) => !play.isTrump(card) && play.isHighestRemaining(card));
    if (sureWinners.isNotEmpty) {
      return _firstBy(sureWinners, play.pointsDescending);
    }
  }

  final sideCards = legal.where((card) => !play.isTrump(card)).toList();
  final candidates = sideCards.isNotEmpty ? sideCards : legal;

  // Asse in Nebenfarben holen frueh die Punkte heim.
  final aces = candidates.where((card) => card.rank == Rank.ass);
  if (aces.isNotEmpty) {
    return _firstBy(
      aces,
      (first, second) => play.suitLength(second.suit) - play.suitLength(first.suit),
    );
  }

  // Sonst billig aus der kuerzesten Farbe anspielen.
  return _firstBy(candidates, (first, second) {
    final lengthDiff = play.suitLength(first.suit) - play.suitLength(second.suit);
    return lengthDiff != 0 ? lengthDiff : play.pointsAscending(first, second);
  });
}

JassCard _chooseDiscard(_Play play) {
  final keepers = play.legal.where((card) => !play.isTrump(card)).toList();
  final candidates = keepers.isNotEmpty ? keepers : play.legal;

  // Moeglichst eine Farbe leerspielen, dabei so wenig Punkte wie moeglich abgeben.
  return _firstBy(candidates, (first, second) {
    final pointDiff = play.pointsAscending(first, second);
    return pointDiff != 0 ? pointDiff : play.suitLength(first.suit) - play.suitLength(second.suit);
  });
}

JassCard _chooseSmear(_Play play) {
  final nonTrump = play.legal.where((card) => !play.isTrump(card)).toList();
  return _firstBy(nonTrump.isNotEmpty ? nonTrump : play.legal, play.pointsDescending);
}

JassCard _chooseFollow(_Play play, {required bool useMemory}) {
  final state = play.state;
  final currentWinner = trickWinner(state.trick, play.mode);
  final partnerWinning =
      play.sameSide(state, currentWinner, play.seat) && currentWinner != play.seat;
  final isLastSeat = state.trick.length == state.players.length - 1;
  final pointsAtStake = trickPoints(state.trick, play.mode);
  final winningCards = play.legal.where(play.wouldWin).toList();

  if (partnerWinning) {
    final safe = isLastSeat || (useMemory && play.isTrickSafe(_chooseSmear(play), currentWinner));
    return safe ? _chooseSmear(play) : _chooseDiscard(play);
  }

  if (winningCards.isEmpty) {
    return _chooseDiscard(play);
  }

  final cheapNonTrumpWins = winningCards.where((card) => !play.isTrump(card));
  if (cheapNonTrumpWins.isNotEmpty) {
    return _firstBy(cheapNonTrumpWins, play.rankAscending);
  }

  // Nur Trumpf gewinnt: Trumpf nicht fuer Kleinkram verheizen.
  final trumpsInHand = play.hand.where(play.isTrump).length;
  final worthTrumping = isLastSeat ? pointsAtStake >= 4 : pointsAtStake >= 10 || trumpsInHand >= 4;

  if (!worthTrumping) {
    final discard = _chooseDiscard(play);
    if (!play.isTrump(discard)) {
      return discard;
    }
  }

  return _firstBy(winningCards, play.rankAscending);
}

/// Die einfache Stufe (das urspruengliche Verhalten der Web-App).
JassCard _chooseSimple(_Play play) {
  final state = play.state;
  if (state.trick.isEmpty) {
    final trumps = play.legal.where(play.isTrump).toList();
    if (trumps.length >= 2) {
      return _firstBy(trumps, play.rankDescending);
    }
    return _firstBy(play.legal, play.rankDescending);
  }

  final currentWinner = trickWinner(state.trick, play.mode);
  final teammateWinning = play.sameSide(state, currentWinner, play.seat);
  final winningCards = play.legal.where(play.wouldWin).toList();

  if (winningCards.isNotEmpty && !teammateWinning) {
    return _firstBy(winningCards, play.pointsAscending);
  }
  if (teammateWinning) {
    return _firstBy(play.legal, play.pointsDescending);
  }
  return _firstBy(play.legal, play.pointsAscending);
}

/// Karte, die der Computer auf [seat] spielen wuerde.
///
/// Ohne [difficulty] gilt die Stufe des Spielers, sonst die der Partie.
JassCard aiChooseCard(
  GameState state,
  int seat, {
  Difficulty? difficulty,
  AiTuning tuning = defaultAiTuning,
}) {
  final level = difficulty ?? state.players[seat].difficulty ?? state.matchConfig.difficulty;
  final legal = playableCards(state, seat);
  if (legal.length == 1) {
    return legal.first;
  }

  final play = _Play(state, seat, legal, tuning.correctBieterSides ? sameSide : sameTeamId);
  if (level == Difficulty.einfach) {
    return _chooseSimple(play);
  }

  final useMemory = level == Difficulty.schwer;
  return state.trick.isEmpty
      ? _chooseLead(play, useMemory: useMemory)
      : _chooseFollow(play, useMemory: useMemory);
}

/// Naechste Aktion des Computers, der gerade am Zug ist.
///
/// Folgt dem Spielablauf der Web-App. Liefert `null` in Phasen ohne
/// Spielerentscheidung (Rundenstart, Stichende, Spielende). Mit [difficulty]
/// laesst sich die Stufe vorgeben, etwa fuer einen Tipp an den Menschen.
GameAction? aiDecide(GameState state, {AiTuning tuning = defaultAiTuning, Difficulty? difficulty}) {
  final seat = state.currentPlayer;
  final hand = state.players[seat].hand;

  switch (state.phase) {
    case GamePhase.bidding:
      final value = aiBidDecision(state, seat);
      return value == 0 ? PassBid(seat) : PlaceBid(seat, value);
    case GamePhase.chooseTrump:
      if (canPushTrump(state) && shouldPushTrump(hand, state.rules)) {
        return PushTrump(seat);
      }
      if (state.isSchieber) {
        return ChooseMode(seat, bestSchieberMode(hand, state.rules));
      }
      return ChooseMode(
        seat,
        bestModeFrom(
          hand,
          state.allowedRoundModes,
          state.rules,
          multipliers: state.usesRoundMultipliers,
        ),
      );
    case GamePhase.announceWeis:
      return DeclareWeis(seat);
    case GamePhase.playing:
      return PlayCard(seat, aiChooseCard(state, seat, tuning: tuning, difficulty: difficulty));
    case GamePhase.setup || GamePhase.trickEnd || GamePhase.roundEnd || GamePhase.gameOver:
      return null;
  }
}
