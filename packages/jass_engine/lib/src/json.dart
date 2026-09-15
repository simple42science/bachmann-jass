import 'cards.dart';

/// Platzhalter fuer `copyWith`: unterscheidet "nicht angegeben" von `null`.
const Object unchanged = Object();

List<String> cardsToJson(Iterable<JassCard> cards) => [for (final card in cards) card.id];

List<JassCard> cardsFromJson(Object? json) => [
  for (final id in json! as List<Object?>) JassCard.fromId(id! as String),
];

List<int> intsFromJson(Object? json) => [for (final value in json! as List<Object?>) value! as int];

/// JSON kennt nur String-Schluessel; Sitzplaetze werden als "0", "1", ... abgelegt.
Map<String, Object?> intKeyedToJson<V>(Map<int, V> map, Object? Function(V value) encode) => {
  for (final entry in map.entries) '${entry.key}': encode(entry.value),
};

Map<int, V> intKeyedFromJson<V>(Object? json, V Function(Object? value) decode) => {
  for (final entry in (json! as Map<String, Object?>).entries)
    int.parse(entry.key): decode(entry.value),
};
