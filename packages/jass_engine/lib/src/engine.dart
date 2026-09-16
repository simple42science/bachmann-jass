import 'dart:math' as math;

import 'actions.dart';
import 'cards.dart';
import 'dealing.dart';
import 'errors.dart';
import 'events.dart';
import 'game_state.dart';
import 'internal.dart';
import 'model.dart';
import 'rng.dart';
import 'rule_set.dart';
import 'rules.dart';
import 'trick_play.dart';
import 'weis_phase.dart';

/// Ergebnis einer Aktion: neuer Zustand und die Ereignisse in ihrer Reihenfolge.
final class ActionResult {
  const ActionResult(this.state, this.events);

  final GameState state;
  final List<GameEvent> events;
}

/// Namen der Computergegner wie in der Web-App.
const List<String> defaultOpponentNames = ['Yannick', 'Papsli', 'Gusti'];

/// Die Rosen 7 bestimmt im Schieber den ersten Geber.
const JassCard schieberStartCard = JassCard(Suit.rosen, Rank.seven);

/// Sitz 0 ist der Mensch, die anderen Plaetze sind Computergegner.
List<SeatSetup> defaultSeats(GameVariant variant, {String humanName = 'Du'}) => [
  SeatSetup(name: humanName, isHuman: true),
  for (final name in defaultOpponentNames.take(variant.playerCount - 1))
    SeatSetup(name: name, isHuman: false),
];

/// Legt eine neue Partie an. Die erste Runde beginnt mit [StartRound].
///
/// Ohne [seed] wird ein zufaelliger gewaehlt; er steht danach in [GameState.seed].
GameState createGame({
  required GameVariant variant,
  MatchConfig? matchConfig,
  RuleSet rules = RuleSet.bachmann,
  List<SeatSetup>? seats,
  int? seed,
}) {
  final seatList = seats ?? defaultSeats(variant);
  if (seatList.length != variant.playerCount) {
    throw ArgumentError.value(
      seatList.length,
      'seats',
      '${variant.name} braucht ${variant.playerCount} Sitze',
    );
  }

  final gameSeed = (seed ?? Mulberry32.randomSeed()) & 0xFFFFFFFF;
  final isSchieber = variant == GameVariant.schieber;

  return GameState(
    variant: variant,
    matchConfig: matchConfig ?? MatchConfig(targetScore: variant.defaultTargetScore),
    rules: rules,
    seed: gameSeed,
    rngState: gameSeed,
    players: [
      for (var index = 0; index < seatList.length; index += 1)
        Player(
          id: index,
          name: seatList[index].name,
          isHuman: seatList[index].isHuman,
          difficulty: seatList[index].difficulty,
          // Schieber: Sitze 0/2 gegen 1/3. Bieterjass: Sitz 0 gegen 1 und 2 (wie die Web-App).
          teamId: isSchieber ? index % 2 : (index == 0 ? 0 : 1),
        ),
    ],
    teams: isSchieber
        ? const [
            Team(id: 0, playerIds: [0, 2]),
            Team(id: 1, playerIds: [1, 3]),
          ]
        : const [],
    phase: GamePhase.setup,
    roundNumber: 0,
    dealer: variant.playerCount - 1,
    currentPlayer: 0,
    biddingOrder: const [],
    biddingPassed: const [],
    highestBid: 0,
    highestBidder: -1,
    roundMode: null,
    soloPlayer: -1,
    chooserPlayer: -1,
    forehandPlayer: -1,
    trumpWasPushed: false,
    trick: const [],
    trickLeader: -1,
    trickNumber: 0,
    playedCards: const [],
    capturedCards: const [[], []],
    capturedTricks: const [0, 0],
    capturedPileOwners: const [0, 1],
    firstCapturedTrick: null,
    lastCapturedPile: null,
    teamWeisScores: const [0, 0],
    teamWeisBreakdown: const [[], []],
    teamStoeckPoints: const [0, 0],
    stoeckPlayer: -1,
    stoeckAnnounced: false,
    weisState: null,
    roundSummary: null,
    roundHistory: const [],
  );
}

/// Wendet eine Aktion an. Der uebergebene Zustand bleibt unveraendert.
///
/// Wirft [GameRuleException], wenn die Aktion gerade nicht erlaubt ist.
ActionResult applyAction(GameState state, GameAction action) {
  final events = <GameEvent>[];
  final next = switch (action) {
    StartRound() => _startRound(state, events),
    PlaceBid(:final playerIndex, :final value) => _bid(state, playerIndex, value, events),
    PassBid(:final playerIndex) => _bid(state, playerIndex, 0, events),
    PushTrump(:final playerIndex) => _pushTrump(state, playerIndex, events),
    ChooseMode(:final playerIndex, :final mode) => _chooseMode(state, playerIndex, mode, events),
    DeclareWeis(:final playerIndex, :final weisId) => declareWeis(
      state,
      playerIndex,
      weisId,
      events,
    ),
    DeclineWeis(:final playerIndex) => declineWeis(state, playerIndex, events),
    PlayCard(:final playerIndex, :final card) => playCard(state, playerIndex, card, events),
    NextTrick() => nextTrick(state, events),
  };
  return ActionResult(next, List.unmodifiable(events));
}

/// Darf Vorhand die Spielartwahl gerade an den Partner schieben?
bool canPushTrump(GameState state) =>
    state.isSchieber &&
    state.phase == GamePhase.chooseTrump &&
    !state.trumpWasPushed &&
    state.currentPlayer == state.forehandPlayer;

GameState _startRound(GameState state, List<GameEvent> events) {
  requirePhase(state, const {GamePhase.setup, GamePhase.roundEnd});

  final playerCount = state.players.length;
  final isFirstRound = state.roundNumber == 0;
  var dealer = isFirstRound ? state.dealer : (state.dealer + 1) % playerCount;

  final rng = Mulberry32(state.rngState);
  final hands = dealHands(playerCount, state.variant.dealPacketSize, dealer, rng);

  // Bieterjass: die Vorhand (nach dem Geber) sagt reihum an, auch fuer den
  // Bieter gilt keine Ausnahme. Beim Steigern ist sie die erste Bieterin.
  var forehand = state.isBieter ? (dealer + 1) % playerCount : -1;
  if (state.isSchieber) {
    // Die Rosen 7 bestimmt nur den ersten Geber. Danach ruecken Geber und
    // Vorhand jede Runde gemeinsam weiter.
    if (isFirstRound) {
      final holder = hands.indexWhere((hand) => hand.contains(schieberStartCard));
      forehand = holder >= 0 ? holder : 0;
      dealer = (forehand - 1 + playerCount) % playerCount;
    } else {
      forehand = (dealer + 1) % playerCount;
    }
  }

  // Im Bieterjass gilt das Gebot aus Runde 1 fuer die ganze Partie.
  final keepBidding = state.isBieter && state.soloPlayer >= 0;
  final dealt = state.copyWith(
    rngState: rng.state,
    players: [
      for (var index = 0; index < playerCount; index += 1)
        state.players[index].copyWith(
          hand: sortPlayerHand(hands[index]),
          bid: keepBidding ? state.players[index].bid : null,
          tricksWon: 0,
          pointsWon: 0,
        ),
    ],
    roundNumber: state.roundNumber + 1,
    dealer: dealer,
    currentPlayer: 0,
    biddingOrder: const [],
    biddingPassed: const [],
    highestBid: keepBidding ? state.highestBid : 0,
    highestBidder: keepBidding ? state.highestBidder : -1,
    roundMode: null,
    soloPlayer: keepBidding ? state.soloPlayer : -1,
    chooserPlayer: -1,
    forehandPlayer: forehand,
    trumpWasPushed: false,
    trick: const [],
    trickLeader: -1,
    trickNumber: 0,
    playedCards: const [],
    capturedCards: const [[], []],
    capturedTricks: const [0, 0],
    capturedPileOwners: const [0, 1],
    firstCapturedTrick: null,
    lastCapturedPile: null,
    roundTricks: const [],
    teamWeisScores: const [0, 0],
    teamWeisBreakdown: const [[], []],
    teamStoeckPoints: const [0, 0],
    stoeckPlayer: -1,
    stoeckAnnounced: false,
    weisState: null,
    roundSummary: null,
  );

  if (state.isBieter) {
    if (keepBidding) {
      events.add(
        RoundStarted(roundNumber: dealt.roundNumber, dealer: dealer, firstPlayer: forehand),
      );
      return dealt.copyWith(
        chooserPlayer: forehand,
        currentPlayer: forehand,
        phase: GamePhase.chooseTrump,
      );
    }
    final order = [
      for (var offset = 1; offset <= playerCount; offset += 1) (dealer + offset) % playerCount,
    ];
    events.add(
      RoundStarted(roundNumber: dealt.roundNumber, dealer: dealer, firstPlayer: order.first),
    );
    return dealt.copyWith(
      biddingOrder: order,
      currentPlayer: order.first,
      phase: GamePhase.bidding,
    );
  }

  events.add(RoundStarted(roundNumber: dealt.roundNumber, dealer: dealer, firstPlayer: forehand));
  return dealt.copyWith(
    chooserPlayer: forehand,
    currentPlayer: forehand,
    phase: GamePhase.chooseTrump,
  );
}

/// Tiefstes Gebot, das gerade noch erlaubt ist.
int minimumBid(GameState state) =>
    math.max(state.matchConfig.bieterStartBid, state.highestBid + bidStep);

/// Gebot oder Passen (`value == 0`) im Bieterjass. Gesteigert wird zu Beginn
/// der Partie: Der Hoechstbietende spielt die ganze Partie alleine und muss
/// sein Gebot erreichen, bevor die beiden anderen das Punkteziel erreichen.
GameState _bid(GameState state, int playerIndex, int value, List<GameEvent> events) {
  if (!state.isBieter) {
    throw const GameRuleException(RuleViolation.wrongVariant, 'Gebote gibt es nur im Bieterjass');
  }
  requirePhase(state, const {GamePhase.bidding});
  requireTurn(state, playerIndex);
  if (value < 0 || value > maxBid) {
    throw GameRuleException(RuleViolation.invalidBid, '$value');
  }
  if (value != 0 && value < minimumBid(state)) {
    throw GameRuleException(RuleViolation.bidTooLow, '$value < ${minimumBid(state)}');
  }

  final players = replacedAt(
    state.players,
    playerIndex,
    state.players[playerIndex].copyWith(bid: value),
  );

  GameState next;
  if (value == 0) {
    events.add(BidPassed(playerIndex));
    next = state.copyWith(players: players, biddingPassed: [...state.biddingPassed, playerIndex]);
  } else {
    events.add(BidPlaced(playerIndex, value));
    next = state.copyWith(players: players, highestBid: value, highestBidder: playerIndex);
  }

  // Gesteigert wird, bis alle bis auf einen gepasst haben.
  final active = next.biddingOrder.where((index) => !next.biddingPassed.contains(index)).toList();
  if (active.isEmpty || (active.length == 1 && next.highestBidder == active.first)) {
    return _finishBidding(next, events);
  }

  var current = nextPlayerIndex(next, playerIndex);
  while (next.biddingPassed.contains(current)) {
    current = nextPlayerIndex(next, current);
  }
  return next.copyWith(currentPlayer: current);
}

GameState _finishBidding(GameState state, List<GameEvent> events) {
  var next = state;
  final allPassed = state.highestBidder == -1;
  if (allPassed) {
    final forced = state.matchConfig.bieterStartBid;
    next = state.copyWith(
      highestBidder: state.dealer,
      highestBid: forced,
      players: replacedAt(
        state.players,
        state.dealer,
        state.players[state.dealer].copyWith(bid: forced),
      ),
    );
  }

  events.add(
    BiddingWon(playerIndex: next.highestBidder, bid: next.highestBid, allPassed: allPassed),
  );
  // Ab jetzt stehen die Seiten fest: der Bieter (Team 0) gegen die beiden
  // anderen (Team 1). Angesagt wird wie in jeder Runde von der Vorhand.
  final solo = next.highestBidder;
  return next.copyWith(
    players: [
      for (final player in next.players) player.copyWith(teamId: player.id == solo ? 0 : 1),
    ],
    soloPlayer: solo,
    currentPlayer: next.forehandPlayer,
    chooserPlayer: next.forehandPlayer,
    phase: GamePhase.chooseTrump,
  );
}

GameState _pushTrump(GameState state, int playerIndex, List<GameEvent> events) {
  if (!canPushTrump(state)) {
    throw const GameRuleException(RuleViolation.pushNotAllowed);
  }
  requireTurn(state, playerIndex);

  final partner = partnerOf(state, state.forehandPlayer);
  events.add(TrumpPushed(fromPlayer: state.forehandPlayer, toPlayer: partner));
  return state.copyWith(trumpWasPushed: true, chooserPlayer: partner, currentPlayer: partner);
}

GameState _chooseMode(GameState state, int playerIndex, RoundMode mode, List<GameEvent> events) {
  requirePhase(state, const {GamePhase.chooseTrump});
  requireTurn(state, playerIndex);
  if (!state.allowedRoundModes.contains(mode)) {
    throw GameRuleException(RuleViolation.modeNotAllowed, mode.name);
  }

  final leader = state.forehandPlayer;
  events.add(ModeChosen(playerIndex: playerIndex, mode: mode, leader: leader));
  final next = state.copyWith(roundMode: mode, trickLeader: leader);

  if (state.isSchieber) {
    return startWeisPhase(next, events);
  }
  return next.copyWith(phase: GamePhase.playing, currentPlayer: leader);
}
