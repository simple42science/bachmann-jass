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
  const ModePanel({super.key, required this.game, required this.onAction, this.compact = false});

  final GameState game;
  final void Function(GameAction action) onAction;

  /// Wenig Hoehe (Handy quer): Schieben steht als Kachel in der Reihe.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final seat = game.currentPlayer;
    final canPush = canPushTrump(game);

    final iconWidth = compact ? 18.0 : 26.0;
    Widget icon(RoundMode mode) {
      final trump = mode.trumpSuit;
      if (trump != null) {
        return PlayingCardView(
          card: JassCard(trump, Rank.under),
          size: Size(iconWidth, iconWidth * cardAspect),
        );
      }
      return Icon(switch (mode) {
        RoundMode.obeAbe => Icons.arrow_downward,
        RoundMode.uneUfe => Icons.arrow_upward,
        RoundMode.slalom => Icons.south,
        _ => Icons.north,
      }, color: colors.brassGlow);
    }

    // Beim Slalom gehoert die Richtung zur Ansage.
    String title(RoundMode mode) => switch (mode) {
      RoundMode.slalom => texts.modeSlalomFromTop,
      RoundMode.slalomUneUfe => texts.modeSlalomFromBottom,
      _ => texts.mode(mode),
    };

    // Breit genug fuer vier Kacheln nebeneinander, damit alle acht Spielarten
    // ohne Scrollen sichtbar sind.
    return PanelFrame(
      title: canPush ? texts.modePromptPush : texts.modePrompt,
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: compact ? 6 : 8,
            children: [
              for (final mode in game.allowedRoundModes)
                OptionTile(
                  title: title(mode),
                  leading: icon(mode),
                  trailing: game.usesRoundMultipliers && game.rules.multiplierFor(mode) > 1
                      ? Text(
                          texts.multiplier(game.rules.multiplierFor(mode)),
                          style: TextStyle(color: colors.brassGlow, fontWeight: FontWeight.w700),
                        )
                      : null,
                  selected: false,
                  minWidth: compact ? 100 : 124,
                  dense: compact,
                  onTap: () => onAction(ChooseMode(seat, mode)),
                ),
              if (canPush && compact)
                OptionTile(
                  title: texts.pushButton,
                  leading: Icon(Icons.redo, color: colors.brassGlow),
                  selected: false,
                  minWidth: 100,
                  dense: true,
                  onTap: () => onAction(PushTrump(seat)),
                ),
            ],
          ),
          if (canPush && !compact) ...[
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
