import 'dart:convert';

import 'package:bachmann_jass/app/settings.dart';
import 'package:bachmann_jass/game/game_controller.dart';
import 'package:bachmann_jass/game/game_session.dart';
import 'package:bachmann_jass/game/key_value_store.dart';
import 'package:bachmann_jass/game/stats.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

import '../support/test_app.dart';

void main() {
  ProviderContainer makeContainer({AppSettings settings = AppSettings.defaults}) {
    final container = ProviderContainer(
      overrides: testOverrides(settings: settings, instantAi: false),
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Laesst die Zeit laufen, bis der Mensch dran ist.
  void settle(FakeAsync async, ProviderContainer container) {
    for (var guard = 0; guard < 200; guard += 1) {
      final session = container.read(gameControllerProvider)!;
      if (session.humanTurn || session.state.phase == GamePhase.roundEnd) {
        return;
      }
      async.elapse(const Duration(seconds: 1));
    }
  }

  test('Zuruecknehmen stellt den Stand vor dem letzten eigenen Zug wieder her', () {
    fakeAsync((async) {
      final container = makeContainer();
      final controller = container.read(gameControllerProvider.notifier);
      controller.startNewGame(
        variant: GameVariant.schieber,
        matchConfig: const MatchConfig(targetScore: 1000),
        playerName: 'Test',
        seed: 5,
      );
      settle(async, container);
      var session = container.read(gameControllerProvider)!;
      expect(session.canUndo, isFalse);

      // Bis zur ersten eigenen Karte spielen.
      while (session.state.phase != GamePhase.playing || !session.humanTurn) {
        if (session.humanTurn) {
          expect(controller.act(aiDecide(session.state)!), isNull);
        }
        settle(async, container);
        session = container.read(gameControllerProvider)!;
      }
      final before = jsonEncode(session.state.toJson());
      final card = playableCards(session.state, 0).first;
      expect(controller.act(PlayCard(0, card)), isNull);
      async.elapse(const Duration(seconds: 3));
      expect(container.read(gameControllerProvider)!.canUndo, isTrue);
      expect(container.read(gameControllerProvider)!.state.players[0].hand, isNot(contains(card)));

      controller.undo();
      session = container.read(gameControllerProvider)!;
      expect(jsonEncode(session.state.toJson()), before);
      expect(session.state.players[0].hand, contains(card));
    });
  });

  test('Die einzige erlaubte Karte wird automatisch gespielt', () {
    fakeAsync((async) {
      final container = makeContainer(settings: const AppSettings(autoPlaySingleCard: true));
      final controller = container.read(gameControllerProvider.notifier);
      controller.startNewGame(
        variant: GameVariant.schieber,
        matchConfig: const MatchConfig(targetScore: 1000),
        playerName: 'Test',
        seed: 6,
      );

      // Solange nur eine Karte erlaubt ist, muss der Mensch nie selbst tippen.
      var autoPlayed = false;
      for (var guard = 0; guard < 300; guard += 1) {
        final session = container.read(gameControllerProvider)!;
        final game = session.state;
        if (game.phase == GamePhase.roundEnd || game.phase == GamePhase.gameOver) {
          break;
        }
        if (session.humanTurn) {
          if (game.phase == GamePhase.playing && playableCards(game, 0).length == 1) {
            expect(session.waiting, isTrue, reason: 'Automatisches Spielen ist geplant');
            async.elapse(const Duration(seconds: 2));
            expect(container.read(gameControllerProvider)!.revision, greaterThan(session.revision));
            autoPlayed = true;
            continue;
          }
          expect(controller.act(aiDecide(game)!), isNull);
        }
        async.elapse(const Duration(seconds: 1));
      }
      expect(autoPlayed, isTrue, reason: 'Im Laufe der Runde gab es eine einzige erlaubte Karte');
    });
  });

  /// Spielt eine kurze Bieterjass-Partie zu Ende; der Mensch zieht wie die KI.
  void playToEnd(FakeAsync async, ProviderContainer container, {List<SeatSetup>? seats}) {
    final controller = container.read(gameControllerProvider.notifier);
    controller.startNewGame(
      variant: GameVariant.bieter,
      matchConfig: const MatchConfig(targetScore: 200),
      playerName: 'Test',
      seats: seats,
      seed: 9,
    );
    for (var guard = 0; guard < 4000; guard += 1) {
      final session = container.read(gameControllerProvider)!;
      if (session.state.phase == GamePhase.gameOver) {
        break;
      }
      if (session.state.phase == GamePhase.roundEnd) {
        expect(controller.act(const StartRound()), isNull);
      } else if (session.humanTurn) {
        expect(controller.act(aiDecide(session.state)!), isNull);
      }
      async.elapse(const Duration(seconds: 1));
    }
    async.flushMicrotasks();
    expect(container.read(gameControllerProvider)!.state.phase, GamePhase.gameOver);
  }

  test('Yannicks Jubel ertoent nur, wenn Yannick gewinnt und der Ton an ist', () {
    fakeAsync((async) {
      // Standardsitze: Yannick ist der Computer links.
      final sound = RecordingSoundPlayer();
      final container = ProviderContainer(overrides: testOverrides(instantAi: false, sound: sound));
      addTearDown(container.dispose);
      playToEnd(async, container);
      final session = container.read(gameControllerProvider)!;
      final over = session.events.whereType<GameOver>().single;
      expect(session.state.players[1].name, 'Yannick');
      expect(sound.wins, cheeringPlayerWon(session.state, over) ? 1 : 0);
      expect(cheeringPlayerWon(session.state, over), over.winnerPlayer == 1);

      // Ohne einen Yannick am Tisch bleibt es still, auch wenn dieselbe Partie laeuft.
      final silent = RecordingSoundPlayer();
      final nobody = ProviderContainer(overrides: testOverrides(instantAi: false, sound: silent));
      addTearDown(nobody.dispose);
      playToEnd(
        async,
        nobody,
        seats: const [
          SeatSetup(name: 'Test', isHuman: true),
          SeatSetup(name: 'Anna', isHuman: false),
          SeatSetup(name: 'Beat', isHuman: false),
        ],
      );
      expect(silent.wins, 0);

      // Heisst der Mensch Yannick, jubelt es bei seinem Sieg.
      final own = RecordingSoundPlayer();
      final human = ProviderContainer(overrides: testOverrides(instantAi: false, sound: own));
      addTearDown(human.dispose);
      playToEnd(
        async,
        human,
        seats: const [
          SeatSetup(name: ' yannick ', isHuman: true),
          SeatSetup(name: 'Anna', isHuman: false),
          SeatSetup(name: 'Beat', isHuman: false),
        ],
      );
      final humanSession = human.read(gameControllerProvider)!;
      expect(own.wins, over.winnerPlayer == 0 ? 1 : 0);
      expect(humanSession.state.phase, GamePhase.gameOver);

      // Ausgeschaltet bleibt es still.
      final muted = RecordingSoundPlayer();
      final quiet = ProviderContainer(
        overrides: testOverrides(
          instantAi: false,
          sound: muted,
          settings: const AppSettings(winSound: false),
        ),
      );
      addTearDown(quiet.dispose);
      playToEnd(async, quiet);
      expect(muted.wins, 0);
    });
  });

  test('Die Statistik verbucht Runden, Gebote und das Spielende', () {
    fakeAsync((async) {
      final store = MemoryKeyValueStore();
      final container = ProviderContainer(overrides: testOverrides(store: store, instantAi: false));
      addTearDown(container.dispose);
      playToEnd(async, container);

      final stats = container.read(statsProvider);
      expect(container.read(gameControllerProvider)!.state.phase, GamePhase.gameOver);
      expect(stats.gamesPlayed, 1);
      expect(stats.roundsPlayed, greaterThan(0));
      expect(stats.bidsAttempted, greaterThanOrEqualTo(stats.bidsMade));
      expect(store.values, contains(StatsStore.key));

      GameStats? loaded;
      StatsStore(store).load().then((value) => loaded = value);
      async.flushMicrotasks();
      expect(loaded!.gamesPlayed, 1);
    });
  });

  test('Einstellungen ueberstehen JSON und lesen alte Staende tolerant', () {
    final settings = AppSettings.defaults.copyWith(
      speedFactor: 0.7,
      autoPlaySingleCard: true,
      confirmPlay: true,
      allowUndo: true,
      winSound: false,
      opponentNames: const ['Anna', 'Beat', 'Cla'],
      opponentDifficulties: const [Difficulty.schwer, null, Difficulty.einfach],
      rules: RuleSet.bachmann.copyWith(bedanken: true, trickReview: TrickReview.all),
    );
    final restored = AppSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())) as Map<String, Object?>,
    );
    expect(restored.toJson(), settings.toJson());
    expect(restored.rules, settings.rules);

    final legacy = AppSettings.fromJson({'speed': 'schnell', 'variant': 'schieber'});
    expect(legacy.speedFactor, GameSpeed.schnell.factor);
    expect(legacy.speed, GameSpeed.schnell);
    expect(legacy.opponentNames, defaultOpponentNames);
    expect(legacy.rules, RuleSet.bachmann);
    expect(legacy.allowUndo, isFalse);
    expect(legacy.winSound, isTrue);

    final seats = settings.seatsFor(GameVariant.schieber, 'Ich');
    expect(seats.map((s) => s.name), ['Ich', 'Anna', 'Beat', 'Cla']);
    expect(seats[1].difficulty, Difficulty.schwer);
    expect(settings.seatsFor(GameVariant.bieter, 'Ich'), hasLength(3));
  });
}
