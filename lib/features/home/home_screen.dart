import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/debug_state.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../game/game_controller.dart';
import '../../game/game_texts.dart';
import '../../game/saved_game.dart';
import '../../l10n/generated/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startNewGame(BuildContext context, WidgetRef ref) async {
    final texts = AppLocalizations.of(context);
    if (ref.read(savedGameProvider) != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(texts.discardSavedTitle),
          content: Text(texts.discardSavedBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(texts.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(texts.discardSavedConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    context.go(Routes.setup);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final saved = ref.watch(savedGameProvider);

    return Scaffold(
      body: WoodBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Messingschild mit dem Namen der App.
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: colors.brassGradient,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.brassGlow, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x99000000), blurRadius: 14, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            texts.homeKicker.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: JassFonts.ui(
                              size: 13,
                              weight: FontWeight.w800,
                              color: colors.ink,
                              letterSpacing: 6,
                            ),
                          ),
                          Text(
                            texts.homeTitle,
                            textAlign: TextAlign.center,
                            style: JassFonts.serif(
                              size: 76,
                              weight: 700,
                              color: colors.ink,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (saved != null) ...[
                      FilledButton(
                        onPressed: () {
                          if (ref.read(gameControllerProvider.notifier).resume()) {
                            context.go(Routes.table);
                          }
                        },
                        child: Text(texts.resumeGame),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        texts.resumeHint(
                          texts.variant(saved.state.variant),
                          saved.state.roundNumber,
                          ' – ${DateFormat('dd.MM.yyyy HH:mm').format(saved.savedAt)}',
                        ),
                        textAlign: TextAlign.center,
                        style: JassFonts.ui(size: 12, color: colors.muted),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _startNewGame(context, ref),
                        child: Text(texts.newGame),
                      ),
                    ] else
                      FilledButton(
                        onPressed: () => _startNewGame(context, ref),
                        child: Text(texts.newGame),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => context.go(Routes.rules),
                          child: Text(texts.menuRules),
                        ),
                        TextButton(
                          onPressed: () => context.go(Routes.settings),
                          child: Text(texts.menuSettings),
                        ),
                        TextButton(
                          onPressed: () => context.go(Routes.stats),
                          child: Text(texts.menuStats),
                        ),
                        if (debugMenuAvailable)
                          TextButton(
                            onPressed: () => context.go(Routes.debug),
                            child: Text(texts.menuDebug),
                          ),
                      ],
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
