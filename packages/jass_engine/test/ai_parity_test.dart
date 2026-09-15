@TestOn('vm')
library;

import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/parity_fixtures.dart';

/// Die Dart-KI trifft in jeder aufgezeichneten Situation dieselbe Entscheidung
/// wie die KI der Web-App. In den Fixtures spielen alle Sitze mit der KI; nur
/// die als `scripted` markierten Entscheidungen wurden vorgegeben.
void main() {
  for (final fixture in ParityFixture.loadAll()) {
    test('KI entscheidet wie die Web-App: ${fixture.name}', () {
      var decisions = 0;
      for (final game in fixture.games) {
        replayGame(
          fixture,
          game,
          beforeAction: (state, code, where) {
            if (code == 's' || code == 'n') {
              return;
            }
            final isModeChoice = code.startsWith('m') || code.startsWith('u');
            final isBid = code.startsWith('b') || code.startsWith('x');
            if ((isModeChoice && fixture.scripted.contains('mode')) ||
                (isBid && fixture.scripted.contains('bid'))) {
              return;
            }

            final decision = aiDecide(state, tuning: AiTuning.webApp);
            expect(decision, isNotNull, reason: where);
            expect(encodeAction(decision!), code, reason: where);
            decisions += 1;
          },
        );
      }
      expect(decisions, greaterThan(0));
    });
  }
}
