# Bachmann Jass

Schweizer Jass (Schieber und Bieterjass) als Flutter-App für Android und Web.

Web-Version: **https://simple42science.github.io/bachmann-jass/** (im Browser spielbar, als App installierbar, offline nutzbar).

Die App ersetzt die bisherige Web-App [`bachmann_jass_game`](https://github.com/YannickLuca/bachmann_jass_game). Die Schieber-Regeln sind aus der Web-App übernommen und per Paritätstest abgesichert: Für dieselben Seeds spielt die Dart-Engine exakt dieselben Partien. Der Bieterjass folgt den Familienregeln: Zu Beginn der Partie wird ab 400, 450 oder 500 gesteigert, der Höchstbietende spielt alleine und muss sein Gebot erreichen, bevor die beiden anderen zusammen 1000 Punkte haben. Neu gebaut sind Oberfläche, Spielablauf, Animationen, Einstellungen, Hausregeln und die Computergegner: Die Stufen Normal und Schwer entscheiden per Stichprobe (die unbekannten Karten werden mehrmals plausibel verteilt und jede Möglichkeit durchgespielt), die Stufe Einfach entspricht der stärksten Stufe der Web-App.

## Stand

Meilenstein M4: Schieber und Bieterjass sind komplett spielbar (Steigern, Schieben, Spielartwahl inklusive Slalom-Richtung, Weis, Stöck, Match, Rundenabrechnung, Spielende, Pause, Speicherstand), im Design „Stammtisch“ (Holz, Filz, Messing, Tischkarten, Schiefertafel), mit Animationen, Jasstafel mit Z-Tafel-Strichen und Verlauf, Regel-Screen, Einstellungen (Tempo, automatisch spielen, Bestätigen, Zug zurücknehmen), Hausregel-Editor (Preset Bachmann, Bedanken, Stich-Rückblick), Gegnernamen und -stärke, Statistik und Yannicks Jubel, wenn er gewinnt. Es fehlen noch weitere Klänge, ein eigenes Icon, das Tutorial und Avatare.

Arbeitspakete, Entscheide und Stand: [`docs/UMSETZUNGSPLAN.md`](docs/UMSETZUNGSPLAN.md). Screenshots der Web-Version: [`docs/screenshots/`](docs/screenshots/).

## Grundsätze

- offline spielbar, keine Kosten, keine Datenerhebung
- Regeln als reines Dart-Paket (`packages/jass_engine`), unabhängig von Flutter
- jede Regel durch Tests abgesichert, Verhalten identisch zur Web-App

## Aufbau

```text
lib/
  app/        Start, Router, Theme (Design-System Stammtisch), Einstellungen, Demo-Start
  game/       GameController (Spielablauf, KI-Wartezeiten, Pause, Zurücknehmen),
              Speicherstand, Statistik, Ton, Texte
  features/   Screens: Home, Setup, Tisch (Geometrie, Karten, Hand, Panels, Animationen),
              Jasstafel, Regeln, Einstellungen, Statistik
  l10n/       Texte (ARB, Deutsch)
packages/jass_engine/   Regeln, Wertung, Computergegner, Zufall (reines Dart)
assets/cards/           36 Karten als WebP
assets/fonts/           Vollkorn, Alegreya Sans, Caveat (OFL)
assets/sounds/          Yannicks Jubel
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

## Web-Version veröffentlichen

[`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml) baut bei jedem Push auf `main` die Web-Version (`--base-href /bachmann-jass/`) und veröffentlicht sie auf GitHub Pages unter https://simple42science.github.io/bachmann-jass/. Im Repo ist dafür unter *Settings → Pages* die Source „GitHub Actions“ gesetzt; das Repo ist öffentlich, weil GitHub Pages nur so gratis ist.

## Werkzeuge

| Befehl | Zweck |
| --- | --- |
| `python tool/convert_cards.py` | Kartenbilder der Web-App nach `assets/cards/` konvertieren |
| `python tool/make_icons.py` | Web- und Android-Icons aus dem App-Icon erzeugen |
| `node tool/export_rng_fixture.mjs` | Zufallszahlen der Web-App als Fixture exportieren |
| `node tool/export_parity_fixtures.mjs` | Partien der Web-App für den Paritätstest aufzeichnen |
| `dart run tool/benchmark.dart normal einfach 300` | KI-Stufen gegeneinander messen (im Engine-Paket); `schwer@web` = KI der Web-App, `schwer@48` = 48 Stichproben |
| `dart run tool/benchmark_bieter.dart schieber 200` | KI-Anpassungen im Bieterjass messen (im Engine-Paket) |
| `node tool/screenshot_web.mjs` | Web-Version in vier Fenstergrössen fotografieren |

Die Werkzeuge, die aus der Web-App lesen, erwarten sie unter `../bachmann_jass_game` oder im Pfad aus `JASS_WEB_APP`.

### Demo-Start

Ein Build mit `--dart-define=JASS_DEMO=true` startet über die URL direkt eine reproduzierbare Spielsituation, zum Beispiel `?demo=schieber&seed=5&moves=4` (Schieber mit Seed 5, der Mensch hat seine ersten vier Entscheidungen wie die KI gespielt). `&screen=scoreboard` öffnet die Jasstafel, `&screen=rules` die Regeln, `&screen=settings` die Einstellungen. Computerzüge kommen dabei sofort. Der Screenshot-Befehl nutzt das:

```powershell
flutter build web --release --dart-define=JASS_DEMO=true
node tool/screenshot_web.mjs
```
