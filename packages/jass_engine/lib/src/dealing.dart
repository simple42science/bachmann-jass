import 'package:collection/collection.dart';

import 'cards.dart';
import 'rng.dart';

const List<Suit> _handSuitOrder = [Suit.rosen, Suit.eicheln, Suit.schellen, Suit.schilten];

/// Fisher-Yates wie in der Web-App: von hinten nach vorne, eine Zufallszahl je Tausch.
List<JassCard> shuffleCards(List<JassCard> cards, Mulberry32 rng) {
  final deck = [...cards];
  for (var index = deck.length - 1; index > 0; index -= 1) {
    final swapIndex = (rng.nextDouble() * (index + 1)).floor();
    final temp = deck[index];
    deck[index] = deck[swapIndex];
    deck[swapIndex] = temp;
  }
  return deck;
}

/// Mischt und verteilt in Paketen, beginnend links vom Geber.
List<List<JassCard>> dealHands(int playerCount, int packetSize, int dealer, Mulberry32 rng) {
  final shuffled = shuffleCards(JassCard.deck, rng);
  final hands = List.generate(playerCount, (_) => <JassCard>[]);
  final dealOrder = List.generate(playerCount, (index) => (dealer + 1 + index) % playerCount);
  final targetHandSize = shuffled.length ~/ playerCount;
  var deckIndex = 0;

  while (deckIndex < shuffled.length) {
    for (final playerIndex in dealOrder) {
      for (
        var packetCard = 0;
        packetCard < packetSize &&
            hands[playerIndex].length < targetHandSize &&
            deckIndex < shuffled.length;
        packetCard += 1
      ) {
        hands[playerIndex].add(shuffled[deckIndex]);
        deckIndex += 1;
      }
    }
  }
  return hands;
}

/// Sortierung der Engine (Rosen, Eicheln, Schellen, Schilten; je Farbe aufsteigend).
///
/// Bleibt unabhaengig von der Spielart, weil die Computergegner bei
/// Gleichstand die zuerst liegende Karte waehlen.
List<JassCard> sortPlayerHand(Iterable<JassCard> hand) {
  final sorted = [...hand];
  mergeSort(
    sorted,
    compare: (JassCard first, JassCard second) {
      if (first.suit != second.suit) {
        return _handSuitOrder.indexOf(first.suit) - _handSuitOrder.indexOf(second.suit);
      }
      return first.rank.index - second.rank.index;
    },
  );
  return sorted;
}

/// Sortierung fuer die Anzeige: Trumpf zuerst, jede Farbe nach Staerke in
/// der Spielart (Puur ganz rechts, bei Une-Ufe die Sechs ganz rechts).
List<JassCard> sortHandForDisplay(Iterable<JassCard> hand, RoundMode? mode) {
  final trump = mode?.trumpSuit;
  final suitOrder = [?trump, ..._handSuitOrder.where((suit) => suit != trump)];
  final sorted = [...hand];
  mergeSort(
    sorted,
    compare: (JassCard first, JassCard second) {
      if (first.suit != second.suit) {
        return suitOrder.indexOf(first.suit) - suitOrder.indexOf(second.suit);
      }
      return rankIndex(first, mode) - rankIndex(second, mode);
    },
  );
  return sorted;
}
