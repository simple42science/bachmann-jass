import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Zerlegt Punkte in die Striche der Jasstafel.
///
/// Auf der klassischen Schiefertafel stehen Hunderter als Striche auf der
/// oberen Linie, ein Fuenfziger auf der Schraegen, Zwanziger auf der unteren
/// Linie; der Rest unter zwanzig wird als Zahl notiert.
({int hundreds, int fifty, int twenties, int ones}) zTafelStrokes(int points) {
  final total = math.max(0, points);
  final hundreds = total ~/ 100;
  var rest = total % 100;
  final fifty = rest ~/ 50;
  rest %= 50;
  final twenties = rest ~/ 20;
  return (hundreds: hundreds, fifty: fifty, twenties: twenties, ones: rest % 20);
}

/// Kreidestriche eines Teams auf der Jasstafel.
class ZTafelPainter extends CustomPainter {
  const ZTafelPainter({required this.points, required this.chalk});

  final int points;
  final Color chalk;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = chalk.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stroke = Paint()
      ..color = chalk
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final top = size.height * 0.18;
    final bottom = size.height * 0.82;
    final right = size.width - 4;
    const left = 4.0;

    // Der Rahmen: obere Linie, Schraege, untere Linie - das "Z".
    canvas.drawLine(Offset(left, top), Offset(right, top), frame);
    canvas.drawLine(Offset(right, top), Offset(left, bottom), frame);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), frame);

    final marks = zTafelStrokes(points);
    // Leichtes Zittern, damit die Striche wie von Hand wirken.
    final random = math.Random(points);
    double jitter() => (random.nextDouble() - 0.5) * 1.6;

    void tally(int count, double y, double start) {
      const step = 8.0;
      final reach = size.height * 0.16;
      var x = start;
      for (var index = 0; index < count; index += 1) {
        if (index % 5 == 4) {
          // Der fuenfte Strich streicht das Buendel durch.
          canvas.drawLine(
            Offset(x - 4 * step - 2, y + reach * 0.4 + jitter()),
            Offset(x + 2, y - reach * 0.4 + jitter()),
            stroke,
          );
        } else {
          canvas.drawLine(
            Offset(x + jitter(), y - reach + jitter()),
            Offset(x + jitter(), y + reach + jitter()),
            stroke,
          );
        }
        x += step;
      }
    }

    tally(marks.hundreds, top, left + 10);
    tally(marks.twenties, bottom, left + 10);

    if (marks.fifty > 0) {
      final center = Offset((left + right) / 2, (top + bottom) / 2);
      canvas.drawLine(
        center + Offset(-5 + jitter(), -7 + jitter()),
        center + Offset(5 + jitter(), 7 + jitter()),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(ZTafelPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.chalk != chalk;
}
