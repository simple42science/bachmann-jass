import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/debug_state.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../game/game_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// Debug-Menue: Seed anzeigen und setzen, Gegnerkarten aufdecken, KI spielt fuer mich.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final TextEditingController _seed = TextEditingController(text: '1');

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  void _start(GameVariant variant) {
    final settings = ref.read(settingsProvider);
    final texts = AppLocalizations.of(context);
    final name = settings.playerName.isEmpty ? texts.playerNameDefault : settings.playerName;
    ref
        .read(gameControllerProvider.notifier)
        .startNewGame(
          variant: variant,
          matchConfig: settings.matchConfigFor(variant),
          playerName: name,
          seats: settings.seatsFor(variant, name),
          rules: settings.rules,
          seed: int.tryParse(_seed.text.trim()) ?? 1,
        );
    context.go(Routes.table);
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final session = ref.watch(gameControllerProvider);
    final reveal = ref.watch(revealHandsProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go(session == null ? Routes.home : Routes.table),
        ),
        title: Text(texts.debugTitle),
      ),
      body: WoodBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(texts.debugCopy, style: JassFonts.ui(size: 13, color: colors.muted)),
                    const SizedBox(height: 16),
                    Text(
                      session == null
                          ? texts.debugNoGame
                          : texts.debugCurrentSeed(session.state.seed, session.state.roundNumber),
                      style: JassFonts.serif(size: 18, color: colors.brassGlow),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _seed,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: texts.debugSeedLabel),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: () => _start(GameVariant.schieber),
                          child: Text(texts.debugStartSchieber),
                        ),
                        FilledButton(
                          onPressed: () => _start(GameVariant.bieter),
                          child: Text(texts.debugStartBieter),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        texts.debugRevealHands,
                        style: JassFonts.ui(size: 15, weight: FontWeight.w700),
                      ),
                      value: reveal,
                      activeThumbColor: colors.brassGlow,
                      onChanged: (_) => ref.read(revealHandsProvider.notifier).toggle(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        texts.debugAiPlaysHuman,
                        style: JassFonts.ui(size: 15, weight: FontWeight.w700),
                      ),
                      value: controller.aiPlaysHuman,
                      activeThumbColor: colors.brassGlow,
                      onChanged: (value) => setState(() => controller.aiPlaysHuman = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
