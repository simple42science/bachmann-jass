import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../motion.dart';
import '../table_geometry.dart';
import 'playing_card_view.dart';

/// Verzoegerung beim Austeilen: in 3er-Paketen, wie am echten Tisch.
Duration dealDelay(Motion motion, int index) => motion.ms((index ~/ 3) * 130 + (index % 3) * 45);

/// Die eigene Hand: aufgedeckt, gefaechert, spielbare Karten leicht angehoben.
///
/// Beim Austeilen gleiten die Karten von oben herein; danach ruecken sie mit
/// jeder gespielten Karte weich zusammen.
class HumanHandView extends StatelessWidget {
  const HumanHandView({
    super.key,
    required this.geometry,
    required this.hand,
    required this.playable,
    required this.interactive,
    required this.motion,
    required this.roundNumber,
    required this.onTap,
    this.selected,
    this.highlighted,
  });

  final TableGeometry geometry;
  final List<JassCard> hand;

  /// Beim Bestaetigen zuerst angetippte Karte; steht hoeher.
  final JassCard? selected;

  /// Vom Tipp empfohlene Karte; bekommt einen Messingrand.
  final JassCard? highlighted;

  /// Karten, die gerade gespielt werden duerfen (leer, wenn nicht am Zug).
  final Set<JassCard> playable;

  /// Der Mensch ist am Zug; nicht spielbare Karten werden abgedunkelt.
  final bool interactive;
  final Motion motion;

  /// Neue Runde = neues Austeilen.
  final int roundNumber;
  final void Function(JassCard card) onTap;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final cardSize = geometry.cardSize;
    final total = geometry.handWidth(hand.length);
    final left = (geometry.size.width - total) / 2;
    final lift = cardSize.height * 0.12;

    return SizedBox(
      width: geometry.size.width,
      height: geometry.handHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < hand.length; index += 1)
            AnimatedPositioned(
              key: ValueKey('hand-${hand[index].id}'),
              duration: motion.ms(260),
              curve: Curves.easeOutCubic,
              left: left + index * geometry.handStep,
              top: hand[index] == selected
                  ? -lift
                  : playable.contains(hand[index])
                  ? 0
                  : lift,
              child: _dealIn(
                index,
                _HandCard(
                  card: hand[index],
                  size: cardSize,
                  fan: fanTransform(index, hand.length),
                  isPlayable: playable.contains(hand[index]),
                  dimmed: interactive && !playable.contains(hand[index]),
                  highlighted: hand[index] == highlighted || hand[index] == selected,
                  label: playable.contains(hand[index])
                      ? texts.cardPlayLabel(texts.card(hand[index]))
                      : texts.cardNotPlayableLabel(texts.card(hand[index])),
                  onTap: () => onTap(hand[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dealIn(int index, Widget child) {
    if (!motion.enabled) {
      return child;
    }
    return child
        .animate(
          key: ValueKey('deal-$roundNumber-${hand[index].id}'),
          delay: dealDelay(motion, index),
        )
        .fadeIn(duration: motion.ms(220))
        .move(
          begin: Offset(0, -geometry.cardSize.height * 1.4),
          end: Offset.zero,
          duration: motion.ms(420),
          curve: Curves.easeOutCubic,
        );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    required this.card,
    required this.size,
    required this.fan,
    required this.isPlayable,
    required this.dimmed,
    required this.highlighted,
    required this.label,
    required this.onTap,
  });

  final JassCard card;
  final Size size;
  final ({double angle, double drop}) fan;
  final bool isPlayable;
  final bool dimmed;
  final bool highlighted;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isPlayable,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
          offset: Offset(0, fan.drop),
          child: Transform.rotate(
            angle: fan.angle,
            alignment: Alignment.bottomCenter,
            child: PlayingCardView(
              card: card,
              size: size,
              dimmed: dimmed,
              highlighted: highlighted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Verdeckte Hand eines Computers als kleiner Faecher; an den Seiten gedreht.
class HiddenHandView extends StatelessWidget {
  const HiddenHandView({
    super.key,
    required this.geometry,
    required this.count,
    required this.quarterTurns,
    required this.motion,
    required this.roundNumber,
    this.revealed,
  });

  final TableGeometry geometry;
  final int count;
  final int quarterTurns;
  final Motion motion;
  final int roundNumber;

  /// Debug: die Karten offen statt als Ruecken zeigen.
  final List<JassCard>? revealed;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final cardSize = geometry.aiCardSize;
    final length = geometry.aiFanLength(count);

    return Semantics(
      label: texts.hiddenHand(count),
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: SizedBox(
          width: length,
          height: cardSize.height + 6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < count; index += 1)
                Positioned(
                  left: index * geometry.aiStep,
                  top: fanTransform(index, count).drop * 0.5,
                  child: _dealIn(
                    index,
                    Transform.rotate(
                      angle: fanTransform(index, count).angle * 0.6,
                      alignment: Alignment.bottomCenter,
                      child: revealed != null && index < revealed!.length
                          ? PlayingCardView(card: revealed![index], size: cardSize)
                          : CardBackView(size: cardSize),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dealIn(int index, Widget child) {
    if (!motion.enabled) {
      return child;
    }
    return child
        .animate(key: ValueKey('deal-$roundNumber-$index-$count'), delay: dealDelay(motion, index))
        .fadeIn(duration: motion.ms(220))
        .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: motion.ms(360));
  }
}
