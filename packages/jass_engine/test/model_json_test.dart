import 'dart:convert';

import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

JassCard card(String id) => JassCard.fromId(id);

/// Ein Spielstand, in dem jedes optionale Feld belegt ist.
GameState richState() {
  final weis = detectWeis(
    [card('rosen_under'), card('rosen_ober'), card('rosen_koenig'), card('eicheln_6')],
    RoundMode.rosen,
    RuleSet.bachmann,
  ).first.withPlayer(0);

  const schieberSummary = SchieberRoundSummary(
    roundMode: RoundMode.schellen,
    multiplier: 2,
    results: [
      TeamRoundResult(
        teamId: 0,
        trickPoints: 100,
        weisPoints: 20,
        stoeckPoints: 20,
        matchPoints: 0,
        basePoints: 140,
        roundPoints: 280,
        tricksWon: 6,
      ),
      TeamRoundResult(
        teamId: 1,
        trickPoints: 57,
        weisPoints: 0,
        stoeckPoints: 0,
        matchPoints: 0,
        basePoints: 57,
        roundPoints: 114,
        tricksWon: 3,
      ),
    ],
    roundWinnerTeamId: 0,
    trumpChooser: 2,
    pushed: true,
    targetScore: 2500,
    weisWinnerTeamId: 0,
    highestWeis: null,
    stoeckPlayer: 0,
    matchTeamId: null,
  );

  const bieterSummary = BieterRoundSummary(
    roundMode: RoundMode.obeAbe,
    multiplier: 3,
    soloPlayer: 1,
    bid: 90,
    soloPoints: 71,
    succeeded: false,
    soloGain: -270,
    defenderGain: 135,
  );

  final firstTrick = [
    TrickEntry(0, card('eicheln_ass')),
    TrickEntry(1, card('eicheln_7')),
    TrickEntry(2, card('eicheln_10')),
    TrickEntry(3, card('schilten_6')),
  ];

  return GameState(
    variant: GameVariant.schieber,
    matchConfig: const MatchConfig(targetScore: 2500, difficulty: Difficulty.schwer),
    rules: RuleSet.bachmann,
    seed: 4242,
    rngState: 123456789,
    players: [
      Player(
        id: 0,
        name: 'Du',
        isHuman: true,
        teamId: 0,
        hand: [card('rosen_ass'), card('schellen_10')],
        tricksWon: 1,
        pointsWon: 21,
      ),
      Player(
        id: 1,
        name: 'Yannick',
        isHuman: false,
        teamId: 1,
        difficulty: Difficulty.einfach,
        hand: [card('schellen_9')],
      ),
      const Player(id: 2, name: 'Papsli', isHuman: false, teamId: 0),
      const Player(id: 3, name: 'Gusti', isHuman: false, teamId: 1, bid: 0, totalScore: 17),
    ],
    teams: const [
      Team(id: 0, playerIds: [0, 2], totalScore: 280),
      Team(id: 1, playerIds: [1, 3], totalScore: 114),
    ],
    phase: GamePhase.playing,
    roundNumber: 2,
    dealer: 3,
    currentPlayer: 1,
    biddingOrder: const [1, 2, 0],
    biddingPassed: const [2],
    highestBid: 0,
    highestBidder: -1,
    roundMode: RoundMode.slalom,
    soloPlayer: -1,
    chooserPlayer: 2,
    forehandPlayer: 0,
    trumpWasPushed: true,
    trick: [TrickEntry(0, card('rosen_6'))],
    trickLeader: 0,
    trickNumber: 1,
    playedCards: [for (final entry in firstTrick) entry.card, card('rosen_6')],
    capturedCards: [
      [for (final entry in firstTrick) entry.card],
      const [],
    ],
    capturedTricks: const [1, 0],
    capturedPileOwners: const [0, 1],
    firstCapturedTrick: CapturedTrick(pileId: 0, winner: 0, cards: firstTrick),
    lastCapturedPile: 0,
    teamWeisScores: const [20, 0],
    teamWeisBreakdown: [
      [weis],
      const [],
    ],
    teamStoeckPoints: const [0, 20],
    stoeckPlayer: 0,
    stoeckAnnounced: false,
    weisState: WeisState(
      order: const [0, 1, 2, 3],
      currentIndex: 4,
      possibleByPlayer: {
        0: [weis],
        1: const [],
        2: const [],
        3: const [],
      },
      highestByPlayer: {0: weis, 1: null, 2: null, 3: null},
      declaredByPlayer: {0: weis, 1: null, 2: null, 3: null},
      declaredEntries: [
        WeisDeclaration(playerIndex: 0, weis: weis, orderIndex: 0),
        const WeisDeclaration(playerIndex: 1, weis: null, orderIndex: 1),
      ],
      winningDeclaration: WeisDeclaration(playerIndex: 0, weis: weis, orderIndex: 0),
      awardedTeamId: 0,
    ),
    roundSummary: bieterSummary,
    roundHistory: const [
      RoundHistoryEntry(
        roundNumber: 1,
        dealer: 2,
        totals: {0: 280, 1: 114},
        summary: schieberSummary,
      ),
      RoundHistoryEntry(
        roundNumber: 2,
        dealer: 0,
        totals: {0: 135, 1: -270, 2: 135},
        summary: bieterSummary,
      ),
    ],
  );
}

String encode(GameState state) => jsonEncode(state.toJson());

void main() {
  test('Ein Spielstand uebersteht JSON verlustfrei', () {
    final original = encode(richState());
    final restored = GameState.fromJson(jsonDecode(original) as Map<String, Object?>);

    expect(encode(restored), original);
    expect(restored.weisState!.declaredByPlayer.containsKey(1), isTrue);
    expect(restored.weisState!.declaredByPlayer[1], isNull);
    expect(restored.roundSummary, isA<BieterRoundSummary>());
    expect(restored.roundHistory.first.summary, isA<SchieberRoundSummary>());
  });

  test('Ein fremdes Speicherformat wird abgelehnt', () {
    final json = richState().toJson()..['schemaVersion'] = GameState.schemaVersion + 1;
    expect(() => GameState.fromJson(json), throwsFormatException);
  });

  test('copyWith unterscheidet zwischen weglassen und auf null setzen', () {
    final state = richState();

    expect(state.copyWith().roundMode, RoundMode.slalom);
    expect(state.copyWith(roundMode: null).roundMode, isNull);
    expect(state.copyWith(weisState: null).weisState, isNull);
    expect(state.copyWith(firstCapturedTrick: null).firstCapturedTrick, isNull);
    expect(state.copyWith(lastCapturedPile: null).lastCapturedPile, isNull);
    expect(state.copyWith(roundSummary: null).roundSummary, isNull);
    expect(state.players[3].copyWith(bid: null).bid, isNull);
    expect(state.players[3].copyWith().bid, 0);
  });

  test('Abgeleitete Werte folgen Spielart und Zaehlweise', () {
    final state = richState();

    expect(state.trickMode, RoundMode.uneUfe, reason: 'Slalom, zweiter Stich');
    expect(state.roundMultiplier, 3);
    expect(state.allowedRoundModes, RoundMode.values);
    expect(state.isInteractive, isTrue);
  });

  test('Das Bachmann-Regelwerk entspricht der Web-App', () {
    const rules = RuleSet.bachmann;

    expect(rules.lastTrickBonus, 5);
    expect(rules.matchBonus, 100);
    expect(rules.stoeckPoints, 20);
    expect(rules.fourSixesCount, isFalse);
    expect(rules.fourOfAKindBeatsSequence, isTrue);
    expect(
      {for (final mode in RoundMode.baseModes) mode.name: rules.multiplierFor(mode)},
      {
        'eicheln': 1,
        'rosen': 1,
        'schellen': 2,
        'schilten': 2,
        'obeAbe': 3,
        'uneUfe': 3,
        'slalom': 3,
      },
    );
    expect(RuleSet.fromJson(rules.toJson()).toJson(), rules.toJson());
  });
}
