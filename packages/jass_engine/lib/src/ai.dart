import 'dart:math' as math;

import 'actions.dart';
import 'cards.dart';
import 'engine.dart';
import 'game_state.dart';
import 'model.dart';
import 'rng.dart';
import 'rollout.dart';
import 'rule_set.dart';
import 'rules.dart';

/// Spielstrategie der Computergegner, portiert aus `ai.js` der Web-App und
/// mit [AiTuning.improvedPlay] weiterentwickelt.
///
/// Reine lokale Heuristik ohne Netzwerk. Spielweisen, aufsteigend:
/// - geradeaus:      ohne Plan (nur noch fuer die Paritaet mit der Web-App)
/// - Stellungsspiel: Trumpf ziehen, schmieren, billig stechen, sparsam abwerfen
/// - Gedaechtnis:    dazu sichere Stiche und sicheres Schmieren aus den
///                   gespielten Karten
/// - Stichprobe:     verteilt die unbekannten Karten mehrmals plausibel (wer
///                   eine Farbe nicht mehr hat, bekommt sie nicht) und spielt
///                   jede Moeglichkeit durch, siehe rollout.dart; je mehr
///                   Stichproben, desto staerker
///
/// Stufen der App: einfach = Gedaechtnis, normal = Stichprobe mit einem
/// Viertel der Proben, schwer = Stichprobe mit allen Proben.
/// Mit [AiTuning.webApp] gelten die Stufen der Web-App: einfach = geradeaus,
/// normal = Stellungsspiel, schwer = Gedaechtnis.

/// Einzeln schaltbare Abweichungen von der KI der Web-App.
final class AiTuning {
  const AiTuning({
    required this.correctBieterSides,
    required this.improvedPlay,
    this.rolloutSamples = 64,
  });

  /// Verhalten exakt wie die Web-App (fuer den Paritaetstest und Vergleiche).
  static const AiTuning webApp = AiTuning(correctBieterSides: false, improvedPlay: false);

  /// Standard der App.
  static const AiTuning standard = AiTuning(correctBieterSides: true, improvedPlay: true);

  /// Im Bieterjass Bieter gegen Verteidiger unterscheiden statt nach `teamId`.
  ///
  /// Die Web-App gibt den Sitzen 1 und 2 immer dieselbe `teamId`. Ihre KI
  /// schmiert darum auch dann Punkte, wenn der vermeintliche Partner der Bieter
  /// ist. Gemessen mit tool/benchmark_bieter.dart (200 Verteilungen x 3 Sitze):
  /// Siegquote 62.8 % (Zaehlweise wie im Schieber) und 66.7 % (einfach) statt 33.3 %.
  final bool correctBieterSides;

  /// Staerkere Spielweise als in der Web-App: Stichproben statt Heuristik auf
  /// den Stufen normal und schwer, Slalom in beide Richtungen, ein Anspiel
  /// nach Spielart (im Une-Ufe zaehlt die Sechs, nicht das Ass), Rueckschluesse
  /// auf fremde Haende und Zurueckhaltung beim Trumpfziehen als Verteidiger.
  final bool improvedPlay;

  /// Stichproben der Stufe schwer je Kartenentscheidung (normal nimmt ein
  /// Viertel); mehr spielt staerker, kostet aber Rechenzeit auf dem Geraet.
  final int rolloutSamples;

  /// Stichproben je Kartenentscheidung fuer diese Stufe.
  int cardSamples(Difficulty level) =>
      level == Difficulty.schwer ? rolloutSamples : math.max(4, rolloutSamples ~/ 4);

  /// Spielart und Gebot brauchen weniger Proben als eine einzelne Karte.
  int modeSamples(Difficulty level) => math.max(8, cardSamples(level) * 2 ~/ 3);

  AiTuning copyWith({int? rolloutSamples}) => AiTuning(
    correctBieterSides: correctBieterSides,
    improvedPlay: improvedPlay,
    rolloutSamples: rolloutSamples ?? this.rolloutSamples,
  );
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

/// Bewertet eine Spielart. Im Slalom zaehlt mit [weightedSlalom] die
/// Startrichtung staerker, weil sie bei ungerader Stichzahl einmal mehr kommt;
/// die Web-App mittelt nur.
int evaluateRoundMode(List<JassCard> hand, RoundMode mode, {bool weightedSlalom = false}) {
  if (mode.isTrump) {
    return evaluateTrumpSuit(hand, mode.trumpSuit!);
  }
  if (mode.isSlalom) {
    // Slalom braucht beides: hohe Karten fuer Obenabe und tiefe fuer Une-Ufe.
    final high = evaluateNoTrumpMode(hand, RoundMode.obeAbe);
    final low = evaluateNoTrumpMode(hand, RoundMode.uneUfe);
    if (!weightedSlalom) {
      return ((high + low) / 2).round();
    }
    final tricks = math.max(1, hand.length);
    final first = mode == RoundMode.slalom ? high : low;
    final second = mode == RoundMode.slalom ? low : high;
    return ((first * ((tricks + 1) ~/ 2) + second * (tricks ~/ 2)) / tricks).round();
  }
  return evaluateNoTrumpMode(hand, mode);
}

/// Uebersetzt eine Handbewertung in erwartete Stichpunkte.
int estimateRoundPoints(int evaluation) => math.max(0, math.min(157, (evaluation * 1.15).round()));

/// Vorteil gegenueber einer ausgeglichenen Runde. Der Multiplikator vervielfacht
/// die Punkte beider Teams, darum zaehlt er auf die Differenz.
int modeAdvantage(
  List<JassCard> hand,
  RoundMode mode,
  RuleSet rules, {
  bool multipliers = true,
  AiTuning tuning = defaultAiTuning,
}) {
  final estimate = estimateRoundPoints(
    evaluateRoundMode(hand, mode, weightedSlalom: tuning.improvedPlay),
  );
  return (estimate - _halfRoundPoints) * (multipliers ? rules.multiplierFor(mode) : 1);
}

/// Beste Spielart aus einer Auswahl; bei Gleichstand die zuerst genannte.
RoundMode bestModeFrom(
  List<JassCard> hand,
  List<RoundMode> allowedModes,
  RuleSet rules, {
  bool multipliers = true,
  AiTuning tuning = defaultAiTuning,
}) {
  int advantage(RoundMode mode) =>
      modeAdvantage(hand, mode, rules, multipliers: multipliers, tuning: tuning);
  return allowedModes.reduce((best, mode) => advantage(mode) > advantage(best) ? mode : best);
}

Suit bestTrumpSuit(List<JassCard> hand) => Suit.values.reduce(
  (best, suit) => evaluateTrumpSuit(hand, suit) > evaluateTrumpSuit(hand, best) ? suit : best,
);

/// Spielarten, die diese KI ansagt: die Web-App kennt nur einen Slalom.
List<RoundMode> _modesFor(List<RoundMode> allowed, AiTuning tuning) => tuning.improvedPlay
    ? allowed
    : [
        for (final mode in allowed)
          if (mode.base == mode) mode,
      ];

RoundMode bestSchieberMode(
  List<JassCard> hand,
  RuleSet rules, {
  AiTuning tuning = defaultAiTuning,
}) => bestModeFrom(hand, _modesFor(RoundMode.values, tuning), rules, tuning: tuning);

/// Geschoben wird, wenn die eigene Hand keinen Vorteil verspricht.
bool shouldPushTrump(List<JassCard> hand, RuleSet rules, {AiTuning tuning = defaultAiTuning}) =>
    modeAdvantage(hand, bestSchieberMode(hand, rules, tuning: tuning), rules, tuning: tuning) <= 0;

/// Schmerzgrenze eines Computers beim Steigern, fuer die ganze Partie.
///
/// Geboten wird nicht fuer eine Runde, sondern fuer die Partie: Der Bieter muss
/// sein Gebot erreichen, bevor die beiden anderen 1000 Punkte haben. Darum
/// zaehlt weniger die erste Hand als der Mut. Jeder Computer zieht aus dem Seed
/// eine Grenze zwischen 450 und 650, leicht nach der ersten Hand verschoben.
/// So endet das Steigern meist zwischen 450 und 650, und ein Mensch wird noch
/// ein Stueck hochgetrieben.
int aiBidLimit(GameState state, int seat) {
  final rng = Mulberry32(state.seed ^ ((seat + 1) * 0x9E3779B1));
  final base = 450 + (rng.nextDouble() * 21).floor() * 10;
  final hand = state.players[seat].hand;
  final strength = estimateRoundPoints(evaluateTrumpSuit(hand, bestTrumpSuit(hand)));
  final shift = ((strength - 80) / 4).round().clamp(-20, 20);
  final limit = ((base + shift) / bidStep).round() * bidStep;
  return math.max(state.matchConfig.bieterStartBid, limit);
}

/// Gebot fuer den Bieterjass; `0` bedeutet passen. Gesteigert wird in
/// Zehnerschritten, mit Luft nach oben auch in Zwanzigern.
int aiBidDecision(
  GameState state,
  int seat, {
  Difficulty? difficulty,
  AiTuning tuning = defaultAiTuning,
}) {
  final minimum = minimumBid(state);
  final limit = aiBidLimit(state, seat);
  if (minimum > limit) {
    return 0;
  }
  return limit - minimum >= 4 * bidStep ? minimum + bidStep : minimum;
}

/* ------------------------------------------------------------------ *
 * Kartenspiel
 * ------------------------------------------------------------------ */

/// Spielweisen, aufsteigend nach Staerke.
enum _Style { simple, positional, memory, rollout }

_Style _styleFor(Difficulty level, AiTuning tuning) => switch ((tuning.improvedPlay, level)) {
  (false, Difficulty.einfach) => _Style.simple,
  (false, Difficulty.normal) => _Style.positional,
  (false, Difficulty.schwer) => _Style.memory,
  (true, Difficulty.einfach) => _Style.memory,
  (true, Difficulty.normal || Difficulty.schwer) => _Style.rollout,
};

Difficulty _levelFor(GameState state, int seat, Difficulty? difficulty) =>
    difficulty ?? state.players[seat].difficulty ?? state.matchConfig.difficulty;

typedef _SideCheck = bool Function(GameState state, int first, int second);

final class _Play {
  _Play(
    this.state,
    this.seat,
    this.legal,
    this.sameSide, {
    required this.style,
    required this.tuning,
  }) : mode = state.trickMode,
       hand = state.players[seat].hand;

  final GameState state;
  final int seat;
  final List<JassCard> legal;
  final _SideCheck sameSide;
  final _Style style;
  final AiTuning tuning;
  final RoundMode? mode;
  final List<JassCard> hand;

  bool get improved => tuning.improvedPlay;

  bool get memory => style.index >= _Style.memory.index;

  bool get expert => style == _Style.rollout;

  Suit? get trump => mode?.trumpSuit;

  bool isTrump(JassCard card) => trump != null && card.suit == trump;

  /// Gezaehlt wird nach der angesagten Spielart, gestochen nach der des Stichs.
  int points(JassCard card) => cardPoints(card, state.roundMode);

  int rank(JassCard card) => rankIndex(card, mode);

  /// Hoechste Karte einer Nebenfarbe in dieser Spielart (Ass, im Une-Ufe die Sechs).
  bool isTopCard(JassCard card) => !isTrump(card) && rank(card) == Rank.values.length - 1;

  int suitLength(Suit suit) => hand.where((card) => card.suit == suit).length;

  bool wouldWin(JassCard card) =>
      trickWinner([...state.trick, TrickEntry(seat, card)], mode) == seat;

  bool isOpponent(int other) => !sameSide(state, seat, other);

  /// Alle Gegner am Tisch.
  late final List<int> opponents = [
    for (var index = 0; index < state.players.length; index += 1)
      if (index != seat && isOpponent(index)) index,
  ];

  /// Wer in diesem Stich nach mir noch spielt.
  late final List<int> playersAfterMe = [
    for (var offset = 1; offset < state.players.length - state.trick.length; offset += 1)
      (seat + offset) % state.players.length,
  ];

  /// Karten, die weder gespielt wurden noch auf der eigenen Hand liegen.
  late final List<JassCard> unseen = [
    for (final card in JassCard.deck)
      if (!state.playedCards.contains(card) && !hand.contains(card)) card,
  ];

  late final List<Set<Suit>> voids = inferVoids(state);

  /// Koennte dieser Spieler die Karte noch halten? Die Web-App zieht keine
  /// Rueckschluesse und rechnet mit allem.
  bool couldHold(int player, JassCard card) => !improved || !voids[player].contains(card.suit);

  int get unseenTrumps => trump == null ? 0 : unseen.where((card) => card.suit == trump).length;

  /// Kein Gegner kann mehr trumpfen: Trumpf ist ausgespielt oder beide sind blank.
  bool get opponentsOutOfTrump =>
      trump != null &&
      (unseenTrumps == 0 ||
          opponents.every((player) => !couldHold(player, JassCard(trump!, Rank.six))));

  /// Droht ein Gegner aus [players], die Farbe zu stechen? Nur bekannte
  /// Blanken zaehlen; wer die Farbe noch bedienen muss, kann nicht trumpfen.
  bool mayBeTrumped(Suit suit, Iterable<int> players) {
    final trump = this.trump;
    if (trump == null || suit == trump || unseenTrumps == 0) {
      return false;
    }
    return players.any(
      (player) =>
          isOpponent(player) && voids[player].contains(suit) && !voids[player].contains(trump),
    );
  }

  /// Konservative Pruefung, ob der Stich nach dieser Karte nicht mehr zu holen ist.
  bool isTrickSafe(JassCard card, int leadingSeat) {
    final simulated = [...state.trick, TrickEntry(seat, card)];
    if (playersAfterMe.isEmpty) {
      return trickWinner(simulated, mode) == leadingSeat;
    }
    final threats = playersAfterMe.where(isOpponent).toList();
    return unseen.every((other) {
      if (trickWinner([...simulated, TrickEntry(-1, other)], mode) != -1) {
        return true;
      }
      return !threats.any((player) => couldHold(player, other));
    });
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

/// Soll mit diesen Trumpfkarten Trumpf gezogen werden?
bool _shouldDrawTrump(_Play play, List<JassCard> trumps) {
  if (trumps.isEmpty) {
    return false;
  }
  final state = play.state;
  final caller = state.isBieter ? state.soloPlayer : state.chooserPlayer;
  final isChooser = caller == play.seat;
  final strongTrump = trumps.any((card) => card.rank == Rank.under || card.rank == Rank.nine);

  if (!play.improved) {
    // Web-App: als Ansager zuerst Trumpf ziehen, solange man die Kontrolle hat.
    return trumps.length >= 3 || (isChooser && trumps.length >= 2 && strongTrump);
  }
  if (play.expert && play.opponentsOutOfTrump) {
    // Die Gegner sind blank: die eigenen Truempfe stechen spaeter Nebenfarben.
    return false;
  }
  final ownSideCalled = caller >= 0 && play.sameSide(state, caller, play.seat);
  if (ownSideCalled) {
    return trumps.length >= 3 || (trumps.length >= 2 && strongTrump);
  }
  // Als Verteidiger nur mit einer Uebermacht ins Trumpf des Ansagers spielen.
  return trumps.length >= 4 && strongTrump;
}

JassCard _chooseLead(_Play play) {
  final legal = play.legal;
  final trumps = legal.where(play.isTrump).toList();

  if (_shouldDrawTrump(play, trumps)) {
    return _firstBy(trumps, play.rankDescending);
  }

  if (play.memory) {
    // Sichere Stiche zuerst; der Experte meidet Farben, die ein Gegner sticht.
    final sureWinners = legal.where(
      (card) =>
          !play.isTrump(card) &&
          play.isHighestRemaining(card) &&
          !(play.expert && play.mayBeTrumped(card.suit, play.opponents)),
    );
    if (sureWinners.isNotEmpty) {
      return _firstBy(sureWinners, play.pointsDescending);
    }
  }

  final sideCards = legal.where((card) => !play.isTrump(card)).toList();
  final candidates = sideCards.isNotEmpty ? sideCards : legal;

  if (play.expert) {
    // Anspiel fuer den Partner: eine Farbe, die er nicht mehr hat, sticht er.
    final partner = partnerOf(play.state, play.seat);
    final trump = play.trump;
    if (partner >= 0 &&
        trump != null &&
        play.unseenTrumps > 0 &&
        !play.voids[partner].contains(trump)) {
      final nextOpponent = (play.seat + 1) % play.state.players.length;
      final ruffs = sideCards.where(
        (card) =>
            play.voids[partner].contains(card.suit) &&
            !play.voids[nextOpponent].contains(card.suit),
      );
      if (ruffs.isNotEmpty) {
        return _firstBy(ruffs, play.pointsAscending);
      }
    }
  }

  // Die hoechsten Karten der Nebenfarben holen frueh die Punkte heim (Asse;
  // im Une-Ufe die Sechser). Die Web-App nahm in jeder Spielart das Ass.
  final tops = candidates.where(
    (card) =>
        (play.improved ? play.isTopCard(card) : card.rank == Rank.ass) &&
        !(play.expert && play.mayBeTrumped(card.suit, play.opponents)),
  );
  if (tops.isNotEmpty) {
    return _firstBy(
      tops,
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
  var candidates = keepers.isNotEmpty ? keepers : play.legal;

  if (play.expert) {
    // Sichere Stiche nicht wegwerfen, solange es Alternativen gibt.
    final expendable = candidates.where((card) => !play.isHighestRemaining(card)).toList();
    if (expendable.isNotEmpty) {
      candidates = expendable;
    }
  }

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

JassCard _chooseFollow(_Play play) {
  final state = play.state;
  final currentWinner = trickWinner(state.trick, play.mode);
  final partnerWinning =
      play.sameSide(state, currentWinner, play.seat) && currentWinner != play.seat;
  final isLastSeat = state.trick.length == state.players.length - 1;
  final pointsAtStake = trickPoints(state.trick, state.roundMode);
  final winningCards = play.legal.where(play.wouldWin).toList();

  if (partnerWinning) {
    final safe = isLastSeat || (play.memory && play.isTrickSafe(_chooseSmear(play), currentWinner));
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

/// Die geradeaus spielende Stufe (das urspruengliche Verhalten der Web-App).
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
  final level = _levelFor(state, seat, difficulty);
  final legal = playableCards(state, seat);
  if (legal.length == 1) {
    return legal.first;
  }

  final play = _Play(
    state,
    seat,
    legal,
    tuning.correctBieterSides ? sameSide : sameTeamId,
    style: _styleFor(level, tuning),
    tuning: tuning,
  );
  if (play.style == _Style.simple) {
    return _chooseSimple(play);
  }
  final heuristic = state.trick.isEmpty ? _chooseLead(play) : _chooseFollow(play);
  if (play.style != _Style.rollout) {
    return heuristic;
  }
  return rolloutChooseCard(
        state,
        seat,
        legal,
        samples: tuning.cardSamples(level),
        preferred: heuristic,
      ) ??
      heuristic;
}

/// Spielartwahl per Stichprobe; `null` heisst schieben. Laesst sich die Lage
/// nicht simulieren, entscheidet die Handbewertung.
RoundMode? _rolloutMode(
  GameState state,
  int seat,
  List<RoundMode> modes,
  int samples,
  AiTuning tuning,
) {
  final advantages = rolloutModeAdvantages(state, seat, modes, samples: samples);
  final hand = state.players[seat].hand;
  if (advantages == null) {
    if (canPushTrump(state) && shouldPushTrump(hand, state.rules, tuning: tuning)) {
      return null;
    }
    return bestModeFrom(
      hand,
      modes,
      state.rules,
      multipliers: state.usesRoundMultipliers,
      tuning: tuning,
    );
  }
  double score(RoundMode mode) =>
      advantages[mode]! * (state.usesRoundMultipliers ? state.rules.multiplierFor(mode) : 1);
  final best = modes.reduce((a, b) => score(b) > score(a) ? b : a);
  if (canPushTrump(state) && score(best) <= 0) {
    return null;
  }
  return best;
}

/// Naechste Aktion des Computers, der gerade am Zug ist.
///
/// Folgt dem Spielablauf der Web-App. Liefert `null` in Phasen ohne
/// Spielerentscheidung (Rundenstart, Stichende, Spielende). Mit [difficulty]
/// laesst sich die Stufe vorgeben.
GameAction? aiDecide(GameState state, {AiTuning tuning = defaultAiTuning, Difficulty? difficulty}) {
  final seat = state.currentPlayer;
  final hand = state.players[seat].hand;

  switch (state.phase) {
    case GamePhase.bidding:
      final value = aiBidDecision(state, seat, difficulty: difficulty, tuning: tuning);
      return value == 0 ? PassBid(seat) : PlaceBid(seat, value);
    case GamePhase.chooseTrump:
      final level = _levelFor(state, seat, difficulty);
      if (_styleFor(level, tuning) == _Style.rollout) {
        final mode = _rolloutMode(
          state,
          seat,
          _modesFor(state.allowedRoundModes, tuning),
          tuning.modeSamples(level),
          tuning,
        );
        return mode == null ? PushTrump(seat) : ChooseMode(seat, mode);
      }
      if (canPushTrump(state) && shouldPushTrump(hand, state.rules, tuning: tuning)) {
        return PushTrump(seat);
      }
      if (state.isSchieber) {
        return ChooseMode(seat, bestSchieberMode(hand, state.rules, tuning: tuning));
      }
      return ChooseMode(
        seat,
        bestModeFrom(
          hand,
          _modesFor(state.allowedRoundModes, tuning),
          state.rules,
          multipliers: state.usesRoundMultipliers,
          tuning: tuning,
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
