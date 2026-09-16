import 'dart:convert';
import 'dart:io';

import 'package:jass_engine/jass_engine.dart';
import 'package:test/test.dart';

/// Liest die Fixtures aus tool/export_parity_fixtures.mjs und spielt sie mit
/// der Dart-Engine nach.

const _deckChars = '0123456789abcdefghijklmnopqrstuvwxyz';

JassCard cardFromChar(String char) => JassCard.deck[_deckChars.indexOf(char)];

String cardChar(JassCard card) => _deckChars[card.deckIndex];

GameAction decodeAction(String code) {
  final seat = code.length > 1 ? int.tryParse(code[1]) : null;
  return switch (code[0]) {
    's' => const StartRound(),
    'n' => const NextTrick(),
    'b' => PlaceBid(seat!, int.parse(code.substring(3))),
    'x' => PassBid(seat!),
    'u' => PushTrump(seat!),
    'm' => ChooseMode(seat!, RoundMode.values.byName(code.substring(3))),
    'w' => DeclareWeis(seat!),
    'c' => PlayCard(seat!, cardFromChar(code[2])),
    _ => throw FormatException('Unbekannter Aktionscode: $code'),
  };
}

String encodeAction(GameAction action) => switch (action) {
  StartRound() => 's',
  NextTrick() => 'n',
  PlaceBid(:final playerIndex, :final value) => 'b$playerIndex:$value',
  PassBid(:final playerIndex) => 'x$playerIndex',
  PushTrump(:final playerIndex) => 'u$playerIndex',
  ChooseMode(:final playerIndex, :final mode) => 'm$playerIndex:${mode.name}',
  DeclareWeis(:final playerIndex, weisId: null) => 'w$playerIndex',
  DeclareWeis(:final playerIndex, :final weisId) => 'w$playerIndex:$weisId',
  DeclineWeis(:final playerIndex) => 'd$playerIndex',
  PlayCard(:final playerIndex, :final card) => 'c$playerIndex${cardChar(card)}',
};

final class FixtureRound {
  FixtureRound(Map<String, Object?> json)
    : hands = [for (final hand in json['hands']! as List<Object?>) hand! as String],
      actions = (json['actions']! as String).split(' '),
      end = json['end']! as Map<String, Object?>;

  final List<String> hands;
  final List<String> actions;
  final Map<String, Object?> end;
}

final class FixtureGame {
  FixtureGame(Map<String, Object?> json)
    : seed = json['seed']! as int,
      finished = json['finished']! as bool,
      rounds = [
        for (final round in json['rounds']! as List<Object?>)
          FixtureRound(round! as Map<String, Object?>),
      ];

  final int seed;
  final bool finished;
  final List<FixtureRound> rounds;
}

final class ParityFixture {
  ParityFixture._(this.name, Map<String, Object?> json)
    : variant = GameVariant.values.byName(json['variant']! as String),
      matchConfig = MatchConfig(
        targetScore: (json['matchConfig']! as Map<String, Object?>)['targetScore']! as int,
        difficulty: Difficulty.values.byName(
          (json['matchConfig']! as Map<String, Object?>)['difficulty']! as String,
        ),
        bieterScoring: BieterScoring.values.byName(
          (json['matchConfig']! as Map<String, Object?>)['scoring']! as String,
        ),
      ),
      scripted = {for (final entry in json['scripted']! as List<Object?>) entry! as String},
      games = [
        for (final game in json['games']! as List<Object?>)
          FixtureGame(game! as Map<String, Object?>),
      ];

  static List<ParityFixture> loadAll() {
    final files =
        Directory(
            'test/fixtures/parity',
          ).listSync().whereType<File>().where((file) => file.path.endsWith('.json')).toList()
          ..sort((first, second) => first.path.compareTo(second.path));
    return [
      for (final file in files)
        ParityFixture._(
          file.uri.pathSegments.last.replaceAll('.json', ''),
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
        ),
    ];
  }

  final String name;
  final GameVariant variant;
  final MatchConfig matchConfig;

  /// Entscheidungsarten, die im Export vorgegeben statt von der KI getroffen wurden.
  final Set<String> scripted;
  final List<FixtureGame> games;
}

List<Object?> _summaryOf(RoundSummary summary) => switch (summary) {
  // Der Bieterjass folgt seit dem 16.09.2026 den Familienregeln und nicht
  // mehr der Web-App; Fixtures gibt es nur noch fuer den Schieber.
  BieterRoundSummary() => ['bieter', summary.soloPlayer, summary.bid, summary.soloPoints],
  SchieberRoundSummary() => [
    'schieber',
    [
      for (final r in summary.results)
        [
          r.teamId,
          r.trickPoints,
          r.weisPoints,
          r.stoeckPoints,
          r.matchPoints,
          r.basePoints,
          r.roundPoints,
          r.tricksWon,
        ],
    ],
    summary.roundWinnerTeamId,
    summary.trumpChooser,
    summary.pushed,
    summary.roundMode.name,
    summary.multiplier,
    summary.targetScore,
    summary.weisWinnerTeamId,
    summary.highestWeis?.id,
    summary.stoeckPlayer,
    summary.matchTeamId,
  ],
};

/// Gleiche Struktur wie `snapshot()` im Exporter.
Map<String, Object?> snapshotOf(GameState state) {
  final first = state.firstCapturedTrick;
  return {
    'phase': state.phase.name,
    'round': state.roundNumber,
    'dealer': state.dealer,
    'forehand': state.forehandPlayer,
    'mode': state.roundMode?.name,
    'chooser': state.chooserPlayer,
    'pushed': state.trumpWasPushed,
    'bid': [state.highestBid, state.highestBidder, state.soloPlayer],
    'players': [
      for (final player in state.players)
        [player.bid, player.tricksWon, player.pointsWon, player.totalScore],
    ],
    'teams': [for (final team in state.teams) team.totalScore],
    'piles': [
      state.capturedTricks[0],
      state.capturedTricks[1],
      state.capturedPileOwners[0],
      state.capturedPileOwners[1],
      state.lastCapturedPile,
    ],
    'firstTrick': first == null
        ? null
        : [
            first.pileId,
            first.winner,
            first.cards.map((entry) => '${entry.playerIndex}${cardChar(entry.card)}').join(),
          ],
    'weis': [
      state.teamWeisScores[0],
      state.teamWeisScores[1],
      state.teamWeisBreakdown[0].map((weis) => weis.id).join('|'),
      state.teamWeisBreakdown[1].map((weis) => weis.id).join('|'),
      state.weisState?.winningDeclaration?.playerIndex,
    ],
    'stoeck': [
      state.teamStoeckPoints[0],
      state.teamStoeckPoints[1],
      state.stoeckPlayer,
      state.stoeckAnnounced,
    ],
    'summary': _summaryOf(state.roundSummary!),
    'totals': state.roundHistory.last.totals.values.toList(),
  };
}

/// Wird vor jeder aufgezeichneten Aktion mit dem Zustand davor aufgerufen.
typedef BeforeAction = void Function(GameState state, String code, String where);

/// Spielt eine aufgezeichnete Partie nach und vergleicht jede Runde mit der Web-App.
///
/// Nach jeder Runde wird der Zustand ueber JSON gesichert und geladen, damit
/// auch der Speicherstand ueber ganze Partien geprueft ist.
GameState replayGame(ParityFixture fixture, FixtureGame game, {BeforeAction? beforeAction}) {
  var state = createGame(
    variant: fixture.variant,
    matchConfig: fixture.matchConfig,
    seed: game.seed,
  );

  for (var roundIndex = 0; roundIndex < game.rounds.length; roundIndex += 1) {
    final round = game.rounds[roundIndex];
    for (var actionIndex = 0; actionIndex < round.actions.length; actionIndex += 1) {
      final code = round.actions[actionIndex];
      final where =
          '${fixture.name}, Seed ${game.seed}, Runde ${roundIndex + 1}, Aktion $actionIndex ($code)';
      beforeAction?.call(state, code, where);
      try {
        state = applyAction(state, decodeAction(code)).state;
      } on GameRuleException catch (error) {
        fail('$where wurde abgelehnt: $error');
      }
      if (code == 's') {
        expect(
          [for (final player in state.players) player.hand.map(cardChar).join()],
          round.hands,
          reason: '$where: Kartenverteilung',
        );
      }
    }
    expect(
      snapshotOf(state),
      round.end,
      reason: '${fixture.name}, Seed ${game.seed}, Runde ${roundIndex + 1}',
    );
    state = GameState.fromJson(jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>);
  }

  expect(
    state.phase == GamePhase.gameOver,
    game.finished,
    reason: '${fixture.name}, Seed ${game.seed}: Spielende',
  );
  return state;
}
