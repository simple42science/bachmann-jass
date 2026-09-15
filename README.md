# Bachmann Jass

Schweizer Jass (Schieber und Bieterjass) als Flutter-App für Android und Web.

Die App ersetzt die bisherige Web-App [`bachmann_jass_game`](https://github.com/YannickLuca/bachmann_jass_game). Regeln und Computergegner sind aus der Web-App übernommen und per Paritätstest abgesichert: Für dieselben Seeds spielt die Dart-Engine exakt dieselben Partien. Neu gebaut sind Oberfläche, Spielablauf, Einstellungen und später Animationen und Hausregeln.

## Stand

Meilenstein M3: Schieber und Bieterjass sind komplett spielbar (Bieten, Schieben, Spielartwahl, Weis, Stöck, Match, Rundenabrechnung, Spielende, Tempo, Pause, Speicherstand), im Design „Stammtisch“ (Holz, Filz, Messing, Tischkarten, Schiefertafel), mit Animationen (Austeilen, Kartenflug, Stich einsammeln, Einblendungen), Jasstafel mit Z-Tafel-Strichen und Verlauf sowie Regel-Screen. Es fehlen noch Sound, ein eigenes Icon, das Tutorial und die Einstellungen aus Phase 5.

Arbeitspakete, Entscheide und Stand: [`docs/UMSETZUNGSPLAN.md`](docs/UMSETZUNGSPLAN.md). Screenshots der Web-Version: [`docs/screenshots/`](docs/screenshots/).

## Grundsätze

- offline spielbar, keine Kosten, keine Datenerhebung
- Regeln als reines Dart-Paket (`packages/jass_engine`), unabhängig von Flutter
- jede Regel durch Tests abgesichert, Verhalten identisch zur Web-App

## Aufbau

```text
lib/
  app/        Start, Router, Theme (Design-System Stammtisch), Einstellungen, Demo-Start
  game/       GameController (Spielablauf, KI-Wartezeiten, Pause), Speicherstand, Texte
  features/   Screens: Home, Setup, Tisch (Geometrie, Karten, Hand, Panels, Animationen),
              Jasstafel, Regeln
  l10n/       Texte (ARB, Deutsch)
packages/jass_engine/   Regeln, Wertung, Computergegner, Zufall (reines Dart)
assets/cards/           36 Karten als WebP
assets/fonts/           Vollkorn, Alegreya Sans, Caveat (OFL)
docs/design/            Design-Mockups (Stammtisch, verworfene Richtungen)
tool/                   Konvertierung, Fixtures aus der Web-App, Screenshots
```

Die Engine kennt nur `applyAction(state, action) → (state, events)`. Der `GameController` orchestriert Eingaben, Computerzüge und Speichern; die Widgets lesen den Zustand.

## Entwickeln

Flutter SDK (stable) muss installiert sein.

```powershell
flutter pub get
flutter run -d edge            # Web
flutter run -d <geraet>        # Android
```

Prüfen wie in der CI:

```powershell
dart format --output=none --set-exit-if-changed lib test packages/jass_engine
flutter analyze
flutter test
cd packages/jass_engine; dart analyze --fatal-infos; dart test; dart test -p node
```

## Werkzeuge

| Befehl | Zweck |
| --- | --- |
| `python tool/convert_cards.py` | Kartenbilder der Web-App nach `assets/cards/` konvertieren |
| `python tool/make_icons.py` | Web- und Android-Icons aus dem App-Icon erzeugen |
| `node tool/export_rng_fixture.mjs` | Zufallszahlen der Web-App als Fixture exportieren |
| `node tool/export_parity_fixtures.mjs` | Partien der Web-App für den Paritätstest aufzeichnen |
| `dart run tool/benchmark.dart normal einfach 300` | KI-Stufen gegeneinander messen (im Engine-Paket) |
| `dart run tool/benchmark_bieter.dart schieber 200` | KI-Anpassungen im Bieterjass messen (im Engine-Paket) |
| `node tool/screenshot_web.mjs` | Web-Version in vier Fenstergrössen fotografieren |

Die Werkzeuge, die aus der Web-App lesen, erwarten sie unter `../bachmann_jass_game` oder im Pfad aus `JASS_WEB_APP`.

### Demo-Start

Ein Build mit `--dart-define=JASS_DEMO=true` startet über die URL direkt eine reproduzierbare Spielsituation, zum Beispiel `?demo=schieber&seed=5&moves=4` (Schieber mit Seed 5, der Mensch hat seine ersten vier Entscheidungen wie die KI gespielt). `&screen=scoreboard` öffnet die Jasstafel, `&screen=rules` die Regeln. Computerzüge kommen dabei sofort. Der Screenshot-Befehl nutzt das:

```powershell
flutter build web --release --dart-define=JASS_DEMO=true
node tool/screenshot_web.mjs
```
