import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jass_engine/jass_engine.dart';

import '../game/game_controller.dart';

/// Demo-Start ueber die URL, nur in Builds mit `--dart-define=JASS_DEMO=true`.
///
/// Damit lassen sich fuer Screenshots und Browsertests reproduzierbare
/// Spielsituationen direkt aufrufen, zum Beispiel
/// `?demo=schieber&seed=5&moves=3`: Schieber mit Seed 5, der Mensch spielt
/// seine ersten drei Entscheidungen wie die KI. Computerzuege kommen sofort.
/// `&screen=scoreboard` oeffnet die Jasstafel, `&screen=rules` die Regeln.
const bool demoEnabled = bool.fromEnvironment('JASS_DEMO');

final class DemoRequest {
  const DemoRequest({
    required this.variant,
    required this.seed,
    required this.humanMoves,
    this.screen = 'table',
  });

  /// `null`, wenn die URL keinen Demo-Start verlangt.
  static DemoRequest? fromUri(Uri uri) {
    final variantName = uri.queryParameters['demo'];
    if (!demoEnabled || variantName == null) {
      return null;
    }
    final variant = GameVariant.values.cast<GameVariant?>().firstWhere(
      (value) => value?.name == variantName,
      orElse: () => null,
    );
    if (variant == null) {
      return null;
    }
    return DemoRequest(
      variant: variant,
      seed: int.tryParse(uri.queryParameters['seed'] ?? '') ?? 1,
      humanMoves: int.tryParse(uri.queryParameters['moves'] ?? '') ?? 0,
      screen: uri.queryParameters['screen'] ?? 'table',
    );
  }

  final GameVariant variant;
  final int seed;
  final int humanMoves;

  /// `table`, `scoreboard` oder `rules`: die Seite, die nach dem Start offen ist.
  final String screen;
}

/// Startet die Demo-Partie und spielt die ersten Entscheidungen des Menschen.
Future<void> runDemo(ProviderContainer container, DemoRequest request) async {
  final controller = container.read(gameControllerProvider.notifier);
  controller.startNewGame(
    variant: request.variant,
    matchConfig: MatchConfig(
      targetScore: request.variant.defaultTargetScore,
      bieterScoring: BieterScoring.schieber,
    ),
    playerName: 'Näschel',
    seed: request.seed,
  );

  var moves = 0;
  for (var guard = 0; guard < 500 && moves < request.humanMoves; guard += 1) {
    final session = container.read(gameControllerProvider)!;
    if (session.state.phase == GamePhase.roundEnd || session.state.phase == GamePhase.gameOver) {
      break;
    }
    if (session.humanTurn) {
      final action = aiDecide(session.state);
      if (action != null) {
        controller.act(action);
        moves += 1;
      }
    }
    // Computerzuege laufen ueber Timer und brauchen einen Umlauf der Ereignisschleife.
    await Future<void>.delayed(Duration.zero);
  }
}
