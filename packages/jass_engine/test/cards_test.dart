import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Das Deck hat 36 eindeutige Karten in der Reihenfolge der Web-App', () {
    expect(JassCard.deck, hasLength(36));
    expect(JassCard.deck.map((card) => card.id).toSet(), hasLength(36));
    expect(JassCard.deck.first.id, 'eicheln_6');
    expect(JassCard.deck.last.id, 'schilten_ass');

    for (final card in JassCard.deck) {
      expect(JassCard.fromId(card.id), card);
      expect(JassCard.deck[card.deckIndex], card);
    }
  });
}
