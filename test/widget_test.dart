import 'package:bachmann_jass/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Startbildschirm zeigt Titel und verbundene Engine', (tester) async {
    await tester.pumpWidget(const BachmannJassApp());

    expect(find.text('Jass'), findsOneWidget);
    expect(find.text('36 Karten bereit'), findsOneWidget);
  });
}
