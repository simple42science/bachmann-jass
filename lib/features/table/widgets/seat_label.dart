import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Namensschild eines Sitzplatzes mit Abzeichen (Geber, Partner, Gebot).
class SeatLabel extends StatelessWidget {
  const SeatLabel({super.key, required this.name, required this.badge, required this.active});

  final String name;
  final String badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? colors.gold.withValues(alpha: 0.22) : colors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? colors.gold : colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.circle, size: 8, color: colors.goldLight),
            ),
          Text(
            name,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colors.text),
          ),
          if (badge.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(badge, style: TextStyle(fontSize: 11, color: colors.goldLight)),
          ],
        ],
      ),
    );
  }
}
