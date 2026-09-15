@TestOn('vm')
library;

import 'package:test/test.dart';

import 'support/parity_fixtures.dart';

/// Die Dart-Engine spielt die Partien der Web-App nach (Golden Master).
///
/// Jede Aktion muss angenommen werden, jede Kartenverteilung und jeder
/// Rundenstand muss exakt mit der JS-Engine uebereinstimmen.
void main() {
  final fixtures = ParityFixture.loadAll();

  test('Paritaets-Fixtures sind vorhanden', () {
    expect(fixtures, isNotEmpty);
  });

  for (final fixture in fixtures) {
    test('Engine spielt wie die Web-App: ${fixture.name}', () {
      for (final game in fixture.games) {
        replayGame(fixture, game);
      }
    });
  }
}
