import 'package:flutter/widgets.dart';

/// Skaliert alle Animationsdauern am Tisch nach Tempo und Systemeinstellung.
///
/// Bei "Bewegung reduzieren" ist der Faktor 0: Animationen entfallen ganz.
@immutable
final class Motion {
  const Motion(this.scale);

  /// [speedFactor] ist das Tempo der Einstellungen (1.0 = normal).
  factory Motion.of(BuildContext context, double speedFactor) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const Motion(0);
    }
    return Motion(speedFactor.clamp(0.55, 1.3));
  }

  final double scale;

  bool get enabled => scale > 0;

  Duration ms(int milliseconds) => Duration(milliseconds: (milliseconds * scale).round());
}
