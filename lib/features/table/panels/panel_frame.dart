import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Rahmen fuer Bedien-Panels ueber dem Tisch: ein dunkles Holzbrett mit
/// Messingkante, begrenzt breit, bei wenig Hoehe scrollbar.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.maxWidth = 460,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.jass;
    // Handy quer: engere Raender, damit mehr vom Inhalt ohne Scrollen sichtbar ist.
    final compact = MediaQuery.sizeOf(context).height < 420;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: colors.panel,
          elevation: 14,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.brass, width: 1.5),
            ),
            child: SingleChildScrollView(
              padding: compact
                  ? const EdgeInsets.fromLTRB(14, 10, 14, 10)
                  : const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: JassFonts.serif(size: 19, weight: 700, color: colors.brassGlow),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: JassFonts.ui(size: 13, color: colors.muted)),
                    ),
                  SizedBox(height: compact ? 8 : 12),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
