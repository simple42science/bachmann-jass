import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jass_engine/jass_engine.dart';

import '../app/settings.dart';
import 'game_session.dart';
import 'saved_game.dart';

/// Wofuer der Computer gerade Bedenkzeit braucht.
enum AiDelayKind { bidding, trump, weis, card, trickEnd }

/// Wartezeiten in Millisekunden (min, max) wie in der Web-App.
const Map<AiDelayKind, (int, int)> _delayRanges = {
  AiDelayKind.bidding: (1200, 2100),
  AiDelayKind.trump: (1500, 2600),
  AiDelayKind.weis: (900, 1700),
  AiDelayKind.card: (1500, 2700),
  AiDelayKind.trickEnd: (1700, 2500),
};

typedef AiDelay = Duration Function(AiDelayKind kind, GameSpeed speed, math.Random random);

Duration defaultAiDelay(AiDelayKind kind, GameSpeed speed, math.Random random) {
  final (min, max) = _delayRanges[kind]!;
  final base = min + random.nextInt(max - min + 1);
  return Duration(milliseconds: (base * speed.factor).round());
}

/// Wartezeit vor Computerzuegen; Tests ueberschreiben sie mit null.
final aiDelayProvider = Provider<AiDelay>((ref) => defaultAiDelay);

/// Fuehrt die Partie: nimmt Eingaben entgegen, laesst die Computer mit
/// Bedenkzeit ziehen, raeumt Stiche ab und sichert nach jeder Aktion.
///
/// Der Zustand ist `null`, solange keine Partie am Tisch liegt.
class GameController extends Notifier<GameSession?> {
  Timer? _timer;
  bool _pausedBySystem = false;
  final math.Random _random = math.Random();

  @override
  GameSession? build() {
    ref.onDispose(_cancelTimer);
    return null;
  }

  void startNewGame({
    required GameVariant variant,
    required MatchConfig matchConfig,
    required String playerName,
    int? seed,
  }) {
    final created = createGame(
      variant: variant,
      matchConfig: matchConfig,
      seats: defaultSeats(variant, humanName: playerName),
      seed: seed,
    );
    final result = applyAction(created, const StartRound());
    _publish(result.state, result.events, revision: 1);
  }

  /// Nimmt die gespeicherte Partie wieder auf. `false`, wenn keine vorliegt.
  bool resume() {
    final saved = ref.read(savedGameProvider);
    if (saved == null) {
      return false;
    }
    _publish(saved.state, const [], revision: 1);
    return true;
  }

  /// Aktion des Menschen. Liefert bei einem Regelverstoss den Grund, sonst `null`.
  RuleViolation? act(GameAction action) {
    final session = state;
    if (session == null) {
      return null;
    }
    try {
      final result = applyAction(session.state, action);
      _pausedBySystem = false;
      _publish(result.state, result.events, revision: session.revision + 1);
      return null;
    } on GameRuleException catch (error) {
      return error.violation;
    }
  }

  /// Ein Tipp auf den Tisch ueberspringt die laufende Wartezeit.
  void skipDelay() {
    if (_timer != null) {
      _runScheduled();
    }
  }

  void pause({bool bySystem = false}) {
    final session = state;
    if (session == null || session.paused) {
      return;
    }
    _cancelTimer();
    _pausedBySystem = bySystem;
    state = session.copyWith(paused: true, waiting: false);
  }

  void resumeGame() {
    final session = state;
    if (session == null || !session.paused) {
      return;
    }
    _pausedBySystem = false;
    state = session.copyWith(paused: false);
    _schedule();
  }

  /// Nach einer Unterbrechung durch das System (App im Hintergrund) weiterspielen.
  void resumeAfterSystemPause() {
    if (_pausedBySystem) {
      resumeGame();
    }
  }

  /// Zurueck zum Homescreen; die Partie bleibt gespeichert.
  void leaveTable() {
    _cancelTimer();
    state = null;
  }

  /// Partie endgueltig aufgeben.
  void abandon() {
    _cancelTimer();
    ref.read(savedGameProvider.notifier).clear();
    state = null;
  }

  void _publish(GameState next, List<GameEvent> events, {required int revision}) {
    _cancelTimer();
    // Der Verlauf sammelt die Ereignisse seit dem letzten Rundenstart.
    final startsRound = events.any((event) => event is RoundStarted);
    final roundEvents = startsRound ? events : [...?state?.roundEvents, ...events];
    state = GameSession(state: next, events: events, roundEvents: roundEvents, revision: revision);

    final saved = ref.read(savedGameProvider.notifier);
    if (next.phase == GamePhase.gameOver) {
      saved.clear();
    } else {
      saved.save(next);
    }
    _schedule();
  }

  AiDelayKind? _pendingKind(GameState game) {
    if (game.phase == GamePhase.trickEnd) {
      return AiDelayKind.trickEnd;
    }
    if (!game.isInteractive || game.players[game.currentPlayer].isHuman) {
      return null;
    }
    return switch (game.phase) {
      GamePhase.bidding => AiDelayKind.bidding,
      GamePhase.chooseTrump => AiDelayKind.trump,
      GamePhase.announceWeis => AiDelayKind.weis,
      _ => AiDelayKind.card,
    };
  }

  void _schedule() {
    final session = state;
    if (session == null || session.paused) {
      return;
    }
    final kind = _pendingKind(session.state);
    if (kind == null) {
      return;
    }
    final delay = ref.read(aiDelayProvider)(kind, ref.read(settingsProvider).speed, _random);
    state = session.copyWith(waiting: true);
    _timer = Timer(delay, _runScheduled);
  }

  void _runScheduled() {
    _cancelTimer();
    final session = state;
    if (session == null || session.paused) {
      return;
    }
    final game = session.state;
    final action = game.phase == GamePhase.trickEnd ? const NextTrick() : aiDecide(game);
    if (action == null) {
      return;
    }
    final result = applyAction(game, action);
    _publish(result.state, result.events, revision: session.revision + 1);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameSession?>(GameController.new);
