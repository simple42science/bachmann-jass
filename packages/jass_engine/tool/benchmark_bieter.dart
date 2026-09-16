/// Misst im Bieterjass, ob eine KI-Anpassung (AiTuning) staerker spielt als
/// die KI der Web-App.
///
/// Pro Verteilung spielt die angepasste KI dreimal, einmal auf jedem Sitz,
/// gegen zwei Gegner mit dem Verhalten der Web-App. Ohne Vorteil laege ihre
/// Siegquote bei 33 Prozent.
///
/// Usage: dart run tool/benchmark_bieter.dart [einfach|schieber] [verteilungen]
library;

import 'package:jass_engine/jass_engine.dart';

typedef _Variant = ({AiTuning tuning, Difficulty level});

const Map<String, _Variant> _variants = {
  'Web-App (Kontrolle)': (tuning: AiTuning.webApp, level: Difficulty.normal),
  'App: einfach': (tuning: AiTuning.standard, level: Difficulty.einfach),
  'App: normal': (tuning: AiTuning.standard, level: Difficulty.normal),
  'App: schwer': (tuning: AiTuning.standard, level: Difficulty.schwer),
};

void main(List<String> args) {
  final scoring = BieterScoring.values.byName(args.elementAtOrNull(0) ?? 'schieber');
  final deals = int.parse(args.elementAtOrNull(1) ?? '200');
  print('Bieterjass, Zaehlweise ${scoring.name}, $deals Verteilungen x 3 Sitze');

  for (final MapEntry(key: label, value: variant) in _variants.entries) {
    var games = 0;
    var wins = 0;
    var lead = 0.0;
    var bids = 0;
    var bidsMade = 0;

    for (var seed = 1; seed <= deals; seed += 1) {
      for (var seat = 0; seat < 3; seat += 1) {
        final result = _play(seed, scoring, variant, seat);
        games += 1;
        if (result.winner == seat) {
          wins += 1;
        }
        final others = result.scores.fold(0, (sum, score) => sum + score) - result.scores[seat];
        lead += result.scores[seat] - others / 2;
        bids += result.bids;
        bidsMade += result.bidsMade;
      }
    }

    print(
      '  ${label.padRight(28)} Siegquote ${(wins / games * 100).toStringAsFixed(1)}%'
      ' | Vorsprung ${(lead / games).toStringAsFixed(0).padLeft(4)} Punkte'
      ' | Gebote erfuellt ${(bidsMade / bids * 100).toStringAsFixed(0)}% von $bids',
    );
  }
}

({int winner, List<int> scores, int bids, int bidsMade}) _play(
  int seed,
  BieterScoring scoring,
  _Variant variant,
  int tunedSeat,
) {
  var state = createGame(
    variant: GameVariant.bieter,
    matchConfig: MatchConfig(targetScore: 1500, bieterScoring: scoring),
    seed: seed,
    seats: [for (var seat = 0; seat < 3; seat += 1) SeatSetup(name: 'Sitz $seat', isHuman: false)],
  );

  var bids = 0;
  var bidsMade = 0;
  for (var rounds = 0; state.phase != GamePhase.gameOver && rounds < 80; rounds += 1) {
    state = applyAction(state, const StartRound()).state;
    while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
      final tuned = state.currentPlayer == tunedSeat;
      final action = tuned
          ? aiDecide(state, tuning: variant.tuning, difficulty: variant.level)
          : aiDecide(state, tuning: AiTuning.webApp);
      state = applyAction(state, action ?? const NextTrick()).state;
    }
    final summary = state.roundSummary! as BieterRoundSummary;
    if (summary.soloPlayer == tunedSeat) {
      bids += 1;
      if (summary.succeeded) {
        bidsMade += 1;
      }
    }
  }

  final scores = [for (final player in state.players) player.totalScore];
  var winner = 0;
  for (var seat = 1; seat < scores.length; seat += 1) {
    if (scores[seat] > scores[winner]) {
      winner = seat;
    }
  }
  return (winner: winner, scores: scores, bids: bids, bidsMade: bidsMade);
}
