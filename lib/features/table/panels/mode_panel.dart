import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../design/option_tile.dart';
import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../table_geometry.dart';
import '../widgets/playing_card_view.dart';
import 'panel_frame.dart';

/// Spielartwahl: Trumpffarben mit dem Puur als Symbol, dazu Obe-Abe, Une-Ufe,
/// Slalom und - fuer Vorhand im Schieber - Schieben.
class ModePanel extends StatelessWidget {
  const ModePanel({super.key, required this.game, required this.onAction});

  final GameState game;
  final void Function(GameAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final seat = game.currentPlayer;
    final canPush = canPushTrump(game);

    Widget icon(RoundMode mode) {
      final trump = mode.trumpSuit;
      if (trump != null) {
        return PlayingCardView(
          card: JassCard(trump, Rank.under),
          size: const Size(26, 26 * cardAspect),
        );
      }
      return Icon(switch (mode) {
        RoundMode.obeAbe => Icons.arrow_downward,
        RoundMode.uneUfe => Icons.arrow_upward,
        _ => Icons.swap_vert,
      }, color: colors.goldLight);
    }

    return PanelFrame(
      title: canPush ? texts.modePromptPush : texts.modePrompt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in game.allowedRoundModes)
                OptionTile(
                  title: texts.mode(mode),
                  leading: icon(mode),
                  trailing: game.usesRoundMultipliers && game.rules.multiplierFor(mode) > 1
                      ? Text(
                          texts.multiplier(game.rules.multiplierFor(mode)),
                          style: TextStyle(color: colors.goldLight, fontWeight: FontWeight.w700),
                        )
                      : null,
                  selected: false,
                  minWidth: 132,
                  onTap: () => onAction(ChooseMode(seat, mode)),
                ),
            ],
          ),
          if (canPush) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => onAction(PushTrump(seat)),
              child: Text(texts.pushButton),
            ),
          ],
        ],
      ),
    );
  }
}
