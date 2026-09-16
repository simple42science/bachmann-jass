import 'package:meta/meta.dart';

/// Die vier Farben des Schweizer Blatts, in der Reihenfolge der Web-App.
///
/// Die Reihenfolge ist Teil des Verhaltens: Sie bestimmt das ungemischte Deck
/// und damit jede Kartenverteilung eines Seeds.
enum Suit { eicheln, rosen, schellen, schilten }

/// Die neun Raenge von der Sechs bis zum Ass (natuerliche Reihenfolge).
enum Rank {
  six('6'),
  seven('7'),
  eight('8'),
  nine('9'),
  ten('10'),
  under('under'),
  ober('ober'),
  koenig('koenig'),
  ass('ass');

  const Rank(this.code);

  /// Bezeichner wie in Karten-IDs und Dateinamen der Kartenbilder.
  final String code;

  static Rank fromCode(String code) => values.firstWhere(
    (rank) => rank.code == code,
    orElse: () => throw FormatException('Unbekannter Rang: $code'),
  );
}

@immutable
final class JassCard {
  const JassCard(this.suit, this.rank);

  factory JassCard.fromId(String id) {
    final separator = id.indexOf('_');
    if (separator <= 0) {
      throw FormatException('Ungueltige Karten-ID: $id');
    }
    return JassCard(
      Suit.values.byName(id.substring(0, separator)),
      Rank.fromCode(id.substring(separator + 1)),
    );
  }

  /// Das ungemischte Deck: Farben aussen, Raenge innen.
  static final List<JassCard> deck = List.unmodifiable([
    for (final suit in Suit.values)
      for (final rank in Rank.values) JassCard(suit, rank),
  ]);

  final Suit suit;
  final Rank rank;

  /// Zum Beispiel `rosen_7`, identisch zur Web-App.
  String get id => '${suit.name}_${rank.code}';

  /// Position im ungemischten Deck (0 bis 35).
  int get deckIndex => suit.index * Rank.values.length + rank.index;

  @override
  bool operator ==(Object other) => other is JassCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => deckIndex;

  @override
  String toString() => id;
}

/// Spielart einer Runde. Die ersten vier sind Trumpffarben.
enum RoundMode {
  eicheln(Suit.eicheln),
  rosen(Suit.rosen),
  schellen(Suit.schellen),
  schilten(Suit.schilten),
  obeAbe(null),
  uneUfe(null),

  /// Slalom, der obenabe beginnt (der Slalom der Web-App).
  slalom(null),

  /// Slalom, der unten-ufe beginnt.
  slalomUneUfe(null);

  const RoundMode(this.trumpSuit);

  final Suit? trumpSuit;

  bool get isTrump => trumpSuit != null;

  bool get isSlalom => this == slalom || this == slalomUneUfe;

  /// Grundform fuer Regeln, Multiplikatoren und Texte: beide Slaloms sind Slalom.
  RoundMode get base => this == slalomUneUfe ? slalom : this;

  static const List<RoundMode> trumpModes = [eicheln, rosen, schellen, schilten];

  /// Die sieben Spielarten der Regeln, ohne die zweite Slalom-Richtung.
  static const List<RoundMode> baseModes = [
    eicheln,
    rosen,
    schellen,
    schilten,
    obeAbe,
    uneUfe,
    slalom,
  ];

  static RoundMode forSuit(Suit suit) => trumpModes[suit.index];

  /// Im Slalom wechselt die Spielart mit jedem Stich: der erste Stich geht in
  /// die angesagte Richtung, der zweite in die andere und so weiter. Alle
  /// anderen Spielarten bleiben gleich.
  RoundMode trickMode(int trickNumber) {
    if (!isSlalom) {
      return this;
    }
    final startsHigh = this == slalom;
    return trickNumber.isEven == startsHigh ? obeAbe : uneUfe;
  }
}

// Indexiert mit Rank.index: 6, 7, 8, 9, 10, Under, Ober, Koenig, Ass.
const List<int> _basePoints = [0, 0, 0, 0, 10, 2, 3, 4, 11];
const List<int> _trumpPoints = [0, 0, 0, 14, 10, 20, 3, 4, 11];
const List<int> _obeAbePoints = [0, 0, 8, 0, 10, 2, 3, 4, 11];
const List<int> _uneUfePoints = [11, 0, 8, 0, 10, 2, 3, 4, 0];

// Staerke im Trumpf, indexiert mit Rank.index: 6 < 7 < 8 < 10 < Ober < Koenig < Ass < Nell < Puur.
const List<int> _trumpStrength = [0, 1, 2, 7, 3, 8, 4, 5, 6];

/// Kartenwert in einer Spielart. Slalom ohne Stichnummer zaehlt wie der erste
/// Stich (obenabe); ohne Spielart gelten die Grundwerte.
int cardPoints(JassCard card, RoundMode? roundMode) {
  final mode = roundMode?.trickMode(0);
  switch (mode) {
    case RoundMode.obeAbe:
      return _obeAbePoints[card.rank.index];
    case RoundMode.uneUfe:
      return _uneUfePoints[card.rank.index];
    default:
      return mode != null && card.suit == mode.trumpSuit
          ? _trumpPoints[card.rank.index]
          : _basePoints[card.rank.index];
  }
}

/// Staerke einer Karte innerhalb ihrer Farbe; hoeher sticht.
int rankIndex(JassCard card, RoundMode? roundMode) {
  final mode = roundMode?.trickMode(0);
  if (mode == RoundMode.uneUfe) {
    return Rank.values.length - 1 - card.rank.index;
  }
  if (mode != null && card.suit == mode.trumpSuit) {
    return _trumpStrength[card.rank.index];
  }
  return card.rank.index;
}
