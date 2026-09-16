import 'dart:math' as math;

import 'cards.dart';
import 'game_state.dart';
import 'model.dart';
import 'rules.dart';

/// Entscheidungen per Stichprobe: Die unbekannten Karten werden mehrmals
/// zufaellig, aber mit dem bisherigen Spiel vertraeglich auf die anderen
/// verteilt, und jede Moeglichkeit wird mit einer schnellen Spielweise zu
/// Ende gespielt. Gewaehlt wird, was im Schnitt am meisten Punkte bringt.
///
/// Das Verfahren kennt keine fremden Karten: Es sieht nur die eigene Hand,
/// die gespielten Karten und wer welche Farbe nicht mehr bedienen konnte.

/// Was sich aus den bisherigen Stichen ueber fremde Haende ableiten laesst:
/// wer eine angespielte Farbe nicht bedient hat, hat sie nicht mehr. Wer bei
/// angespieltem Trumpf keinen Trumpf legt, hat keinen mehr.
List<Set<Suit>> inferVoids(GameState state) {
  final voids = [for (var index = 0; index < state.players.length; index += 1) <Suit>{}];
  final roundMode = state.roundMode;
  if (roundMode == null) {
    return voids;
  }

  void scan(List<TrickEntry> cards, RoundMode? trickMode) {
    if (cards.isEmpty) {
      return;
    }
    final led = cards.first.card.suit;
    final trump = trickMode?.trumpSuit;
    for (final entry in cards.skip(1)) {
      final suit = entry.card.suit;
      if (suit == led || (trump != null && suit == trump)) {
        // Bedient oder (freiwillig) getrumpft: keine Aussage ueber die Farbe.
        continue;
      }
      voids[entry.playerIndex].add(led);
    }
  }

  for (var index = 0; index < state.roundTricks.length; index += 1) {
    scan(state.roundTricks[index].cards, roundMode.trickMode(index));
  }
  scan(state.trick, state.trickMode);
  return voids;
}

/// Karten, die [seat] weder gespielt gesehen hat noch selbst haelt.
List<JassCard> unseenCards(GameState state, int seat) {
  final own = state.players[seat].hand;
  return [
    for (final card in JassCard.deck)
      if (!state.playedCards.contains(card) && !own.contains(card)) card,
  ];
}

/// Passen die unbekannten Karten genau in die fremden Haende? Sonst laesst
/// sich die Lage nicht simulieren (etwa in kuenstlichen Testzustaenden).
bool canSample(GameState state, int seat) {
  var need = 0;
  for (var player = 0; player < state.players.length; player += 1) {
    if (player != seat) {
      need += state.players[player].hand.length;
    }
  }
  return need > 0 && unseenCards(state, seat).length == need;
}

/// Verteilt die aus Sicht von [seat] unbekannten Karten zufaellig auf die
/// anderen Spieler, passend zu deren Handgroesse und bekannten Blanken.
/// Setzt [canSample] voraus.
List<List<JassCard>> sampleHands(
  GameState state,
  int seat,
  List<Set<Suit>> voids,
  math.Random random,
) {
  final count = state.players.length;
  final own = state.players[seat].hand;
  final unseen = unseenCards(state, seat);
  final need = [
    for (var player = 0; player < count; player += 1)
      player == seat ? 0 : state.players[player].hand.length,
  ];

  for (var attempt = 0; attempt < 12; attempt += 1) {
    // Nach einigen Fehlversuchen ohne Blanken verteilen, damit es sicher aufgeht.
    final strict = attempt < 8;
    final hands = [for (var player = 0; player < count; player += 1) <JassCard>[]];
    final remaining = [...need];
    final cards = [...unseen]..shuffle(random);
    if (strict) {
      // Karten mit wenigen moeglichen Haltern zuerst, sonst bleiben sie uebrig.
      int holders(JassCard card) => [
        for (var p = 0; p < count; p += 1)
          if (need[p] > 0 && !voids[p].contains(card.suit)) p,
      ].length;
      cards.sort((a, b) => holders(a) - holders(b));
    }

    var ok = true;
    for (final card in cards) {
      final options = [
        for (var player = 0; player < count; player += 1)
          if (remaining[player] > 0 && (!strict || !voids[player].contains(card.suit))) player,
      ];
      if (options.isEmpty) {
        ok = false;
        break;
      }
      // Gewichtet nach Restbedarf, damit die Haende gleichmaessig voll werden.
      var pick = random.nextInt(options.fold(0, (sum, player) => sum + remaining[player]));
      var chosen = options.last;
      for (final player in options) {
        pick -= remaining[player];
        if (pick < 0) {
          chosen = player;
          break;
        }
      }
      hands[chosen].add(card);
      remaining[chosen] -= 1;
    }
    if (ok) {
      hands[seat] = [...own];
      return hands;
    }
  }
  throw StateError('Unbekannte Karten lassen sich nicht verteilen');
}

/// Schlanker Spielverlauf einer Runde ohne Ereignisse, Weis und Stöck.
final class _Sim {
  _Sim({
    required this.hands,
    required this.roundMode,
    required this.sides,
    required this.trick,
    required this.leader,
    required this.trickNumber,
    required this.handSize,
    required this.lastTrickBonus,
    required this.matchBonus,
  }) : tricksBySide = [0, 0],
       pointsBySide = [0, 0];

  final List<List<JassCard>> hands;
  final RoundMode roundMode;

  /// Seite je Spieler: 0 = die Seite des Entscheiders, 1 = die Gegenseite.
  final List<int> sides;
  List<TrickEntry> trick;
  int leader;
  int trickNumber;
  final int handSize;
  final int lastTrickBonus;
  final int matchBonus;
  final List<int> tricksBySide;
  final List<int> pointsBySide;

  int get playerCount => hands.length;

  RoundMode get mode => roundMode.trickMode(trickNumber);

  int get currentPlayer => (leader + trick.length) % playerCount;

  void play(int player, JassCard card) {
    hands[player].remove(card);
    trick.add(TrickEntry(player, card));
    if (trick.length == playerCount) {
      final mode = this.mode;
      final winner = trickWinner(trick, mode);
      final last = trickNumber == handSize - 1;
      pointsBySide[sides[winner]] += trickPoints(trick, mode) + (last ? lastTrickBonus : 0);
      tricksBySide[sides[winner]] += 1;
      trickNumber += 1;
      leader = winner;
      trick = [];
    }
  }

  bool get finished => trickNumber >= handSize;

  /// Spielt die Runde zu Ende und liefert den Punktevorsprung der Seite 0.
  int finish() {
    while (!finished) {
      final player = currentPlayer;
      final legal = legalCards(hands[player], trick, mode);
      if (legal.isEmpty) {
        break;
      }
      play(player, legal.length == 1 ? legal.first : _policy(this, player, legal));
    }
    for (var side = 0; side < 2; side += 1) {
      if (matchBonus > 0 && tricksBySide[side] == handSize) {
        pointsBySide[side] += matchBonus;
      }
    }
    return pointsBySide[0] - pointsBySide[1];
  }
}

JassCard _first(Iterable<JassCard> cards, int Function(JassCard a, JassCard b) compare) {
  JassCard? best;
  for (final card in cards) {
    if (best == null || compare(card, best) < 0) {
      best = card;
    }
  }
  return best!;
}

/// Schnelle Spielweise fuer die Simulation: Trumpf ziehen, hohe Karten
/// heimholen, billig stechen, beim Partner schmieren, sonst sparsam abwerfen.
JassCard _policy(_Sim sim, int player, List<JassCard> legal) {
  final mode = sim.mode;
  final trump = mode.trumpSuit;
  final hand = sim.hands[player];
  bool isTrump(JassCard card) => trump != null && card.suit == trump;
  int points(JassCard card) => cardPoints(card, mode);
  int rank(JassCard card) => rankIndex(card, mode);
  int suitLength(Suit suit) => hand.where((card) => card.suit == suit).length;

  JassCard discard() {
    final keepers = legal.where((card) => !isTrump(card)).toList();
    return _first(keepers.isNotEmpty ? keepers : legal, (a, b) {
      final diff = points(a) - points(b);
      return diff != 0 ? diff : suitLength(a.suit) - suitLength(b.suit);
    });
  }

  if (sim.trick.isEmpty) {
    final trumps = legal.where(isTrump).toList();
    if (trumps.length >= 3) {
      return _first(trumps, (a, b) => rank(b) - rank(a));
    }
    final side = legal.where((card) => !isTrump(card)).toList();
    final candidates = side.isNotEmpty ? side : legal;
    final tops = candidates.where((card) => !isTrump(card) && rank(card) == Rank.values.length - 1);
    if (tops.isNotEmpty) {
      return _first(tops, (a, b) => suitLength(b.suit) - suitLength(a.suit));
    }
    return _first(candidates, (a, b) {
      final diff = suitLength(a.suit) - suitLength(b.suit);
      return diff != 0 ? diff : points(a) - points(b);
    });
  }

  final winner = trickWinner(sim.trick, mode);
  final partnerWinning = sim.sides[winner] == sim.sides[player];
  final lastSeat = sim.trick.length == sim.playerCount - 1;
  if (partnerWinning) {
    if (!lastSeat) {
      return discard();
    }
    final nonTrump = legal.where((card) => !isTrump(card)).toList();
    return _first(nonTrump.isNotEmpty ? nonTrump : legal, (a, b) => points(b) - points(a));
  }

  final winning = legal
      .where((card) => trickWinner([...sim.trick, TrickEntry(player, card)], mode) == player)
      .toList();
  if (winning.isEmpty) {
    return discard();
  }
  final cheap = winning.where((card) => !isTrump(card));
  if (cheap.isNotEmpty) {
    return _first(cheap, (a, b) => rank(a) - rank(b));
  }
  final stake = trickPoints(sim.trick, mode);
  final worth = lastSeat ? stake >= 4 : stake >= 10 || hand.where(isTrump).length >= 4;
  if (!worth) {
    final cheapest = discard();
    if (!isTrump(cheapest)) {
      return cheapest;
    }
  }
  return _first(winning, (a, b) => rank(a) - rank(b));
}

/// Seite je Spieler aus Sicht von [seat]. Im Bieterjass steht der Bieter
/// allein; solange noch geboten wird, rechnet jeder mit sich allein gegen
/// die anderen (die `teamId` der Sitze 1 und 2 ist dort ohne Bedeutung).
List<int> _sidesFor(GameState state, int seat) {
  if (state.isBieter && state.soloPlayer < 0) {
    return [
      for (var player = 0; player < state.players.length; player += 1) player == seat ? 0 : 1,
    ];
  }
  return [
    for (var player = 0; player < state.players.length; player += 1)
      sameSide(state, seat, player) ? 0 : 1,
  ];
}

/// Deterministischer Zufall je Spielsituation, damit sich Partien aus dem
/// Seed exakt nachspielen lassen.
math.Random _randomFor(GameState state, int seat) => math.Random(
  state.rngState ^ (state.trickNumber * 7919) ^ (state.trick.length * 104729) ^ (seat * 15485863),
);

_Sim _simFor(GameState state, int seat, List<List<JassCard>> hands, RoundMode mode) => _Sim(
  hands: [
    for (final hand in hands) [...hand],
  ],
  roundMode: mode,
  sides: _sidesFor(state, seat),
  trick: [...state.trick],
  leader: state.trick.isEmpty ? state.trickLeader : state.trick.first.playerIndex,
  trickNumber: state.trickNumber,
  handSize: state.variant.handSize,
  lastTrickBonus: state.rules.lastTrickBonus,
  matchBonus: state.isSchieber ? state.rules.matchBonus : 0,
);

/// Karte mit dem besten Punkteschnitt ueber [samples] Verteilungen.
/// [preferred] gewinnt bei Gleichstand (etwa die Wahl der Heuristik).
/// `null`, wenn sich die Lage nicht simulieren laesst.
JassCard? rolloutChooseCard(
  GameState state,
  int seat,
  List<JassCard> legal, {
  required int samples,
  JassCard? preferred,
}) {
  if (legal.length == 1) {
    return legal.first;
  }
  if (state.roundMode == null || !canSample(state, seat)) {
    return null;
  }
  final random = _randomFor(state, seat);
  final voids = inferVoids(state);
  final totals = List<int>.filled(legal.length, 0);

  for (var sample = 0; sample < samples; sample += 1) {
    final hands = sampleHands(state, seat, voids, random);
    for (var index = 0; index < legal.length; index += 1) {
      final sim = _simFor(state, seat, hands, state.roundMode!);
      sim.play(seat, legal[index]);
      totals[index] += sim.finish();
    }
  }

  var best = preferred != null ? legal.indexOf(preferred) : 0;
  if (best < 0) {
    best = 0;
  }
  for (var index = 0; index < legal.length; index += 1) {
    if (totals[index] > totals[best]) {
      best = index;
    }
  }
  return legal[best];
}

/// Erwarteter Punktevorsprung je Spielart (ohne Multiplikator), gemittelt
/// ueber [samples] Verteilungen der fremden Karten. `null`, wenn sich die
/// Lage nicht simulieren laesst.
Map<RoundMode, double>? rolloutModeAdvantages(
  GameState state,
  int seat,
  List<RoundMode> modes, {
  required int samples,
}) {
  if (!canSample(state, seat)) {
    return null;
  }
  final random = _randomFor(state, seat);
  final voids = inferVoids(state);
  final totals = {for (final mode in modes) mode: 0};

  for (var sample = 0; sample < samples; sample += 1) {
    final hands = sampleHands(state, seat, voids, random);
    for (final mode in modes) {
      final sim = _simFor(state, seat, hands, mode);
      sim.leader = state.isBieter ? seat : state.forehandPlayer;
      totals[mode] = totals[mode]! + sim.finish();
    }
  }
  return {for (final mode in modes) mode: totals[mode]! / samples};
}
