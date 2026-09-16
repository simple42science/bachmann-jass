import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../game/game_session.dart';
import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../motion.dart';
import '../table_geometry.dart';
import 'playing_card_view.dart';

/// Kurze Einblendung fuer besondere Ereignisse: Stöck, Match und die
/// gemeldeten Weise der Computer, deren Karten kurz aufgedeckt werden.
class EventToast extends StatelessWidget {
  const EventToast({
    super.key,
    required this.session,
    required this.geometry,
    required this.motion,
  });

  final GameSession session;
  final TableGeometry geometry;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final game = session.state;

    String? text;
    List<JassCard> cards = const [];
    for (final event in session.events) {
      switch (event) {
        case StoeckAnnounced(:final points):
          text = texts.toastStoeck(points);
        case WeisDeclared(:final playerIndex, :final weis)
            when weis != null && !game.players[playerIndex].isHuman:
          text = texts.toastWeis(game.players[playerIndex].name, texts.weis(weis));
          cards = weis.cards;
        case RoundScored(summary: SchieberRoundSummary(matchTeamId: final teamId))
            when teamId != null:
          text = texts.toastMatch(game.rules.matchBonus);
        default:
          break;
      }
    }
    if (text == null) {
      return const SizedBox.shrink();
    }

    final colors = context.jass;
    final cardWidth = (geometry.trickCardSize.width * 0.8).clamp(28.0, 56.0);
    Widget toast = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: geometry.center.width - 16),
      child: Material(
        color: colors.panel,
        elevation: 10,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.brass, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: JassFonts.serif(size: 19, weight: 700, color: colors.brassGlow)),
              if (cards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // Ein langer Weis (bis neun Karten) schrumpft, statt die
                  // Mitte des Tisches zu sprengen.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: PlayingCardView(
                              card: card,
                              size: Size(cardWidth, cardWidth * cardAspect),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (motion.enabled) {
      toast = toast
          .animate(key: ValueKey('toast-${session.revision}'))
          .fadeIn(duration: motion.ms(200))
          .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: motion.ms(260))
          .then(delay: motion.ms(cards.isEmpty ? 1400 : 2700))
          .fadeOut(duration: motion.ms(300));
    }
    return IgnorePointer(child: Center(child: toast));
  }
}
