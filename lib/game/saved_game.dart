import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jass_engine/jass_engine.dart';

import '../app/bootstrap.dart';
import 'key_value_store.dart';

@immutable
final class SavedGame {
  const SavedGame({required this.savedAt, required this.state});

  final DateTime savedAt;
  final GameState state;
}

/// Speicherstand der laufenden Partie.
///
/// Gesichert wird nach jeder Aktion. Abgeschlossene Partien werden nicht
/// angeboten, und ein unlesbarer Stand (zum Beispiel aus einer aelteren
/// Version) wird verworfen statt die App zu blockieren.
final class SavedGameStore {
  const SavedGameStore(this._store);

  static const String key = 'bachmann-jass:game:v1';

  final KeyValueStore _store;

  Future<SavedGame?> load() async {
    final raw = await _store.read(key);
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final state = GameState.fromJson(json['game']! as Map<String, Object?>);
      if (state.phase == GamePhase.setup || state.phase == GamePhase.gameOver) {
        return null;
      }
      return SavedGame(
        savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt']! as int),
        state: state,
      );
    } on Object {
      return null;
    }
  }

  Future<void> save(SavedGame saved) => _store.write(
    key,
    jsonEncode({'savedAt': saved.savedAt.millisecondsSinceEpoch, 'game': saved.state.toJson()}),
  );

  Future<void> clear() => _store.remove(key);
}

class SavedGameController extends Notifier<SavedGame?> {
  @override
  SavedGame? build() => ref.watch(initialSavedGameProvider);

  void save(GameState gameState) {
    final saved = SavedGame(savedAt: DateTime.now(), state: gameState);
    state = saved;
    unawaited(SavedGameStore(ref.read(keyValueStoreProvider)).save(saved));
  }

  void clear() {
    state = null;
    unawaited(SavedGameStore(ref.read(keyValueStoreProvider)).clear());
  }
}

final savedGameProvider = NotifierProvider<SavedGameController, SavedGame?>(
  SavedGameController.new,
);
