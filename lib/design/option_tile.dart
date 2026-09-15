import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Auswahlkachel fuer Setup und Spielartwahl.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.minWidth = 96,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    final subtitleText = subtitle;
    return Semantics(
      button: true,
      selected: selected,
      label: subtitleText == null ? title : '$title. $subtitleText',
      child: Material(
        color: selected
            ? colors.gold.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minWidth: minWidth, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? colors.gold : colors.border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? colors.goldLight : colors.text,
                        ),
                      ),
                      if (subtitleText != null)
                        Text(subtitleText, style: TextStyle(fontSize: 12, color: colors.muted)),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abschnittstitel mit Hinweiszeile rechts.
class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4, color: colors.text),
          ),
          if (hint != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint!,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
