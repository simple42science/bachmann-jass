import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jass_engine/jass_engine.dart';

import '../game/key_value_store.dart';
import 'bootstrap.dart';

/// Tempo der Computerzuege; der Faktor skaliert alle Wartezeiten.
enum GameSpeed {
  langsam(1.5),
  normal(1.0),
  schnell(0.45);

  const GameSpeed(this.factor);

  final double factor;

  GameSpeed get next => values[(index + 1) % values.length];
}

/// Zielscores, die im Schieber zur Wahl stehen.
const List<int> schieberTargetScores = [1000, 2500];

@immutable
final class AppSettings {
  const AppSettings({
    this.playerName = '',
    this.variant = GameVariant.bieter,
    this.schieberTargetScore = 1000,
    this.bieterScoring = BieterScoring.einfach,
    this.difficulty = Difficulty.normal,
    this.speed = GameSpeed.normal,
  });

  /// Liest tolerant: unbekannte oder fehlende Werte fallen auf den Standard zurueck.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.cast<T?>().firstWhere((value) => value?.name == raw, orElse: () => null) ?? fallback;
    final target = json['schieberTargetScore'];
    return AppSettings(
      playerName: json['playerName'] is String ? json['playerName']! as String : '',
      variant: pick(GameVariant.values, json['variant'], GameVariant.bieter),
      schieberTargetScore: target is int && schieberTargetScores.contains(target) ? target : 1000,
      bieterScoring: pick(BieterScoring.values, json['bieterScoring'], BieterScoring.einfach),
      difficulty: pick(Difficulty.values, json['difficulty'], Difficulty.normal),
      speed: pick(GameSpeed.values, json['speed'], GameSpeed.normal),
    );
  }

  static const AppSettings defaults = AppSettings();

  final String playerName;
  final GameVariant variant;
  final int schieberTargetScore;
  final BieterScoring bieterScoring;
  final Difficulty difficulty;
  final GameSpeed speed;

  MatchConfig matchConfigFor(GameVariant variant) => switch (variant) {
    GameVariant.schieber => MatchConfig(targetScore: schieberTargetScore, difficulty: difficulty),
    GameVariant.bieter => MatchConfig(
      targetScore: GameVariant.bieter.defaultTargetScore,
      difficulty: difficulty,
      bieterScoring: bieterScoring,
    ),
  };

  AppSettings copyWith({
    String? playerName,
    GameVariant? variant,
    int? schieberTargetScore,
    BieterScoring? bieterScoring,
    Difficulty? difficulty,
    GameSpeed? speed,
  }) => AppSettings(
    playerName: playerName ?? this.playerName,
    variant: variant ?? this.variant,
    schieberTargetScore: schieberTargetScore ?? this.schieberTargetScore,
    bieterScoring: bieterScoring ?? this.bieterScoring,
    difficulty: difficulty ?? this.difficulty,
    speed: speed ?? this.speed,
  );

  Map<String, Object?> toJson() => {
    'playerName': playerName,
    'variant': variant.name,
    'schieberTargetScore': schieberTargetScore,
    'bieterScoring': bieterScoring.name,
    'difficulty': difficulty.name,
    'speed': speed.name,
  };
}

final class SettingsStore {
  const SettingsStore(this._store);

  static const String key = 'bachmann-jass:settings:v1';

  final KeyValueStore _store;

  Future<AppSettings> load() async {
    final raw = await _store.read(key);
    if (raw == null) {
      return AppSettings.defaults;
    }
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return AppSettings.defaults;
    } on TypeError {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) => _store.write(key, jsonEncode(settings.toJson()));
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  void update(AppSettings settings) {
    state = settings;
    unawaited(SettingsStore(ref.read(keyValueStoreProvider)).save(settings));
  }

  void setSpeed(GameSpeed speed) => update(state.copyWith(speed: speed));
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
