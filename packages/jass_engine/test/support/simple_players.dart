import 'package:jass_engine/jass_engine.dart';

JassCard card(String id) => JassCard.fromId(id);

GameState step(GameState state, GameAction action) => applyAction(state, action).state;

/// Einfache, deterministische Testspieler: der erste Bieter nimmt 60, Spielart
/// ist immer Rosen, gemeldet wird der hoechste Weis, gespielt die erste erlaubte Karte.
GameAction? simpleAction(GameState state) {
  final seat = state.currentPlayer;
  return switch (state.phase) {
    GamePhase.setup || GamePhase.roundEnd => const StartRound(),
    GamePhase.bidding =>
      seat == state.biddingOrder.first && state.highestBid == 0
          ? PlaceBid(seat, 60)
          : PassBid(seat),
    GamePhase.chooseTrump => ChooseMode(seat, RoundMode.rosen),
    GamePhase.announceWeis => DeclareWeis(seat),
    GamePhase.playing => PlayCard(seat, playableCards(state, seat).first),
    GamePhase.trickEnd => const NextTrick(),
    GamePhase.gameOver => null,
  };
}

/// Spielt bis zum Ende der laufenden Runde.
GameState finishRound(GameState state) {
  var current = state;
  do {
    current = step(current, simpleAction(current)!);
  } while (current.phase != GamePhase.roundEnd && current.phase != GamePhase.gameOver);
  return current;
}

/// Kopie von [state], in der [seat] die Hand [hand] haelt.
GameState withHand(GameState state, int seat, List<JassCard> hand) => state.copyWith(
  players: [
    for (final player in state.players) player.id == seat ? player.copyWith(hand: hand) : player,
  ],
);
