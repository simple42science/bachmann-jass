import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../table_geometry.dart';
import '../widgets/playing_card_view.dart';

/// Welche Stiche laut Hausregel gezeigt werden.
List<CapturedTrick> reviewableTricks(GameState game) => switch (game.rules.trickReview) {
  TrickReview.none => const [],
  TrickReview.last => game.roundTricks.isEmpty ? const [] : [game.roundTricks.last],
  TrickReview.first => game.roundTricks.isEmpty ? const [] : [game.roundTricks.first],
  TrickReview.all => game.roundTricks,
};

Future<void> showTrickReview(BuildContext context, GameState game) {
  final texts = AppLocalizations.of(context);
  final colors = context.jass;
  final tricks = reviewableTricks(game);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(texts.trickReviewTitle(game.rules.trickReview.name)),
      content: SizedBox(
        width: 420,
        child: tricks.isEmpty
            ? Text(texts.trickReviewEmpty)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final trick in tricks) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(
                        texts.trickReviewWon(
                          game.roundTricks.indexOf(trick) + 1,
                          game.players[trick.winner].name,
                        ),
                        style: JassFonts.ui(
                          size: 13,
                          weight: FontWeight.w800,
                          color: colors.brassGlow,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final entry in trick.cards)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                PlayingCardView(
                                  card: entry.card,
                                  size: const Size(56, 56 * cardAspect),
                                  highlighted: entry.playerIndex == trick.winner,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  game.players[entry.playerIndex].name,
                                  style: JassFonts.ui(size: 11, color: colors.muted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(texts.close))],
    ),
  );
}
