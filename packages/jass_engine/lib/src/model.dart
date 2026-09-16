import 'package:meta/meta.dart';

import 'cards.dart';
import 'json.dart';

enum GameVariant {
  bieter(playerCount: 3, handSize: 12, dealPacketSize: 3, defaultTargetScore: 1000),
  schieber(playerCount: 4, handSize: 9, dealPacketSize: 3, defaultTargetScore: 1000);

  const GameVariant({
    required this.playerCount,
    required this.handSize,
    required this.dealPacketSize,
    required this.defaultTargetScore,
  });

  final int playerCount;
  final int handSize;
  final int dealPacketSize;
  final int defaultTargetScore;
}

enum Difficulty { einfach, normal, schwer }

/// Zaehlweise im Bieterjass: nur Farben einfach, oder alle Spielarten mit Multiplikator.
enum BieterScoring { einfach, schieber }

enum GamePhase { setup, bidding, chooseTrump, announceWeis, playing, trickEnd, roundEnd, gameOver }

/// Bieterjass: uebliche Anfangsgebote, Schrittweite und Obergrenze des Steigerns.
const List<int> bieterStartBids = [400, 450, 500];
const int bidStep = 10;
const int maxBid = 2000;

@immutable
final class MatchConfig {
  const MatchConfig({
    required this.targetScore,
    this.difficulty = Difficulty.normal,
    this.bieterScoring = BieterScoring.einfach,
    this.bieterStartBid = 450,
  });

  factory MatchConfig.fromJson(Map<String, Object?> json) => MatchConfig(
    targetScore: json['targetScore']! as int,
    difficulty: Difficulty.values.byName(json['difficulty']! as String),
    bieterScoring: BieterScoring.values.byName(json['bieterScoring']! as String),
    bieterStartBid: json['bieterStartBid'] as int? ?? 450,
  );

  /// Schieber: Ziel beider Teams. Bieterjass: Ziel der beiden, die zusammen
  /// gegen den Bieter spielen (1000); der Bieter muss sein Gebot erreichen.
  final int targetScore;

  /// Standardstufe fuer alle Computergegner ohne eigene Stufe.
  final Difficulty difficulty;

  /// Nur im Bieterjass relevant.
  final BieterScoring bieterScoring;

  /// Bieterjass: Mit diesem Wert beginnt das Steigern zu Beginn der Partie.
  final int bieterStartBid;

  Map<String, Object?> toJson() => {
    'targetScore': targetScore,
    'difficulty': difficulty.name,
    'bieterScoring': bieterScoring.name,
    'bieterStartBid': bieterStartBid,
  };
}

/// Beschreibung eines Sitzplatzes beim Anlegen einer Partie.
@immutable
final class SeatSetup {
  const SeatSetup({required this.name, required this.isHuman, this.difficulty});

  final String name;
  final bool isHuman;

  /// Eigene Stufe dieses Computergegners; sonst gilt die Stufe der Partie.
  final Difficulty? difficulty;
}

@immutable
final class Player {
  const Player({
    required this.id,
    required this.name,
    required this.isHuman,
    required this.teamId,
    this.difficulty,
    this.hand = const [],
    this.bid,
    this.tricksWon = 0,
    this.pointsWon = 0,
    this.totalScore = 0,
  });

  factory Player.fromJson(Map<String, Object?> json) => Player(
    id: json['id']! as int,
    name: json['name']! as String,
    isHuman: json['isHuman']! as bool,
    teamId: json['teamId']! as int,
    difficulty: json['difficulty'] == null
        ? null
        : Difficulty.values.byName(json['difficulty']! as String),
    hand: cardsFromJson(json['hand']),
    bid: json['bid'] as int?,
    tricksWon: json['tricksWon']! as int,
    pointsWon: json['pointsWon']! as int,
    totalScore: json['totalScore']! as int,
  );

  final int id;
  final String name;
  final bool isHuman;
  final int teamId;
  final Difficulty? difficulty;
  final List<JassCard> hand;

  /// Gebot im Bieterjass: `null` = noch nicht geboten, `0` = gepasst.
  final int? bid;
  final int tricksWon;

  /// Stichpunkte der laufenden Runde (inklusive letztem Stich).
  final int pointsWon;

  /// Spielpunkte der Partie (nur im Bieterjass; im Schieber zaehlt das Team).
  final int totalScore;

  Player copyWith({
    List<JassCard>? hand,
    Object? bid = unchanged,
    int? teamId,
    int? tricksWon,
    int? pointsWon,
    int? totalScore,
  }) => Player(
    id: id,
    name: name,
    isHuman: isHuman,
    teamId: teamId ?? this.teamId,
    difficulty: difficulty,
    hand: hand ?? this.hand,
    bid: identical(bid, unchanged) ? this.bid : bid as int?,
    tricksWon: tricksWon ?? this.tricksWon,
    pointsWon: pointsWon ?? this.pointsWon,
    totalScore: totalScore ?? this.totalScore,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'isHuman': isHuman,
    'teamId': teamId,
    'difficulty': difficulty?.name,
    'hand': cardsToJson(hand),
    'bid': bid,
    'tricksWon': tricksWon,
    'pointsWon': pointsWon,
    'totalScore': totalScore,
  };
}

@immutable
final class Team {
  const Team({required this.id, required this.playerIds, this.totalScore = 0});

  factory Team.fromJson(Map<String, Object?> json) => Team(
    id: json['id']! as int,
    playerIds: intsFromJson(json['playerIds']),
    totalScore: json['totalScore']! as int,
  );

  final int id;
  final List<int> playerIds;
  final int totalScore;

  Team copyWith({int? totalScore}) =>
      Team(id: id, playerIds: playerIds, totalScore: totalScore ?? this.totalScore);

  Map<String, Object?> toJson() => {'id': id, 'playerIds': playerIds, 'totalScore': totalScore};
}

@immutable
final class TrickEntry {
  const TrickEntry(this.playerIndex, this.card);

  factory TrickEntry.fromJson(Map<String, Object?> json) =>
      TrickEntry(json['playerIndex']! as int, JassCard.fromId(json['card']! as String));

  final int playerIndex;
  final JassCard card;

  Map<String, Object?> toJson() => {'playerIndex': playerIndex, 'card': card.id};
}

List<TrickEntry> trickFromJson(Object? json) => [
  for (final entry in json! as List<Object?>) TrickEntry.fromJson(entry! as Map<String, Object?>),
];

List<Map<String, Object?>> trickToJson(Iterable<TrickEntry> trick) => [
  for (final entry in trick) entry.toJson(),
];

/// Ein eingesammelter Stich mit Stapel und Gewinner.
@immutable
final class CapturedTrick {
  const CapturedTrick({required this.pileId, required this.winner, required this.cards});

  factory CapturedTrick.fromJson(Map<String, Object?> json) => CapturedTrick(
    pileId: json['pileId']! as int,
    winner: json['winner']! as int,
    cards: trickFromJson(json['cards']),
  );

  final int pileId;
  final int winner;
  final List<TrickEntry> cards;

  Map<String, Object?> toJson() => {
    'pileId': pileId,
    'winner': winner,
    'cards': trickToJson(cards),
  };
}
