import 'package:meta/meta.dart';

import 'cards.dart';
import 'model.dart';
import 'round.dart';
import 'weis.dart';

/// Was durch eine Aktion geschehen ist, in der Reihenfolge des Geschehens.
///
/// Die Engine erzeugt keine Texte. Aus diesen Ereignissen entstehen in der App
/// Animationen, Sounds, der Spielverlauf und die Statistik.
@immutable
sealed class GameEvent {
  const GameEvent();
}

final class RoundStarted extends GameEvent {
  const RoundStarted({required this.roundNumber, required this.dealer, required this.firstPlayer});

  final int roundNumber;
  final int dealer;

  /// Wer als erster bietet (Bieterjass) oder die Spielart waehlt (Schieber).
  final int firstPlayer;
}

final class BidPlaced extends GameEvent {
  const BidPlaced(this.playerIndex, this.value);

  final int playerIndex;
  final int value;
}

final class BidPassed extends GameEvent {
  const BidPassed(this.playerIndex);

  final int playerIndex;
}

final class BiddingWon extends GameEvent {
  const BiddingWon({required this.playerIndex, required this.bid, required this.allPassed});

  final int playerIndex;
  final int bid;

  /// Alle haben gepasst; der Geber muss mit dem Pflichtgebot spielen.
  final bool allPassed;
}

final class TrumpPushed extends GameEvent {
  const TrumpPushed({required this.fromPlayer, required this.toPlayer});

  final int fromPlayer;
  final int toPlayer;
}

final class ModeChosen extends GameEvent {
  const ModeChosen({required this.playerIndex, required this.mode, required this.leader});

  final int playerIndex;
  final RoundMode mode;

  /// Wer den ersten Stich ausspielt.
  final int leader;
}

/// Ein Spieler war in der Weisrunde an der Reihe; [weis] ist `null`, wenn er nichts meldet.
final class WeisDeclared extends GameEvent {
  const WeisDeclared(this.playerIndex, this.weis);

  final int playerIndex;
  final Weis? weis;
}

final class WeisAwarded extends GameEvent {
  const WeisAwarded({
    required this.teamId,
    required this.points,
    required this.weisen,
    required this.best,
  });

  final int teamId;
  final int points;

  /// Alle Weise, die das Team schreibt.
  final List<Weis> weisen;

  /// Der Weis, der den Vergleich entschieden hat.
  final WeisDeclaration best;
}

final class NoWeisAwarded extends GameEvent {
  const NoWeisAwarded();
}

final class StoeckAnnounced extends GameEvent {
  const StoeckAnnounced({required this.playerIndex, required this.points, required this.inWeis});

  final int playerIndex;
  final int points;

  /// Beide Karten steckten in einem gemeldeten Weis.
  final bool inWeis;
}

final class CardPlayed extends GameEvent {
  const CardPlayed(this.playerIndex, this.card);

  final int playerIndex;
  final JassCard card;
}

final class TrickWon extends GameEvent {
  const TrickWon({
    required this.winner,
    required this.pileId,
    required this.points,
    required this.trickNumber,
    required this.cards,
    required this.isLastTrick,
  });

  final int winner;
  final int pileId;

  /// Stichpunkte inklusive Bonus fuer den letzten Stich.
  final int points;

  /// Nummer des Stichs, beginnend bei 1.
  final int trickNumber;
  final List<TrickEntry> cards;
  final bool isLastTrick;
}

final class NextTrickStarted extends GameEvent {
  const NextTrickStarted(this.leader);

  final int leader;
}

final class RoundScored extends GameEvent {
  const RoundScored(this.summary);

  final RoundSummary summary;
}

final class GameOver extends GameEvent {
  const GameOver({this.winnerPlayer, this.winnerTeam, required this.variant});

  final GameVariant variant;

  /// Sieger im Bieterjass.
  final int? winnerPlayer;

  /// Siegerteam im Schieber.
  final int? winnerTeam;
}
