import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/demo.dart';
import 'app/router.dart';
import 'game/game_controller.dart';
import 'game/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await bootstrap(SharedPreferencesStore(SharedPreferencesAsync()));

  final demo = DemoRequest.fromUri(Uri.base);
  final container = ProviderContainer(
    overrides: [
      ...overrides,
      if (demo != null) ...[
        aiDelayProvider.overrideWithValue((kind, speed, random) => Duration.zero),
        initialLocationProvider.overrideWithValue(switch (demo.screen) {
          'scoreboard' => Routes.scoreboard,
          'rules' => Routes.rules,
          'settings' => Routes.settings,
          'stats' => Routes.stats,
          _ => Routes.table,
        }),
      ],
    ],
  );
  if (demo != null) {
    await runDemo(container, demo);
  }

  runApp(UncontrolledProviderScope(container: container, child: const BachmannJassApp()));
}
