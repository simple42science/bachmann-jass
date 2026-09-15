import 'package:meta/meta.dart';

import 'cards.dart';
import 'json.dart';
import 'model.dart';
import 'round.dart';
import 'rule_set.dart';
import 'weis.dart';

/// Vollstaendiger, unveraenderlicher Zustand einer Partie.
///
/// Die Felder folgen bewusst dem Spielobjekt der Web-App, damit sich beide
/// Engines Zug um Zug vergleichen lassen. Stapel und Team-Werte sind Listen mit
/// zwei Eintraegen (Index 0 und 1).
@immutable
final class GameState {
  const GameState({
    required this.variant,
    required this.matchConfig,
    required this.rules,
    required this.seed,
    required this.rngState,
    required this.players,
    required this.teams,
    required this.phase,
    required this.roundNumber,
    required this.dealer,
    required this.currentPlayer,
    required this.biddingOrder,
    required this.biddingPassed,
    required this.highestBid,
    required this.highestBidder,
    required this.roundMode,
    required this.soloPlayer,
    required this.chooserPlayer,
    required this.forehandPlayer,
    required this.trumpWasPushed,
    required this.trick,
    required this.trickLeader,
    required this.trickNumber,
    required this.playedCards,
    required this.capturedCards,
    required this.capturedTricks,
    required this.capturedPileOwners,
    required this.firstCapturedTrick,
    required this.lastCapturedPile,
    this.roundTricks = const [],
    required this.teamWeisScores,
    required this.teamWeisBreakdown,
    required this.teamStoeckPoints,
    required this.stoeckPlayer,
    required this.stoeckAnnounced,
    required this.weisState,
    required this.roundSummary,
    required this.roundHistory,
  });

  factory GameState.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException('Speicherstand-Version $version wird nicht unterstuetzt.');
    }
    return GameState(
      variant: GameVariant.values.byName(json['variant']! as String),
      matchConfig: MatchConfig.fromJson(json['matchConfig']! as Map<String, Object?>),
      rules: RuleSet.fromJson(json['rules']! as Map<String, Object?>),
      seed: json['seed']! as int,
      rngState: json['rngState']! as int,
      players: [
        for (final player in json['players']! as List<Object?>)
          Player.fromJson(player! as Map<String, Object?>),
      ],
      teams: [
        for (final team in json['teams']! as List<Object?>)
          Team.fromJson(team! as Map<String, Object?>),
      ],
      phase: GamePhase.values.byName(json['phase']! as String),
      roundNumber: json['roundNumber']! as int,
      dealer: json['dealer']! as int,
      currentPlayer: json['currentPlayer']! as int,
      biddingOrder: intsFromJson(json['biddingOrder']),
      biddingPassed: intsFromJson(json['biddingPassed']),
      highestBid: json['highestBid']! as int,
      highestBidder: json['highestBidder']! as int,
      roundMode: json['roundMode'] == null
          ? null
          : RoundMode.values.byName(json['roundMode']! as String),
      soloPlayer: json['soloPlayer']! as int,
      chooserPlayer: json['chooserPlayer']! as int,
      forehandPlayer: json['forehandPlayer']! as int,
      trumpWasPushed: json['trumpWasPushed']! as bool,
      trick: trickFromJson(json['trick']),
      trickLeader: json['trickLeader']! as int,
      trickNumber: json['trickNumber']! as int,
      playedCards: cardsFromJson(json['playedCards']),
      capturedCards: [
        for (final pile in json['capturedCards']! as List<Object?>) cardsFromJson(pile),
      ],
      capturedTricks: intsFromJson(json['capturedTricks']),
      capturedPileOwners: intsFromJson(json['capturedPileOwners']),
      firstCapturedTrick: json['firstCapturedTrick'] == null
          ? null
          : CapturedTrick.fromJson(json['firstCapturedTrick']! as Map<String, Object?>),
      lastCapturedPile: json['lastCapturedPile'] as int?,
      roundTricks: [
        for (final trick in json['roundTricks'] as List<Object?>? ?? const [])
          CapturedTrick.fromJson(trick! as Map<String, Object?>),
      ],
      teamWeisScores: intsFromJson(json['teamWeisScores']),
      teamWeisBreakdown: [
        for (final team in json['teamWeisBreakdown']! as List<Object?>)
          [for (final weis in team! as List<Object?>) Weis.fromJson(weis! as Map<String, Object?>)],
      ],
      teamStoeckPoints: intsFromJson(json['teamStoeckPoints']),
      stoeckPlayer: json['stoeckPlayer']! as int,
      stoeckAnnounced: json['stoeckAnnounced']! as bool,
      weisState: json['weisState'] == null
          ? null
          : WeisState.fromJson(json['weisState']! as Map<String, Object?>),
      roundSummary: json['roundSummary'] == null
          ? null
          : RoundSummary.fromJson(json['roundSummary']! as Map<String, Object?>),
      roundHistory: [
        for (final entry in json['roundHistory']! as List<Object?>)
          RoundHistoryEntry.fromJson(entry! as Map<String, Object?>),
      ],
    );
  }

  /// Erhoehen, sobald sich das JSON-Format inkompatibel aendert.
  static const int schemaVersion = 1;

  final GameVariant variant;
  final MatchConfig matchConfig;
  final RuleSet rules;

  /// Seed, mit dem die Partie begonnen hat.
  final int seed;

  /// Aktueller Zufallszustand; das naechste Mischen setzt hier fort.
  final int rngState;

  final List<Player> players;

  /// Nur im Schieber: Team 0 (Sitze 0 und 2) und Team 1 (Sitze 1 und 3).
  final List<Team> teams;

  final GamePhase phase;
  final int roundNumber;
  final int dealer;
  final int currentPlayer;

  final List<int> biddingOrder;
  final List<int> biddingPassed;
  final int highestBid;

  /// Sitz des Hoechstbietenden, sonst -1.
  final int highestBidder;

  final RoundMode? roundMode;

  /// Bieter im Bieterjass, sonst -1.
  final int soloPlayer;
  final int chooserPlayer;

  /// Vorhand im Schieber, sonst -1.
  final int forehandPlayer;
  final bool trumpWasPushed;

  final List<TrickEntry> trick;
  final int trickLeader;

  /// Anzahl bereits abgeschlossener Stiche der Runde.
  final int trickNumber;
  final List<JassCard> playedCards;

  final List<List<JassCard>> capturedCards;
  final List<int> capturedTricks;

  /// Wer den letzten Stich auf den jeweiligen Stapel gelegt hat.
  final List<int> capturedPileOwners;
  final CapturedTrick? firstCapturedTrick;
  final int? lastCapturedPile;

  /// Alle eingesammelten Stiche der laufenden Runde, in Reihenfolge.
  final List<CapturedTrick> roundTricks;

  final List<int> teamWeisScores;
  final List<List<Weis>> teamWeisBreakdown;
  final List<int> teamStoeckPoints;

  /// Wer Koenig und Ober der Trumpffarbe haelt, sonst -1.
  final int stoeckPlayer;
  final bool stoeckAnnounced;
  final WeisState? weisState;

  final RoundSummary? roundSummary;
  final List<RoundHistoryEntry> roundHistory;

  bool get isBieter => variant == GameVariant.bieter;

  bool get isSchieber => variant == GameVariant.schieber;

  int get targetScore => matchConfig.targetScore;

  /// Spielart des laufenden Stichs (im Slalom wechselnd).
  RoundMode? get trickMode => roundMode?.trickMode(trickNumber);

  /// Zaehlen in dieser Partie die Spielart-Multiplikatoren?
  bool get usesRoundMultipliers =>
      isSchieber || matchConfig.bieterScoring == BieterScoring.schieber;

  int get roundMultiplier {
    final mode = roundMode;
    if (mode == null || !usesRoundMultipliers) {
      return 1;
    }
    return rules.multiplierFor(mode);
  }

  /// Im einfachen Bieterjass nur die vier Farben, sonst alle Spielarten.
  List<RoundMode> get allowedRoundModes =>
      usesRoundMultipliers ? RoundMode.values : RoundMode.trumpModes;

  /// Laeuft eine Aktion, bei der jemand am Zug ist?
  bool get isInteractive => const {
    GamePhase.bidding,
    GamePhase.chooseTrump,
    GamePhase.announceWeis,
    GamePhase.playing,
  }.contains(phase);

  GameState copyWith({
    int? rngState,
    List<Player>? players,
    List<Team>? teams,
    GamePhase? phase,
    int? roundNumber,
    int? dealer,
    int? currentPlayer,
    List<int>? biddingOrder,
    List<int>? biddingPassed,
    int? highestBid,
    int? highestBidder,
    Object? roundMode = unchanged,
    int? soloPlayer,
    int? chooserPlayer,
    int? forehandPlayer,
    bool? trumpWasPushed,
    List<TrickEntry>? trick,
    int? trickLeader,
    int? trickNumber,
    List<JassCard>? playedCards,
    List<List<JassCard>>? capturedCards,
    List<int>? capturedTricks,
    List<int>? capturedPileOwners,
    Object? firstCapturedTrick = unchanged,
    Object? lastCapturedPile = unchanged,
    List<CapturedTrick>? roundTricks,
    List<int>? teamWeisScores,
    List<List<Weis>>? teamWeisBreakdown,
    List<int>? teamStoeckPoints,
    int? stoeckPlayer,
    bool? stoeckAnnounced,
    Object? weisState = unchanged,
    Object? roundSummary = unchanged,
    List<RoundHistoryEntry>? roundHistory,
  }) => GameState(
    variant: variant,
    matchConfig: matchConfig,
    rules: rules,
    seed: seed,
    rngState: rngState ?? this.rngState,
    players: players ?? this.players,
    teams: teams ?? this.teams,
    phase: phase ?? this.phase,
    roundNumber: roundNumber ?? this.roundNumber,
    dealer: dealer ?? this.dealer,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    biddingOrder: biddingOrder ?? this.biddingOrder,
    biddingPassed: biddingPassed ?? this.biddingPassed,
    highestBid: highestBid ?? this.highestBid,
    highestBidder: highestBidder ?? this.highestBidder,
    roundMode: identical(roundMode, unchanged) ? this.roundMode : roundMode as RoundMode?,
    soloPlayer: soloPlayer ?? this.soloPlayer,
    chooserPlayer: chooserPlayer ?? this.chooserPlayer,
    forehandPlayer: forehandPlayer ?? this.forehandPlayer,
    trumpWasPushed: trumpWasPushed ?? this.trumpWasPushed,
    trick: trick ?? this.trick,
    trickLeader: trickLeader ?? this.trickLeader,
    trickNumber: trickNumber ?? this.trickNumber,
    playedCards: playedCards ?? this.playedCards,
    capturedCards: capturedCards ?? this.capturedCards,
    capturedTricks: capturedTricks ?? this.capturedTricks,
    capturedPileOwners: capturedPileOwners ?? this.capturedPileOwners,
    firstCapturedTrick: identical(firstCapturedTrick, unchanged)
        ? this.firstCapturedTrick
        : firstCapturedTrick as CapturedTrick?,
    lastCapturedPile: identical(lastCapturedPile, unchanged)
        ? this.lastCapturedPile
        : lastCapturedPile as int?,
    roundTricks: roundTricks ?? this.roundTricks,
    teamWeisScores: teamWeisScores ?? this.teamWeisScores,
    teamWeisBreakdown: teamWeisBreakdown ?? this.teamWeisBreakdown,
    teamStoeckPoints: teamStoeckPoints ?? this.teamStoeckPoints,
    stoeckPlayer: stoeckPlayer ?? this.stoeckPlayer,
    stoeckAnnounced: stoeckAnnounced ?? this.stoeckAnnounced,
    weisState: identical(weisState, unchanged) ? this.weisState : weisState as WeisState?,
    roundSummary: identical(roundSummary, unchanged)
        ? this.roundSummary
        : roundSummary as RoundSummary?,
    roundHistory: roundHistory ?? this.roundHistory,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'variant': variant.name,
    'matchConfig': matchConfig.toJson(),
    'rules': rules.toJson(),
    'seed': seed,
    'rngState': rngState,
    'players': [for (final player in players) player.toJson()],
    'teams': [for (final team in teams) team.toJson()],
    'phase': phase.name,
    'roundNumber': roundNumber,
    'dealer': dealer,
    'currentPlayer': currentPlayer,
    'biddingOrder': biddingOrder,
    'biddingPassed': biddingPassed,
    'highestBid': highestBid,
    'highestBidder': highestBidder,
    'roundMode': roundMode?.name,
    'soloPlayer': soloPlayer,
    'chooserPlayer': chooserPlayer,
    'forehandPlayer': forehandPlayer,
    'trumpWasPushed': trumpWasPushed,
    'trick': trickToJson(trick),
    'trickLeader': trickLeader,
    'trickNumber': trickNumber,
    'playedCards': cardsToJson(playedCards),
    'capturedCards': [for (final pile in capturedCards) cardsToJson(pile)],
    'capturedTricks': capturedTricks,
    'capturedPileOwners': capturedPileOwners,
    'firstCapturedTrick': firstCapturedTrick?.toJson(),
    'lastCapturedPile': lastCapturedPile,
    'roundTricks': [for (final trick in roundTricks) trick.toJson()],
    'teamWeisScores': teamWeisScores,
    'teamWeisBreakdown': [
      for (final team in teamWeisBreakdown) [for (final weis in team) weis.toJson()],
    ],
    'teamStoeckPoints': teamStoeckPoints,
    'stoeckPlayer': stoeckPlayer,
    'stoeckAnnounced': stoeckAnnounced,
    'weisState': weisState?.toJson(),
    'roundSummary': roundSummary?.toJson(),
    'roundHistory': [for (final entry in roundHistory) entry.toJson()],
  };
}
