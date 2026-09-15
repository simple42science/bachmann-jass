import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class BachmannJassApp extends ConsumerWidget {
  const BachmannJassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _LifecycleBridge(child: child!),
    );
  }
}

/// Haelt die Partie an, sobald die App in den Hintergrund geht, und laesst
/// sie beim Zurueckkommen weiterlaufen. So zieht kein Computer, waehrend
/// niemand zuschaut.
class _LifecycleBridge extends ConsumerStatefulWidget {
  const _LifecycleBridge({required this.child});

  final Widget child;

  @override
  ConsumerState<_LifecycleBridge> createState() => _LifecycleBridgeState();
}

class _LifecycleBridgeState extends ConsumerState<_LifecycleBridge> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onHide: () => ref.read(gameControllerProvider.notifier).pause(bySystem: true),
      onShow: () => ref.read(gameControllerProvider.notifier).resumeAfterSystemPause(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
