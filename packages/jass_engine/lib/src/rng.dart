import 'dart:math' as math;

/// Reproduzierbarer Zufall (mulberry32), bitgenau wie `setRandomSeed` der Web-App.
///
/// Auf dem Web rechnet Dart mit JavaScript-Zahlen. Darum wird jede Operation
/// explizit auf 32 Bit begrenzt und die Multiplikation in 16-Bit-Haelften
/// zerlegt; ein direktes `a * b` wuerde dort ab 2^53 ungenau.
final class Mulberry32 {
  Mulberry32(int state) : _state = state & _mask32;

  static const int _mask32 = 0xFFFFFFFF;
  static const int _increment = 0x6d2b79f5;

  int _state;

  /// Aktueller Zustand; damit laesst sich die Folge spaeter fortsetzen.
  int get state => _state;

  /// Zufallszahl in [0, 1).
  double nextDouble() {
    _state = (_state + _increment) & _mask32;
    var t = _state;
    t = _imul32(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul32(t ^ (t >>> 7), t | 61)) & _mask32)) & _mask32;
    return ((t ^ (t >>> 14)) & _mask32) / 4294967296;
  }

  /// Neuer, zufaelliger Seed fuer eine Partie ohne vorgegebenen Seed.
  static int randomSeed([math.Random? random]) => (random ?? math.Random()).nextInt(0x100000000);

  /// `Math.imul` fuer vorzeichenlose 32-Bit-Werte, auf VM und Web exakt.
  static int _imul32(int a, int b) {
    final aHigh = (a >>> 16) & 0xFFFF;
    final aLow = a & 0xFFFF;
    final bHigh = (b >>> 16) & 0xFFFF;
    final bLow = b & 0xFFFF;
    final middle = ((aHigh * bLow + aLow * bHigh) & 0xFFFF) << 16;
    return (aLow * bLow + middle) & _mask32;
  }
}
