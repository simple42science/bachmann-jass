import 'package:bachmann_jass/app/app.dart';
import 'package:bachmann_jass/app/bootstrap.dart';
import 'package:bachmann_jass/app/settings.dart';
import 'package:bachmann_jass/game/game_controller.dart';
import 'package:bachmann_jass/game/key_value_store.dart';
import 'package:bachmann_jass/game/saved_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Overrides fuer Tests: Speicher im Arbeitsspeicher, keine Wartezeit vor Computerzuegen.
List<Override> testOverrides({
  MemoryKeyValueStore? store,
  AppSettings settings = AppSettings.defaults,
  SavedGame? saved,
  bool instantAi = true,
}) => [
  keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
  initialSettingsProvider.overrideWithValue(settings),
  initialSavedGameProvider.overrideWithValue(saved),
  if (instantAi) aiDelayProvider.overrideWithValue((kind, speed, random) => Duration.zero),
];

/// Startet die App mit Test-Overrides und liefert den Container fuer Zugriffe.
Future<ProviderContainer> pumpApp(WidgetTester tester, {List<Override>? overrides}) async {
  final container = ProviderContainer(overrides: overrides ?? testOverrides());
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const BachmannJassApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Setzt die logische Bildschirmgroesse fuer einen Test.
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
