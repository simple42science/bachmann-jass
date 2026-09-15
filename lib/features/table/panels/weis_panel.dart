import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'panel_frame.dart';

/// Weisrunde: zeigt die eigenen Weise; gemeldet wird der hoechste.
class WeisPanel extends StatelessWidget {
  const WeisPanel({super.key, required this.game, required this.onAction});

  final GameState game;
  final void Function(GameAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final seat = game.currentPlayer;
    final options = game.weisState?.possibleByPlayer[seat] ?? const <Weis>[];
    final ownStoeck = game.stoeckPlayer == seat;

    final String title;
    if (options.isEmpty) {
      title = ownStoeck ? texts.weisNoneButStoeck : texts.weisNone;
    } else {
      title = options.length == 1 ? texts.weisPromptOne : texts.weisPromptMany;
    }

    return PanelFrame(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < options.length; index += 1)
            _WeisRow(
              points: options[index].points,
              name: texts.weis(options[index]),
              meta: [
                options[index].type == WeisType.sequence
                    ? texts.weisTypeSequence
                    : texts.weisTypeFourOfKind,
                if (index == 0) texts.weisWillBeDeclared,
              ].join(' · '),
              primary: index == 0,
            ),
          if (ownStoeck)
            _WeisRow(
              points: game.rules.stoeckPoints,
              name: texts.stoeckTitle,
              meta: texts.stoeckMeta,
              primary: false,
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => onAction(DeclareWeis(seat)),
            child: Text(options.isEmpty ? texts.weisContinue : texts.weisConfirm),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => onAction(DeclineWeis(seat)),
              child: Text(texts.weisSkip, style: TextStyle(color: colors.muted)),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeisRow extends StatelessWidget {
  const _WeisRow({
    required this.points,
    required this.name,
    required this.meta,
    required this.primary,
  });

  final int points;
  final String name;
  final String meta;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primary ? colors.brass.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary ? colors.brass : colors.border),
      ),
      child: Row(
        children: [
          Text(
            '$points',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.brassGlow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
                ),
                Text(meta, style: TextStyle(fontSize: 11, color: colors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
