import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'cards.dart';
import 'rule_set.dart';

enum WeisType { sequence, fourOfKind }

/// Punkte fuer eine Folge nach Anzahl Karten.
const Map<int, int> sequencePoints = {3: 20, 4: 50, 5: 100, 6: 150, 7: 200, 8: 250, 9: 300};

@immutable
final class Weis {
  const Weis({
    required this.id,
    required this.type,
    required this.points,
    required this.suit,
    required this.cards,
    required this.lowRank,
    required this.highRank,
    required this.relevantRank,
    this.playerIndex,
  });

  factory Weis.fromJson(Map<String, Object?> json) => Weis(
    id: json['id']! as String,
    type: WeisType.values.byName(json['type']! as String),
    points: json['points']! as int,
    suit: json['suit'] == null ? null : Suit.values.byName(json['suit']! as String),
    cards: [for (final id in json['cards']! as List<Object?>) JassCard.fromId(id! as String)],
    lowRank: Rank.fromCode(json['lowRank']! as String),
    highRank: Rank.fromCode(json['highRank']! as String),
    relevantRank: Rank.fromCode(json['relevantRank']! as String),
    playerIndex: json['playerIndex'] as int?,
  );

  /// Stabil und eindeutig pro Hand, zum Beispiel `sequence:rosen:6:8`.
  final String id;
  final WeisType type;
  final int points;

  /// Farbe einer Folge; bei vier Gleichen `null`.
  final Suit? suit;
  final List<JassCard> cards;
  final Rank lowRank;
  final Rank highRank;

  /// Entscheidet bei gleicher Punktzahl: die hoechste Karte, bei Une-Ufe die tiefste.
  final Rank relevantRank;

  /// Wer den Weis haelt; `null`, solange er nur auf einer Hand erkannt wurde.
  final int? playerIndex;

  int get length => cards.length;

  List<Rank> get ranks => [for (final card in cards) card.rank];

  Weis withPlayer(int index) => Weis(
    id: id,
    type: type,
    points: points,
    suit: suit,
    cards: cards,
    lowRank: lowRank,
    highRank: highRank,
    relevantRank: relevantRank,
    playerIndex: index,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'points': points,
    'suit': suit?.name,
    'cards': [for (final card in cards) card.id],
    'lowRank': lowRank.code,
    'highRank': highRank.code,
    'relevantRank': relevantRank.code,
    'playerIndex': playerIndex,
  };
}

int fourOfAKindPoints(Rank rank, RuleSet rules) {
  if (rank == Rank.six && !rules.fourSixesCount) {
    return 0;
  }
  if (rank == Rank.under) {
    return 200;
  }
  if (rank == Rank.nine) {
    return 150;
  }
  return 100;
}

/// Positiv, wenn [first] staerker ist. `mode` ist die Weis-Spielart
/// (im Slalom die des ersten Stichs).
int compareWeis(Weis? first, Weis? second, RoundMode? mode, RuleSet rules) {
  if (first == null && second == null) {
    return 0;
  }
  if (first == null) {
    return -1;
  }
  if (second == null) {
    return 1;
  }
  if (first.points != second.points) {
    return first.points > second.points ? 1 : -1;
  }
  if (first.type != second.type) {
    final strongerType = rules.fourOfAKindBeatsSequence ? WeisType.fourOfKind : WeisType.sequence;
    return first.type == strongerType ? 1 : -1;
  }

  final firstRank = first.relevantRank.index;
  final secondRank = second.relevantRank.index;
  if (firstRank != secondRank) {
    if (mode == RoundMode.uneUfe) {
      return firstRank < secondRank ? 1 : -1;
    }
    return firstRank > secondRank ? 1 : -1;
  }

  final trump = mode?.trumpSuit;
  final firstTrumpWise = trump != null && first.type == WeisType.sequence && first.suit == trump;
  final secondTrumpWise = trump != null && second.type == WeisType.sequence && second.suit == trump;
  if (firstTrumpWise != secondTrumpWise) {
    return firstTrumpWise ? 1 : -1;
  }
  return 0;
}

/// Staerkster Weis zuerst; bei Gleichstand entscheidet die ID.
List<Weis> sortWeisDescending(Iterable<Weis> weisen, RoundMode? mode, RuleSet rules) {
  final sorted = [...weisen];
  mergeSort(
    sorted,
    compare: (Weis first, Weis second) {
      final comparison = compareWeis(second, first, mode, rules);
      return comparison != 0 ? comparison : first.id.compareTo(second.id);
    },
  );
  return sorted;
}

Weis? highestWeis(Iterable<Weis> weisen, RoundMode? mode, RuleSet rules) =>
    sortWeisDescending(weisen, mode, rules).firstOrNull;

/// Alle Folgen ab drei Karten und alle gueltigen vier Gleichen einer Hand.
List<Weis> detectWeis(List<JassCard> hand, RoundMode? mode, RuleSet rules) {
  final sequences = <Weis>[];

  for (final suit in Suit.values) {
    final suited = hand.where((card) => card.suit == suit).toList();
    mergeSort(suited, compare: (JassCard a, JassCard b) => a.rank.index - b.rank.index);

    var run = <JassCard>[];
    for (var index = 0; index < suited.length; index += 1) {
      final card = suited[index];
      if (run.isEmpty) {
        run.add(card);
      } else if (card.rank.index == suited[index - 1].rank.index + 1) {
        run.add(card);
      } else {
        if (run.length >= 3) {
          sequences.add(_sequenceWeis(run, mode));
        }
        run = [card];
      }
    }
    if (run.length >= 3) {
      sequences.add(_sequenceWeis(run, mode));
    }
  }

  final fourOfKinds = <Weis>[];
  for (final rank in Rank.values) {
    final sameRank = hand.where((card) => card.rank == rank).toList();
    if (sameRank.length == 4 && fourOfAKindPoints(rank, rules) > 0) {
      fourOfKinds.add(
        Weis(
          id: 'fourOfKind:${rank.code}',
          type: WeisType.fourOfKind,
          points: fourOfAKindPoints(rank, rules),
          suit: null,
          cards: sameRank,
          lowRank: rank,
          highRank: rank,
          relevantRank: rank,
        ),
      );
    }
  }

  return sortWeisDescending([...sequences, ...fourOfKinds], mode, rules);
}

Weis _sequenceWeis(List<JassCard> run, RoundMode? mode) {
  final low = run.first.rank;
  final high = run.last.rank;
  return Weis(
    id: 'sequence:${run.first.suit.name}:${low.code}:${high.code}',
    type: WeisType.sequence,
    points: sequencePoints[run.length]!,
    suit: run.first.suit,
    cards: List.unmodifiable(run),
    lowRank: low,
    highRank: high,
    relevantRank: mode == RoundMode.uneUfe ? low : high,
  );
}

/// Koenig und Ober der Trumpffarbe auf einer Hand.
bool hasStoeck(List<JassCard> hand, RoundMode? mode) {
  final trump = mode?.trumpSuit;
  if (trump == null) {
    return false;
  }
  return hand.contains(JassCard(trump, Rank.koenig)) && hand.contains(JassCard(trump, Rank.ober));
}
