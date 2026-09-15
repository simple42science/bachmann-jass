import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../game/game_texts.dart';
import '../../game/stats.dart';
import '../../l10n/generated/app_localizations.dart';

/// Lokale Statistik: Partien, Siege, Gebote, hoechster Weis, Matchs.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final texts = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(texts.statsResetTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(texts.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(texts.statsResetConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(statsProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final stats = ref.watch(statsProvider);
    final entries = stats.byVariant.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(Routes.home)),
        title: Text(texts.statsTitle),
      ),
      body: WoodBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: stats.gamesPlayed == 0 && stats.roundsPlayed == 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          texts.statsEmpty,
                          textAlign: TextAlign.center,
                          style: JassFonts.serif(
                            size: 20,
                            weight: 600,
                            italic: true,
                            color: colors.muted,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _Tile(label: texts.statsGames, value: '${stats.gamesPlayed}'),
                              _Tile(
                                label: texts.statsWon,
                                value: '${stats.gamesWon}',
                                detail: stats.gamesPlayed == 0
                                    ? null
                                    : texts.statsWinRate(
                                        (stats.gamesWon * 100 / stats.gamesPlayed).round(),
                                      ),
                              ),
                              _Tile(label: texts.statsRounds, value: '${stats.roundsPlayed}'),
                              _Tile(
                                label: texts.statsBids,
                                value: texts.statsBidsValue(stats.bidsMade, stats.bidsAttempted),
                              ),
                              _Tile(label: texts.statsHighestWeis, value: '${stats.highestWeis}'),
                              _Tile(label: texts.statsMatches, value: '${stats.matches}'),
                              _Tile(label: texts.statsStoeck, value: '${stats.stoeck}'),
                            ],
                          ),
                          if (entries.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              texts.statsPerVariant,
                              style: JassFonts.serif(
                                size: 20,
                                weight: 700,
                                color: colors.brassGlow,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final entry in entries)
                              () {
                                final parts = entry.key.split(':');
                                final variant = GameVariant.values.byName(parts[0]);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          texts.statsVariantLine(
                                            texts.variant(variant),
                                            texts.difficultyName(parts[1]),
                                          ),
                                          style: JassFonts.ui(size: 15, color: colors.text),
                                        ),
                                      ),
                                      Text(
                                        '${entry.value.won} / ${entry.value.played}',
                                        style: JassFonts.serif(size: 18, color: colors.brassGlow),
                                      ),
                                    ],
                                  ),
                                );
                              }(),
                          ],
                          const SizedBox(height: 28),
                          OutlinedButton(
                            onPressed: () => _confirmReset(context, ref),
                            child: Text(texts.statsReset),
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

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: JassFonts.ui(
              size: 10,
              weight: FontWeight.w800,
              color: colors.muted,
              letterSpacing: 1,
            ),
          ),
          Text(value, style: JassFonts.serif(size: 28, weight: 700, color: colors.brassGlow)),
          if (detail != null) Text(detail!, style: JassFonts.ui(size: 12, color: colors.muted)),
        ],
      ),
    );
  }
}
