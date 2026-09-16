import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/router.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../design/option_tile.dart';
import '../../game/game_controller.dart';
import '../../game/game_texts.dart';
import '../../l10n/generated/app_localizations.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late AppSettings _draft = ref.read(settingsProvider);
  late final TextEditingController _name = TextEditingController(text: _draft.playerName);
  late final TextEditingController _startBid = TextEditingController(
    text: bieterStartBids.contains(_draft.bieterStartBid) ? '' : '${_draft.bieterStartBid}',
  );

  @override
  void dispose() {
    _name.dispose();
    _startBid.dispose();
    super.dispose();
  }

  void _change(AppSettings Function(AppSettings current) update) {
    setState(() => _draft = update(_draft));
  }

  void _start() {
    final texts = AppLocalizations.of(context);
    final settings = _draft.copyWith(playerName: _name.text.trim());
    ref.read(settingsProvider.notifier).update(settings);
    final name = settings.playerName.isEmpty ? texts.playerNameDefault : settings.playerName;
    ref
        .read(gameControllerProvider.notifier)
        .startNewGame(
          variant: settings.variant,
          matchConfig: settings.matchConfigFor(settings.variant),
          playerName: name,
          seats: settings.seatsFor(settings.variant, name),
          rules: settings.rules,
        );
    context.go(Routes.table);
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final multipliers = RuleSet.bachmann.roundMultipliers.entries
        .map((entry) => '${texts.mode(entry.key)} ${texts.multiplier(entry.value)}')
        .join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.setupTitle),
        leading: BackButton(onPressed: () => context.go(Routes.home)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final variant in GameVariant.values)
                        OptionTile(
                          title: texts.variant(variant),
                          subtitle: texts.variantCopy(variant.name),
                          selected: _draft.variant == variant,
                          onTap: () => _change((s) => s.copyWith(variant: variant)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    texts.variantSubtitle(_draft.variant.name),
                    style: TextStyle(color: colors.muted),
                  ),
                  SectionHead(title: texts.playerNameLabel),
                  TextField(
                    controller: _name,
                    maxLength: 18,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _start(),
                    decoration: InputDecoration(hintText: texts.playerNameDefault, counterText: ''),
                  ),
                  SectionHead(
                    title: texts.difficultyLabel,
                    hint: texts.difficultyCopy(_draft.difficulty.name),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final level in Difficulty.values)
                        OptionTile(
                          title: texts.difficultyName(level.name),
                          selected: _draft.difficulty == level,
                          onTap: () => _change((s) => s.copyWith(difficulty: level)),
                        ),
                    ],
                  ),
                  SectionHead(title: texts.speedLabel, hint: texts.speedCopy(_draft.speed.name)),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final speed in GameSpeed.values)
                        OptionTile(
                          title: texts.speedName(speed.name),
                          selected: _draft.speed == speed,
                          onTap: () => _change((s) => s.copyWith(speedFactor: speed.factor)),
                        ),
                    ],
                  ),
                  if (_draft.variant == GameVariant.bieter) ...[
                    SectionHead(
                      title: texts.scoringLabel,
                      hint: _draft.bieterScoring == BieterScoring.schieber ? multipliers : null,
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final scoring in BieterScoring.values)
                          OptionTile(
                            title: texts.scoringName(scoring.name),
                            subtitle: texts.scoringCopy(scoring.name),
                            selected: _draft.bieterScoring == scoring,
                            onTap: () => _change((s) => s.copyWith(bieterScoring: scoring)),
                          ),
                      ],
                    ),
                    SectionHead(
                      title: texts.startBidLabel,
                      hint: texts.startBidHint(GameVariant.bieter.defaultTargetScore),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final value in bieterStartBids)
                          OptionTile(
                            title: '$value',
                            selected: _draft.bieterStartBid == value,
                            minWidth: 72,
                            onTap: () {
                              _startBid.clear();
                              _change((s) => s.copyWith(bieterStartBid: value));
                            },
                          ),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _startBid,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: InputDecoration(
                              hintText: texts.startBidCustom,
                              counterText: '',
                            ),
                            onChanged: (raw) {
                              final value = int.tryParse(raw.trim());
                              if (value != null && value >= minStartBid && value <= maxBid) {
                                _change((s) => s.copyWith(bieterStartBid: value));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SectionHead(title: texts.targetLabel, hint: multipliers),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final target in schieberTargetScores)
                          OptionTile(
                            title: texts.targetPoints(target),
                            subtitle: texts.targetCopy(target.toString()),
                            selected: _draft.schieberTargetScore == target,
                            onTap: () => _change((s) => s.copyWith(schieberTargetScore: target)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .update(_draft.copyWith(playerName: _name.text.trim()));
                      context.go(Routes.settings);
                    },
                    child: Text(texts.menuSettings),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(texts.startGame, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
