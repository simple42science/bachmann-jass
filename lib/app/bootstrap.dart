import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../game/key_value_store.dart';
import '../game/saved_game.dart';
import '../game/stats.dart';
import 'settings.dart';

/// Vor dem ersten Frame geladene Werte. `main` und die Tests ueberschreiben sie.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider wird beim Start ueberschrieben'),
);

final initialSettingsProvider = Provider<AppSettings>((ref) => AppSettings.defaults);

final initialSavedGameProvider = Provider<SavedGame?>((ref) => null);

final initialStatsProvider = Provider<GameStats>((ref) => GameStats.empty);

/// Liest Einstellungen, Speicherstand und Statistik und liefert die Overrides
/// fuer den ProviderScope.
Future<List<Override>> bootstrap(KeyValueStore store) async {
  final settings = await SettingsStore(store).load();
  final saved = await SavedGameStore(store).load();
  final stats = await StatsStore(store).load();
  return [
    keyValueStoreProvider.overrideWithValue(store),
    initialSettingsProvider.overrideWithValue(settings),
    initialSavedGameProvider.overrideWithValue(saved),
    initialStatsProvider.overrideWithValue(stats),
  ];
}
