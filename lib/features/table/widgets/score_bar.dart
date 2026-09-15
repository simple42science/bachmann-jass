import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../../app/theme.dart';
import '../../../game/game_texts.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Punktestand in der Kopfzeile: je Team (Schieber) oder je Spieler (Bieterjass).
///
/// Auf schmalen Bildschirmen teilen sich die Chips die Breite und lassen die
/// Detailzeile weg; sonst zeigen sie Rundenpunkte, Stiche, Weis und Stöck.
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        final chips = game.isSchieber ? _teamChips(texts, compact) : _playerChips(texts, compact);
        if (compact) {
          return Row(
            children: [
              for (var index = 0; index < chips.length; index += 1) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(child: chips[index]),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < chips.length; index += 1) ...[
                if (index > 0) const SizedBox(width: 8),
                chips[index],
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _teamChips(AppLocalizations texts, bool compact) {
    final currentTeam = game.isInteractive ? game.players[game.currentPlayer].teamId : null;
    return [
      for (final team in game.teams)
        () {
          final result = schieberTeamResult(game, team.id);
          final factor = game.roundMultiplier > 1 && game.roundMode != null
              ? ' ${texts.multiplier(game.roundMultiplier)}'
              : '';
          final stats = [
            texts.trickCount(result.tricksWon),
            if (result.weisPoints > 0) texts.scoreWeis(result.weisPoints),
            if (result.stoeckPoints > 0) texts.scoreStoeck(result.stoeckPoints),
            if (result.matchPoints > 0) texts.scoreMatch,
          ].join(' · ');
          return _ScoreChip(
            title: texts.team(game, team.id),
            value: '${team.totalScore}',
            detail: compact
                ? texts.scoreRound('${result.basePoints}$factor')
                : '${texts.scoreRound('${result.basePoints}$factor')} · $stats',
            active: team.id == currentTeam,
            allied: team.id == game.players[0].teamId,
            compact: compact,
          );
        }(),
    ];
  }

  List<Widget> _playerChips(AppLocalizations texts, bool compact) {
    final inRound = game.phase != GamePhase.bidding && game.phase != GamePhase.setup;
    return [
      for (final player in game.players)
        _ScoreChip(
          title: player.name,
          value: '${player.totalScore}',
          detail: [
            if (player.bid != null) texts.seatBadge(game, player.id),
            if (inRound)
              compact
                  ? texts.scorePoints(player.pointsWon)
                  : '${texts.trickCount(player.tricksWon)} · ${texts.scorePoints(player.pointsWon)}',
          ].join(' · '),
          active: game.isInteractive && player.id == game.currentPlayer,
          allied: inRound && player.id == game.soloPlayer,
          compact: compact,
        ),
    ];
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.title,
    required this.value,
    required this.detail,
    required this.active,
    required this.allied,
    required this.compact,
  });

  final String title;
  final String value;
  final String detail;
  final bool active;
  final bool allied;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: allied ? colors.gold.withValues(alpha: 0.14) : colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? colors.gold : colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w800,
                  color: colors.goldLight,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty)
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.muted),
            ),
        ],
      ),
    );
  }
}
