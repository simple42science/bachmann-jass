import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../table_geometry.dart';
import 'playing_card_view.dart';

/// Die eigene Hand: aufgedeckt, gefaechert, spielbare Karten leicht angehoben.
class HumanHandView extends StatelessWidget {
  const HumanHandView({
    super.key,
    required this.geometry,
    required this.hand,
    required this.playable,
    required this.interactive,
    required this.onTap,
  });

  final TableGeometry geometry;
  final List<JassCard> hand;

  /// Karten, die gerade gespielt werden duerfen (leer, wenn nicht am Zug).
  final Set<JassCard> playable;

  /// Der Mensch ist am Zug; nicht spielbare Karten werden abgedunkelt.
  final bool interactive;
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
            Positioned(
              left: left + index * geometry.handStep,
              top: playable.contains(hand[index]) ? 0 : lift,
              child: _HandCard(
                card: hand[index],
                size: cardSize,
                fan: fanTransform(index, hand.length),
                isPlayable: playable.contains(hand[index]),
                dimmed: interactive && !playable.contains(hand[index]),
                label: playable.contains(hand[index])
                    ? texts.cardPlayLabel(texts.card(hand[index]))
                    : texts.cardNotPlayableLabel(texts.card(hand[index])),
                onTap: () => onTap(hand[index]),
              ),
            ),
        ],
      ),
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
    required this.label,
    required this.onTap,
  });

  final JassCard card;
  final Size size;
  final ({double angle, double drop}) fan;
  final bool isPlayable;
  final bool dimmed;
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
            child: PlayingCardView(card: card, size: size, dimmed: dimmed),
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
  });

  final TableGeometry geometry;
  final int count;
  final int quarterTurns;

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
                  child: Transform.rotate(
                    angle: fanTransform(index, count).angle * 0.6,
                    alignment: Alignment.bottomCenter,
                    child: CardBackView(size: cardSize),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
