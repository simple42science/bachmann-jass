import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jass_engine/jass_engine.dart';

import '../../app/debug_state.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../game/game_controller.dart';
import '../../game/game_session.dart';
import '../../game/game_texts.dart';
import '../../l10n/generated/app_localizations.dart';
import 'motion.dart';
import 'panels/bid_panel.dart';
import 'panels/mode_panel.dart';
import 'panels/round_end_panel.dart';
import 'panels/trick_review_dialog.dart';
import 'panels/weis_panel.dart';
import 'table_geometry.dart';
import 'widgets/event_toast.dart';
import 'widgets/hand_view.dart';
import 'widgets/score_bar.dart';
import 'widgets/seat_label.dart';
import 'widgets/trick_view.dart';

enum _MenuAction { speed, trickReview, scoreboard, rules, settings, debug, abandon }

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  Future<void> _confirmAbandon(BuildContext context, WidgetRef ref) async {
    final texts = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(texts.abandonTitle),
        content: Text(texts.abandonBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(texts.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(texts.abandonGame),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(gameControllerProvider.notifier).abandon();
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final texts = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final canUndo = settings.allowUndo && session.canUndo && !session.paused;

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
          if (settings.allowUndo)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: texts.undoButton,
              onPressed: canUndo ? controller.undo : null,
            ),
          IconButton(
            icon: Icon(session.paused ? Icons.play_arrow : Icons.pause),
            tooltip: session.paused ? texts.continueButton : texts.pauseButton,
            onPressed: session.paused ? controller.resumeGame : controller.pause,
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: texts.menuTooltip,
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _MenuAction.speed:
                  ref.read(settingsProvider.notifier).setSpeed(settings.speed.next);
                case _MenuAction.trickReview:
                  showTrickReview(context, session.state);
                case _MenuAction.scoreboard:
                  context.go(Routes.scoreboard);
                case _MenuAction.rules:
                  context.go(Routes.rules);
                case _MenuAction.settings:
                  context.go(Routes.settings);
                case _MenuAction.debug:
                  context.go(Routes.debug);
                case _MenuAction.abandon:
                  _confirmAbandon(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MenuAction.speed,
                child: Text(texts.speedButton(texts.speedName(settings.speed.name))),
              ),
              if (session.state.rules.trickReview != TrickReview.none)
                PopupMenuItem(value: _MenuAction.trickReview, child: Text(texts.menuTrickReview)),
              PopupMenuItem(value: _MenuAction.scoreboard, child: Text(texts.menuScoreboard)),
              PopupMenuItem(value: _MenuAction.rules, child: Text(texts.menuRules)),
              PopupMenuItem(value: _MenuAction.settings, child: Text(texts.menuSettings)),
              if (debugMenuAvailable)
                PopupMenuItem(value: _MenuAction.debug, child: Text(texts.menuDebug)),
              const PopupMenuDivider(),
              PopupMenuItem(value: _MenuAction.abandon, child: Text(texts.menuAbandon)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => _TableStage(
            session: session,
            motion: Motion.of(context, settings.speedFactor),
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

class _TableStage extends ConsumerStatefulWidget {
  const _TableStage({required this.session, required this.geometry, required this.motion});

  final GameSession session;
  final TableGeometry geometry;
  final Motion motion;

  @override
  ConsumerState<_TableStage> createState() => _TableStageState();
}

class _TableStageState extends ConsumerState<_TableStage> {
  /// Beim Bestaetigen: die zuerst angetippte Karte.
  JassCard? _selected;

  /// Vom Tipp empfohlene Karte.
  JassCard? _hint;

  GameSession get session => widget.session;

  TableGeometry get geometry => widget.geometry;

  @override
  void didUpdateWidget(_TableStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.revision != widget.session.revision) {
      _selected = null;
      _hint = null;
    }
  }

  void _act(GameAction action) {
    final violation = ref.read(gameControllerProvider.notifier).act(action);
    if (violation == RuleViolation.notYourTurn) {
      _notify(AppLocalizations.of(context).restrictionNotYourTurn);
    }
  }

  void _playCard(JassCard card) {
    final texts = AppLocalizations.of(context);
    final game = session.state;
    if (!session.humanTurn || game.phase != GamePhase.playing) {
      return;
    }
    final restriction = playRestriction(game.players[0].hand, game.trick, game.trickMode, card);
    if (restriction != null) {
      _notify(texts.restriction(restriction, game));
      return;
    }
    if (ref.read(settingsProvider).confirmPlay && _selected != card) {
      setState(() => _selected = card);
      _notify(texts.confirmPlayHint(texts.card(card)));
      return;
    }
    _act(PlayCard(0, card));
  }

  void _showHint() {
    final texts = AppLocalizations.of(context);
    final action = ref.read(gameControllerProvider.notifier).hint();
    switch (action) {
      case PlayCard(:final card):
        setState(() => _hint = card);
        _notify(texts.hintCard(texts.card(card)));
      case PlaceBid(:final value):
        _notify(texts.hintBid(value));
      case PassBid():
        _notify(texts.hintPass);
      case PushTrump():
        _notify(texts.hintPush);
      case ChooseMode(:final mode):
        _notify(texts.hintMode(texts.modeWithTrump(mode)));
      case DeclareWeis():
        _notify(texts.hintWeis);
      default:
        _notify(texts.hintNone);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _tapTable() {
    final controller = ref.read(gameControllerProvider.notifier);
    if (session.paused) {
      controller.resumeGame();
    } else {
      if (_selected != null) {
        setState(() => _selected = null);
      }
      controller.skipDelay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    final motion = widget.motion;
    final game = session.state;
    final seats = seatsFor(game.variant);
    final reveal = ref.watch(revealHandsProvider);
    final humanPlaying = session.humanTurn && game.phase == GamePhase.playing && !session.paused;
    final playable = humanPlaying ? playableCards(game, 0).toSet() : const <JassCard>{};
    final showTrick = game.phase != GamePhase.roundEnd && game.phase != GamePhase.gameOver;
    final feltRect = Rect.fromLTRB(8, 4, geometry.size.width - 8, geometry.size.height - 6);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tapTable,
      child: CustomPaint(
        painter: WoodGrainPainter(colors: colors),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Der Filz mit Messingkante, eingelassen in den Holzrand.
            Positioned.fromRect(
              rect: feltRect,
              child: _Felt(colors: colors),
            ),
            for (final MapEntry(key: playerIndex, value: seat) in seats.entries)
              if (seat != Seat.bottom)
                Positioned.fromRect(
                  rect: geometry.zones[seat]!,
                  child: _AiSeat(
                    geometry: geometry,
                    seat: seat,
                    motion: motion,
                    roundNumber: game.roundNumber,
                    name: game.players[playerIndex].name,
                    badge: texts.seatBadge(game, playerIndex),
                    active: game.isInteractive && game.currentPlayer == playerIndex,
                    cards: game.players[playerIndex].hand.length,
                    revealed: reveal ? game.players[playerIndex].hand : null,
                  ),
                ),
            Positioned.fromRect(
              rect: geometry.statusRect,
              child: _StatusRow(
                mode: texts.modeChip(game),
                message: session.paused ? texts.msgPaused : texts.phaseMessage(game),
                compact: geometry.compact,
              ),
            ),
            if (showTrick)
              Positioned.fill(
                child: TrickView(
                  geometry: geometry,
                  trick: game.trick,
                  seats: seats,
                  motion: motion,
                  collectTo: seats[game.trickLeader] ?? Seat.bottom,
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
                    motion: motion,
                    roundNumber: game.roundNumber,
                    selected: _selected,
                    highlighted: _hint,
                    onTap: _playCard,
                  ),
                ],
              ),
            ),
            // Tipp: unten rechts ueber der Hand, nur wenn der Mensch dran ist.
            if (session.humanTurn && !session.paused)
              Positioned(
                right: 12,
                top: geometry.handRect.top - 44,
                child: _HintButton(onPressed: _showHint),
              ),
            Positioned.fromRect(
              rect: geometry.center,
              child: EventToast(session: session, geometry: geometry, motion: motion),
            ),
            if (!session.paused)
              Positioned.fromRect(
                rect: geometry.panelRect,
                child: _Panel(session: session, onAction: _act),
              ),
          ],
        ),
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final colors = context.jass;
    return Material(
      color: colors.cream,
      borderRadius: BorderRadius.circular(4),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: colors.inkSoft),
              const SizedBox(width: 4),
              Text(
                texts.hintButton,
                style: JassFonts.ui(size: 13, weight: FontWeight.w800, color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der gruene Filz: heller in der Mitte, dunkler zum Rand, mit Messingring.
class _Felt extends StatelessWidget {
  const _Felt({required this.colors});

  final JassColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.brass, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.feltEdge, width: 3),
          gradient: RadialGradient(
            center: const Alignment(0, -0.1),
            radius: 1.1,
            colors: [colors.felt, colors.feltMid, colors.feltEdge],
            stops: const [0, 0.6, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: RadialGradient(
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
              ],
              stops: const [0, 0.7, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tischkarte und verdeckte Hand eines Computers; an den Seiten steht der
/// Faecher senkrecht.
class _AiSeat extends StatelessWidget {
  const _AiSeat({
    required this.geometry,
    required this.seat,
    required this.motion,
    required this.roundNumber,
    required this.name,
    required this.badge,
    required this.active,
    required this.cards,
    this.revealed,
  });

  final TableGeometry geometry;
  final Seat seat;
  final Motion motion;
  final int roundNumber;
  final String name;
  final String badge;
  final bool active;
  final int cards;

  /// Debug: die Karten offen zeigen.
  final List<JassCard>? revealed;

  @override
  Widget build(BuildContext context) {
    final label = SeatLabel(name: name, badge: badge, active: active);
    final hand = HiddenHandView(
      geometry: geometry,
      count: cards,
      motion: motion,
      roundNumber: roundNumber,
      revealed: revealed,
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
  const _StatusRow({required this.mode, required this.message, required this.compact});

  final String mode;
  final String message;

  /// Wenig Hoehe (Handy quer): Schild und Hinweis in einer Zeile.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    final chip = mode.isEmpty
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: colors.brassGradient,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            // Das Schild wird immer ausgeschrieben; reicht der Platz nicht,
            // rutscht der Hinweis in die naechste Zeile.
            child: Text(
              mode.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: JassFonts.ui(
                size: 11,
                weight: FontWeight.w800,
                color: colors.ink,
                letterSpacing: 0.6,
              ),
            ),
          );
    final text = Text(
      message,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style:
          JassFonts.serif(
            size: compact ? 14 : 15,
            weight: 600,
            italic: true,
            color: colors.cream,
            height: 1.2,
          ).copyWith(
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
    );

    if (compact) {
      return Row(
        children: [
          if (chip != null) Padding(padding: const EdgeInsets.only(right: 10), child: chip),
          Expanded(child: text),
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [?chip, text],
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
