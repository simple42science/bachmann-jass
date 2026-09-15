import 'dart:convert';

import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/simple_players.dart';

void main() {
  test('Ein altes Regelwerk ohne die neuen Felder wird mit Standardwerten gelesen', () {
    final json = RuleSet.bachmann.toJson()
      ..remove('bedanken')
      ..remove('trickReview');
    final rules = RuleSet.fromJson(json);
    expect(rules.bedanken, isFalse);
    expect(rules.trickReview, TrickReview.first);
    expect(rules, RuleSet.bachmann);
  });

  test('copyWith und Gleichheit decken alle Regeln ab', () {
    final changed = RuleSet.bachmann.copyWith(bedanken: true, trickReview: TrickReview.all);
    expect(changed, isNot(RuleSet.bachmann));
    expect(RuleSet.fromJson(changed.toJson()), changed);
    expect(changed.copyWith(bedanken: false, trickReview: TrickReview.first), RuleSet.bachmann);
  });

  test('Alle Stiche der Runde bleiben in Reihenfolge erhalten', () {
    final state = finishRound(createGame(variant: GameVariant.schieber, seed: 8));
    expect(state.roundTricks, hasLength(9));
    expect(state.roundTricks.first.cards, state.firstCapturedTrick!.cards);
    expect(state.roundTricks.every((trick) => trick.cards.length == 4), isTrue);
    final restored = GameState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>,
    );
    expect(restored.roundTricks, hasLength(9));

    final nextRound = step(state, const StartRound());
    expect(nextRound.roundTricks, isEmpty);
  });

  group('Bedanken', () {
    GameState startNearTarget({required bool bedanken}) {
      final created = createGame(
        variant: GameVariant.schieber,
        matchConfig: const MatchConfig(targetScore: 1000),
        rules: RuleSet.bachmann.copyWith(bedanken: bedanken),
        seed: 13,
      );
      // Team 0 steht kurz vor dem Ziel; die Runde bringt es sicher darueber.
      final nearTarget = created.copyWith(
        teams: [created.teams[0].copyWith(totalScore: 990), created.teams[1]],
      );
      return step(nearTarget, const StartRound());
    }

    test('beendet die Partie mitten in der Runde, sobald das Ziel erreicht ist', () {
      var state = startNearTarget(bedanken: true);
      var guard = 0;
      while (state.phase != GamePhase.gameOver && guard < 200) {
        state = step(state, simpleAction(state)!);
        guard += 1;
      }
      expect(state.phase, GamePhase.gameOver);
      final summary = state.roundSummary! as SchieberRoundSummary;
      expect(
        summary.results.fold(0, (sum, result) => sum + result.tricksWon),
        lessThan(9),
        reason: 'Die Runde wurde nicht zu Ende gespielt',
      );
      expect(state.teams.any((team) => team.totalScore >= 1000), isTrue);
      expect(state.roundHistory, hasLength(1));
    });

    test('ohne Bedanken wird die Runde zu Ende gespielt', () {
      final state = finishRound(startNearTarget(bedanken: false));
      final summary = state.roundSummary! as SchieberRoundSummary;
      expect(summary.results.fold(0, (sum, result) => sum + result.tricksWon), 9);
      expect(state.phase, GamePhase.gameOver);
    });
  });

  test('aiDecide kann mit einer vorgegebenen Stufe entscheiden', () {
    var state = step(createGame(variant: GameVariant.schieber, seed: 2), const StartRound());
    while (state.phase != GamePhase.playing) {
      state = step(state, simpleAction(state)!);
    }
    final hint = aiDecide(state, difficulty: Difficulty.schwer);
    expect(hint, isA<PlayCard>());
    expect(playableCards(state, state.currentPlayer), contains((hint! as PlayCard).card));
  });
}
