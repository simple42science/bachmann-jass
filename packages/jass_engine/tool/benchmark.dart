/// Misst zwei KI-Stufen gegeneinander (Port von scripts/benchmark-ai.mjs).
///
/// Beide Teams spielen dieselben Kartenverteilungen, jede zweimal mit
/// getauschten Sitzplaetzen. Weil Engine und KI der Web-App entsprechen,
/// ergeben sich fuer dieselben Seeds dieselben Resultate wie dort.
///
/// Usage: dart run tool/benchmark.dart [stufeA] [stufeB] [verteilungen]
///   dart run tool/benchmark.dart normal einfach 300
///   dart run tool/benchmark.dart schwer schwer@web 300   (@web: KI der Web-App)
///   dart run tool/benchmark.dart schwer@48 schwer 200     (@Zahl: Stichproben des Experten)
library;

import 'package:jass_engine/jass_engine.dart';

/// Stufe plus KI-Variante, zum Beispiel `schwer` oder `schwer@web`.
typedef Side = ({Difficulty level, AiTuning tuning, String name});

Side parseSide(String raw) {
  final parts = raw.split('@');
  final option = parts.length > 1 ? parts[1] : '';
  return (
    level: Difficulty.values.byName(parts[0]),
    tuning: option == 'web'
        ? AiTuning.webApp
        : AiTuning.standard.copyWith(rolloutSamples: int.tryParse(option)),
    name: raw,
  );
}

void main(List<String> args) {
  final levelA = parseSide(args.elementAtOrNull(0) ?? 'normal');
  final levelB = parseSide(args.elementAtOrNull(1) ?? 'einfach');
  final deals = int.parse(args.elementAtOrNull(2) ?? '400');

  var winsA = 0;
  var winsB = 0;
  var draws = 0;
  var pointsA = 0;
  var pointsB = 0;
  var rounds = 0;
  final clock = [Stopwatch(), Stopwatch()];
  final decisions = [0, 0];

  for (var seed = 1; seed <= deals; seed += 1) {
    final first = _runMatch(seed, levelA, levelB, clock, decisions);
    final swapped = [decisions[1], decisions[0]];
    final second = _runMatch(seed, levelB, levelA, [clock[1], clock[0]], swapped);
    decisions[0] = swapped[1];
    decisions[1] = swapped[0];

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
  for (final (index, side) in [levelA, levelB].indexed) {
    final perDecision =
        clock[index].elapsedMicroseconds / (decisions[index] == 0 ? 1 : decisions[index]) / 1000;
    print('  Rechenzeit ${side.name}: ${perDecision.toStringAsFixed(2)} ms je Entscheidung');
  }
}

({List<int> scores, int rounds}) _runMatch(
  int seed,
  Side teamZero,
  Side teamOne,
  List<Stopwatch> clock,
  List<int> decisions,
) {
  var state = createGame(
    variant: GameVariant.schieber,
    matchConfig: const MatchConfig(targetScore: 1000),
    seed: seed,
    seats: [
      for (var seat = 0; seat < 4; seat += 1)
        SeatSetup(
          name: 'Sitz $seat',
          isHuman: false,
          difficulty: seat.isEven ? teamZero.level : teamOne.level,
        ),
    ],
  );

  var rounds = 0;
  while (state.phase != GamePhase.gameOver && rounds < 60) {
    state = applyAction(state, const StartRound()).state;
    while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
      final index = state.currentPlayer.isEven ? 0 : 1;
      final side = index == 0 ? teamZero : teamOne;
      clock[index].start();
      final action = aiDecide(state, tuning: side.tuning);
      clock[index].stop();
      if (action != null) {
        decisions[index] += 1;
      }
      state = applyAction(state, action ?? const NextTrick()).state;
    }
    rounds += 1;
  }

  return (scores: [state.teams[0].totalScore, state.teams[1].totalScore], rounds: rounds);
}
