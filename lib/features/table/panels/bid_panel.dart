import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'panel_frame.dart';

/// Steigern zu Beginn des Bieterjass: das Gebot laesst sich in Zehner- und
/// Fuenfzigerschritten hochsetzen, "Bieten" bietet, "Passen" steigt aus.
class BidPanel extends StatefulWidget {
  const BidPanel({super.key, required this.game, required this.onAction});

  final GameState game;
  final void Function(GameAction action) onAction;

  @override
  State<BidPanel> createState() => _BidPanelState();
}

class _BidPanelState extends State<BidPanel> {
  late int _offer = minimumBid(widget.game);

  @override
  void didUpdateWidget(BidPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nach fremden Geboten wieder beim kleinsten erlaubten Wert beginnen.
    if (oldWidget.game.highestBid != widget.game.highestBid) {
      _offer = minimumBid(widget.game);
    }
  }

  void _raise(int delta) {
    setState(() => _offer = (_offer + delta).clamp(minimumBid(widget.game), maxBid));
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final game = widget.game;
    final seat = game.currentPlayer;
    final minimum = minimumBid(game);

    return PanelFrame(
      title: texts.bidPrompt,
      subtitle: game.highestBid > 0
          ? texts.bidHighestBy(game.players[game.highestBidder].name, game.highestBid)
          : texts.bidStart(game.matchConfig.bieterStartBid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Auf schmalen Handys schrumpft die Zeile, statt ueberzulaufen.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  key: const Key('bid-minus'),
                  tooltip: '-$bidStep',
                  onPressed: _offer - bidStep >= minimum ? () => _raise(-bidStep) : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 10),
                Text(
                  '$_offer',
                  style: JassFonts.serif(size: 34, weight: 700, color: colors.brassGlow),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  key: const Key('bid-plus'),
                  tooltip: '+$bidStep',
                  onPressed: () => _raise(bidStep),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  key: const Key('bid-plus-big'),
                  onPressed: () => _raise(5 * bidStep),
                  child: Text('+${5 * bidStep}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('bid-offer'),
            onPressed: () => widget.onAction(PlaceBid(seat, _offer)),
            child: Text(texts.bidOffer(_offer)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => widget.onAction(PassBid(seat)),
            child: Text(texts.bidPass),
          ),
        ],
      ),
    );
  }
}
