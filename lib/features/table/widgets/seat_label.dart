import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Tischkarte eines Sitzplatzes: Karton mit Namen und Abzeichen (Geber,
/// Partner, Gebot). Wer am Zug ist, bekommt die goldene Karte.
class SeatLabel extends StatelessWidget {
  const SeatLabel({super.key, required this.name, required this.badge, required this.active});

  final String name;
  final String badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? colors.brassGlow : colors.cream,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? colors.brass : Colors.transparent, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: JassFonts.ui(size: 13, weight: FontWeight.w800, color: colors.ink),
          ),
          if (badge.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              badge,
              style: JassFonts.ui(size: 11, weight: FontWeight.w600, color: colors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}
