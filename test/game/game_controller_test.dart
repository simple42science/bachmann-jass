import 'dart:convert';

import 'package:bachmann_jass/app/settings.dart';
import 'package:bachmann_jass/game/game_controller.dart';
import 'package:bachmann_jass/game/key_value_store.dart';
import 'package:bachmann_jass/game/saved_game.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

import '../support/test_app.dart';

void main() {
  ProviderContainer makeContainer({MemoryKeyValueStore? store, SavedGame? saved}) {
    final container = ProviderContainer(
      overrides: testOverrides(store: store, saved: saved, instantAi: false),
    );
    addTearDown(container.dispose);
    return container;
  }

  void startSchieber(ProviderContainer container, {int seed = 5}) {
    container
        .read(gameControllerProvider.notifier)
        .startNewGame(
          variant: GameVariant.schieber,
          matchConfig: const MatchConfig(targetScore: 1000),
          playerName: 'Test',
          seed: seed,
        );
  }

  test('Computer ziehen nach einer Wartezeit, bis der Mensch an der Reihe ist', () {
    fakeAsync((async) {
      final container = makeContainer();
      startSchieber(container);

      final first = container.read(gameControllerProvider)!;
      expect(first.state.phase, GamePhase.chooseTrump);
      expect(first.waiting, !first.humanTurn);

      // Spaetestens nach zwei Minuten ist der Mensch dran oder die Runde vorbei.
      var guard = 0;
      while (!container.read(gameControllerProvider)!.humanTurn && guard < 120) {
        async.elapse(const Duration(seconds: 1));
        guard += 1;
      }
      final session = container.read(gameControllerProvider)!;
      expect(session.humanTurn, isTrue);
      expect(session.waiting, isFalse);
      expect(session.revision, greaterThan(1));
    });
  });

  test('Ein Tipp auf den Tisch ueberspringt die Wartezeit', () {
    fakeAsync((async) {
      final container = makeContainer();
      final controller = container.read(gameControllerProvider.notifier);
      startSchieber(container, seed: 9);

      var session = container.read(gameControllerProvider)!;
      // Seed 9: der Mensch ist nicht als Erster dran (sonst anderen Seed nehmen).
      while (session.humanTurn) {
        startSchieber(container, seed: session.state.seed + 1);
        session = container.read(gameControllerProvider)!;
      }
      final before = session.revision;
      controller.skipDelay();
      expect(container.read(gameControllerProvider)!.revision, before + 1);
    });
  });

  test('Pause haelt die Computer an, Weiter laesst sie ziehen', () {
    fakeAsync((async) {
      final container = makeContainer();
      final controller = container.read(gameControllerProvider.notifier);
      startSchieber(container, seed: 3);
      var session = container.read(gameControllerProvider)!;
      while (session.humanTurn) {
        startSchieber(container, seed: session.state.seed + 1);
        session = container.read(gameControllerProvider)!;
      }

      controller.pause();
      final paused = container.read(gameControllerProvider)!;
      expect(paused.paused, isTrue);
      expect(paused.waiting, isFalse);
      async.elapse(const Duration(seconds: 30));
      expect(container.read(gameControllerProvider)!.revision, paused.revision);

      controller.resumeGame();
      async.elapse(const Duration(seconds: 5));
      expect(container.read(gameControllerProvider)!.revision, greaterThan(paused.revision));
    });
  });

  test('Regelverstoesse werden gemeldet und aendern nichts', () {
    fakeAsync((async) {
      final container = makeContainer();
      final controller = container.read(gameControllerProvider.notifier);
      startSchieber(container, seed: 2);
      final before = container.read(gameControllerProvider)!;
      final json = jsonEncode(before.state.toJson());

      expect(controller.act(const PlaceBid(0, 60)), RuleViolation.wrongVariant);
      expect(controller.act(const NextTrick()), RuleViolation.wrongPhase);
      expect(jsonEncode(container.read(gameControllerProvider)!.state.toJson()), json);
    });
  });

  test('Nach jeder Aktion liegt die Partie im Speicher und laesst sich fortsetzen', () {
    fakeAsync((async) {
      final store = MemoryKeyValueStore();
      final container = makeContainer(store: store);
      startSchieber(container, seed: 11);
      async.elapse(const Duration(seconds: 20));
      async.flushMicrotasks();

      final session = container.read(gameControllerProvider)!;
      expect(store.values, contains(SavedGameStore.key));

      // Neuer Start wie nach einem Neuladen: der Speicherstand wird gelesen.
      SavedGame? loaded;
      SavedGameStore(store).load().then((value) => loaded = value);
      async.flushMicrotasks();
      expect(loaded, isNotNull);
      expect(jsonEncode(loaded!.state.toJson()), jsonEncode(session.state.toJson()));

      final restarted = makeContainer(store: store, saved: loaded);
      expect(restarted.read(gameControllerProvider), isNull);
      expect(restarted.read(gameControllerProvider.notifier).resume(), isTrue);
      expect(
        jsonEncode(restarted.read(gameControllerProvider)!.state.toJson()),
        jsonEncode(session.state.toJson()),
      );
    });
  });

  test('Home behaelt die Partie, Abbrechen loescht sie', () {
    fakeAsync((async) {
      final store = MemoryKeyValueStore();
      final container = makeContainer(store: store);
      final controller = container.read(gameControllerProvider.notifier);
      startSchieber(container);
      async.flushMicrotasks();

      controller.leaveTable();
      expect(container.read(gameControllerProvider), isNull);
      expect(container.read(savedGameProvider), isNotNull);
      expect(controller.resume(), isTrue);

      controller.abandon();
      async.flushMicrotasks();
      expect(container.read(gameControllerProvider), isNull);
      expect(container.read(savedGameProvider), isNull);
      expect(store.values, isNot(contains(SavedGameStore.key)));
    });
  });

  test('Ein Spielende raeumt den Speicherstand weg', () {
    fakeAsync((async) {
      final store = MemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: testOverrides(
          store: store,
          settings: const AppSettings(speed: GameSpeed.schnell),
          instantAi: false,
        ),
      );
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      // Alle Sitze als Computer ist hier nicht vorgesehen; der Mensch spielt
      // stattdessen jeweils die erste erlaubte Karte.
      controller.startNewGame(
        variant: GameVariant.schieber,
        matchConfig: const MatchConfig(targetScore: 300),
        playerName: 'Test',
        seed: 4,
      );

      var guard = 0;
      while (container.read(gameControllerProvider)!.state.phase != GamePhase.gameOver &&
          guard < 5000) {
        final session = container.read(gameControllerProvider)!;
        if (session.humanTurn) {
          final game = session.state;
          final action = switch (game.phase) {
            GamePhase.chooseTrump => const ChooseMode(0, RoundMode.rosen),
            GamePhase.announceWeis => const DeclareWeis(0),
            _ => PlayCard(0, playableCards(game, 0).first),
          };
          expect(controller.act(action), isNull);
        } else if (session.state.phase == GamePhase.roundEnd) {
          expect(controller.act(const StartRound()), isNull);
        } else {
          async.elapse(const Duration(seconds: 1));
        }
        guard += 1;
      }
      async.flushMicrotasks();

      expect(container.read(gameControllerProvider)!.state.phase, GamePhase.gameOver);
      expect(container.read(savedGameProvider), isNull);
      expect(store.values, isNot(contains(SavedGameStore.key)));
    });
  });
}
