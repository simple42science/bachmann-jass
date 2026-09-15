import 'errors.dart';
import 'game_state.dart';
import 'model.dart';

/// Kopie von [list] mit [value] an Position [index].
List<T> replacedAt<T>(List<T> list, int index, T value) => [
  for (var position = 0; position < list.length; position += 1)
    position == index ? value : list[position],
];

void requirePhase(GameState state, Set<GamePhase> phases) {
  if (!phases.contains(state.phase)) {
    throw GameRuleException(
      RuleViolation.wrongPhase,
      'Phase ${state.phase.name}, erwartet ${phases.map((phase) => phase.name).join('/')}',
    );
  }
}

void requireTurn(GameState state, int playerIndex) {
  if (playerIndex != state.currentPlayer) {
    throw GameRuleException(
      RuleViolation.notYourTurn,
      'Sitz $playerIndex, am Zug ist ${state.currentPlayer}',
    );
  }
}
