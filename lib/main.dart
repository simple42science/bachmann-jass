import 'package:flutter/material.dart';
import 'package:jass_engine/jass_engine.dart';

void main() {
  runApp(const BachmannJassApp());
}

class BachmannJassApp extends StatelessWidget {
  const BachmannJassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bachmann Jass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5C35),
          brightness: Brightness.dark,
        ),
      ),
      home: const PlaceholderHome(),
    );
  }
}

/// Platzhalter, bis das Screen-Geruest steht (AP 2.3).
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A5C35), Color(0xFF0B2012)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BACHMANN',
                style: textTheme.labelLarge?.copyWith(
                  letterSpacing: 6,
                  color: const Color(0xFFBDD0BF),
                ),
              ),
              Text(
                'Jass',
                style: textTheme.displayLarge?.copyWith(
                  color: const Color(0xFFF1CF6D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${JassCard.deck.length} Karten bereit',
                style: textTheme.bodyMedium?.copyWith(color: const Color(0xFFF7F2E6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
