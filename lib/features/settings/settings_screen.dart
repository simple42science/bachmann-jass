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

/// Einstellungen: Spielablauf, Gegner und Hausregeln.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final List<TextEditingController> _names = [
    for (final name in ref.read(settingsProvider).opponentNames) TextEditingController(text: name),
  ];

  @override
  void dispose() {
    for (final controller in _names) {
      controller.dispose();
    }
    super.dispose();
  }

  void _update(AppSettings Function(AppSettings current) change) {
    final controller = ref.read(settingsProvider.notifier);
    controller.update(change(ref.read(settingsProvider)));
  }

  void _saveNames() {
    _update((s) => s.copyWith(opponentNames: [for (final c in _names) c.text.trim()]));
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final settings = ref.watch(settingsProvider);
    final hasGame = ref.watch(gameControllerProvider) != null;
    final rules = settings.rules;
    final isPreset = rules == RuleSet.bachmann;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(hasGame ? Routes.table : Routes.home)),
        title: Text(texts.settingsTitle),
      ),
      body: WoodBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHead(title: texts.settingsPlaySection),
                    _SpeedSlider(
                      factor: settings.speedFactor,
                      onChanged: (value) =>
                          ref.read(settingsProvider.notifier).setSpeedFactor(value),
                    ),
                    _Switch(
                      title: texts.settingsAutoPlay,
                      subtitle: texts.settingsAutoPlayCopy,
                      value: settings.autoPlaySingleCard,
                      onChanged: (value) => _update((s) => s.copyWith(autoPlaySingleCard: value)),
                    ),
                    _Switch(
                      title: texts.settingsConfirmPlay,
                      subtitle: texts.settingsConfirmPlayCopy,
                      value: settings.confirmPlay,
                      onChanged: (value) => _update((s) => s.copyWith(confirmPlay: value)),
                    ),
                    _Switch(
                      title: texts.settingsUndo,
                      subtitle: texts.settingsUndoCopy,
                      value: settings.allowUndo,
                      onChanged: (value) => _update((s) => s.copyWith(allowUndo: value)),
                    ),

                    SectionHead(title: texts.settingsSoundSection),
                    _Switch(
                      title: texts.settingsWinSound,
                      subtitle: texts.settingsWinSoundCopy,
                      value: settings.winSound,
                      onChanged: (value) => _update((s) => s.copyWith(winSound: value)),
                    ),

                    SectionHead(title: texts.settingsOpponentsSection),
                    Text(
                      texts.settingsOpponentsCopy,
                      style: JassFonts.ui(size: 13, color: colors.muted),
                    ),
                    const SizedBox(height: 8),
                    for (var index = 0; index < 3; index += 1)
                      _OpponentRow(
                        label: texts.seatName(const ['left', 'top', 'right'][index]),
                        hint: index == 1 ? texts.seatTopHint : null,
                        controller: _names[index],
                        difficulty: settings.opponentDifficulties[index],
                        onNameChanged: (_) => _saveNames(),
                        onDifficultyChanged: (level) => _update(
                          (s) => s.copyWith(
                            opponentDifficulties: [
                              for (var i = 0; i < 3; i += 1)
                                i == index ? level : s.opponentDifficulties[i],
                            ],
                          ),
                        ),
                      ),

                    SectionHead(
                      title: texts.settingsRulesSection,
                      hint: isPreset ? texts.settingsRulesPreset : texts.settingsRulesCustom,
                    ),
                    Text(
                      texts.settingsRulesCopy,
                      style: JassFonts.ui(size: 13, color: colors.muted),
                    ),
                    const SizedBox(height: 8),
                    _Stepper(
                      title: texts.ruleLastTrick,
                      value: rules.lastTrickBonus,
                      min: 0,
                      max: 20,
                      step: 5,
                      onChanged: (v) =>
                          _update((s) => s.copyWith(rules: rules.copyWith(lastTrickBonus: v))),
                    ),
                    _Stepper(
                      title: texts.ruleMatch,
                      value: rules.matchBonus,
                      min: 0,
                      max: 300,
                      step: 50,
                      onChanged: (v) =>
                          _update((s) => s.copyWith(rules: rules.copyWith(matchBonus: v))),
                    ),
                    _Stepper(
                      title: texts.ruleStoeck,
                      value: rules.stoeckPoints,
                      min: 0,
                      max: 50,
                      step: 10,
                      onChanged: (v) =>
                          _update((s) => s.copyWith(rules: rules.copyWith(stoeckPoints: v))),
                    ),
                    _Switch(
                      title: texts.ruleFourSixes,
                      value: rules.fourSixesCount,
                      onChanged: (v) =>
                          _update((s) => s.copyWith(rules: rules.copyWith(fourSixesCount: v))),
                    ),
                    _Switch(
                      title: texts.ruleFourBeatsSequence,
                      value: rules.fourOfAKindBeatsSequence,
                      onChanged: (v) => _update(
                        (s) => s.copyWith(rules: rules.copyWith(fourOfAKindBeatsSequence: v)),
                      ),
                    ),
                    _Switch(
                      title: texts.ruleBedanken,
                      subtitle: texts.ruleBedankenCopy,
                      value: rules.bedanken,
                      onChanged: (v) =>
                          _update((s) => s.copyWith(rules: rules.copyWith(bedanken: v))),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      texts.ruleTrickReview,
                      style: JassFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final kind in TrickReview.values)
                          OptionTile(
                            title: texts.trickReviewName(kind.name),
                            selected: rules.trickReview == kind,
                            minWidth: 80,
                            onTap: () => _update(
                              (s) => s.copyWith(rules: rules.copyWith(trickReview: kind)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      texts.ruleMultipliers,
                      style: JassFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                    for (final mode in RoundMode.baseModes)
                      _Stepper(
                        title: texts.mode(mode),
                        value: rules.multiplierFor(mode),
                        min: 1,
                        max: 5,
                        step: 1,
                        prefix: '×',
                        onChanged: (v) => _update(
                          (s) => s.copyWith(
                            rules: rules.copyWith(
                              roundMultipliers: {...rules.roundMultipliers, mode: v},
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isPreset
                          ? null
                          : () => _update((s) => s.copyWith(rules: RuleSet.bachmann)),
                      child: Text(texts.settingsRulesReset),
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

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({required this.factor, required this.onChanged});

  final double factor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    // Der Regler laeuft von schnell (links) nach langsam (rechts).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                texts.settingsSpeed,
                style: JassFonts.ui(size: 15, weight: FontWeight.w700),
              ),
            ),
            Text(
              texts.settingsSpeedValue(
                texts.speedName(GameSpeed.nearest(factor).name),
                (100 / factor).round(),
              ),
              style: JassFonts.ui(size: 13, color: colors.brassGlow, weight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: factor,
          min: minSpeedFactor,
          max: maxSpeedFactor,
          divisions: 17,
          activeColor: colors.brassLight,
          inactiveColor: colors.brass.withValues(alpha: 0.3),
          onChanged: (value) => onChanged(double.parse(value.toStringAsFixed(2))),
        ),
      ],
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: JassFonts.ui(size: 15, weight: FontWeight.w700, color: colors.text),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: JassFonts.ui(size: 12, color: colors.muted)),
      value: value,
      activeThumbColor: colors.brassGlow,
      activeTrackColor: colors.brass.withValues(alpha: 0.6),
      onChanged: onChanged,
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.prefix = '',
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final int step;
  final String prefix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: JassFonts.ui(size: 15, color: colors.text)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: colors.brassLight,
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$prefix$value',
              textAlign: TextAlign.center,
              style: JassFonts.serif(size: 18, color: colors.brassGlow),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: colors.brassLight,
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({
    required this.label,
    required this.controller,
    required this.difficulty,
    required this.onNameChanged,
    required this.onDifficultyChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final Difficulty? difficulty;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<Difficulty?> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint == null ? label : '$label · $hint',
            style: JassFonts.ui(
              size: 12,
              weight: FontWeight.w800,
              color: colors.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: controller,
                  maxLength: 14,
                  onChanged: onNameChanged,
                  decoration: const InputDecoration(counterText: '', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OptionTile(
                      title: texts.difficultyDefault,
                      selected: difficulty == null,
                      minWidth: 60,
                      onTap: () => onDifficultyChanged(null),
                    ),
                    for (final level in Difficulty.values)
                      OptionTile(
                        title: texts.difficultyName(level.name),
                        selected: difficulty == level,
                        minWidth: 60,
                        onTap: () => onDifficultyChanged(level),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
