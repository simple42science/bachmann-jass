import 'package:flutter/widgets.dart';

import '../../app/settings.dart';

/// Skaliert alle Animationsdauern am Tisch nach Tempo und Systemeinstellung.
///
/// Bei "Bewegung reduzieren" ist der Faktor 0: Animationen entfallen ganz.
@immutable
final class Motion {
  const Motion(this.scale);

  factory Motion.of(BuildContext context, GameSpeed speed) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const Motion(0);
    }
    return Motion(switch (speed) {
      GameSpeed.langsam => 1.25,
      GameSpeed.normal => 1.0,
      GameSpeed.schnell => 0.6,
    });
  }

  final double scale;

  bool get enabled => scale > 0;

  Duration ms(int milliseconds) => Duration(milliseconds: (milliseconds * scale).round());
}
