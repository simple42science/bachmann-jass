import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/simple_players.dart';

// Portiert aus tests/engine/slalom-stoeck.test.mjs der Web-App.

const _stoeck = [JassCard(Suit.rosen, Rank.koenig), JassCard(Suit.rosen, Rank.ober)];

/// Legt Rosen-Koenig und -Ober gezielt auf die Hand von Sitz 0.
GameState primeStoeck(GameState dealt) {
  final hands = [
    for (final player in dealt.players) [...player.hand.where((entry) => !_stoeck.contains(entry))],
  ];
  hands[0].addAll(_stoeck);
  for (var seat = 1; seat < hands.length; seat += 1) {
    while (hands[seat].length < dealt.variant.handSize) {
      final donor = hands[0].indexWhere((entry) => !_stoeck.contains(entry));
      hands[seat].add(hands[0].removeAt(donor));
    }
  }
  return dealt.copyWith(
    players: [for (final player in dealt.players) player.copyWith(hand: hands[player.id])],
  );
}

GameState dealtSchieber(int seed) =>
    step(createGame(variant: GameVariant.schieber, seed: seed), const StartRound());

void main() {
  group('Slalom', () {
    test('wechselt die Spielart mit jedem Stich', () {
      expect(RoundMode.slalom.trickMode(0), RoundMode.obeAbe, reason: 'erster Stich obenabe');
      expect(RoundMode.slalom.trickMode(1), RoundMode.uneUfe, reason: 'zweiter Stich unten-ufe');
      expect(RoundMode.slalom.trickMode(2), RoundMode.obeAbe);
      expect(RoundMode.slalom.trickMode(8), RoundMode.obeAbe, reason: 'neunter Stich obenabe');
      expect(RoundMode.slalomUneUfe.trickMode(0), RoundMode.uneUfe, reason: 'von unten begonnen');
      expect(RoundMode.slalomUneUfe.trickMode(1), RoundMode.obeAbe);
      expect(RoundMode.slalomUneUfe.trickMode(8), RoundMode.uneUfe);
      expect(RoundMode.slalomUneUfe.base, RoundMode.slalom);
      expect(RoundMode.slalomUneUfe.isSlalom, isTrue);
      expect(RoundMode.baseModes, isNot(contains(RoundMode.slalomUneUfe)));
      expect(RoundMode.rosen.trickMode(3), RoundMode.rosen);
    });

    test('im ersten Stich sticht das Ass, im zweiten die Sechs', () {
      final trick = [
        TrickEntry(0, card('rosen_6')),
        TrickEntry(1, card('rosen_ass')),
        TrickEntry(2, card('rosen_10')),
        TrickEntry(3, card('rosen_7')),
      ];
      expect(trickWinner(trick, RoundMode.slalom.trickMode(0)), 1);
      expect(trickWinner(trick, RoundMode.slalom.trickMode(1)), 0);
    });

    test('Kartenwerte folgen der angesagten Richtung, nicht dem einzelnen Stich', () {
      // Von oben angesagt: das Ass zaehlt, die Sechs nicht - in jedem Stich.
      expect(cardPoints(card('rosen_ass'), RoundMode.slalom), 11);
      expect(cardPoints(card('rosen_6'), RoundMode.slalom), 0);
      // Von unten angesagt: umgekehrt.
      expect(cardPoints(card('rosen_ass'), RoundMode.slalomUneUfe), 0);
      expect(cardPoints(card('rosen_6'), RoundMode.slalomUneUfe), 11);
      // Darum ergibt eine Slalom-Runde wie jede andere 157 Punkte.
      for (final mode in [RoundMode.slalom, RoundMode.slalomUneUfe]) {
        expect(handValue(JassCard.deck, mode) + RuleSet.bachmann.lastTrickBonus, 157);
      }
    });

    test('eine ganze Slalom-Runde ergibt 157 Punkte', () {
      for (var seed = 1; seed <= 20; seed += 1) {
        for (final mode in [RoundMode.slalom, RoundMode.slalomUneUfe]) {
          var state = step(
            createGame(variant: GameVariant.schieber, seed: seed),
            const StartRound(),
          );
          state = step(state, ChooseMode(state.currentPlayer, mode));
          while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
            state = step(state, aiDecide(state) ?? const NextTrick());
          }
          expect(
            state.players.fold(0, (sum, player) => sum + player.pointsWon),
            157,
            reason: 'Seed $seed, $mode',
          );
        }
      }
    });

    test('kennt keinen Trumpf und zaehlt dreifach', () {
      expect(RuleSet.bachmann.multiplierFor(RoundMode.slalom), 3);
      expect(RuleSet.bachmann.multiplierFor(RoundMode.slalomUneUfe), 3);
      expect(
        rankIndex(card('rosen_under'), RoundMode.slalom),
        rankIndex(card('rosen_under'), RoundMode.obeAbe),
      );
    });

    test('ganze Runden bleiben regelkonform', () {
      for (var seed = 31; seed < 71; seed += 1) {
        var state = dealtSchieber(seed);
        state = step(state, ChooseMode(state.currentPlayer, RoundMode.slalom));

        final modes = <RoundMode>[];
        while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
          if (state.phase == GamePhase.playing && state.trick.isEmpty) {
            modes.add(state.trickMode!);
          }
          state = step(state, simpleAction(state)!);
        }

        expect(modes, [
          for (var trick = 0; trick < 9; trick += 1)
            trick.isEven ? RoundMode.obeAbe : RoundMode.uneUfe,
        ]);

        final summary = state.roundSummary! as SchieberRoundSummary;
        final trickTotal = summary.results.fold(0, (sum, result) => sum + result.trickPoints);
        // Asse zaehlen nur in Obenabe-Stichen, Sechser nur in Une-Ufe-Stichen.
        expect(trickTotal, inInclusiveRange(108 + 5, 196 + 5), reason: 'Seed $seed');
        expect(state.players.every((player) => player.hand.isEmpty), isTrue);
      }
    });
  });

  group('Stöck', () {
    test('wird beim Weisen noch nicht angesagt', () {
      var state = primeStoeck(dealtSchieber(5));
      state = step(state, ChooseMode(state.currentPlayer, RoundMode.rosen));

      expect(hasStoeck(state.players[0].hand, RoundMode.rosen), isTrue, reason: 'Testaufbau');
      expect(state.stoeckPlayer, 0);
      expect(state.stoeckAnnounced, isFalse);
      expect(state.teamStoeckPoints[0], 0);
    });

    test('zaehlt, sobald die zweite der beiden Karten gespielt ist', () {
      var state = primeStoeck(dealtSchieber(6));
      state = step(state, ChooseMode(state.currentPlayer, RoundMode.rosen));
      while (state.phase == GamePhase.announceWeis) {
        state = step(state, DeclineWeis(state.currentPlayer));
      }
      expect(state.stoeckAnnounced, isFalse, reason: 'Ohne Weis-Meldung bleibt es offen');

      state = step(
        state.copyWith(phase: GamePhase.playing, trick: const [], currentPlayer: 0),
        PlayCard(0, _stoeck[0]),
      );
      expect(state.stoeckAnnounced, isFalse, reason: 'Nach der ersten Karte noch nicht');

      final result = applyAction(
        state.copyWith(phase: GamePhase.playing, trick: const [], currentPlayer: 0),
        PlayCard(0, _stoeck[1]),
      );
      expect(result.state.stoeckAnnounced, isTrue, reason: 'Nach der zweiten Karte schon');
      expect(result.state.teamStoeckPoints[0], RuleSet.bachmann.stoeckPoints);
      expect(result.events.whereType<StoeckAnnounced>().single.inWeis, isFalse);
    });

    test('ein Weis mit beiden Stöck-Karten sagt Stöck gleich mit an', () {
      final sequence = [card('rosen_under'), card('rosen_ober'), card('rosen_koenig')];
      final dealt = dealtSchieber(12);
      final rest = dealt.players[0].hand.where((entry) => !sequence.contains(entry)).take(6);

      var state = dealt.copyWith(
        players: [
          for (final player in dealt.players)
            player.id == 0
                ? player.copyWith(hand: [...sequence, ...rest])
                : player.copyWith(
                    hand: [...player.hand.where((entry) => !sequence.contains(entry))],
                  ),
        ],
      );
      state = step(state, ChooseMode(state.currentPlayer, RoundMode.rosen));
      expect(state.stoeckPlayer, 0);
      expect(state.stoeckAnnounced, isFalse);

      while (state.phase == GamePhase.announceWeis && state.currentPlayer != 0) {
        state = step(state, DeclineWeis(state.currentPlayer));
      }
      final result = applyAction(state, const DeclareWeis(0));

      expect(result.state.stoeckAnnounced, isTrue, reason: 'Stöck steckt im gemeldeten Weis');
      expect(result.state.teamStoeckPoints[0], RuleSet.bachmann.stoeckPoints);
      expect(result.events.whereType<StoeckAnnounced>().single.inWeis, isTrue);
    });
  });

  group('Zaehlweise im Bieterjass', () {
    GameState bieter(BieterScoring scoring, {int seed = 1}) => createGame(
      variant: GameVariant.bieter,
      matchConfig: MatchConfig(targetScore: 1500, bieterScoring: scoring),
      seed: seed,
    );

    test('einfach: nur die vier Farben, alles zaehlt einfach', () {
      final game = bieter(BieterScoring.einfach);
      expect(game.allowedRoundModes, RoundMode.trumpModes);
      expect(game.usesRoundMultipliers, isFalse);
      expect(game.copyWith(roundMode: RoundMode.schellen).roundMultiplier, 1);
      expect(game.copyWith(roundMode: RoundMode.obeAbe).roundMultiplier, 1);
    });

    test('wie im Schieber: alle Spielarten und Multiplikatoren', () {
      final game = bieter(BieterScoring.schieber);
      expect(game.allowedRoundModes, RoundMode.values);
      expect(game.usesRoundMultipliers, isTrue);
      expect(game.copyWith(roundMode: RoundMode.rosen).roundMultiplier, 1);
      expect(game.copyWith(roundMode: RoundMode.schilten).roundMultiplier, 2);
      expect(game.copyWith(roundMode: RoundMode.slalom).roundMultiplier, 3);
    });

    test('der Multiplikator wirkt auf die Spielpunkte, nicht auf das Gebot', () {
      BieterRoundSummary playRound(BieterScoring scoring) {
        var state = step(bieter(scoring, seed: 77), const StartRound());
        final [first, second, third] = state.biddingOrder;
        state = step(state, PlaceBid(first, 450));
        state = step(state, PassBid(second));
        state = step(state, PassBid(third));
        state = step(state, ChooseMode(state.currentPlayer, RoundMode.schilten));
        return finishRound(state).roundSummary! as BieterRoundSummary;
      }

      final einfach = playRound(BieterScoring.einfach);
      final wieSchieber = playRound(BieterScoring.schieber);

      expect(einfach.bid, 450, reason: 'Das Gebot gilt fuer die ganze Partie');
      expect(wieSchieber.bid, 450, reason: 'Das Gebot bleibt gleich');
      expect(einfach.multiplier, 1);
      expect(wieSchieber.multiplier, 2, reason: 'Schilten zaehlt doppelt');
      expect(
        wieSchieber.soloPoints,
        einfach.soloPoints * 2,
        reason: 'Gleiche Karten, die Rundenpunkte zaehlen doppelt',
      );
      expect(wieSchieber.pairPoints, einfach.pairPoints * 2);
      expect(einfach.soloPoints + einfach.pairPoints, 157, reason: '152 Kartenpunkte plus 5');
    });
  });
}
