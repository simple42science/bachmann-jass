import 'dart:convert';

import 'package:meta/meta.dart';

import 'cards.dart';

/// Alles, was ein Spieler (Mensch oder Computer) an der Partie tun kann.
///
/// Aktionen sind reine Daten. Zusammen mit dem Seed beschreiben sie eine
/// Partie vollstaendig und lassen sich speichern, nachspielen oder spaeter
/// ueber ein Netzwerk senden.
@immutable
sealed class GameAction {
  const GameAction();

  factory GameAction.fromJson(Map<String, Object?> json) {
    int player() => json['player']! as int;
    return switch (json['type']) {
      'startRound' => const StartRound(),
      'bid' => PlaceBid(player(), json['value']! as int),
      'pass' => PassBid(player()),
      'push' => PushTrump(player()),
      'mode' => ChooseMode(player(), RoundMode.values.byName(json['mode']! as String)),
      'weis' => DeclareWeis(player(), json['weisId'] as String?),
      'declineWeis' => DeclineWeis(player()),
      'card' => PlayCard(player(), JassCard.fromId(json['card']! as String)),
      'nextTrick' => const NextTrick(),
      final type => throw FormatException('Unbekannte Aktion: $type'),
    };
  }

  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other) =>
      other is GameAction && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  @override
  String toString() => jsonEncode(toJson());
}

/// Neue Runde austeilen (zu Beginn und nach jeder Abrechnung).
final class StartRound extends GameAction {
  const StartRound();

  @override
  Map<String, Object?> toJson() => {'type': 'startRound'};
}

final class PlaceBid extends GameAction {
  const PlaceBid(this.playerIndex, this.value);

  final int playerIndex;
  final int value;

  @override
  Map<String, Object?> toJson() => {'type': 'bid', 'player': playerIndex, 'value': value};
}

final class PassBid extends GameAction {
  const PassBid(this.playerIndex);

  final int playerIndex;

  @override
  Map<String, Object?> toJson() => {'type': 'pass', 'player': playerIndex};
}

/// Vorhand schiebt die Spielartwahl an den Partner (nur Schieber).
final class PushTrump extends GameAction {
  const PushTrump(this.playerIndex);

  final int playerIndex;

  @override
  Map<String, Object?> toJson() => {'type': 'push', 'player': playerIndex};
}

final class ChooseMode extends GameAction {
  const ChooseMode(this.playerIndex, this.mode);

  final int playerIndex;
  final RoundMode mode;

  @override
  Map<String, Object?> toJson() => {'type': 'mode', 'player': playerIndex, 'mode': mode.name};
}

/// Weis melden. Ohne [weisId] wird der hoechste Weis gemeldet; wer keinen hat,
/// bestaetigt damit nur, dass er an der Reihe war.
final class DeclareWeis extends GameAction {
  const DeclareWeis(this.playerIndex, [this.weisId]);

  final int playerIndex;
  final String? weisId;

  @override
  Map<String, Object?> toJson() => {
    'type': 'weis',
    'player': playerIndex,
    if (weisId != null) 'weisId': weisId,
  };
}

/// Bewusst auf die Weis-Meldung verzichten.
final class DeclineWeis extends GameAction {
  const DeclineWeis(this.playerIndex);

  final int playerIndex;

  @override
  Map<String, Object?> toJson() => {'type': 'declineWeis', 'player': playerIndex};
}

/// Karte ausspielen. Ist der Stich damit voll, wird er sofort ausgewertet.
final class PlayCard extends GameAction {
  const PlayCard(this.playerIndex, this.card);

  final int playerIndex;
  final JassCard card;

  @override
  Map<String, Object?> toJson() => {'type': 'card', 'player': playerIndex, 'card': card.id};
}

/// Den ausgewerteten Stich abraeumen; der Gewinner spielt aus.
final class NextTrick extends GameAction {
  const NextTrick();

  @override
  Map<String, Object?> toJson() => {'type': 'nextTrick'};
}

/// Sitz, der die Aktion ausfuehrt; `null` bei Aktionen ohne Spieler.
int? actingPlayer(GameAction action) => switch (action) {
  PlaceBid(:final playerIndex) ||
  PassBid(:final playerIndex) ||
  PushTrump(:final playerIndex) ||
  ChooseMode(:final playerIndex) ||
  DeclareWeis(:final playerIndex) ||
  DeclineWeis(:final playerIndex) ||
  PlayCard(:final playerIndex) => playerIndex,
  StartRound() || NextTrick() => null,
};
