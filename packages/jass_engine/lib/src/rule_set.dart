import 'package:meta/meta.dart';

import 'cards.dart';

/// Welche Stiche der Runde nochmals angeschaut werden duerfen.
enum TrickReview { none, last, first, all }

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
    this.bedanken = false,
    this.trickReview = TrickReview.first,
  });

  /// Liest tolerant: spaeter dazugekommene Regeln fallen auf ihren Standard zurueck.
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
    bedanken: json['bedanken'] as bool? ?? false,
    trickReview:
        TrickReview.values.cast<TrickReview?>().firstWhere(
          (value) => value?.name == json['trickReview'],
          orElse: () => null,
        ) ??
        TrickReview.first,
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

  /// Bedanken: Die Partie endet im Schieber sofort, sobald ein Team das Ziel
  /// erreicht - auch mitten in der Runde. Sonst wird die Runde zu Ende gespielt.
  final bool bedanken;

  /// Welche Stiche nochmals angeschaut werden duerfen.
  final TrickReview trickReview;

  int multiplierFor(RoundMode mode) => roundMultipliers[mode] ?? 1;

  RuleSet copyWith({
    int? lastTrickBonus,
    int? matchBonus,
    int? stoeckPoints,
    bool? fourSixesCount,
    bool? fourOfAKindBeatsSequence,
    Map<RoundMode, int>? roundMultipliers,
    List<int>? bidValues,
    int? forcedDealerBid,
    bool? bedanken,
    TrickReview? trickReview,
  }) => RuleSet(
    lastTrickBonus: lastTrickBonus ?? this.lastTrickBonus,
    matchBonus: matchBonus ?? this.matchBonus,
    stoeckPoints: stoeckPoints ?? this.stoeckPoints,
    fourSixesCount: fourSixesCount ?? this.fourSixesCount,
    fourOfAKindBeatsSequence: fourOfAKindBeatsSequence ?? this.fourOfAKindBeatsSequence,
    roundMultipliers: roundMultipliers ?? this.roundMultipliers,
    bidValues: bidValues ?? this.bidValues,
    forcedDealerBid: forcedDealerBid ?? this.forcedDealerBid,
    bedanken: bedanken ?? this.bedanken,
    trickReview: trickReview ?? this.trickReview,
  );

  Map<String, Object?> toJson() => {
    'lastTrickBonus': lastTrickBonus,
    'matchBonus': matchBonus,
    'stoeckPoints': stoeckPoints,
    'fourSixesCount': fourSixesCount,
    'fourOfAKindBeatsSequence': fourOfAKindBeatsSequence,
    'roundMultipliers': {for (final entry in roundMultipliers.entries) entry.key.name: entry.value},
    'bidValues': bidValues,
    'forcedDealerBid': forcedDealerBid,
    'bedanken': bedanken,
    'trickReview': trickReview.name,
  };

  @override
  bool operator ==(Object other) =>
      other is RuleSet &&
      other.lastTrickBonus == lastTrickBonus &&
      other.matchBonus == matchBonus &&
      other.stoeckPoints == stoeckPoints &&
      other.fourSixesCount == fourSixesCount &&
      other.fourOfAKindBeatsSequence == fourOfAKindBeatsSequence &&
      other.bidValues.length == bidValues.length &&
      other.forcedDealerBid == forcedDealerBid &&
      other.bedanken == bedanken &&
      other.trickReview == trickReview &&
      RoundMode.values.every((mode) => other.multiplierFor(mode) == multiplierFor(mode)) &&
      [
        for (var i = 0; i < bidValues.length; i += 1) other.bidValues[i] == bidValues[i],
      ].every((same) => same);

  @override
  int get hashCode => Object.hash(
    lastTrickBonus,
    matchBonus,
    stoeckPoints,
    fourSixesCount,
    fourOfAKindBeatsSequence,
    forcedDealerBid,
    bedanken,
    trickReview,
    Object.hashAll(bidValues),
    Object.hashAll([for (final mode in RoundMode.values) multiplierFor(mode)]),
  );
}
