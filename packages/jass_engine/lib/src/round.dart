import 'package:meta/meta.dart';

import 'cards.dart';
import 'json.dart';
import 'weis.dart';

Weis? _weisOrNull(Object? json) =>
    json == null ? null : Weis.fromJson(json as Map<String, Object?>);

@immutable
final class WeisDeclaration {
  const WeisDeclaration({required this.playerIndex, required this.weis, required this.orderIndex});

  factory WeisDeclaration.fromJson(Map<String, Object?> json) => WeisDeclaration(
    playerIndex: json['playerIndex']! as int,
    weis: _weisOrNull(json['weis']),
    orderIndex: json['orderIndex']! as int,
  );

  final int playerIndex;

  /// `null`: kein Weis gemeldet oder bewusst verzichtet.
  final Weis? weis;

  /// Position in der Melde-Reihenfolge; bei Gleichstand gewinnt die fruehere.
  final int orderIndex;

  Map<String, Object?> toJson() => {
    'playerIndex': playerIndex,
    'weis': weis?.toJson(),
    'orderIndex': orderIndex,
  };
}

/// Zustand der Weisrunde vor dem ersten Stich (nur Schieber).
@immutable
final class WeisState {
  const WeisState({
    required this.order,
    required this.currentIndex,
    required this.possibleByPlayer,
    required this.highestByPlayer,
    required this.declaredByPlayer,
    required this.declaredEntries,
    this.winningDeclaration,
    this.awardedTeamId,
  });

  factory WeisState.fromJson(Map<String, Object?> json) => WeisState(
    order: intsFromJson(json['order']),
    currentIndex: json['currentIndex']! as int,
    possibleByPlayer: intKeyedFromJson(
      json['possibleByPlayer'],
      (value) => [
        for (final weis in value! as List<Object?>) Weis.fromJson(weis! as Map<String, Object?>),
      ],
    ),
    highestByPlayer: intKeyedFromJson(json['highestByPlayer'], _weisOrNull),
    declaredByPlayer: intKeyedFromJson(json['declaredByPlayer'], _weisOrNull),
    declaredEntries: [
      for (final entry in json['declaredEntries']! as List<Object?>)
        WeisDeclaration.fromJson(entry! as Map<String, Object?>),
    ],
    winningDeclaration: json['winningDeclaration'] == null
        ? null
        : WeisDeclaration.fromJson(json['winningDeclaration']! as Map<String, Object?>),
    awardedTeamId: json['awardedTeamId'] as int?,
  );

  /// Melde-Reihenfolge ab Vorhand.
  final List<int> order;
  final int currentIndex;
  final Map<int, List<Weis>> possibleByPlayer;
  final Map<int, Weis?> highestByPlayer;

  /// Wer schon an der Reihe war. Der Wert `null` heisst: nichts gemeldet.
  final Map<int, Weis?> declaredByPlayer;
  final List<WeisDeclaration> declaredEntries;
  final WeisDeclaration? winningDeclaration;
  final int? awardedTeamId;

  WeisState copyWith({
    int? currentIndex,
    Map<int, Weis?>? declaredByPlayer,
    List<WeisDeclaration>? declaredEntries,
    Object? winningDeclaration = unchanged,
    Object? awardedTeamId = unchanged,
  }) => WeisState(
    order: order,
    currentIndex: currentIndex ?? this.currentIndex,
    possibleByPlayer: possibleByPlayer,
    highestByPlayer: highestByPlayer,
    declaredByPlayer: declaredByPlayer ?? this.declaredByPlayer,
    declaredEntries: declaredEntries ?? this.declaredEntries,
    winningDeclaration: identical(winningDeclaration, unchanged)
        ? this.winningDeclaration
        : winningDeclaration as WeisDeclaration?,
    awardedTeamId: identical(awardedTeamId, unchanged) ? this.awardedTeamId : awardedTeamId as int?,
  );

  Map<String, Object?> toJson() => {
    'order': order,
    'currentIndex': currentIndex,
    'possibleByPlayer': intKeyedToJson(
      possibleByPlayer,
      (List<Weis> weisen) => [for (final weis in weisen) weis.toJson()],
    ),
    'highestByPlayer': intKeyedToJson(highestByPlayer, (Weis? weis) => weis?.toJson()),
    'declaredByPlayer': intKeyedToJson(declaredByPlayer, (Weis? weis) => weis?.toJson()),
    'declaredEntries': [for (final entry in declaredEntries) entry.toJson()],
    'winningDeclaration': winningDeclaration?.toJson(),
    'awardedTeamId': awardedTeamId,
  };
}

/// Abrechnung einer abgeschlossenen Runde.
@immutable
sealed class RoundSummary {
  const RoundSummary({required this.roundMode, required this.multiplier});

  factory RoundSummary.fromJson(Map<String, Object?> json) => switch (json['type']) {
    'bieter' => BieterRoundSummary.fromJson(json),
    'schieber' => SchieberRoundSummary.fromJson(json),
    final type => throw FormatException('Unbekannte Rundenabrechnung: $type'),
  };

  final RoundMode roundMode;
  final int multiplier;

  Map<String, Object?> toJson();
}

final class BieterRoundSummary extends RoundSummary {
  const BieterRoundSummary({
    required super.roundMode,
    required super.multiplier,
    required this.soloPlayer,
    required this.bid,
    required this.soloPoints,
    required this.succeeded,
    required this.soloGain,
    required this.defenderGain,
  });

  factory BieterRoundSummary.fromJson(Map<String, Object?> json) => BieterRoundSummary(
    roundMode: RoundMode.values.byName(json['roundMode']! as String),
    multiplier: json['multiplier']! as int,
    soloPlayer: json['soloPlayer']! as int,
    bid: json['bid']! as int,
    soloPoints: json['soloPoints']! as int,
    succeeded: json['succeeded']! as bool,
    soloGain: json['soloGain']! as int,
    defenderGain: json['defenderGain']! as int,
  );

  final int soloPlayer;
  final int bid;
  final int soloPoints;
  final bool succeeded;

  /// Spielpunkte des Bieters; negativ, wenn er sein Gebot verpasst.
  final int soloGain;

  /// Spielpunkte je Verteidiger.
  final int defenderGain;

  @override
  Map<String, Object?> toJson() => {
    'type': 'bieter',
    'roundMode': roundMode.name,
    'multiplier': multiplier,
    'soloPlayer': soloPlayer,
    'bid': bid,
    'soloPoints': soloPoints,
    'succeeded': succeeded,
    'soloGain': soloGain,
    'defenderGain': defenderGain,
  };
}

@immutable
final class TeamRoundResult {
  const TeamRoundResult({
    required this.teamId,
    required this.trickPoints,
    required this.weisPoints,
    required this.stoeckPoints,
    required this.matchPoints,
    required this.basePoints,
    required this.roundPoints,
    required this.tricksWon,
  });

  factory TeamRoundResult.fromJson(Map<String, Object?> json) => TeamRoundResult(
    teamId: json['teamId']! as int,
    trickPoints: json['trickPoints']! as int,
    weisPoints: json['weisPoints']! as int,
    stoeckPoints: json['stoeckPoints']! as int,
    matchPoints: json['matchPoints']! as int,
    basePoints: json['basePoints']! as int,
    roundPoints: json['roundPoints']! as int,
    tricksWon: json['tricksWon']! as int,
  );

  final int teamId;
  final int trickPoints;
  final int weisPoints;
  final int stoeckPoints;
  final int matchPoints;

  /// Summe vor dem Multiplikator.
  final int basePoints;

  /// Geschriebene Punkte nach dem Multiplikator.
  final int roundPoints;
  final int tricksWon;

  Map<String, Object?> toJson() => {
    'teamId': teamId,
    'trickPoints': trickPoints,
    'weisPoints': weisPoints,
    'stoeckPoints': stoeckPoints,
    'matchPoints': matchPoints,
    'basePoints': basePoints,
    'roundPoints': roundPoints,
    'tricksWon': tricksWon,
  };
}

final class SchieberRoundSummary extends RoundSummary {
  const SchieberRoundSummary({
    required super.roundMode,
    required super.multiplier,
    required this.results,
    required this.roundWinnerTeamId,
    required this.trumpChooser,
    required this.pushed,
    required this.targetScore,
    required this.weisWinnerTeamId,
    required this.highestWeis,
    required this.stoeckPlayer,
    required this.matchTeamId,
  });

  factory SchieberRoundSummary.fromJson(Map<String, Object?> json) => SchieberRoundSummary(
    roundMode: RoundMode.values.byName(json['roundMode']! as String),
    multiplier: json['multiplier']! as int,
    results: [
      for (final result in json['results']! as List<Object?>)
        TeamRoundResult.fromJson(result! as Map<String, Object?>),
    ],
    roundWinnerTeamId: json['roundWinnerTeamId']! as int,
    trumpChooser: json['trumpChooser']! as int,
    pushed: json['pushed']! as bool,
    targetScore: json['targetScore']! as int,
    weisWinnerTeamId: json['weisWinnerTeamId'] as int?,
    highestWeis: _weisOrNull(json['highestWeis']),
    stoeckPlayer: json['stoeckPlayer']! as int,
    matchTeamId: json['matchTeamId'] as int?,
  );

  final List<TeamRoundResult> results;
  final int roundWinnerTeamId;
  final int trumpChooser;
  final bool pushed;
  final int targetScore;
  final int? weisWinnerTeamId;
  final Weis? highestWeis;

  /// Wer Stöck hielt, sonst -1.
  final int stoeckPlayer;
  final int? matchTeamId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'schieber',
    'roundMode': roundMode.name,
    'multiplier': multiplier,
    'results': [for (final result in results) result.toJson()],
    'roundWinnerTeamId': roundWinnerTeamId,
    'trumpChooser': trumpChooser,
    'pushed': pushed,
    'targetScore': targetScore,
    'weisWinnerTeamId': weisWinnerTeamId,
    'highestWeis': highestWeis?.toJson(),
    'stoeckPlayer': stoeckPlayer,
    'matchTeamId': matchTeamId,
  };
}

/// Eine Zeile der Jasstafel.
@immutable
final class RoundHistoryEntry {
  const RoundHistoryEntry({
    required this.roundNumber,
    required this.dealer,
    required this.totals,
    required this.summary,
  });

  factory RoundHistoryEntry.fromJson(Map<String, Object?> json) => RoundHistoryEntry(
    roundNumber: json['roundNumber']! as int,
    dealer: json['dealer']! as int,
    totals: intKeyedFromJson(json['totals'], (value) => value! as int),
    summary: RoundSummary.fromJson(json['summary']! as Map<String, Object?>),
  );

  final int roundNumber;
  final int dealer;

  /// Gesamtstand nach der Runde: je Team (Schieber) oder je Spieler (Bieterjass).
  final Map<int, int> totals;
  final RoundSummary summary;

  Map<String, Object?> toJson() => {
    'roundNumber': roundNumber,
    'dealer': dealer,
    'totals': intKeyedToJson(totals, (int value) => value),
    'summary': summary.toJson(),
  };
}
