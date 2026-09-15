import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../game/game_controller.dart';
import '../../game/game_texts.dart';
import '../../l10n/generated/app_localizations.dart';
import 'ztafel_painter.dart';

/// Die Jasstafel: eine Schiefertafel im Holzrahmen mit Kreidezahlen, den
/// Strichen der Z-Tafel, allen Runden und dem Verlauf der laufenden Runde.
class ScoreboardScreen extends ConsumerWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final game = session.state;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(Routes.table)),
        title: Text(texts.scoreboardTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                texts.targetShort(game.targetScore),
                style: JassFonts.ui(size: 13, color: colors.muted),
              ),
            ),
          ),
        ],
      ),
      body: WoodBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _Slate(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (game.isSchieber) _TeamTotals(game: game) else _PlayerTotals(game: game),
                      const SizedBox(height: 14),
                      if (game.roundHistory.isEmpty)
                        Text(
                          texts.scoreboardEmpty,
                          style: JassFonts.handwriting(size: 20, color: colors.chalk),
                        )
                      else if (game.isSchieber)
                        _SchieberTable(game: game)
                      else
                        _BieterTable(game: game),
                      const SizedBox(height: 18),
                      _RoundLog(events: session.roundEvents, game: game),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Schiefertafel im Holzrahmen.
class _Slate extends StatelessWidget {
  const _Slate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.woodLight, colors.wood],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.6),
            radius: 1.4,
            colors: [const Color(0xFF3A3F3D), colors.slate, const Color(0xFF1E2322)],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }
}

class _TeamTotals extends StatelessWidget {
  const _TeamTotals({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final leader = game.teams.reduce((a, b) => b.totalScore > a.totalScore ? b : a);
    final remaining = game.targetScore - leader.totalScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final team in game.teams) ...[
              if (team.id > 0) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: team.id == 0
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      texts.team(game, team.id).toUpperCase(),
                      style: JassFonts.ui(
                        size: 11,
                        weight: FontWeight.w800,
                        color: colors.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${team.totalScore}',
                      style: JassFonts.handwriting(size: 44, color: colors.chalk),
                    ),
                    SizedBox(
                      width: 140,
                      height: 52,
                      child: CustomPaint(
                        painter: ZTafelPainter(points: team.totalScore, chalk: colors.chalk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 2, color: colors.chalk.withValues(alpha: 0.35)),
        const SizedBox(height: 8),
        Text(
          remaining > 0
              ? texts.scoreboardRemaining(texts.team(game, leader.id), remaining)
              : texts.scoreboardReached(texts.team(game, leader.id)),
          style: JassFonts.handwriting(
            size: 19,
            weight: 500,
            color: colors.chalk.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _PlayerTotals extends StatelessWidget {
  const _PlayerTotals({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final player in game.players)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      player.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: JassFonts.ui(
                        size: 11,
                        weight: FontWeight.w800,
                        color: colors.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${player.totalScore}',
                      style: JassFonts.handwriting(size: 40, color: colors.chalk),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 2, color: colors.chalk.withValues(alpha: 0.35)),
      ],
    );
  }
}

class _ChalkCell extends StatelessWidget {
  const _ChalkCell(this.text, {this.align = TextAlign.right, this.size = 22, this.dim = false});

  final String text;
  final TextAlign align;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: JassFonts.handwriting(
          size: size,
          weight: dim ? 500 : 700,
          color: dim ? colors.chalk.withValues(alpha: 0.6) : colors.chalk,
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text, {this.align = TextAlign.right});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: JassFonts.ui(
          size: 10,
          weight: FontWeight.w800,
          color: colors.muted,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ModeCell extends StatelessWidget {
  const _ModeCell({required this.label, required this.multiplier, required this.tags});

  final String label;
  final int multiplier;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Text(
            label,
            style: JassFonts.ui(size: 14, weight: FontWeight.w700, color: colors.chalk),
          ),
          if (multiplier > 1)
            Text(
              AppLocalizations.of(context).multiplier(multiplier),
              style: JassFonts.ui(size: 13, weight: FontWeight.w700, color: colors.brassLight),
            ),
          for (final tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colors.brassLight,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tag.toUpperCase(),
                style: JassFonts.ui(
                  size: 9,
                  weight: FontWeight.w800,
                  color: colors.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

TableRow _divider(BuildContext context, int columns) => TableRow(
  decoration: BoxDecoration(
    border: Border(bottom: BorderSide(color: context.jass.chalk.withValues(alpha: 0.18))),
  ),
  children: [for (var i = 0; i < columns; i += 1) const SizedBox(height: 1)],
);

class _SchieberTable extends StatelessWidget {
  const _SchieberTable({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(30),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(52),
        3: FixedColumnWidth(58),
        4: FixedColumnWidth(52),
        5: FixedColumnWidth(58),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _HeadCell(texts.colRound, align: TextAlign.left),
            _HeadCell(texts.colMode, align: TextAlign.left),
            _HeadCell(texts.colUs),
            _HeadCell(texts.colTotal),
            _HeadCell(texts.colThem),
            _HeadCell(texts.colTotal),
          ],
        ),
        for (final entry in game.roundHistory)
          if (entry.summary case final SchieberRoundSummary summary) ...[
            _divider(context, 6),
            TableRow(
              children: [
                _ChalkCell('${entry.roundNumber}', align: TextAlign.left, size: 18, dim: true),
                _ModeCell(
                  label: texts.mode(summary.roundMode),
                  multiplier: summary.multiplier,
                  tags: [
                    if (summary.weisWinnerTeamId != null) texts.tagWeis,
                    if (summary.stoeckPlayer >= 0) texts.tagStoeck,
                    if (summary.matchTeamId != null) texts.tagMatch,
                  ],
                ),
                _ChalkCell('${summary.results.firstWhere((r) => r.teamId == 0).roundPoints}'),
                _ChalkCell('${entry.totals[0]}', dim: true, size: 18),
                _ChalkCell('${summary.results.firstWhere((r) => r.teamId == 1).roundPoints}'),
                _ChalkCell('${entry.totals[1]}', dim: true, size: 18),
              ],
            ),
          ],
      ],
    );
  }
}

class _BieterTable extends StatelessWidget {
  const _BieterTable({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 440),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(30),
            1: FixedColumnWidth(84),
            2: FlexColumnWidth(),
            3: FixedColumnWidth(54),
            4: FixedColumnWidth(60),
            5: FixedColumnWidth(70),
            6: FixedColumnWidth(58),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                _HeadCell(texts.colRound, align: TextAlign.left),
                _HeadCell(texts.colBidder, align: TextAlign.left),
                _HeadCell(texts.colMode, align: TextAlign.left),
                _HeadCell(texts.colBid),
                _HeadCell(texts.colReached),
                _HeadCell(texts.colResult),
                _HeadCell(texts.colPoints),
              ],
            ),
            for (final entry in game.roundHistory)
              if (entry.summary case final BieterRoundSummary summary) ...[
                _divider(context, 7),
                TableRow(
                  children: [
                    _ChalkCell('${entry.roundNumber}', align: TextAlign.left, size: 18, dim: true),
                    _ModeCell(
                      label: game.players[summary.soloPlayer].name,
                      multiplier: 1,
                      tags: const [],
                    ),
                    _ModeCell(
                      label: texts.mode(summary.roundMode),
                      multiplier: summary.multiplier,
                      tags: const [],
                    ),
                    _ChalkCell('${summary.bid}'),
                    _ChalkCell('${summary.soloPoints}'),
                    _ChalkCell(
                      summary.succeeded ? texts.resultMade : texts.resultMissed,
                      size: 17,
                      dim: true,
                    ),
                    _ChalkCell('${summary.soloGain > 0 ? '+' : ''}${summary.soloGain}'),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Verlauf der laufenden Runde, Satz fuer Satz aus den Ereignissen.
class _RoundLog extends StatelessWidget {
  const _RoundLog({required this.events, required this.game});

  final List<GameEvent> events;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final lines = [
      for (final event in events)
        if (texts.logLine(game, event) case final String line) line,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texts.logTitle.toUpperCase(),
          style: JassFonts.ui(
            size: 10,
            weight: FontWeight.w800,
            color: colors.muted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        if (lines.isEmpty)
          Text(
            texts.logEmpty,
            style: JassFonts.handwriting(size: 18, weight: 500, color: colors.chalk),
          )
        else
          for (final line in lines.reversed.take(40))
            Text(
              line,
              style: JassFonts.handwriting(
                size: 18,
                weight: 500,
                color: colors.chalk.withValues(alpha: 0.9),
              ),
            ),
      ],
    );
  }
}
