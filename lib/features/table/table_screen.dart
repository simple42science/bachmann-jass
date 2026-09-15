import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/router.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../game/game_controller.dart';
import '../../game/game_session.dart';
import '../../game/game_texts.dart';
import '../../l10n/generated/app_localizations.dart';
import 'panels/bid_panel.dart';
import 'panels/mode_panel.dart';
import 'panels/round_end_panel.dart';
import 'panels/weis_panel.dart';
import 'table_geometry.dart';
import 'widgets/hand_view.dart';
import 'widgets/score_bar.dart';
import 'widgets/seat_label.dart';
import 'widgets/trick_view.dart';

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final texts = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: texts.homeButton,
          onPressed: () {
            controller.leaveTable();
            context.go(Routes.home);
          },
        ),
        title: ScoreBar(game: session.state),
        actions: [
          IconButton(
            icon: Icon(session.paused ? Icons.play_arrow : Icons.pause),
            tooltip: session.paused ? texts.continueButton : texts.pauseButton,
            onPressed: session.paused ? controller.resumeGame : controller.pause,
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: texts.speedButton(texts.speedName(settings.speed.name)),
            onPressed: () => ref.read(settingsProvider.notifier).setSpeed(settings.speed.next),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => _TableStage(
            session: session,
            geometry: TableGeometry.compute(
              size: constraints.biggest,
              variant: session.state.variant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableStage extends ConsumerWidget {
  const _TableStage({required this.session, required this.geometry});

  final GameSession session;
  final TableGeometry geometry;

  void _act(BuildContext context, WidgetRef ref, GameAction action) {
    final violation = ref.read(gameControllerProvider.notifier).act(action);
    if (violation == RuleViolation.notYourTurn) {
      _notify(context, AppLocalizations.of(context).restrictionNotYourTurn);
    }
  }

  void _playCard(BuildContext context, WidgetRef ref, JassCard card) {
    final texts = AppLocalizations.of(context);
    final game = session.state;
    if (!session.humanTurn || game.phase != GamePhase.playing) {
      return;
    }
    final restriction = playRestriction(game.players[0].hand, game.trick, game.trickMode, card);
    if (restriction != null) {
      _notify(context, texts.restriction(restriction, game));
      return;
    }
    _act(context, ref, PlayCard(0, card));
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _tapTable(WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    if (session.paused) {
      controller.resumeGame();
    } else {
      controller.skipDelay();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final game = session.state;
    final seats = seatsFor(game.variant);
    final humanPlaying = session.humanTurn && game.phase == GamePhase.playing && !session.paused;
    final playable = humanPlaying ? playableCards(game, 0).toSet() : const <JassCard>{};
    final showTrick = game.phase != GamePhase.roundEnd && game.phase != GamePhase.gameOver;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapTable(ref),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.1,
            colors: [colors.felt, colors.feltDark],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final MapEntry(key: playerIndex, value: seat) in seats.entries)
              if (seat != Seat.bottom)
                Positioned.fromRect(
                  rect: geometry.zones[seat]!,
                  child: _AiSeat(
                    geometry: geometry,
                    seat: seat,
                    name: game.players[playerIndex].name,
                    badge: texts.seatBadge(game, playerIndex),
                    active: game.isInteractive && game.currentPlayer == playerIndex,
                    cards: game.players[playerIndex].hand.length,
                  ),
                ),
            Positioned.fromRect(
              rect: geometry.statusRect,
              child: _StatusRow(
                mode: texts.modeChip(game),
                message: session.paused ? texts.msgPaused : texts.phaseMessage(game),
              ),
            ),
            if (showTrick)
              Positioned.fill(
                child: TrickView(
                  geometry: geometry,
                  trick: game.trick,
                  seats: seats,
                  winner: game.phase == GamePhase.trickEnd ? game.trickLeader : null,
                ),
              ),
            Positioned.fromRect(
              rect: geometry.handRect,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: TableGeometry.labelHeight,
                    child: SeatLabel(
                      name: game.players[0].name,
                      badge: texts.seatBadge(game, 0),
                      active: session.humanTurn,
                    ),
                  ),
                  HumanHandView(
                    geometry: geometry,
                    hand: game.players[0].hand,
                    playable: playable,
                    interactive: humanPlaying,
                    onTap: (card) => _playCard(context, ref, card),
                  ),
                ],
              ),
            ),
            if (!session.paused)
              Positioned.fromRect(
                rect: geometry.panelRect,
                child: _Panel(session: session, onAction: (action) => _act(context, ref, action)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Namensschild und verdeckte Hand eines Computers; an den Seiten steht der
/// Faecher senkrecht.
class _AiSeat extends StatelessWidget {
  const _AiSeat({
    required this.geometry,
    required this.seat,
    required this.name,
    required this.badge,
    required this.active,
    required this.cards,
  });

  final TableGeometry geometry;
  final Seat seat;
  final String name;
  final String badge;
  final bool active;
  final int cards;

  @override
  Widget build(BuildContext context) {
    final label = SeatLabel(name: name, badge: badge, active: active);
    final hand = HiddenHandView(
      geometry: geometry,
      count: cards,
      quarterTurns: switch (seat) {
        Seat.left => 1,
        Seat.right => 3,
        Seat.top => 2,
        Seat.bottom => 0,
      },
    );
    if (seat == Seat.top) {
      if (geometry.compact) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [label, const SizedBox(width: 10), hand],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [label, const SizedBox(height: 4), hand],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: label),
        const SizedBox(height: 8),
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: hand),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.mode, required this.message});

  final String mode;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Row(
      children: [
        if (mode.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.gold),
            ),
            child: Text(
              mode,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.goldLight),
            ),
          ),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.text),
          ),
        ),
      ],
    );
  }
}

/// Das zur Phase passende Bedien-Panel, sofern der Mensch etwas entscheiden muss.
class _Panel extends ConsumerWidget {
  const _Panel({required this.session, required this.onAction});

  final GameSession session;
  final void Function(GameAction action) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = session.state;
    final controller = ref.read(gameControllerProvider.notifier);

    if (game.phase == GamePhase.roundEnd) {
      return RoundEndPanel(game: game, onNextRound: () => onAction(const StartRound()));
    }
    if (game.phase == GamePhase.gameOver) {
      return GameOverPanel(
        game: game,
        onHome: () {
          controller.abandon();
          context.go(Routes.home);
        },
      );
    }
    if (!session.humanTurn) {
      return const SizedBox.shrink();
    }
    return switch (game.phase) {
      GamePhase.bidding => BidPanel(game: game, onAction: onAction),
      GamePhase.chooseTrump => ModePanel(game: game, onAction: onAction),
      GamePhase.announceWeis => WeisPanel(game: game, onAction: onAction),
      _ => const SizedBox.shrink(),
    };
  }
}
