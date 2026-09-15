import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'fixtures/rng_fixture.g.dart';

const _deckChars = '0123456789abcdefghijklmnopqrstuvwxyz';

String encodeHand(List<JassCard> hand) => hand.map((card) => _deckChars[card.deckIndex]).join();

List<String> ids(Iterable<JassCard> cards) => [for (final card in cards) card.id];

void main() {
  test('mulberry32 liefert bitgenau dieselben Zahlen wie die Web-App', () {
    for (final fixture in rngFixtures) {
      final rng = Mulberry32(fixture.seed);
      final values = [
        for (var index = 0; index < fixture.values.length; index += 1) rng.nextDouble(),
      ];
      expect(values, fixture.values, reason: 'Seed ${fixture.seed}');
    }
  });

  test('Derselbe Seed ergibt dieselben Kartenverteilungen wie die Web-App', () {
    for (final fixture in rngFixtures) {
      final rng = Mulberry32(fixture.seed);
      final deals = [
        dealHands(4, 3, 3, rng),
        dealHands(4, 3, 0, rng),
        dealHands(3, 3, 2, rng),
        dealHands(3, 3, 1, rng),
      ];
      expect(
        [
          for (final hands in deals) [for (final hand in hands) encodeHand(hand)],
        ],
        fixture.deals,
        reason: 'Seed ${fixture.seed}',
      );
    }
  });

  test('Eine Zufallsfolge laesst sich aus dem gespeicherten Zustand fortsetzen', () {
    final original = Mulberry32(42)
      ..nextDouble()
      ..nextDouble();
    final resumed = Mulberry32(original.state);

    expect(resumed.nextDouble(), original.nextDouble());
    expect(resumed.state, original.state);
  });

  test('Jede Verteilung gibt alle 36 Karten genau einmal aus', () {
    final rng = Mulberry32(99);
    for (final (players, dealer) in [(4, 3), (3, 2)]) {
      final hands = dealHands(players, 3, dealer, rng);
      expect(hands.map((hand) => hand.length).toSet(), {36 ~/ players});
      expect(hands.expand((hand) => hand).toSet(), JassCard.deck.toSet());
    }
  });

  group('Handsortierung', () {
    final hand = [
      'eicheln_ass',
      'rosen_under',
      'rosen_6',
      'rosen_9',
      'schilten_7',
      'rosen_ass',
    ].map(JassCard.fromId);

    test('Die Engine sortiert unabhaengig von der Spielart wie die Web-App', () {
      expect(ids(sortPlayerHand(hand)), [
        'rosen_6',
        'rosen_9',
        'rosen_under',
        'rosen_ass',
        'eicheln_ass',
        'schilten_7',
      ]);
    });

    test('Die Anzeige legt Trumpf nach vorne und den Puur ganz rechts', () {
      expect(ids(sortHandForDisplay(hand, RoundMode.rosen)), [
        'rosen_6',
        'rosen_ass',
        'rosen_9',
        'rosen_under',
        'eicheln_ass',
        'schilten_7',
      ]);
    });

    test('Bei Une-Ufe steht die Sechs als hoechste Karte rechts', () {
      expect(ids(sortHandForDisplay(hand, RoundMode.uneUfe)), [
        'rosen_ass',
        'rosen_under',
        'rosen_9',
        'rosen_6',
        'eicheln_ass',
        'schilten_7',
      ]);
    });
  });
}
