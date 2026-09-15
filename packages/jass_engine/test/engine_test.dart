import 'dart:convert';

import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/simple_players.dart';

void expectCleanRoundEnd(GameState state) {
  expect(
    state.players.every((player) => player.hand.isEmpty),
    isTrue,
    reason: 'Alle Karten gespielt',
  );
  final tricks = state.players.fold(0, (sum, player) => sum + player.tricksWon);
  expect(tricks, state.variant.handSize, reason: 'Anzahl Stiche');
  final trickPoints = state.players.fold(0, (sum, player) => sum + player.pointsWon);
  expect(trickPoints, 157, reason: 'Stichpunkte einer Rosen-Runde');

  if (state.stoeckPlayer >= 0) {
    expect(
      state.stoeckAnnounced,
      isTrue,
      reason: 'Stöck ist spaetestens mit der zweiten Karte angesagt',
    );
  }
  final summary = state.roundSummary;
  if (summary is SchieberRoundSummary) {
    expect(summary.results.fold(0, (sum, result) => sum + result.trickPoints), 157);
  }
  expect(state.roundHistory.last.summary, same(summary));
}

void main() {
  for (final variant in GameVariant.values) {
    test('${variant.name}: ganze Partien laufen regelkonform bis zum Ziel', () {
      for (var seed = 1; seed <= 15; seed += 1) {
        // Die Testspieler bieten im Bieterjass immer 60 und spielen zufaellig; die
        // Punkte pendeln dann um null. Ein tieferes Ziel haelt den Test kurz.
        var state = createGame(
          variant: variant,
          seed: seed,
          matchConfig: variant == GameVariant.bieter ? const MatchConfig(targetScore: 300) : null,
        );
        var rounds = 0;
        while (state.phase != GamePhase.gameOver && rounds < 400) {
          state = finishRound(state);
          expectCleanRoundEnd(state);
          rounds += 1;
        }
        expect(
          state.phase,
          GamePhase.gameOver,
          reason: 'Seed $seed endet nach $rounds Runden nicht',
        );
        expect(state.roundHistory, hasLength(rounds));
      }
    });
  }

  test('Derselbe Seed ergibt dieselbe Partie', () {
    String playOut(int seed) {
      var state = createGame(variant: GameVariant.schieber, seed: seed);
      for (var round = 0; round < 3; round += 1) {
        state = finishRound(state);
      }
      return jsonEncode(state.toJson());
    }

    expect(playOut(8), playOut(8));
    expect(playOut(8), isNot(playOut(9)));
  });

  test('Eine Aktion veraendert den uebergebenen Zustand nicht', () {
    final start = step(createGame(variant: GameVariant.schieber, seed: 3), const StartRound());
    final before = jsonEncode(start.toJson());

    var state = start;
    for (var index = 0; index < 20; index += 1) {
      state = step(state, simpleAction(state)!);
    }

    expect(jsonEncode(start.toJson()), before);
    expect(jsonEncode(state.toJson()), isNot(before));
  });

  test('Ereignisse beschreiben den Ablauf in der richtigen Reihenfolge', () {
    final created = createGame(variant: GameVariant.schieber, seed: 11);
    final started = applyAction(created, const StartRound());
    expect(started.events.single, isA<RoundStarted>());

    var state = step(started.state, ChooseMode(started.state.currentPlayer, RoundMode.rosen));
    while (state.phase == GamePhase.announceWeis) {
      state = step(state, DeclineWeis(state.currentPlayer));
    }

    final kinds = <Type>[];
    for (var seat = 0; seat < 4; seat += 1) {
      final result = applyAction(state, simpleAction(state)!);
      kinds.addAll(result.events.whereType<GameEvent>().map((event) => event.runtimeType));
      state = result.state;
    }

    expect(kinds.whereType<Type>().where((type) => type == CardPlayed), hasLength(4));
    expect(kinds.last, TrickWon);
    expect(state.phase, GamePhase.trickEnd);
  });

  group('Ungueltige Aktionen', () {
    GameRuleException? violationOf(GameState state, GameAction action) {
      try {
        applyAction(state, action);
        return null;
      } on GameRuleException catch (error) {
        return error;
      }
    }

    test('werden mit einem typisierten Grund abgelehnt', () {
      final bieter = step(createGame(variant: GameVariant.bieter, seed: 2), const StartRound());
      final first = bieter.biddingOrder[0];
      final second = bieter.biddingOrder[1];

      expect(violationOf(bieter, PassBid(second))?.violation, RuleViolation.notYourTurn);
      expect(violationOf(bieter, PlaceBid(first, 65))?.violation, RuleViolation.invalidBid);
      expect(violationOf(bieter, PushTrump(first))?.violation, RuleViolation.pushNotAllowed);
      expect(violationOf(bieter, const NextTrick())?.violation, RuleViolation.wrongPhase);

      final afterBid = step(bieter, PlaceBid(first, 80));
      expect(violationOf(afterBid, PlaceBid(second, 70))?.violation, RuleViolation.bidTooLow);

      final schieber = step(createGame(variant: GameVariant.schieber, seed: 2), const StartRound());
      expect(
        violationOf(schieber, PlaceBid(schieber.currentPlayer, 60))?.violation,
        RuleViolation.wrongVariant,
      );

      var playing = step(schieber, ChooseMode(schieber.currentPlayer, RoundMode.obeAbe));
      while (playing.phase == GamePhase.announceWeis) {
        playing = step(playing, DeclineWeis(playing.currentPlayer));
      }
      final foreign = playing.players[(playing.currentPlayer + 1) % 4].hand.first;
      expect(
        violationOf(playing, PlayCard(playing.currentPlayer, foreign))?.violation,
        RuleViolation.cardNotInHand,
      );
    });

    test('lassen sich im einfachen Bieterjass nicht mit Obe-Abe umgehen', () {
      var state = step(createGame(variant: GameVariant.bieter, seed: 4), const StartRound());
      while (state.phase == GamePhase.bidding) {
        state = step(state, simpleAction(state)!);
      }
      expect(
        () => applyAction(state, ChooseMode(state.currentPlayer, RoundMode.obeAbe)),
        throwsA(
          isA<GameRuleException>().having(
            (e) => e.violation,
            'violation',
            RuleViolation.modeNotAllowed,
          ),
        ),
      );
    });
  });

  test('playRestriction nennt den Grund einer gesperrten Karte', () {
    final hand = [card('rosen_6'), card('eicheln_ass'), card('schilten_7')];
    final trumpLed = [TrickEntry(0, card('rosen_koenig'))];
    final sideLed = [TrickEntry(0, card('eicheln_10')), TrickEntry(1, card('rosen_ass'))];

    expect(playRestriction(hand, trumpLed, RoundMode.rosen, card('rosen_6')), isNull);
    expect(
      playRestriction(hand, trumpLed, RoundMode.rosen, card('eicheln_ass')),
      PlayRestriction.mustFollowTrump,
    );
    expect(
      playRestriction(hand, sideLed, RoundMode.rosen, card('schilten_7')),
      PlayRestriction.mustFollowSuit,
    );
    expect(
      playRestriction(hand, sideLed, RoundMode.rosen, card('rosen_6')),
      PlayRestriction.noUndertrump,
    );
    expect(
      playRestriction(hand, sideLed, RoundMode.rosen, card('schellen_9')),
      PlayRestriction.notInHand,
    );
  });

  test('Aktionen ueberstehen JSON', () {
    final actions = <GameAction>[
      const StartRound(),
      const PlaceBid(1, 90),
      const PassBid(2),
      const PushTrump(0),
      const ChooseMode(2, RoundMode.slalom),
      const DeclareWeis(3),
      const DeclareWeis(3, 'sequence:rosen:6:8'),
      const DeclineWeis(1),
      PlayCard(0, card('schellen_under')),
      const NextTrick(),
    ];
    for (final action in actions) {
      expect(
        GameAction.fromJson(jsonDecode(jsonEncode(action.toJson())) as Map<String, Object?>),
        action,
      );
    }
  });
}
