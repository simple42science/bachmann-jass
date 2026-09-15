import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'panel_frame.dart';

/// Abrechnung am Rundenende mit Knopf fuer die naechste Runde.
class RoundEndPanel extends StatelessWidget {
  const RoundEndPanel({super.key, required this.game, required this.onNextRound});

  final GameState game;
  final VoidCallback onNextRound;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    return PanelFrame(
      title: texts.roundEndTitle(game.roundNumber),
      subtitle: texts.phaseMessage(game),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in texts.roundSummaryLines(game))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: TextStyle(fontSize: 13, color: colors.text)),
            ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onNextRound, child: Text(texts.nextRound)),
        ],
      ),
    );
  }
}

/// Rangliste am Spielende.
class GameOverPanel extends StatelessWidget {
  const GameOverPanel({super.key, required this.game, required this.onHome});

  final GameState game;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    return PanelFrame(
      title: texts.gameOverTitle,
      subtitle: texts.phaseMessage(game),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in texts.rankingLines(game))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: TextStyle(fontSize: 14, color: colors.text)),
            ),
          const SizedBox(height: 10),
          FilledButton(onPressed: onHome, child: Text(texts.toHome)),
        ],
      ),
    );
  }
}
