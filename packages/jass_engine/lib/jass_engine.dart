/// Regeln, Wertung und Computergegner fuer Schweizer Jass.
///
/// Reines Dart ohne Flutter, damit dieselben Regeln spaeter auch auf einem
/// Server laufen koennen.
///
/// Einstieg: [createGame] legt eine Partie an, [applyAction] fuehrt Aktionen
/// aus und liefert den neuen Zustand samt Ereignissen.
library;

import 'src/engine.dart';

export 'src/actions.dart';
export 'src/ai.dart';
export 'src/cards.dart';
export 'src/dealing.dart';
export 'src/engine.dart';
export 'src/errors.dart';
export 'src/events.dart';
export 'src/game_state.dart';
export 'src/model.dart';
export 'src/rng.dart';
export 'src/round.dart';
export 'src/rule_set.dart';
export 'src/rules.dart';
export 'src/weis.dart';
