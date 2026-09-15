import 'package:bachmann_jass/app/router.dart';
import 'package:bachmann_jass/features/table/panels/bid_panel.dart';
import 'package:bachmann_jass/features/table/panels/mode_panel.dart';
import 'package:bachmann_jass/features/table/panels/round_end_panel.dart';
import 'package:bachmann_jass/features/table/panels/weis_panel.dart';
import 'package:bachmann_jass/features/table/widgets/hand_view.dart';
import 'package:bachmann_jass/game/game_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

import '../support/test_app.dart';

/// Bildschirmgroessen inklusive Kopfzeile.
const Map<String, Size> screens = {
  'iPhone SE': Size(320, 568),
  'Handy hoch': Size(390, 844),
  'Handy quer': Size(844, 390),
  'Tablet hoch': Size(768, 1024),
  'Tablet quer': Size(1024, 768),
  'Desktop': Size(1440, 780),
};

Future<ProviderContainer> openTable(
  WidgetTester tester, {
  required GameVariant variant,
  int seed = 7,
  BieterScoring scoring = BieterScoring.einfach,
}) async {
  final container = await pumpApp(tester);
  container
      .read(gameControllerProvider.notifier)
      .startNewGame(
        variant: variant,
        matchConfig: MatchConfig(targetScore: variant.defaultTargetScore, bieterScoring: scoring),
        playerName: 'Du',
        seed: seed,
      );
  container.read(routerProvider).go(Routes.table);
  await tester.pumpAndSettle();
  return container;
}

/// Laesst die Computer ziehen, bis der Mensch dran ist oder die Runde endet.
Future<void> settleUntilHuman(WidgetTester tester, ProviderContainer container) async {
  for (var guard = 0; guard < 200; guard += 1) {
    final session = container.read(gameControllerProvider)!;
    if (session.humanTurn || !session.waiting) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final MapEntry(key: name, value: size) in screens.entries) {
    for (final variant in GameVariant.values) {
      testWidgets('$name, ${variant.name}: der Tisch rendert ohne Ueberlauf', (tester) async {
        setScreenSize(tester, size);
        final container = await openTable(tester, variant: variant);
        await settleUntilHuman(tester, container);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HumanHandView), findsOneWidget);
        final hand = container.read(gameControllerProvider)!.state.players[0].hand;
        expect(find.bySemanticsLabel(RegExp('.*')), findsWidgets);
        expect(hand, hasLength(variant.handSize));
      });
    }
  }

  testWidgets('Bieterjass: bieten, Spielart waehlen, Karte spielen', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final container = await openTable(tester, variant: GameVariant.bieter, seed: 12);
    await settleUntilHuman(tester, container);
    await tester.pumpAndSettle();

    var session = container.read(gameControllerProvider)!;
    expect(session.state.phase, GamePhase.bidding);
    expect(find.byType(BidPanel), findsOneWidget);

    // Der Mensch bietet 157, die Computer passen darauf.
    await tester.tap(find.widgetWithText(FilledButton, '157'));
    await tester.pumpAndSettle();
    await settleUntilHuman(tester, container);
    await tester.pumpAndSettle();

    session = container.read(gameControllerProvider)!;
    expect(session.state.phase, GamePhase.chooseTrump);
    expect(session.state.soloPlayer, 0);
    expect(find.byType(ModePanel), findsOneWidget);
    expect(find.text('Obe-Abe'), findsNothing, reason: 'Einfache Zaehlweise: nur Farben');

    await tester.tap(find.text('Rosen'));
    await tester.pumpAndSettle();
    session = container.read(gameControllerProvider)!;
    expect(session.state.phase, GamePhase.playing);
    expect(session.humanTurn, isTrue, reason: 'Der Bieter spielt aus');

    // Die letzte Karte liegt im Faecher zuoberst und ist darum sicher zu treffen.
    final card = session.state.players[0].hand.last;
    await tester.tap(find.bySemanticsLabel(RegExp('.* spielen')).last);
    await tester.pumpAndSettle();
    session = container.read(gameControllerProvider)!;
    expect(session.state.players[0].hand, isNot(contains(card)));
    expect(session.state.players[0].hand, hasLength(11));
  });

  testWidgets('Schieber: gesperrte Karten erklaeren sich, Weis und Rundenende erscheinen', (
    tester,
  ) async {
    setScreenSize(tester, const Size(1024, 768));
    final container = await openTable(tester, variant: GameVariant.schieber, seed: 5);
    final controller = container.read(gameControllerProvider.notifier);
    await settleUntilHuman(tester, container);
    await tester.pumpAndSettle();

    var session = container.read(gameControllerProvider)!;
    if (session.state.phase == GamePhase.chooseTrump) {
      expect(find.byType(ModePanel), findsOneWidget);
      await tester.tap(find.text('Rosen'));
      await tester.pumpAndSettle();
      await settleUntilHuman(tester, container);
      await tester.pumpAndSettle();
      session = container.read(gameControllerProvider)!;
    }
    expect(session.state.phase, GamePhase.announceWeis);
    expect(find.byType(WeisPanel), findsOneWidget);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    // Runde per Controller zu Ende spielen, dabei einmal eine gesperrte Karte antippen.
    var explained = false;
    for (var guard = 0; guard < 400; guard += 1) {
      session = container.read(gameControllerProvider)!;
      final game = session.state;
      if (game.phase == GamePhase.roundEnd || game.phase == GamePhase.gameOver) {
        break;
      }
      if (!session.humanTurn) {
        await tester.pump(const Duration(milliseconds: 50));
        continue;
      }
      if (game.phase == GamePhase.playing) {
        final legal = playableCards(game, 0);
        final blocked = game.players[0].hand.where((card) => !legal.contains(card)).firstOrNull;
        if (blocked != null && !explained) {
          // Im Faecher ist nur der linke Streifen einer Karte frei sichtbar.
          final finder = find.bySemanticsLabel(RegExp('.*nicht spielbar')).first;
          final box = tester.getRect(finder);
          await tester.tapAt(Offset(box.left + 6, box.center.dy));
          await tester.pump();
          expect(find.byType(SnackBar), findsOneWidget);
          explained = true;
          await tester.pumpAndSettle();
        }
        expect(controller.act(PlayCard(0, legal.first)), isNull);
      } else {
        expect(controller.act(const DeclareWeis(0)), isNull);
      }
      await tester.pump();
    }
    await tester.pumpAndSettle();

    session = container.read(gameControllerProvider)!;
    expect(session.state.phase, GamePhase.roundEnd);
    expect(find.byType(RoundEndPanel), findsOneWidget);
    // Die Abrechnung kann laenger sein als der Panelbereich und scrollt dann.
    await tester.ensureVisible(find.text('Nächste Runde'));
    await tester.tap(find.text('Nächste Runde'));
    await tester.pumpAndSettle();
    expect(container.read(gameControllerProvider)!.state.roundNumber, 2);
    expect(tester.takeException(), isNull);
  });
}
