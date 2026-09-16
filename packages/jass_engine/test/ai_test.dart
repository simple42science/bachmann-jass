import 'dart:convert';

import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/simple_players.dart';

// Portiert aus tests/engine/ai.test.mjs und den Vollsimulationen aus rules.test.mjs.

const rules = RuleSet.bachmann;

List<JassCard> hand(List<String> cardIds) => [for (final id in cardIds) card(id)];

/// Spielt bis zum Rundenende; alle Entscheidungen trifft die KI.
GameState aiRound(GameState state) {
  var current = state;
  do {
    final action = aiDecide(current) ?? simpleAction(current)!;
    if (action is PlayCard) {
      expect(
        playableCards(current, action.playerIndex),
        contains(action.card),
        reason: 'Die KI muss legal spielen',
      );
    }
    current = step(current, action);
  } while (current.phase != GamePhase.roundEnd && current.phase != GamePhase.gameOver);
  return current;
}

/// Punkte der Runde, Stich fuer Stich nach der jeweiligen Spielart gezaehlt
/// (im Slalom wechselt sie, darum ist die Summe dort nicht fest 157).
int roundTrickPoints(GameState state) {
  final mode = state.roundMode!;
  var total = state.rules.lastTrickBonus;
  for (var index = 0; index < state.roundTricks.length; index += 1) {
    total += trickPoints(state.roundTricks[index].cards, mode.trickMode(index));
  }
  return total;
}

void main() {
  group('Handbewertung', () {
    test('Puur und Nell wiegen schwerer als Ass und Koenig', () {
      expect(
        evaluateTrumpSuit(hand(['rosen_under', 'rosen_9', 'rosen_6']), Suit.rosen),
        greaterThan(
          evaluateTrumpSuit(hand(['eicheln_ass', 'eicheln_koenig', 'eicheln_10']), Suit.eicheln),
        ),
      );
    });

    test('bestTrumpSuit waehlt die Farbe mit der echten Trumpfstaerke', () {
      final cards = hand([
        'rosen_under', 'rosen_9', 'rosen_8', 'rosen_7', //
        'eicheln_ass', 'eicheln_koenig', 'eicheln_ober', 'schellen_6', 'schilten_6',
      ]);
      expect(bestTrumpSuit(cards), Suit.rosen);
    });

    test('eine Hand aus lauter tiefen Karten ist eine Une-Ufe-Hand', () {
      final lowCards = hand([
        'rosen_6', 'rosen_7', 'eicheln_8', 'eicheln_6', 'schellen_7', //
        'schellen_8', 'schilten_6', 'schilten_7', 'schilten_8',
      ]);
      expect(bestSchieberMode(lowCards, rules), RoundMode.uneUfe);
      expect(shouldPushTrump(lowCards, rules), isFalse, reason: 'Mit Une-Ufe wird nicht geschoben');
    });

    final weak = hand([
      'rosen_8', 'rosen_10', 'eicheln_9', 'eicheln_ober', 'schellen_8', //
      'schellen_koenig', 'schilten_9', 'schilten_10', 'schilten_ober',
    ]);
    final strong = hand([
      'rosen_under', 'rosen_9', 'rosen_ass', 'rosen_koenig', 'rosen_10', //
      'eicheln_ass', 'eicheln_koenig', 'schellen_ass', 'schilten_6',
    ]);

    test('schwache Haende werden geschoben, starke nicht', () {
      expect(shouldPushTrump(weak, rules), isTrue);
      expect(shouldPushTrump(strong, rules), isFalse);
    });

    test('der Multiplikator wirkt auf den Vorteil, nicht auf die Erwartung', () {
      expect(
        modeAdvantage(weak, RoundMode.obeAbe, rules),
        lessThan(modeAdvantage(weak, RoundMode.rosen, rules)),
      );
      expect(
        modeAdvantage(weak, RoundMode.schellen, rules),
        lessThan(modeAdvantage(weak, RoundMode.eicheln, rules)),
      );
    });
  });

  group('Kartenspiel', () {
    test('jede Stufe spielt ueber ganze Runden nur legale Karten', () {
      for (final level in Difficulty.values) {
        for (var index = 0; index < 15; index += 1) {
          final state = createGame(
            variant: GameVariant.schieber,
            matchConfig: MatchConfig(targetScore: 1000, difficulty: level),
            seed: 4242 + index,
          );
          final ended = aiRound(step(state, const StartRound()));
          expect(ended.players.every((player) => player.hand.isEmpty), isTrue);
        }
      }
    });

    test('die Stufen bilden eine echte Rangfolge', () {
      double duel(Difficulty levelA, Difficulty levelB, int deals) {
        var winsA = 0;
        var winsB = 0;
        for (var seed = 1; seed <= deals; seed += 1) {
          for (final swapped in [false, true]) {
            final teamZero = swapped ? levelB : levelA;
            final teamOne = swapped ? levelA : levelB;
            var state = createGame(
              variant: GameVariant.schieber,
              matchConfig: const MatchConfig(targetScore: 1000),
              seed: seed,
              seats: [
                for (var seat = 0; seat < 4; seat += 1)
                  SeatSetup(
                    name: 'Sitz $seat',
                    isHuman: false,
                    difficulty: seat.isEven ? teamZero : teamOne,
                  ),
              ],
            );
            for (var rounds = 0; state.phase != GamePhase.gameOver && rounds < 40; rounds += 1) {
              state = aiRound(step(state, const StartRound()));
            }
            final scoreA = state.teams[swapped ? 1 : 0].totalScore;
            final scoreB = state.teams[swapped ? 0 : 1].totalScore;
            if (scoreA > scoreB) {
              winsA += 1;
            } else if (scoreB > scoreA) {
              winsB += 1;
            }
          }
        }
        return winsA / (winsA + winsB);
      }

      expect(duel(Difficulty.normal, Difficulty.einfach, 30), greaterThan(0.55));
      expect(duel(Difficulty.schwer, Difficulty.einfach, 30), greaterThan(0.55));
    });

    test('ein Spielstand mitten im Stich uebersteht JSON und laesst sich zu Ende spielen', () {
      var state = step(
        createGame(
          variant: GameVariant.schieber,
          matchConfig: const MatchConfig(targetScore: 1000, difficulty: Difficulty.schwer),
          seed: 7,
        ),
        const StartRound(),
      );
      while (state.trick.length != 1) {
        state = step(state, aiDecide(state)!);
      }

      final restored = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>,
      );
      expect(restored.phase, state.phase);
      expect(restored.trick, hasLength(1));
      expect(restored.playedCards, hasLength(1));
      expect(restored.currentPlayer, state.currentPlayer);
      expect(restored.players[0].hand, state.players[0].hand);

      final ended = aiRound(restored);
      expect(roundTrickPoints(ended), 157);
    });
  });

  group('Vollsimulation mit KI', () {
    test('200 Schieber-Runden bleiben regelkonform', () {
      for (var index = 0; index < 200; index += 1) {
        final state = createGame(
          variant: GameVariant.schieber,
          matchConfig: const MatchConfig(targetScore: 2500),
          seed: 10000 + index,
        );
        final ended = aiRound(step(state, const StartRound()));
        final summary = ended.roundSummary! as SchieberRoundSummary;
        expect(
          summary.results.fold(0, (sum, result) => sum + result.trickPoints),
          roundTrickPoints(ended),
        );
        expect(ended.roundMode!.isSlalom || roundTrickPoints(ended) == 157, isTrue);
        expect(summary.results.fold(0, (sum, result) => sum + result.tricksWon), 9);
      }
    });

    test('200 Bieterjass-Runden bleiben regelkonform', () {
      for (var index = 0; index < 200; index += 1) {
        final state = createGame(variant: GameVariant.bieter, seed: 20000 + index);
        final ended = aiRound(step(state, const StartRound()));
        expect(ended.players.every((player) => player.hand.isEmpty), isTrue);
        expect(ended.roundMode!.isSlalom || roundTrickPoints(ended) == 157, isTrue);
        expect(
          ended.players.fold(0, (sum, player) => sum + player.pointsWon),
          roundTrickPoints(ended),
        );
      }
    });

    test('eine ganze Partie erreicht den Zielscore', () {
      var state = createGame(
        variant: GameVariant.schieber,
        matchConfig: const MatchConfig(targetScore: 1000),
        seed: 99,
      );
      for (var rounds = 0; state.phase != GamePhase.gameOver && rounds < 100; rounds += 1) {
        state = aiRound(step(state, const StartRound()));
      }
      expect(state.phase, GamePhase.gameOver);
      expect(state.teams.any((team) => team.totalScore >= 1000), isTrue);
    });
  });
}
