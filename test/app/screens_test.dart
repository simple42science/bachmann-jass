import 'package:bachmann_jass/app/router.dart';
import 'package:bachmann_jass/features/scoreboard/ztafel_painter.dart';
import 'package:bachmann_jass/game/game_controller.dart';
import 'package:bachmann_jass/game/game_texts.dart';
import 'package:bachmann_jass/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

import '../support/test_app.dart';

/// Spielt per Controller bis zum Rundenende (der Mensch waehlt immer die erste Option).
Future<void> playRound(WidgetTester tester, ProviderContainer container) async {
  final controller = container.read(gameControllerProvider.notifier);
  for (var guard = 0; guard < 400; guard += 1) {
    final session = container.read(gameControllerProvider)!;
    final game = session.state;
    if (game.phase == GamePhase.roundEnd || game.phase == GamePhase.gameOver) {
      return;
    }
    if (!session.humanTurn) {
      await tester.pump(const Duration(milliseconds: 50));
      continue;
    }
    final action = switch (game.phase) {
      GamePhase.bidding => PassBid(0),
      GamePhase.chooseTrump => const ChooseMode(0, RoundMode.rosen),
      GamePhase.announceWeis => const DeclareWeis(0),
      _ => PlayCard(0, playableCards(game, 0).first),
    };
    expect(controller.act(action), isNull);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Die Jasstafel zeigt Runden, Striche und den Verlauf', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final container = await pumpApp(tester);
    container
        .read(gameControllerProvider.notifier)
        .startNewGame(
          variant: GameVariant.schieber,
          matchConfig: const MatchConfig(targetScore: 1000),
          playerName: 'Du',
          seed: 5,
        );
    container.read(routerProvider).go(Routes.table);
    await tester.pumpAndSettle();
    await playRound(tester, container);
    await tester.pumpAndSettle();

    container.read(routerProvider).go(Routes.scoreboard);
    await tester.pumpAndSettle();

    expect(find.text('Jasstafel'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    final texts = AppLocalizations.of(tester.element(find.text('Jasstafel')));
    final played = container.read(gameControllerProvider)!.state.roundHistory.single.summary;
    expect(
      find.text(texts.mode(played.roundMode)),
      findsWidgets,
      reason: 'eine abgeschlossene Runde',
    );
    expect(find.textContaining('Runde abgerechnet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(container.read(gameControllerProvider), isNotNull);
  });

  testWidgets('Der Regel-Screen kommt aus dem Regelwerk', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final container = await pumpApp(tester);
    await tester.tap(find.text('Regeln'));
    await tester.pumpAndSettle();

    expect(find.text('Regeln und Punkte'), findsOneWidget);
    expect(find.textContaining('${RuleSet.bachmann.stoeckPoints} Punkte'), findsWidgets);
    expect(find.text('×3'), findsWidgets, reason: 'Multiplikator-Tabelle');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Neue Partie'), findsOneWidget);
    expect(container.read(gameControllerProvider), isNull);
  });

  test('Die Z-Tafel zerlegt Punkte in Hunderter, Fuenfziger, Zwanziger und Rest', () {
    expect(zTafelStrokes(0), (hundreds: 0, fifty: 0, twenties: 0, ones: 0));
    expect(zTafelStrokes(157), (hundreds: 1, fifty: 1, twenties: 0, ones: 7));
    expect(zTafelStrokes(676), (hundreds: 6, fifty: 1, twenties: 1, ones: 6));
    expect(zTafelStrokes(99), (hundreds: 0, fifty: 1, twenties: 2, ones: 9));
    expect(zTafelStrokes(-30), (hundreds: 0, fifty: 0, twenties: 0, ones: 0));
  });

  testWidgets('Jedes Ereignis wird zu einem Satz im Verlauf', (tester) async {
    late AppLocalizations texts;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            texts = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    var state = createGame(variant: GameVariant.schieber, seed: 3);
    final seen = <Type>{};
    for (var guard = 0; guard < 400 && state.phase != GamePhase.gameOver; guard += 1) {
      final action = switch (state.phase) {
        GamePhase.setup || GamePhase.roundEnd => const StartRound(),
        GamePhase.trickEnd => const NextTrick(),
        _ => aiDecide(state)!,
      };
      final result = applyAction(state, action);
      for (final event in result.events) {
        seen.add(event.runtimeType);
        final line = texts.logLine(result.state, event);
        expect(line == null || line.isNotEmpty, isTrue, reason: '$event');
        if (event is! NextTrickStarted) {
          expect(line, isNotNull, reason: '$event braucht eine Zeile');
        }
      }
      state = result.state;
      if (state.roundNumber > 2 && state.phase == GamePhase.roundEnd) {
        break;
      }
    }
    expect(seen, containsAll([RoundStarted, ModeChosen, CardPlayed, TrickWon, RoundScored]));
  });
}
