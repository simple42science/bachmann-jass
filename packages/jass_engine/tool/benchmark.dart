/// Misst zwei KI-Stufen gegeneinander (Port von scripts/benchmark-ai.mjs).
///
/// Beide Teams spielen dieselben Kartenverteilungen, jede zweimal mit
/// getauschten Sitzplaetzen. Weil Engine und KI der Web-App entsprechen,
/// ergeben sich fuer dieselben Seeds dieselben Resultate wie dort.
///
/// Usage: dart run tool/benchmark.dart [stufeA] [stufeB] [verteilungen]
///   dart run tool/benchmark.dart normal einfach 300
library;

import 'package:jass_engine/jass_engine.dart';

void main(List<String> args) {
  final levelA = Difficulty.values.byName(args.elementAtOrNull(0) ?? 'normal');
  final levelB = Difficulty.values.byName(args.elementAtOrNull(1) ?? 'einfach');
  final deals = int.parse(args.elementAtOrNull(2) ?? '400');

  var winsA = 0;
  var winsB = 0;
  var draws = 0;
  var pointsA = 0;
  var pointsB = 0;
  var rounds = 0;

  for (var seed = 1; seed <= deals; seed += 1) {
    final first = _runMatch(seed, levelA, levelB);
    final second = _runMatch(seed, levelB, levelA);

    for (final (a, b, played) in [
      (first.scores[0], first.scores[1], first.rounds),
      (second.scores[1], second.scores[0], second.rounds),
    ]) {
      pointsA += a;
      pointsB += b;
      rounds += played;
      if (a > b) {
        winsA += 1;
      } else if (b > a) {
        winsB += 1;
      } else {
        draws += 1;
      }
    }
  }

  final played = winsA + winsB + draws;
  print('$played Partien ($deals Verteilungen, Sitzplaetze getauscht)');
  print('  ${levelA.name}: $winsA Siege | Schnitt ${(pointsA / played).toStringAsFixed(0)} Punkte');
  print('  ${levelB.name}: $winsB Siege | Schnitt ${(pointsB / played).toStringAsFixed(0)} Punkte');
  if (draws > 0) {
    print('  Unentschieden: $draws');
  }
  print('  Siegquote ${levelA.name}: ${(winsA / played * 100).toStringAsFixed(1)}%');
  print('  Runden pro Partie: ${(rounds / played).toStringAsFixed(1)}');
}

({List<int> scores, int rounds}) _runMatch(int seed, Difficulty teamZero, Difficulty teamOne) {
  var state = createGame(
    variant: GameVariant.schieber,
    matchConfig: const MatchConfig(targetScore: 1000),
    seed: seed,
    seats: [
      for (var seat = 0; seat < 4; seat += 1)
        SeatSetup(name: 'Sitz $seat', isHuman: false, difficulty: seat.isEven ? teamZero : teamOne),
    ],
  );

  var rounds = 0;
  while (state.phase != GamePhase.gameOver && rounds < 60) {
    state = applyAction(state, const StartRound()).state;
    while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
      state = applyAction(state, aiDecide(state) ?? const NextTrick()).state;
    }
    rounds += 1;
  }

  return (scores: [state.teams[0].totalScore, state.teams[1].totalScore], rounds: rounds);
}
