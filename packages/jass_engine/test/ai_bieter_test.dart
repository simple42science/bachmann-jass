import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/simple_players.dart';

void main() {
  test('Im Bieterjass schmiert ein Verteidiger dem Bieter keine Punkte', () {
    final base = createGame(variant: GameVariant.bieter, seed: 1);
    final state = withHand(
      base.copyWith(
        phase: GamePhase.playing,
        roundMode: RoundMode.rosen,
        soloPlayer: 1,
        chooserPlayer: 1,
        currentPlayer: 2,
        trick: [TrickEntry(0, card('eicheln_7')), TrickEntry(1, card('eicheln_ass'))],
      ),
      2,
      [card('eicheln_10'), card('eicheln_6'), card('schilten_7')],
    );

    expect(sameSide(state, 1, 2), isFalse, reason: 'Sitz 2 verteidigt gegen den Bieter');
    expect(sameSide(state, 0, 2), isTrue, reason: 'Sitz 0 verteidigt mit');
    expect(
      aiChooseCard(state, 2),
      card('eicheln_6'),
      reason: 'Abwerfen statt dem Bieter schmieren',
    );
    expect(
      aiChooseCard(state, 2, tuning: AiTuning.webApp),
      card('eicheln_10'),
      reason: 'So spielte die Web-App',
    );
  });
}
