import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../game/game_controller.dart';
import '../../game/game_texts.dart';
import '../../l10n/generated/app_localizations.dart';

/// Regeln und Punkte, erzeugt aus dem Regelwerk der laufenden Partie (oder
/// dem Preset "Bachmann"), damit die Anzeige nie vom Code abweicht.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final session = ref.watch(gameControllerProvider);
    final rules = session?.state.rules ?? RuleSet.bachmann;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go(session == null ? Routes.home : Routes.table),
        ),
        title: Text(texts.rulesTitle),
      ),
      body: WoodBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      texts.rulesKicker.toUpperCase(),
                      style: JassFonts.ui(
                        size: 11,
                        weight: FontWeight.w800,
                        color: colors.muted,
                        letterSpacing: 2,
                      ),
                    ),
                    _Section(
                      title: texts.rulesFollowTitle,
                      bullets: [
                        texts.rulesFollow1,
                        texts.rulesFollow2,
                        texts.rulesFollow3,
                        texts.rulesFollow4,
                        texts.rulesFollow5,
                      ],
                    ),
                    _Section(
                      title: texts.rulesModesTitle,
                      bullets: [
                        texts.rulesModeTrump,
                        texts.rulesModeObeAbe,
                        texts.rulesModeUneUfe,
                        texts.rulesModeSlalom,
                      ],
                    ),
                    _Section(title: texts.rulesCardValuesTitle, child: _CardValueTable()),
                    _Section(
                      title: texts.rulesWeisTitle,
                      bullets: [
                        texts.rulesWeisOnlyHighest,
                        texts.rulesWeisTie(
                          rules.fourOfAKindBeatsSequence
                              ? texts.rulesTieFour
                              : texts.rulesTieSequence,
                        ),
                      ],
                      child: _WeisTable(rules: rules),
                    ),
                    _Section(
                      title: texts.rulesBonusTitle,
                      bullets: [
                        texts.rulesStoeck(rules.stoeckPoints),
                        texts.rulesLastTrick(rules.lastTrickBonus),
                        texts.rulesMatch(rules.matchBonus),
                        texts.rulesRoundTotal(152 + rules.lastTrickBonus),
                      ],
                    ),
                    _Section(
                      title: texts.rulesMultipliersTitle,
                      intro: texts.rulesMultipliersCopy,
                      child: _KeyValueTable(
                        rows: [
                          for (final mode in RoundMode.baseModes)
                            (texts.mode(mode), texts.multiplier(rules.multiplierFor(mode))),
                        ],
                      ),
                    ),
                    _Section(
                      title: texts.rulesSchieberTitle,
                      bullets: [
                        texts.rulesSchieber1,
                        texts.rulesSchieber2,
                        texts.rulesSchieber3,
                        texts.rulesSchieber4(GameVariant.schieber.defaultTargetScore),
                      ],
                    ),
                    _Section(
                      title: texts.rulesBieterTitle,
                      bullets: [
                        texts.rulesBieter1,
                        texts.rulesBieter2,
                        texts.rulesBieter3(rules.forcedDealerBid),
                        texts.rulesBieter4,
                        texts.rulesBieter5(GameVariant.bieter.defaultTargetScore),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.intro, this.bullets = const [], this.child});

  final String title;
  final String? intro;
  final List<String> bullets;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    final body = JassFonts.ui(size: 15, color: colors.text, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: JassFonts.serif(size: 22, weight: 700, color: colors.brassGlow)),
          if (intro != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(intro!, style: body),
            ),
          if (child != null) Padding(padding: const EdgeInsets.only(top: 10), child: child),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: colors.brass, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(bullet, style: body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CardValueTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final rows = <(String, RoundMode, Suit)>[
      (texts.rulesRowSide, RoundMode.rosen, Suit.eicheln),
      (texts.rulesRowTrump, RoundMode.rosen, Suit.rosen),
      (texts.mode(RoundMode.obeAbe), RoundMode.obeAbe, Suit.eicheln),
      (texts.mode(RoundMode.uneUfe), RoundMode.uneUfe, Suit.eicheln),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _Grid(
        header: [texts.modeLabel, for (final rank in Rank.values) texts.rank(rank)],
        rows: [
          for (final (label, mode, suit) in rows)
            [label, for (final rank in Rank.values) '${cardPoints(JassCard(suit, rank), mode)}'],
        ],
      ),
    );
  }
}

class _WeisTable extends StatelessWidget {
  const _WeisTable({required this.rules});

  final RuleSet rules;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return _KeyValueTable(
      rows: [
        for (final MapEntry(key: length, value: points) in sequencePoints.entries)
          (texts.rulesSequence(length), '$points'),
        for (final rank in [Rank.under, Rank.nine, Rank.ass, Rank.six])
          (
            rank == Rank.six ? texts.rulesFourSixes : texts.rulesFourOf(texts.rank(rank)),
            fourOfAKindPoints(rank, rules) == 0
                ? texts.rulesNotCounted
                : '${fourOfAKindPoints(rank, rules)}',
          ),
      ],
    );
  }
}

class _KeyValueTable extends StatelessWidget {
  const _KeyValueTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => _Grid(
    header: null,
    rows: [
      for (final (key, value) in rows) [key, value],
    ],
    lastColumnRight: true,
  );
}

/// Kleine Tabelle mit Messing-Kopfzeile auf dunklem Holz.
class _Grid extends StatelessWidget {
  const _Grid({required this.header, required this.rows, this.lastColumnRight = false});

  final List<String>? header;
  final List<List<String>> rows;
  final bool lastColumnRight;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    final columns = (header ?? rows.first).length;
    Widget cell(String text, {bool head = false, bool right = false, bool first = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: head
                ? JassFonts.ui(size: 12, weight: FontWeight.w800, color: colors.ink)
                : JassFonts.ui(
                    size: 14,
                    weight: first ? FontWeight.w700 : FontWeight.w500,
                    color: colors.text,
                  ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        columnWidths: header == null ? const {0: FlexColumnWidth()} : null,
        children: [
          if (header != null)
            TableRow(
              decoration: BoxDecoration(color: colors.brassLight),
              children: [
                for (var i = 0; i < columns; i += 1) cell(header![i], head: true, right: i > 0),
              ],
            ),
          for (var r = 0; r < rows.length; r += 1)
            TableRow(
              decoration: BoxDecoration(
                color: r.isOdd ? Colors.white.withValues(alpha: 0.04) : null,
              ),
              children: [
                for (var i = 0; i < columns; i += 1)
                  cell(
                    rows[r][i],
                    first: i == 0,
                    right: header != null ? i > 0 : lastColumnRight && i == columns - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
