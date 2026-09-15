import 'package:meta/meta.dart';

import 'cards.dart';

/// Alle regional abweichenden Werte an einer Stelle. Gehoert zum Spielstand,
/// damit eine laufende Partie ihre Regeln behaelt.
@immutable
final class RuleSet {
  const RuleSet({
    required this.lastTrickBonus,
    required this.matchBonus,
    required this.stoeckPoints,
    required this.fourSixesCount,
    required this.fourOfAKindBeatsSequence,
    required this.roundMultipliers,
    required this.bidValues,
    required this.forcedDealerBid,
  });

  factory RuleSet.fromJson(Map<String, Object?> json) => RuleSet(
    lastTrickBonus: json['lastTrickBonus']! as int,
    matchBonus: json['matchBonus']! as int,
    stoeckPoints: json['stoeckPoints']! as int,
    fourSixesCount: json['fourSixesCount']! as bool,
    fourOfAKindBeatsSequence: json['fourOfAKindBeatsSequence']! as bool,
    roundMultipliers: {
      for (final entry in (json['roundMultipliers']! as Map<String, Object?>).entries)
        RoundMode.values.byName(entry.key): entry.value! as int,
    },
    bidValues: [for (final value in json['bidValues']! as List<Object?>) value! as int],
    forcedDealerBid: json['forcedDealerBid']! as int,
  );

  /// Die Werte der bisherigen Web-App (Bachmann-Hausregeln).
  static const RuleSet bachmann = RuleSet(
    lastTrickBonus: 5,
    matchBonus: 100,
    stoeckPoints: 20,
    fourSixesCount: false,
    fourOfAKindBeatsSequence: true,
    roundMultipliers: {
      RoundMode.eicheln: 1,
      RoundMode.rosen: 1,
      RoundMode.schellen: 2,
      RoundMode.schilten: 2,
      RoundMode.obeAbe: 3,
      RoundMode.uneUfe: 3,
      RoundMode.slalom: 3,
    },
    bidValues: [60, 70, 80, 90, 100, 110, 120, 130, 140, 157],
    forcedDealerBid: 60,
  );

  /// Punkte fuer den letzten Stich.
  final int lastTrickBonus;

  /// Zusatzpunkte, wenn ein Team alle Stiche holt.
  final int matchBonus;

  /// Punkte fuer Koenig und Ober der Trumpffarbe.
  final int stoeckPoints;

  /// Zaehlen vier Sechser als Weis?
  final bool fourSixesCount;

  /// Gewinnen vier Gleiche gegen eine Folge mit gleicher Punktzahl?
  final bool fourOfAKindBeatsSequence;

  /// Faktor je Spielart.
  final Map<RoundMode, int> roundMultipliers;

  /// Erlaubte Gebote im Bieterjass, aufsteigend. Passen ist kein Gebotswert.
  final List<int> bidValues;

  /// Mit diesem Gebot spielt der Geber, wenn alle passen.
  final int forcedDealerBid;

  int multiplierFor(RoundMode mode) => roundMultipliers[mode] ?? 1;

  Map<String, Object?> toJson() => {
    'lastTrickBonus': lastTrickBonus,
    'matchBonus': matchBonus,
    'stoeckPoints': stoeckPoints,
    'fourSixesCount': fourSixesCount,
    'fourOfAKindBeatsSequence': fourOfAKindBeatsSequence,
    'roundMultipliers': {for (final entry in roundMultipliers.entries) entry.key.name: entry.value},
    'bidValues': bidValues,
    'forcedDealerBid': forcedDealerBid,
  };
}
