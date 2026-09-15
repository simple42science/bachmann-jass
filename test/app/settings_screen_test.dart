import 'package:bachmann_jass/app/settings.dart';
import 'package:bachmann_jass/game/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('Einstellungen aendern Hausregeln und werden gespeichert', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    final store = MemoryKeyValueStore();
    final container = await pumpApp(tester, overrides: testOverrides(store: store));

    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    expect(find.text('Hausregeln'), findsOneWidget);
    expect(find.text('Preset Bachmann'), findsOneWidget);

    // Bedanken einschalten: das Preset gilt damit als angepasst.
    await tester.ensureVisible(find.text('Bedanken'));
    await tester.tap(find.text('Bedanken'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).rules.bedanken, isTrue);
    expect(find.text('Angepasst'), findsOneWidget);
    expect(store.values[SettingsStore.key], contains('"bedanken":true'));

    // Zuruecksetzen stellt das Preset wieder her.
    await tester.ensureVisible(find.text('Auf Bachmann zurücksetzen'));
    await tester.tap(find.text('Auf Bachmann zurücksetzen'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).rules, RuleSet.bachmann);

    // Gegnername und Stich-Rueckblick.
    await tester.ensureVisible(find.text('Alle Stiche'));
    await tester.tap(find.text('Alle Stiche'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).rules.trickReview, TrickReview.all);

    final nameField = find.byType(TextField).first;
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Anna');
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).opponentNames.first, 'Anna');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Die Statistik ist leer, bis eine Partie endet', (tester) async {
    setScreenSize(tester, const Size(390, 844));
    await pumpApp(tester);
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Partie beendet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
