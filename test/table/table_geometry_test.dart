import 'dart:ui';

import 'package:bachmann_jass/features/table/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jass_engine/jass_engine.dart';

/// Fensterflaeche unter der Kopfzeile, von iPhone SE bis Desktop.
const Map<String, Size> screens = {
  'iPhone SE': Size(320, 512),
  'Handy hoch': Size(390, 744),
  'Handy quer': Size(844, 334),
  'Tablet hoch': Size(768, 968),
  'Tablet quer': Size(1024, 712),
  'Desktop': Size(1440, 724),
};

void main() {
  for (final MapEntry(key: name, value: size) in screens.entries) {
    for (final variant in GameVariant.values) {
      test('$name, ${variant.name}: alles hat Platz und nichts ueberlappt', () {
        final geometry = TableGeometry.compute(size: size, variant: variant);
        final bounds = Offset.zero & size;

        expect(geometry.handWidth(variant.handSize), lessThanOrEqualTo(size.width));
        expect(geometry.cardSize.width, inInclusiveRange(40, 150));
        expect(geometry.handRect.bottom, lessThanOrEqualTo(size.height));

        for (final MapEntry(key: seat, value: zone) in geometry.zones.entries) {
          expect(bounds.contains(zone.topLeft), isTrue, reason: '$seat innerhalb');
          expect(zone.width, greaterThan(0), reason: '$seat hat Breite');
          expect(zone.height, greaterThan(0), reason: '$seat hat Hoehe');
          if (seat != Seat.bottom) {
            expect(zone.bottom, lessThanOrEqualTo(geometry.handRect.top + 0.01));
          }
        }

        final left = geometry.zones[Seat.left]!;
        final right = geometry.zones[Seat.right]!;
        expect(left.right, lessThan(right.left), reason: 'Seiten getrennt');
        expect(
          geometry.aiFanLength(variant.handSize),
          lessThanOrEqualTo(left.height - TableGeometry.labelHeight - 8 + 0.01),
          reason: 'Seitlicher Faecher passt unter das Namensschild',
        );

        expect(geometry.center.width, greaterThan(100));
        expect(geometry.center.height, greaterThan(60));
        expect(geometry.trickCardSize.width, inInclusiveRange(30, geometry.cardSize.width * 1.1));

        final trickArea = Rect.fromLTRB(
          geometry.center.left,
          geometry.statusRect.bottom,
          geometry.center.right,
          geometry.center.bottom,
        );
        for (final MapEntry(key: seat, value: slot) in geometry.trickSlots.entries) {
          final cardRect = Rect.fromCenter(
            center: slot,
            width: geometry.trickCardSize.width,
            height: geometry.trickCardSize.height,
          );
          expect(
            trickArea.inflate(2).contains(cardRect.topLeft) &&
                trickArea.inflate(2).contains(cardRect.bottomRight),
            isTrue,
            reason: '$seat: Stichkarte $cardRect liegt in $trickArea',
          );
        }
      });
    }
  }

  test('Die Sitzplaetze folgen der Web-App', () {
    expect(seatsFor(GameVariant.bieter), {0: Seat.bottom, 1: Seat.left, 2: Seat.right});
    expect(seatsFor(GameVariant.schieber), {
      0: Seat.bottom,
      1: Seat.left,
      2: Seat.top,
      3: Seat.right,
    });
  });
}
