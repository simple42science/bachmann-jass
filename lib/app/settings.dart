import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jass_engine/jass_engine.dart';

import '../game/key_value_store.dart';
import 'bootstrap.dart';

/// Tempo-Vorgaben; der Faktor skaliert alle Wartezeiten der Computer.
enum GameSpeed {
  langsam(1.5),
  normal(1.0),
  schnell(0.45);

  const GameSpeed(this.factor);

  final double factor;

  GameSpeed get next => values[(index + 1) % values.length];

  /// Die Vorgabe, die dem Faktor am naechsten liegt.
  static GameSpeed nearest(double factor) =>
      values.reduce((a, b) => (a.factor - factor).abs() <= (b.factor - factor).abs() ? a : b);
}

/// Zielscores, die im Schieber zur Wahl stehen.
const List<int> schieberTargetScores = [1000, 2500];

/// Grenzen des stufenlosen Tempos.
const double minSpeedFactor = 0.3;
const double maxSpeedFactor = 2.0;

@immutable
final class AppSettings {
  const AppSettings({
    this.playerName = '',
    this.variant = GameVariant.bieter,
    this.schieberTargetScore = 1000,
    this.bieterScoring = BieterScoring.einfach,
    this.difficulty = Difficulty.normal,
    this.speedFactor = 1.0,
    this.autoPlaySingleCard = false,
    this.confirmPlay = false,
    this.allowUndo = true,
    this.opponentNames = defaultOpponentNames,
    this.opponentDifficulties = const [null, null, null],
    this.rules = RuleSet.bachmann,
  });

  /// Liest tolerant: unbekannte oder fehlende Werte fallen auf den Standard zurueck.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.cast<T?>().firstWhere((value) => value?.name == raw, orElse: () => null) ?? fallback;
    final target = json['schieberTargetScore'];
    final rawFactor = json['speedFactor'];
    // Aeltere Staende kennen nur die Vorgabe "speed".
    final factor = rawFactor is num
        ? rawFactor.toDouble()
        : pick(GameSpeed.values, json['speed'], GameSpeed.normal).factor;
    final names = json['opponentNames'];
    final difficulties = json['opponentDifficulties'];
    RuleSet rules = RuleSet.bachmann;
    if (json['rules'] is Map<String, Object?>) {
      try {
        rules = RuleSet.fromJson(json['rules']! as Map<String, Object?>);
      } on Object {
        rules = RuleSet.bachmann;
      }
    }
    return AppSettings(
      playerName: json['playerName'] is String ? json['playerName']! as String : '',
      variant: pick(GameVariant.values, json['variant'], GameVariant.bieter),
      schieberTargetScore: target is int && schieberTargetScores.contains(target) ? target : 1000,
      bieterScoring: pick(BieterScoring.values, json['bieterScoring'], BieterScoring.einfach),
      difficulty: pick(Difficulty.values, json['difficulty'], Difficulty.normal),
      speedFactor: factor.clamp(minSpeedFactor, maxSpeedFactor),
      autoPlaySingleCard: json['autoPlaySingleCard'] as bool? ?? false,
      confirmPlay: json['confirmPlay'] as bool? ?? false,
      allowUndo: json['allowUndo'] as bool? ?? true,
      opponentNames: names is List && names.length == 3 && names.every((n) => n is String)
          ? [for (final name in names) name as String]
          : defaultOpponentNames,
      opponentDifficulties: difficulties is List && difficulties.length == 3
          ? [
              for (final raw in difficulties)
                Difficulty.values.cast<Difficulty?>().firstWhere(
                  (value) => value?.name == raw,
                  orElse: () => null,
                ),
            ]
          : const [null, null, null],
      rules: rules,
    );
  }

  static const AppSettings defaults = AppSettings();

  final String playerName;
  final GameVariant variant;
  final int schieberTargetScore;
  final BieterScoring bieterScoring;
  final Difficulty difficulty;

  /// Stufenloses Tempo; 1.0 entspricht den Wartezeiten der Web-App.
  final double speedFactor;

  /// Die einzige erlaubte Karte wird ohne Tippen gespielt.
  final bool autoPlaySingleCard;

  /// Eine Karte wird erst beim zweiten Tippen gespielt.
  final bool confirmPlay;

  /// Der letzte eigene Zug darf zurueckgenommen werden.
  final bool allowUndo;

  /// Namen der Computergegner auf den Sitzen 1 bis 3 (links, gegenueber, rechts).
  final List<String> opponentNames;

  /// Eigene Stufe je Computergegner; `null` = Stufe der Partie.
  final List<Difficulty?> opponentDifficulties;

  /// Hausregeln fuer neue Partien.
  final RuleSet rules;

  GameSpeed get speed => GameSpeed.nearest(speedFactor);

  MatchConfig matchConfigFor(GameVariant variant) => switch (variant) {
    GameVariant.schieber => MatchConfig(targetScore: schieberTargetScore, difficulty: difficulty),
    GameVariant.bieter => MatchConfig(
      targetScore: GameVariant.bieter.defaultTargetScore,
      difficulty: difficulty,
      bieterScoring: bieterScoring,
    ),
  };

  /// Sitzplaetze fuer eine neue Partie: der Mensch auf Sitz 0, dann die Gegner.
  List<SeatSetup> seatsFor(GameVariant variant, String humanName) => [
    SeatSetup(name: humanName, isHuman: true),
    for (var index = 0; index < variant.playerCount - 1; index += 1)
      SeatSetup(
        name: opponentNames[index].trim().isEmpty
            ? defaultOpponentNames[index]
            : opponentNames[index],
        isHuman: false,
        difficulty: opponentDifficulties[index],
      ),
  ];

  AppSettings copyWith({
    String? playerName,
    GameVariant? variant,
    int? schieberTargetScore,
    BieterScoring? bieterScoring,
    Difficulty? difficulty,
    double? speedFactor,
    bool? autoPlaySingleCard,
    bool? confirmPlay,
    bool? allowUndo,
    List<String>? opponentNames,
    List<Difficulty?>? opponentDifficulties,
    RuleSet? rules,
  }) => AppSettings(
    playerName: playerName ?? this.playerName,
    variant: variant ?? this.variant,
    schieberTargetScore: schieberTargetScore ?? this.schieberTargetScore,
    bieterScoring: bieterScoring ?? this.bieterScoring,
    difficulty: difficulty ?? this.difficulty,
    speedFactor: (speedFactor ?? this.speedFactor).clamp(minSpeedFactor, maxSpeedFactor),
    autoPlaySingleCard: autoPlaySingleCard ?? this.autoPlaySingleCard,
    confirmPlay: confirmPlay ?? this.confirmPlay,
    allowUndo: allowUndo ?? this.allowUndo,
    opponentNames: opponentNames ?? this.opponentNames,
    opponentDifficulties: opponentDifficulties ?? this.opponentDifficulties,
    rules: rules ?? this.rules,
  );

  Map<String, Object?> toJson() => {
    'playerName': playerName,
    'variant': variant.name,
    'schieberTargetScore': schieberTargetScore,
    'bieterScoring': bieterScoring.name,
    'difficulty': difficulty.name,
    'speedFactor': speedFactor,
    'autoPlaySingleCard': autoPlaySingleCard,
    'confirmPlay': confirmPlay,
    'allowUndo': allowUndo,
    'opponentNames': opponentNames,
    'opponentDifficulties': [for (final level in opponentDifficulties) level?.name],
    'rules': rules.toJson(),
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

  void setSpeed(GameSpeed speed) => update(state.copyWith(speedFactor: speed.factor));

  void setSpeedFactor(double factor) => update(state.copyWith(speedFactor: factor));

  void setRules(RuleSet rules) => update(state.copyWith(rules: rules));
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
