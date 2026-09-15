# Bachmann Jass

Schweizer Jass (Schieber und Bieterjass) als Flutter-App für Android, Web und iOS.

Die App ersetzt die bisherige Web-App [`bachmann_jass_game`](https://github.com/YannickLuca/bachmann_jass_game). Regeln und Computergegner werden aus der Web-App übernommen und per Paritätstest abgesichert. Neu gebaut werden Oberfläche, Animationen, Einstellungen und Hausregeln.

## Stand

Planung. Arbeitspakete, Entscheide und Meilensteine stehen in [`docs/UMSETZUNGSPLAN.md`](docs/UMSETZUNGSPLAN.md).

## Grundsätze

- offline spielbar, keine Kosten, keine Datenerhebung
- Regeln als reines Dart-Paket (`packages/jass_engine`), unabhängig von Flutter
- jede Regel durch Tests abgesichert, Verhalten identisch zur Web-App
