/// Misst im Bieterjass (Familienregeln: Steigern fuer die ganze Partie, der
/// Bieter gegen die beiden anderen), wie stark eine KI-Stufe spielt.
///
/// Pro Verteilung spielt die gemessene Stufe dreimal, einmal auf jedem Sitz,
/// gegen zwei Gegner der Stufe einfach. Ohne Vorteil laege ihre Siegquote bei
/// 33 Prozent. Dazu: wie oft sie Bieter wurde und wie oft sie das Gebot dann
/// erreicht hat, und wo das Steigern endete.
///
/// Usage: dart run tool/benchmark_bieter.dart [einfach|schieber] [verteilungen]
library;

import 'package:jass_engine/jass_engine.dart';

const List<Difficulty> _levels = Difficulty.values;

void main(List<String> args) {
  final scoring = BieterScoring.values.byName(args.elementAtOrNull(0) ?? 'schieber');
  final deals = int.parse(args.elementAtOrNull(1) ?? '100');
  print('Bieterjass, Zaehlweise ${scoring.name}, $deals Verteilungen x 3 Sitze');

  for (final level in _levels) {
    var games = 0;
    var wins = 0;
    var solo = 0;
    var soloWins = 0;
    var bidSum = 0;
    var bidMin = 1 << 30;
    var bidMax = 0;

    for (var seed = 1; seed <= deals; seed += 1) {
      for (var seat = 0; seat < 3; seat += 1) {
        final result = _play(seed, scoring, level, seat);
        games += 1;
        if (result.winners.contains(seat)) {
          wins += 1;
        }
        if (result.solo == seat) {
          solo += 1;
          if (result.winners.contains(seat)) {
            soloWins += 1;
          }
        }
        if (seat == 0) {
          bidSum += result.bid;
          bidMin = result.bid < bidMin ? result.bid : bidMin;
          bidMax = result.bid > bidMax ? result.bid : bidMax;
        }
      }
    }

    print(
      '  ${level.name.padRight(8)} Siegquote ${(wins / games * 100).toStringAsFixed(1)}%'
      ' | Bieter in $solo Partien, davon $soloWins gewonnen'
      ' | Gebote ${(bidSum / deals).toStringAsFixed(0)} im Schnitt ($bidMin bis $bidMax)',
    );
  }
}

({List<int> winners, int solo, int bid}) _play(
  int seed,
  BieterScoring scoring,
  Difficulty level,
  int measuredSeat,
) {
  var state = createGame(
    variant: GameVariant.bieter,
    matchConfig: MatchConfig(targetScore: 1000, bieterScoring: scoring),
    seed: seed,
    seats: [
      for (var seat = 0; seat < 3; seat += 1)
        SeatSetup(
          name: 'Sitz $seat',
          isHuman: false,
          difficulty: seat == measuredSeat ? level : Difficulty.einfach,
        ),
    ],
  );

  GameOver? over;
  for (var rounds = 0; state.phase != GamePhase.gameOver && rounds < 80; rounds += 1) {
    var result = applyAction(state, const StartRound());
    state = result.state;
    while (state.phase != GamePhase.roundEnd && state.phase != GamePhase.gameOver) {
      result = applyAction(state, aiDecide(state) ?? const NextTrick());
      state = result.state;
    }
    over = result.events.whereType<GameOver>().firstOrNull ?? over;
  }

  final winnerTeam = over?.winnerTeam ?? -1;
  return (
    winners: [
      for (final player in state.players)
        if (player.teamId == winnerTeam) player.id,
    ],
    solo: state.soloPlayer,
    bid: state.highestBid,
  );
}
