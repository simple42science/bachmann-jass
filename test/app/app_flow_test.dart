import 'package:bachmann_jass/app/settings.dart';
import 'package:bachmann_jass/features/table/widgets/hand_view.dart';
import 'package:bachmann_jass/features/table/widgets/playing_card_view.dart';
import 'package:bachmann_jass/game/game_controller.dart';
import 'package:bachmann_jass/game/key_value_store.dart';
import 'package:bachmann_jass/game/saved_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('Home -> Neue Partie -> Spiel starten fuehrt an den Tisch', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final container = await pumpApp(tester);

    expect(find.text('Jass'), findsOneWidget);
    await tester.tap(find.text('Neue Partie'));
    await tester.pumpAndSettle();

    expect(find.text('Neue Partie'), findsOneWidget);
    await tester.tap(find.text('Schieber Jass'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yannick');
    await tester.ensureVisible(find.text('Spiel starten'));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();

    final session = container.read(gameControllerProvider);
    expect(session, isNotNull);
    expect(session!.state.variant, GameVariant.schieber);
    expect(session.state.players[0].name, 'Yannick');
    expect(find.byType(HumanHandView), findsOneWidget);
    expect(find.byType(PlayingCardView), findsAtLeast(9));
    expect(container.read(settingsProvider).variant, GameVariant.schieber);
  });

  testWidgets('Eine gespeicherte Partie laesst sich vom Homescreen fortsetzen', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final store = MemoryKeyValueStore();
    var state = createGame(variant: GameVariant.bieter, seed: 21);
    state = applyAction(state, const StartRound()).state;
    final saved = SavedGame(savedAt: DateTime(2026, 9, 15, 18, 30), state: state);
    await SavedGameStore(store).save(saved);

    final container = await pumpApp(
      tester,
      overrides: testOverrides(store: store, saved: saved),
    );
    expect(find.text('Partie fortsetzen'), findsOneWidget);
    expect(find.textContaining('Bieterjass, Runde 1'), findsOneWidget);

    await tester.tap(find.text('Partie fortsetzen'));
    await tester.pumpAndSettle();
    expect(container.read(gameControllerProvider)!.state.seed, 21);
    expect(find.byType(HumanHandView), findsOneWidget);
  });

  testWidgets('Die Kopfzeile fuehrt zurueck zum Homescreen und behaelt die Partie', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final container = await pumpApp(tester);
    await tester.tap(find.text('Neue Partie'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Spiel starten'));
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Partie fortsetzen'), findsOneWidget);
    expect(container.read(gameControllerProvider), isNull);
  });
}
