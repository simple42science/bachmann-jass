import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/debug/debug_screen.dart';
import '../features/home/home_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/scoreboard/scoreboard_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/table/table_screen.dart';
import '../game/game_controller.dart';
import 'debug_state.dart';

abstract final class Routes {
  static const String home = '/';
  static const String setup = '/setup';
  static const String table = '/table';
  static const String scoreboard = '/table/scoreboard';
  static const String rules = '/rules';
  static const String settings = '/settings';
  static const String stats = '/stats';
  static const String debug = '/debug';
}

/// Erste Seite nach dem Start; der Demo-Start setzt sie auf den Tisch.
final initialLocationProvider = Provider<String>((ref) => Routes.home);

final routerProvider = Provider<GoRouter>((ref) {
  // Nach einem Neuladen im Browser liegt keine Partie am Tisch:
  // der Homescreen bietet dann "Partie fortsetzen" an.
  String? requireGame(Object context, GoRouterState state) =>
      ref.read(gameControllerProvider) == null ? Routes.home : null;

  return GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: Routes.setup, builder: (context, state) => const SetupScreen()),
      GoRoute(path: Routes.rules, builder: (context, state) => const RulesScreen()),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: Routes.stats, builder: (context, state) => const StatsScreen()),
      GoRoute(
        path: Routes.debug,
        builder: (context, state) => const DebugScreen(),
        redirect: (context, state) => debugMenuAvailable ? null : Routes.home,
      ),
      GoRoute(
        path: Routes.table,
        builder: (context, state) => const TableScreen(),
        redirect: requireGame,
        routes: [
          GoRoute(
            path: 'scoreboard',
            builder: (context, state) => const ScoreboardScreen(),
            redirect: requireGame,
          ),
        ],
      ),
    ],
  );
});
