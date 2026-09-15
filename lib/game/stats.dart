import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jass_engine/jass_engine.dart';

import '../app/bootstrap.dart';
import 'key_value_store.dart';

/// Partien und Siege je Jassart und Stufe.
@immutable
final class VariantStats {
  const VariantStats({this.played = 0, this.won = 0});

  factory VariantStats.fromJson(Map<String, Object?> json) =>
      VariantStats(played: json['played'] as int? ?? 0, won: json['won'] as int? ?? 0);

  final int played;
  final int won;

  Map<String, Object?> toJson() => {'played': played, 'won': won};
}

/// Alles bleibt lokal auf dem Geraet.
@immutable
final class GameStats {
  const GameStats({
    this.byVariant = const {},
    this.roundsPlayed = 0,
    this.bidsAttempted = 0,
    this.bidsMade = 0,
    this.highestWeis = 0,
    this.matches = 0,
    this.stoeck = 0,
  });

  factory GameStats.fromJson(Map<String, Object?> json) => GameStats(
    byVariant: {
      for (final entry in (json['byVariant'] as Map<String, Object?>? ?? const {}).entries)
        entry.key: VariantStats.fromJson(entry.value! as Map<String, Object?>),
    },
    roundsPlayed: json['roundsPlayed'] as int? ?? 0,
    bidsAttempted: json['bidsAttempted'] as int? ?? 0,
    bidsMade: json['bidsMade'] as int? ?? 0,
    highestWeis: json['highestWeis'] as int? ?? 0,
    matches: json['matches'] as int? ?? 0,
    stoeck: json['stoeck'] as int? ?? 0,
  );

  static const GameStats empty = GameStats();

  /// Schluessel `variant:difficulty`, zum Beispiel `schieber:normal`.
  final Map<String, VariantStats> byVariant;
  final int roundsPlayed;

  /// Gebote des Menschen im Bieterjass.
  final int bidsAttempted;
  final int bidsMade;
  final int highestWeis;

  /// Matchs des eigenen Teams.
  final int matches;

  /// Eigene Stöck-Ansagen.
  final int stoeck;

  int get gamesPlayed => byVariant.values.fold(0, (sum, stats) => sum + stats.played);

  int get gamesWon => byVariant.values.fold(0, (sum, stats) => sum + stats.won);

  static String keyFor(GameState game) =>
      '${game.variant.name}:${game.matchConfig.difficulty.name}';

  /// Verbucht die Ereignisse einer Aktion aus Sicht des Menschen (Sitz 0).
  GameStats record(GameState game, List<GameEvent> events) {
    var next = this;
    for (final event in events) {
      switch (event) {
        case RoundScored(summary: final BieterRoundSummary summary):
          next = next.copyWith(
            roundsPlayed: next.roundsPlayed + 1,
            bidsAttempted: next.bidsAttempted + (summary.soloPlayer == 0 ? 1 : 0),
            bidsMade: next.bidsMade + (summary.soloPlayer == 0 && summary.succeeded ? 1 : 0),
          );
        case RoundScored(summary: final SchieberRoundSummary summary):
          final ownTeam = game.players[0].teamId;
          next = next.copyWith(
            roundsPlayed: next.roundsPlayed + 1,
            matches: next.matches + (summary.matchTeamId == ownTeam ? 1 : 0),
          );
        case WeisAwarded(:final teamId, :final points) when teamId == game.players[0].teamId:
          next = next.copyWith(highestWeis: math.max(next.highestWeis, points));
        case StoeckAnnounced(:final playerIndex) when playerIndex == 0:
          next = next.copyWith(stoeck: next.stoeck + 1);
        case GameOver(:final winnerPlayer, :final winnerTeam):
          final won = game.isSchieber ? winnerTeam == game.players[0].teamId : winnerPlayer == 0;
          final key = keyFor(game);
          final current = next.byVariant[key] ?? const VariantStats();
          next = next.copyWith(
            byVariant: {
              ...next.byVariant,
              key: VariantStats(played: current.played + 1, won: current.won + (won ? 1 : 0)),
            },
          );
        default:
          break;
      }
    }
    return next;
  }

  GameStats copyWith({
    Map<String, VariantStats>? byVariant,
    int? roundsPlayed,
    int? bidsAttempted,
    int? bidsMade,
    int? highestWeis,
    int? matches,
    int? stoeck,
  }) => GameStats(
    byVariant: byVariant ?? this.byVariant,
    roundsPlayed: roundsPlayed ?? this.roundsPlayed,
    bidsAttempted: bidsAttempted ?? this.bidsAttempted,
    bidsMade: bidsMade ?? this.bidsMade,
    highestWeis: highestWeis ?? this.highestWeis,
    matches: matches ?? this.matches,
    stoeck: stoeck ?? this.stoeck,
  );

  Map<String, Object?> toJson() => {
    'byVariant': {for (final entry in byVariant.entries) entry.key: entry.value.toJson()},
    'roundsPlayed': roundsPlayed,
    'bidsAttempted': bidsAttempted,
    'bidsMade': bidsMade,
    'highestWeis': highestWeis,
    'matches': matches,
    'stoeck': stoeck,
  };
}

final class StatsStore {
  const StatsStore(this._store);

  static const String key = 'bachmann-jass:stats:v1';

  final KeyValueStore _store;

  Future<GameStats> load() async {
    final raw = await _store.read(key);
    if (raw == null) {
      return GameStats.empty;
    }
    try {
      return GameStats.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return GameStats.empty;
    }
  }

  Future<void> save(GameStats stats) => _store.write(key, jsonEncode(stats.toJson()));

  Future<void> clear() => _store.remove(key);
}

class StatsController extends Notifier<GameStats> {
  @override
  GameStats build() => ref.watch(initialStatsProvider);

  void record(GameState game, List<GameEvent> events) {
    final next = state.record(game, events);
    if (identical(next, state)) {
      return;
    }
    state = next;
    unawaited(StatsStore(ref.read(keyValueStoreProvider)).save(next));
  }

  void reset() {
    state = GameStats.empty;
    unawaited(StatsStore(ref.read(keyValueStoreProvider)).clear());
  }
}

final statsProvider = NotifierProvider<StatsController, GameStats>(StatsController.new);
