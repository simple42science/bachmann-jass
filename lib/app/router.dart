import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/table/table_screen.dart';
import '../game/game_controller.dart';

abstract final class Routes {
  static const String home = '/';
  static const String setup = '/setup';
  static const String table = '/table';
}

/// Erste Seite nach dem Start; der Demo-Start setzt sie auf den Tisch.
final initialLocationProvider = Provider<String>((ref) => Routes.home);

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: Routes.setup, builder: (context, state) => const SetupScreen()),
      GoRoute(
        path: Routes.table,
        builder: (context, state) => const TableScreen(),
        // Nach einem Neuladen im Browser liegt keine Partie am Tisch:
        // der Homescreen bietet dann "Partie fortsetzen" an.
        redirect: (context, state) => ref.read(gameControllerProvider) == null ? Routes.home : null,
      ),
    ],
  ),
);
