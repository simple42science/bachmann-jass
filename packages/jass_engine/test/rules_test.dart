import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

import 'support/simple_players.dart';

// Portiert aus tests/engine/rules.test.mjs der Web-App.

List<String> ids(Iterable<JassCard> cards) => [for (final entry in cards) entry.id]..sort();

List<JassCard> hand(List<String> cardIds) => [for (final id in cardIds) card(id)];

TrickEntry played(int seat, String id) => TrickEntry(seat, card(id));

void main() {
  group('Bedienpflicht nach offiziellen Regeln', () {
    test('wer die Farbe hat, muss bedienen', () {
      final trick = [played(0, 'eicheln_ass'), played(1, 'rosen_under')];
      expect(
        ids(legalCards(hand(['eicheln_6', 'schilten_ass', 'schellen_10']), trick, RoundMode.rosen)),
        ['eicheln_6'],
      );
    });

    test('kein Trumpfzwang: ohne Bedienfarbe darf abgeworfen werden', () {
      final trick = [played(0, 'eicheln_ass')];
      expect(
        ids(legalCards(hand(['rosen_ass', 'rosen_6', 'schilten_koenig']), trick, RoundMode.rosen)),
        ['rosen_6', 'rosen_ass', 'schilten_koenig'],
      );
    });

    test('kein Uebertrumpfzwang: hoeherer Trumpf ist erlaubt, nicht Pflicht', () {
      final trick = [played(0, 'eicheln_ass'), played(1, 'rosen_10')];
      expect(
        ids(legalCards(hand(['rosen_ass', 'schilten_7', 'schellen_10']), trick, RoundMode.rosen)),
        ['rosen_ass', 'schellen_10', 'schilten_7'],
      );
    });

    test('Untertrumpfen ist verboten, solange Fehlkarten in der Hand sind', () {
      final trick = [played(0, 'eicheln_ass'), played(1, 'rosen_ass')];
      expect(ids(legalCards(hand(['rosen_6', 'schilten_7']), trick, RoundMode.rosen)), [
        'schilten_7',
      ]);
    });

    test('Untertrumpfen ist erlaubt, wenn nur noch Trumpf in der Hand liegt', () {
      final trick = [played(0, 'eicheln_ass'), played(1, 'rosen_ass')];
      expect(ids(legalCards(hand(['rosen_6', 'rosen_7']), trick, RoundMode.rosen)), [
        'rosen_6',
        'rosen_7',
      ]);
    });

    test('Trumpf darf gespielt werden, obwohl man bedienen koennte', () {
      final trick = [played(0, 'eicheln_ass')];
      expect(ids(legalCards(hand(['eicheln_6', 'rosen_under']), trick, RoundMode.rosen)), [
        'eicheln_6',
        'rosen_under',
      ]);
    });

    test('Trumpf angespielt: Trumpf muss bedient werden', () {
      final trick = [played(0, 'rosen_koenig')];
      expect(ids(legalCards(hand(['rosen_6', 'eicheln_ass']), trick, RoundMode.rosen)), [
        'rosen_6',
      ]);
    });

    test('Puur-Ausnahme: der einzige Trumpf-Under muss nicht bedient werden', () {
      final trick = [played(0, 'rosen_koenig')];
      expect(ids(legalCards(hand(['rosen_under', 'eicheln_ass']), trick, RoundMode.rosen)), [
        'eicheln_ass',
        'rosen_under',
      ]);
    });

    test('Obe-Abe und Une-Ufe kennen nur Farbzwang', () {
      final trick = [played(0, 'eicheln_ass')];
      expect(ids(legalCards(hand(['eicheln_6', 'schellen_under']), trick, RoundMode.obeAbe)), [
        'eicheln_6',
      ]);
      expect(ids(legalCards(hand(['schellen_under']), trick, RoundMode.uneUfe)), [
        'schellen_under',
      ]);
    });

    test('Bieterjass benutzt dieselbe Bedienpflicht wie der Schieber', () {
      final base = createGame(variant: GameVariant.bieter, seed: 1);
      final state = withHand(
        base.copyWith(
          phase: GamePhase.playing,
          roundMode: RoundMode.rosen,
          trick: [played(0, 'eicheln_ass')],
          currentPlayer: 1,
        ),
        1,
        hand(['rosen_ass', 'schilten_7']),
      );
      expect(ids(playableCards(state, 1)), ['rosen_ass', 'schilten_7']);
    });
  });

  test('Geber und Vorhand ruecken jede Runde gemeinsam weiter', () {
    var state = step(
      createGame(
        variant: GameVariant.schieber,
        matchConfig: const MatchConfig(targetScore: 2500),
        seed: 21,
      ),
      const StartRound(),
    );
    final firstDealer = state.dealer;

    expect(state.forehandPlayer, (firstDealer + 1) % 4, reason: 'Vorhand sitzt neben dem Geber');
    expect(state.players[state.forehandPlayer].hand, contains(card('rosen_7')));

    for (var round = 2; round <= 8; round += 1) {
      state = step(finishRound(state), const StartRound());
      expect(state.dealer, (firstDealer + round - 1) % 4, reason: 'Geber in Runde $round');
      expect(state.forehandPlayer, (state.dealer + 1) % 4, reason: 'Vorhand in Runde $round');
      expect(state.chooserPlayer, state.forehandPlayer, reason: 'Vorhand waehlt die Spielart');
    }
  });

  group('Steigern im Bieterjass', () {
    GameState dealt({int startBid = 450}) => step(
      createGame(
        variant: GameVariant.bieter,
        seed: 1,
        matchConfig: MatchConfig(targetScore: 1000, bieterStartBid: startBid),
      ),
      const StartRound(),
    );

    test('gesteigert wird ab dem Anfangsgebot, bis alle bis auf einen passen', () {
      var state = dealt();
      final [first, second, third] = state.biddingOrder;

      expect(minimumBid(state), 450);
      state = step(state, PlaceBid(first, 450));
      expect(state.currentPlayer, second);
      expect(minimumBid(state), 460);
      state = step(state, PlaceBid(second, 500));
      expect(state.currentPlayer, third);
      state = step(state, PassBid(third));
      expect(state.currentPlayer, first, reason: 'Der erste Bieter darf nachziehen');
      state = step(state, PlaceBid(first, 530));
      expect(state.currentPlayer, second);
      state = step(state, PassBid(second));

      expect(state.phase, GamePhase.chooseTrump);
      expect(state.soloPlayer, first);
      expect(state.currentPlayer, first, reason: 'der Bieter sagt in der ersten Runde an');
      expect(state.highestBid, 530);
      final playing = step(state, ChooseMode(first, RoundMode.rosen));
      expect(playing.trickLeader, first, reason: 'der Bieter spielt die erste Karte aus');
      expect(playing.currentPlayer, first);
      expect(state.soloTarget, 530);
      expect(state.pairTarget, 1000);
      expect(state.players[first].teamId, 0);
      expect(state.players.where((p) => p.id != first).map((p) => p.teamId), everyElement(1));
    });

    test('passen alle, spielt der Geber mit dem Anfangsgebot', () {
      var state = dealt(startBid: 500);
      for (final seat in state.biddingOrder) {
        state = step(state, PassBid(seat));
      }
      expect(state.phase, GamePhase.chooseTrump);
      expect(state.soloPlayer, state.dealer);
      expect(state.highestBid, 500);
    });

    test('ein zu tiefes oder unsinniges Gebot ist ungueltig', () {
      final state = dealt();
      final [first, second, _] = state.biddingOrder;
      expect(() => applyAction(state, PlaceBid(first, 440)), throwsA(isA<GameRuleException>()));
      expect(() => applyAction(state, PlaceBid(first, 5000)), throwsA(isA<GameRuleException>()));
      final afterBid = step(state, PlaceBid(first, 480));
      expect(() => applyAction(afterBid, PlaceBid(second, 485)), throwsA(isA<GameRuleException>()));
      expect(step(afterBid, PlaceBid(second, 490)).highestBid, 490);
    });

    test('der Bieter bleibt die ganze Partie und die Seiten sammeln auf ihr Ziel', () {
      var state = dealt();
      final [first, second, third] = state.biddingOrder;
      state = step(state, PlaceBid(first, 450));
      state = step(state, PassBid(second));
      state = step(state, PassBid(third));
      final solo = state.soloPlayer;
      expect(state.currentPlayer, solo, reason: 'Runde 1: der Bieter sagt an');

      var rounds = 0;
      while (state.phase != GamePhase.gameOver && rounds < 40) {
        while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
          state = applyAction(state, aiDecide(state) ?? const NextTrick()).state;
        }
        final summary = state.roundSummary! as BieterRoundSummary;
        expect(summary.soloPlayer, solo);
        expect(summary.bid, 450);
        expect(state.players[solo].totalScore, summary.soloTotal);
        expect(state.pairScore, summary.pairTotal);
        rounds += 1;
        if (state.phase == GamePhase.roundEnd) {
          state = step(state, const StartRound());
          expect(state.phase, GamePhase.chooseTrump, reason: 'kein zweites Steigern');
          expect(state.soloPlayer, solo);
          expect(state.currentPlayer, (state.dealer + 1) % 3, reason: 'die Vorhand sagt reihum an');
        }
      }
      expect(state.phase, GamePhase.gameOver);
      final last = state.roundSummary! as BieterRoundSummary;
      expect(last.soloWon || last.pairWon, isTrue);
      if (last.soloWon) {
        expect(state.players[solo].totalScore, greaterThanOrEqualTo(450));
      } else {
        expect(state.pairScore, greaterThanOrEqualTo(1000));
        expect(state.players[solo].totalScore, lessThan(450));
      }
    });
  });

  group('Stöck und Match', () {
    test('Koenig und Ober der Trumpffarbe sind Stöck', () {
      expect(hasStoeck(hand(['rosen_koenig', 'rosen_ober']), RoundMode.rosen), isTrue);
      expect(hasStoeck(hand(['rosen_koenig', 'eicheln_ober']), RoundMode.rosen), isFalse);
      expect(
        hasStoeck(hand(['rosen_koenig', 'rosen_ober']), RoundMode.obeAbe),
        isFalse,
        reason: 'Kein Stöck ohne Trumpf',
      );
    });

    test('der Stöck-Besitzer wird erkannt, aber noch nicht gutgeschrieben', () {
      var state = step(createGame(variant: GameVariant.schieber, seed: 5), const StartRound());
      final holder = state.players.indexWhere((player) => hasStoeck(player.hand, RoundMode.rosen));
      state = step(state, ChooseMode(state.currentPlayer, RoundMode.rosen));

      expect(state.stoeckPlayer, holder);
      expect(state.stoeckAnnounced, isFalse, reason: 'Angesagt wird erst waehrend des Spiels');
      expect(state.teamStoeckPoints, [0, 0]);
    });

    test('alle Stiche einer Runde geben 100 Zusatzpunkte', () {
      final base = createGame(variant: GameVariant.schieber, seed: 1);
      GameState withTricks(int seat0, int seat2) => base.copyWith(
        roundMode: RoundMode.rosen,
        players: [
          for (final player in base.players)
            switch (player.id) {
              0 => player.copyWith(tricksWon: seat0),
              2 => player.copyWith(tricksWon: seat2),
              _ => player,
            },
        ],
      );

      expect(schieberTeamResult(withTricks(5, 4), 0).matchPoints, RuleSet.bachmann.matchBonus);
      expect(schieberTeamResult(withTricks(5, 4), 1).matchPoints, 0);
      expect(schieberTeamResult(withTricks(5, 3), 0).matchPoints, 0, reason: 'Ein Stich fehlt');
    });
  });

  group('Punktetabellen', () {
    test('Spielart-Multiplikatoren gelten in beiden Partien gleich', () {
      const expected = {
        RoundMode.rosen: 1,
        RoundMode.eicheln: 1,
        RoundMode.schellen: 2,
        RoundMode.schilten: 2,
        RoundMode.obeAbe: 3,
        RoundMode.uneUfe: 3,
        RoundMode.slalom: 3,
      };
      for (final target in [1000, 2500]) {
        final game = createGame(
          variant: GameVariant.schieber,
          matchConfig: MatchConfig(targetScore: target),
        );
        for (final MapEntry(key: mode, value: factor) in expected.entries) {
          expect(
            game.copyWith(roundMode: mode).roundMultiplier,
            factor,
            reason: '$mode im $target-er',
          );
        }
      }
    });

    test('Vier Sechser zaehlen nicht, vier Under und vier Neuner schon', () {
      List<Weis> four(Rank rank) => detectWeis(
        [for (final suit in Suit.values) JassCard(suit, rank)],
        RoundMode.obeAbe,
        RuleSet.bachmann,
      );
      expect(four(Rank.six), isEmpty);
      expect(four(Rank.under).first.points, 200);
      expect(four(Rank.nine).first.points, 150);
      expect(four(Rank.ass).first.points, 100);
      expect(four(Rank.seven).first.points, 100);
    });

    test('Vier Gleiche schlagen die Folge bei gleicher Punktzahl', () {
      final sequence = detectWeis(
        hand(['rosen_6', 'rosen_7', 'rosen_8', 'rosen_9', 'rosen_10']),
        RoundMode.obeAbe,
        RuleSet.bachmann,
      ).first;
      final fourOfKind = detectWeis(
        [for (final suit in Suit.values) JassCard(suit, Rank.ass)],
        RoundMode.obeAbe,
        RuleSet.bachmann,
      ).first;

      expect(sequence.points, 100);
      expect(fourOfKind.points, 100);
      expect(compareWeis(fourOfKind, sequence, RoundMode.obeAbe, RuleSet.bachmann), greaterThan(0));
    });

    test('Kartenwerte ergeben in jeder Spielart 157 inklusive letztem Stich', () {
      for (final mode in RoundMode.values) {
        final total = handValue(JassCard.deck, mode);
        expect(total + RuleSet.bachmann.lastTrickBonus, 157, reason: 'Summe fuer $mode');
      }
    });
  });

  test('Wer auf den Weis verzichtet, schreibt keine Weispunkte', () {
    var state = step(createGame(variant: GameVariant.schieber, seed: 9), const StartRound());
    state = step(state, ChooseMode(state.currentPlayer, RoundMode.obeAbe));
    while (state.phase == GamePhase.announceWeis) {
      state = step(state, DeclineWeis(state.currentPlayer));
    }
    expect(state.teamWeisScores, [0, 0]);
    expect(state.phase, GamePhase.playing);
  });
}
