import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'panel_frame.dart';

/// Gebot im Bieterjass: ein Tipp auf den Wert bietet, "Passen" passt.
class BidPanel extends StatelessWidget {
  const BidPanel({super.key, required this.game, required this.onAction});

  final GameState game;
  final void Function(GameAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final seat = game.currentPlayer;
    final values = game.rules.bidValues.where((value) => value > game.highestBid).toList();

    return PanelFrame(
      title: texts.bidPrompt,
      subtitle: game.highestBid > 0 ? texts.bidHighest(game.highestBid) : texts.bidNone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                FilledButton.tonal(
                  onPressed: () => onAction(PlaceBid(seat, value)),
                  child: Text('$value'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => onAction(PassBid(seat)), child: Text(texts.bidPass)),
        ],
      ),
    );
  }
}
