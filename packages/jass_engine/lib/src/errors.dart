/// Grund, warum eine Aktion abgelehnt wurde.
enum RuleViolation {
  wrongPhase,
  wrongVariant,
  notYourTurn,
  invalidBid,
  bidTooLow,
  pushNotAllowed,
  modeNotAllowed,
  unknownWeis,
  cardNotInHand,
  cardNotAllowed,
}

/// Eine Aktion verstoesst gegen die Regeln oder passt nicht zum Spielstand.
///
/// Der Spielstand bleibt dabei unveraendert. Die App uebersetzt [violation]
/// in einen Hinweis fuer den Spieler.
final class GameRuleException implements Exception {
  const GameRuleException(this.violation, [this.detail = '']);

  final RuleViolation violation;

  /// Technischer Zusatz fuer Logs und Tests, nicht fuer die Anzeige.
  final String detail;

  @override
  String toString() => 'GameRuleException(${violation.name}${detail.isEmpty ? '' : ': $detail'})';
}
