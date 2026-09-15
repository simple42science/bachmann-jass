# Bachmann Jass – Umsetzungsplan Flutter

Stand: 15.09.2026 · Repo: `simple42science/bachmann-jass` (privat) · Referenz: `../bachmann_jass_game` (Web-App v1.1.0)

Die bestehende Jass-Web-App wird als Flutter-App neu aufgebaut. Sie soll **dynamischer** werden (Animationen, Sound, Haptik), **besser steuerbar** (Einstellungen, Hausregeln, Debug-Werkzeuge) und ein **eigenes, hochwertiges Design** bekommen. Regeln und Computergegner werden nicht neu erfunden: Sie werden 1:1 übernommen und per Test gegen das Original abgesichert.

## Legende

| Zeichen | Bedeutung |
| --- | --- |
| 🟢 **Claude** | kann ich selbständig umsetzen und testen |
| 🟡 **Claude + Input** | ich setze um, brauche aber einen Entscheid, Material oder eine Abnahme von dir |
| 🔴 **Deine Hilfe** | geht nur mit dir: Konten, Kosten, Geräte, Rechtsfragen, echte Spieltests |

Umfang: **S** = wenige Stunden · **M** = etwa 1–2 Arbeitstage · **L** = mehrere Arbeitstage

---

## 1. Analyse des Ist-Stands

### 1.1 Bestand

| Baustein | Datei | Umfang | Beurteilung | Im Flutter-Projekt |
| --- | --- | --- | --- | --- |
| Regel-Engine | `public/game-engine.js` | 1509 Zeilen | sauber, ohne DOM, gut getestet | 1:1 nach Dart portieren |
| Computergegner | `public/ai.js` | 391 Zeilen | 3 Stufen, gemessene Siegquoten 74 / 63 / 80 % | portieren, danach verbessern |
| UI und Spielablauf | `public/app.js` | 1845 Zeilen | imperativ, HTML-Strings, globaler Zustand | neu bauen |
| Layout | `public/style.css` | 2105 Zeilen | 4 Breakpoints, viele Einzelkorrekturen | durch adaptives Layout ersetzen |
| Tests | `tests/engine/` | 53 Tests, alle grün (15.09.2026) | decken Regeln, KI, Speicherstand ab | dienen als Spezifikation |
| Browsertest | `tests/browser/` | eigener DevTools-Treiber | nur lokal lauffähig | durch Golden- und Integrationstests ersetzen |
| Kartenbilder | `public/assets/…` | 36 PNG, 52 MB, je 1348×2104 px | angezeigt werden höchstens 180 px Breite | als WebP verkleinern |
| Auslieferung | GitHub Pages (Konto YannickLuca) | PWA mit Service Worker | offline spielbar | Flutter Web plus Store-Apps |

### 1.2 Was gut ist und übernommen wird

- Regeln, Strategie und UI sind sauber getrennt, und ein Test erzwingt das.
- Die offizielle Bedienpflicht ist vollständig umgesetzt, inklusive Puur-Ausnahme, Untertrumpfverbot und fehlendem Trumpfzwang. Slalom, Stöck-Ansage, Weis-Vergleich und Match sind ebenfalls abgedeckt.
- Das Regelwerk ist zentral in `RULE_SET` gebündelt.
- Der Zufall lässt sich seeden, dadurch sind Partien reproduzierbar.
- Simulationstests über Hunderte Runden prüfen Invarianten, zum Beispiel 157 Punkte pro Runde.
- Die App läuft komplett offline, verursacht keine Kosten und erhebt keine Daten. Dieses Prinzip bleibt.

### 1.3 Wo die Web-App an Grenzen stösst

- **Layout ist fragil.** 7 von 22 Commits sind reine Layout-Korrekturen (iPhone, schmale Geräte, Überlappungen). Mit CSS-Breakpoints wächst der Aufwand mit jeder Kombination aus 3er- oder 4er-Tisch, Hoch- oder Querformat und 9 oder 12 Handkarten.
- **Animationen sind schwer erweiterbar.** Jede Aktion rendert den ganzen Tisch per `innerHTML` neu. Kartenflüge hängen an CSS-Klassen und einem Set bereits animierter Karten. Aufwendigere Abläufe wie Austeilen, Weis zeigen oder Punkte hochzählen sind so kaum wartbar.
- **Der Zustand ist global.** Variablen wie `selectedDifficulty`, `aiLocked` und `pendingAiTimeout` liegen verteilt in `app.js`.
- **Keine Store-Präsenz.** Auf iOS gelten für PWAs Einschränkungen bei Speicher und Hintergrundbetrieb.

### 1.4 Befunde im Code (werden beim Port gelöst)

| # | Befund | Stelle | Lösung im Port |
| --- | --- | --- | --- |
| 1 | Die Engine schreibt deutsche Logtexte direkt in den Spielzustand | `game-engine.js`, alle `game.log.push` | typisierte Events; Text entsteht erst in der UI |
| 2 | Das Regelwerk ist global und gehört nicht zur Partie | `game-engine.js:121` | `RuleSet` im Spielzustand, damit Hausregeln möglich werden |
| 3 | Die Namen der Computergegner sind fest verdrahtet (Yannick, Papsli, Gusti) | `game-engine.js:387` | konfigurierbar |
| 4 | Die Handsortierung ignoriert die Spielart; das Umsortieren nach der Trumpfwahl bewirkt nichts | `game-engine.js:352`, `:1072` | Trumpf zuerst, bei Une-Ufe umgekehrte Reihenfolge |
| 5 | Das KI-Gebot im Bieterjass „wie im Schieber" rechnet nur mit Trumpffarben, obwohl die KI danach Obe-Abe, Une-Ufe oder Slalom wählen darf | `ai.js:169` | Gebot aus der besten erlaubten Spielart |
| 6 | Die Stöck-Punkte stehen in zwei UI-Texten fest als 20, statt aus dem Regelwerk zu kommen | `app.js:965`, `:1152` | aus dem `RuleSet` |
| 7 | „Home" bricht die Partie ab und löscht den Speicherstand; eine Pause gibt es nicht | `app.js:1614` | Pause-Menü; Abbrechen als eigene Aktion |
| 8 | Nur der erste Stich lässt sich nochmals ansehen; gegnerische Weise erscheinen nur als Logtext | `app.js:529`, `game-engine.js:966` | einstellbarer Stich-Rückblick, Weis-Karten kurz aufdecken |
| 9 | Der Schieber endet erst am Rundenende, auch wenn das Ziel mitten in der Runde erreicht ist | `game-engine.js:1474` | optionale Regel „Bedanken" |
| 10 | Die Schriften kommen übers Netz von Google Fonts; offline fällt die App auf die Systemschrift zurück | `index.html:16` | Schriften in die App einbetten |

---

## 2. Zielbild

### 2.1 Dynamischer, steuerbarer, cooler

**Dynamischer.** Jede Spielaktion erzeugt ein Event, und jedes Event löst eine Animation aus. Die Karten werden in 3er-Paketen ausgeteilt, jede Karte fliegt vom richtigen Sitzplatz auf den Tisch und der Stich gleitet zum Gewinner. Weis-Karten werden kurz gezeigt, Stöck und Match bekommen einen eigenen Effekt, und die Punkte zählen in der Abrechnung hoch. Dazu kommen Sound und Haptik. Tempo und „Bewegung reduzieren" steuern alles an einer Stelle.

**Besser steuerbar.**

- *Für Spielende:* Pause, Tipp-Knopf, optionales Zurücknehmen eines Zugs, automatisches Spielen der einzigen erlaubten Karte, Ausspielen per Tippen oder Ziehen, stufenloses Tempo.
- *Für dich als Besitzer:* Hausregel-Editor mit Presets, Namen und Stärke der Gegner, Debug-Menü mit Seed, aufgedeckten Karten, Szenarien und Replay.

**Cooler.** Ein eigenes Design-System mit Tokens, austauschbaren Tischdecken und einem Kartenrücken mit Monogramm. Die Jasstafel bekommt einen Kreide-Look. Das Layout passt sich an Handy (hoch und quer), Tablet, Desktop und Web an.

### 2.2 Architektur

```text
 Spieler-Eingabe ─┐
                  ├─► GameController ─► jass_engine.apply(state, action)
 KI-Spieler ──────┘        │                         │
                           │ ◄──── neuer State + Events
                           │
                           ├─► Animations-Warteschlange ─► Widgets (Tisch, Hand, Jasstafel)
                           └─► Speicher (Partie, Einstellungen, Statistik)
```

- `packages/jass_engine` ist reines Dart ohne Flutter. Es enthält Regeln, `RuleSet`, Wertung, KI und den Seed-Zufall. So bleibt es später auch auf einem Server für ein Online-Spiel nutzbar.
- Die Engine kennt nur `apply(state, action) → (state, events)`. Sie hat keine Timer, keine Texte und keine Seiteneffekte.
- Der `GameController` orchestriert Eingaben, KI-Züge, Tempo und Speichern. Die Widgets lesen nur den Zustand und spielen die Events ab.

### 2.3 Projektstruktur

```text
bachmann_jass_app/                 Git-Root → github.com/simple42science/bachmann-jass
├─ docs/                           Plan, Entscheide, Design-Notizen
├─ packages/jass_engine/           Regeln, KI, Zufall, Tests (reines Dart)
│  ├─ lib/src/{model,rules,scoring,weis,ai}/
│  └─ test/ + test/fixtures/       portierte Tests und Paritäts-Fixtures
├─ lib/
│  ├─ app/                         Router, Theme, Start
│  ├─ design/                      Tokens, Skins, Basis-Widgets
│  ├─ game/                        GameController, Animations-Warteschlange, Speicher
│  └─ features/{home,setup,table,scoreboard,rules,settings,stats,debug}/
├─ assets/{cards,fonts,sounds,images}/
├─ tool/                           Asset-Konvertierung, Fixture-Export, KI-Benchmark
├─ test/  integration_test/
└─ .github/workflows/
```

### 2.4 Technik

| Bereich | Wahl | Begründung |
| --- | --- | --- |
| SDK | Flutter Stable (lokal 3.41.6, Upgrade in AP 0.2) | bereits installiert |
| Zustand | `flutter_riverpod` | testbar, klare Abhängigkeiten zwischen Partie, Einstellungen und Regeln |
| Modelle und JSON | `freezed` + `json_serializable` | unveränderlicher Zustand, `copyWith`, sichere Speicherstände |
| Navigation | `go_router` | sprechende URLs und Browser-Zurück im Web |
| Animation | `flutter_animate` + eigene `AnimationController` | einfache Effekte deklarativ, Kartenflüge präzise |
| Speicher | `shared_preferences` + JSON-Dateien (`path_provider`) | wie in Busdriver und LingoTrail |
| Audio | `just_audio` oder `flutter_soloud` | `just_audio` kennst du aus LingoTrail; `flutter_soloud` hat weniger Latenz bei kurzen Effekten |
| Schriften | Playfair Display, Inter (OFL), eingebettet | offline verfügbar |
| Icons und Splash | `flutter_launcher_icons`, `flutter_native_splash` | wie in LingoTrail |
| Qualität | `flutter_lints` + Zusatzregeln, GitHub Actions | Analyse, Tests und Build bei jedem Push |

---

## 3. Arbeitspakete

### 3.1 Übersicht

| AP | Titel | Wer | Umfang | Setzt voraus | Stand |
| --- | --- | --- | --- | --- | --- |
| 0.1 | Repo und Projektgerüst | 🟢 | S | – | Repo angelegt |
| 0.2 | Entwicklungsumgebung | 🟡 | S | – | offen |
| 0.3 | Grundsatzentscheide | 🔴 | S | – | offen |
| 1.1 | Datenmodell | 🟢 | M | 0.1 | offen |
| 1.2 | Regel-Engine portieren | 🟢 | L | 1.1 | offen |
| 1.3 | Reproduzierbarer Zufall | 🟢 | S | 1.1 | offen |
| 1.4 | Tests und Paritätsprüfung gegen die Web-App | 🟢 | M | 1.2, 1.3 | offen |
| 1.5 | Computergegner portieren | 🟢 | M | 1.2 | offen |
| 2.1 | GameController und Spielablauf | 🟢 | M | 1.2 | offen |
| 2.2 | Speicherstand und Einstellungen | 🟢 | S | 2.1 | offen |
| 2.3 | Navigation und Screen-Gerüst | 🟢 | S | 0.1 | offen |
| 2.4 | Texte und Lokalisierung | 🟡 | S | 1.2 | offen |
| 3.1 | Designrichtung | 🟡 | M | 0.3 | offen |
| 3.2 | Design-System und Theme | 🟢 | M | 3.1 | offen |
| 3.3 | Karten-Assets | 🟡 | S | – | offen |
| 3.4 | App-Icon und Splash | 🟡 | S | 3.1 | offen |
| 3.5 | Sound und Haptik | 🟡 | S | 4.3 | offen |
| 4.1 | Adaptives Tisch-Layout | 🟢 | L | 2.1 | offen |
| 4.2 | Karten und Hand | 🟢 | M | 3.3, 4.1 | offen |
| 4.3 | Animationen | 🟢 | L | 4.1, 4.2 | offen |
| 4.4 | Bedien-Panels | 🟢 | M | 4.1 | offen |
| 4.5 | Jasstafel und Verlauf | 🟢 | M | 2.1 | offen |
| 4.6 | Regeln und Tutorial | 🟡 | M | 4.4 | offen |
| 5.1 | Spieler-Einstellungen | 🟢 | M | 2.2 | offen |
| 5.2 | Hausregel-Editor | 🟡 | M | 1.2, 2.2 | offen |
| 5.3 | Gegner und Profile | 🟡 | S | 2.2 | offen |
| 5.4 | Statistik | 🟢 | S | 2.2 | offen |
| 5.5 | Debug-Menü | 🟢 | S | 2.1 | offen |
| 6.1 | Automatisierte Tests | 🟢 | M | Phase 4 | offen |
| 6.2 | Performance und Barrierefreiheit | 🟡 | M | Phase 4 | offen |
| 6.3 | Spieltests | 🔴 | M | M3 | offen |
| 7.1 | Web-Version | 🟡 | S | 6.1 | offen |
| 7.2 | Android-Release | 🔴 | M | 6.3 | offen |
| 7.3 | iOS-Release | 🔴 | M | 6.3 | offen |
| 7.4 | Web-App ablösen | 🟡 | S | 7.1 | offen |
| 8.x | Ausblick nach 1.0 | 🟢 / 🟡 / 🔴 | – | Version 1.0 | später |

### Phase 0 – Grundlagen

#### AP 0.1 Repo und Projektgerüst · 🟢 Claude · S

- ✅ GitHub-Repo `simple42science/bachmann-jass` (privat) mit diesem Plan angelegt.
- Flutter-Projekt erzeugen (`flutter create --org com.simple42science --project-name bachmann_jass`), Plattformen gemäss D1.
- Dart-Paket `packages/jass_engine` anlegen und als Pfad-Abhängigkeit einbinden.
- Strenge Lints, `dart format` als Standard.
- GitHub Action mit `flutter analyze`, `flutter test`, `dart test` im Engine-Paket und Web-Build.
- **Fertig, wenn** das leere Gerüst auf Edge und Android startet und die CI grün ist.

#### AP 0.2 Entwicklungsumgebung · 🟡 Claude + Input · S

- Befund: Das Flutter-SDK liegt in `C:\Dev\Flutter_Apps\flutter` (3.41.6), steht aber nicht im PATH. Im PATH stehen stattdessen zwei Ordner, die es nicht mehr gibt (`Desktop\flutter`, `OneDrive\flutter`).
- PATH bereinigen und `flutter upgrade` ausführen – mache ich mit deinem OK.
- Web-Tests laufen über Edge (`-d edge`), Chrome ist nicht nötig.
- 🔴 Android-Handy mit USB-Debugging anschliessen oder in Android Studio einen Emulator anlegen. Das Android SDK ist vorhanden.
- Visual Studio fehlt. Es wird nur für Windows-Desktop-Builds gebraucht und ist deshalb vorerst nicht nötig.
- **Fertig, wenn** `flutter doctor` für Android und Web grün ist und die App auf deinem Handy läuft.

#### AP 0.3 Grundsatzentscheide · 🔴 Deine Hilfe · S

- Entscheide D1, D2, D3 und D6 aus Kapitel 4 treffen: Plattformen, App-ID, Monetarisierung, Rechte an den Kartenbildern.
- **Fertig, wenn** die Entscheide in Kapitel 4 eingetragen sind.

### Phase 1 – Spielkern in Dart

Ziel dieser Phase: Die Dart-Engine verhält sich nachweislich genau wie `game-engine.js` und `ai.js`. Erst danach wird UI gebaut.

#### AP 1.1 Datenmodell · 🟢 Claude · M

- Enums statt Strings: `Suit`, `Rank`, `RoundMode`, `Phase`, `Variant`, `Difficulty`.
- Unveränderlicher `GameState` mit `copyWith` und JSON, inklusive Schema-Version für spätere Migrationen.
- `RuleSet` wird Teil des Zustands statt globaler Konstante (Befund 2). Presets: „Offiziell" und „Bachmann" mit den heutigen Werten.
- Spieler mit konfigurierbarem Namen und Typ (Mensch oder KI mit Stufe).
- **Fertig, wenn** jeder Zustand verlustfrei nach JSON und zurück geht.

#### AP 1.2 Regel-Engine portieren · 🟢 Claude · L

- Alle Regeln aus `game-engine.js` übernehmen: Austeilen in Paketen, Bieten, Schieben, Spielartwahl, Bedienpflicht, Stichwertung, Slalom, Weis-Erkennung und -Vergleich, Stöck-Ansage, Match, Wertung beider Jassarten, Rundenhistorie.
- Aktionen als `sealed class GameAction`: Bieten, Schieben, Spielart wählen, Weis melden, Weis verzichten, Karte spielen, nächster Stich, nächste Runde.
- Eine zentrale Funktion `apply(state, action) → (state, events)`. Ungültige Aktionen liefern einen typisierten Fehler.
- Events statt Logtexten (Befund 1): `CardsDealt`, `BidPlaced`, `TrumpPushed`, `ModeChosen`, `WeisDeclared`, `StoeckAnnounced`, `CardPlayed`, `TrickWon`, `RoundScored`, `GameWon`. Sie steuern später Animation, Sound, Verlauf und Statistik.
- Neue Hilfsfunktion, die erklärt, warum eine Karte nicht erlaubt ist („Rosen muss bedient werden").
- Handsortierung nach Spielart (Befund 4). Die Regel „Bedanken" wird vorbereitet und ist im Preset „Bachmann" ausgeschaltet (Befund 9).
- **Fertig, wenn** ganze Partien beider Jassarten per Code durchspielbar sind.

#### AP 1.3 Reproduzierbarer Zufall · 🟢 Claude · S

- mulberry32 aus `setRandomSeed` exakt nach Dart portieren. Auf dem Web rechnet Dart mit JavaScript-Zahlen. `Math.imul` und `>>> 0` müssen darum 32-Bit-sicher nachgebaut und auf der Dart-VM **und** im Web getestet werden.
- Der Seed wird im Spielzustand gespeichert. Damit ist jede Partie nachspielbar, für Debugging, Replays und Fehlerberichte.
- **Fertig, wenn** derselbe Seed in JavaScript, auf der Dart-VM und im Dart-Web dieselbe Kartenverteilung ergibt.

#### AP 1.4 Tests und Paritätsprüfung gegen die Web-App · 🟢 Claude · M

- Die 53 bestehenden Tests nach `package:test` übertragen: Bedienpflicht, Bieten, Stöck, Match, Weis, Slalom, Vollsimulationen, Rangfolge der Stufen, Speicherstand.
- **Golden Master:** Ein Node-Skript unter `tool/` lässt die JS-Engine zum Beispiel 500 Partien mit festen Seeds spielen. Aktionen, Stiche und Punkte landen als JSON-Fixtures im Repo.
  - Engine-Fixtures: Die Dart-Engine spielt die aufgezeichneten Aktionen nach und muss dieselben Stiche und Punkte ergeben.
  - KI-Fixtures: Die Dart-KI muss in denselben Situationen dieselbe Entscheidung treffen.
- Die Web-App selbst bleibt dabei unverändert.
- **Fertig, wenn** alle portierten Tests und 100 % der Fixtures grün sind → **Meilenstein M1**.

#### AP 1.5 Computergegner portieren · 🟢 Claude · M

- `ai.js` mit allen drei Stufen übertragen: Handbewertung, Spielartwahl, Schieben, Bieten, Ausspielen, Schmieren, Kartengedächtnis.
- Paritätsfalle: JavaScript sortiert stabil, `List.sort` in Dart garantiert das nicht. Für identische Entscheidungen wird stabil sortiert (`mergeSort` aus `package:collection`).
- Benchmark als CLI (`dart run tool/benchmark.dart normal einfach 300`). Ziel sind die heutigen Siegquoten (74 / 63 / 80 %) ± 3 Prozentpunkte.
- Rechenzeit messen; nur falls eine Stufe spürbar Zeit braucht, wird sie in ein Isolate ausgelagert.
- Danach, in einem eigenen Commit: Das Bieterjass-Gebot berücksichtigt alle erlaubten Spielarten (Befund 5).
- **Fertig, wenn** die KI-Fixtures identisch sind und der Benchmark die Quoten bestätigt.

### Phase 2 – App-Architektur

#### AP 2.1 GameController und Spielablauf · 🟢 Claude · M

- Ein Riverpod-Notifier ersetzt die globalen Variablen und die Timeout-Logik aus `app.js` (`aiLocked`, `pendingAiAction`, `gameLoop`).
- Er nimmt Eingaben entgegen, lässt KI-Spieler mit Tempo-Verzögerung ziehen und reicht Events an die Animations-Warteschlange weiter.
- Pause, Fortsetzen und „Tippen überspringt die Wartezeit" liegen zentral an einer Stelle.
- **Fertig, wenn** eine Partie in einem Test mit simulierter Uhr komplett durchläuft.

#### AP 2.2 Speicherstand und Einstellungen · 🟢 Claude · S

- Automatisch speichern nach jeder Aktion und beim Wegschalten der App (`AppLifecycleState.paused`).
- Speicherstand mit Schema-Version; Einstellungen über `shared_preferences`.
- „Home" pausiert und behält die Partie. Abbrechen wird eine eigene, bestätigte Aktion (Befund 7).

#### AP 2.3 Navigation und Screen-Gerüst · 🟢 Claude · S

- `go_router` mit Home, Neue Partie, Tisch, Jasstafel, Regeln, Einstellungen und Statistik.
- Im Web mit sprechenden URLs und funktionierendem Browser-Zurück.

#### AP 2.4 Texte und Lokalisierung · 🟡 Claude + Input · S

- Alle Texte in ARB-Dateien (`gen-l10n`), Basis ist Hochdeutsch in Schweizer Schreibweise (ohne ß).
- Events werden erst in der UI zu Sätzen, etwa „Papsli sagt Stöck an".
- 🟡 Optional ein Mundart-Modus. Die Ausdrücke dafür lieferst du.

### Phase 3 – Design

#### AP 3.1 Designrichtung · 🟡 Claude + Input · M

- Ich entwerfe drei Richtungen als Mockups (Setup, Tisch hoch, Tisch quer, Jasstafel), zum Beispiel:
  - **Stammtisch:** Filz, Holzrand, Messing, Jasstafel in Kreide – warm und traditionell.
  - **Premium Dark:** Weiterentwicklung des heutigen Looks mit tiefem Grün, Glas-Panels und Goldakzenten.
  - **Alpen-Pop:** klare Flächen, kräftige Farben, verspielte Animationen.
- 🔴 Du wählst eine Richtung oder kombinierst.
- **Fertig, wenn** die Richtung abgenommen ist (D4).

#### AP 3.2 Design-System und Theme · 🟢 Claude · M

- Tokens als `ThemeExtension`: Farben, Typografie, Abstände, Radien, Schatten, Animationsdauern und -kurven.
- Playfair Display und Inter direkt in die App einbetten (Befund 10).
- Tischdecken als austauschbare Skins, zum Beispiel Filz grün, Holz und Nacht.
- Ein Widget-Katalog als Debug-Screen zeigt alle Bausteine.

#### AP 3.3 Karten-Assets · 🟡 Claude + Input · S

- 36 PNG mit zusammen 52 MB nach WebP konvertieren. Gemessen: 1,8 MB bei 480 px Breite, 2,9 MB bei 720 px. Beide Grössen als 1×/2×-Varianten ablegen.
- Das Konvertierungsskript liegt unter `tool/`, damit der Schritt reproduzierbar bleibt.
- Neuer Kartenrücken als Vektorgrafik, zum Beispiel mit „B"-Monogramm. Heute ist der Rücken nur ein CSS-Streifenmuster.
- 🔴 **Rechte klären:** Woher stammt das Kartenset `jasskarten_deck_png_sharper`, und darf es in einer Store-App verwendet werden? Falls nicht: ein lizenziertes Set kaufen oder ein eigenes Deck gestalten lassen.

#### AP 3.4 App-Icon und Splash · 🟡 Claude + Input · S

- Aus dem bestehenden `app-icon.svg` oder dem neuen Design mit `flutter_launcher_icons` und `flutter_native_splash` erzeugen, inklusive Android-Adaptive-Icon.
- 🟡 Abnahme durch dich.

#### AP 3.5 Sound und Haptik · 🟡 Claude + Input · S

- Geräusche für Ausspielen, Mischen, Stich einsammeln, Stöck und Match; Haptik beim Ausspielen. Beides einzeln abschaltbar.
- 🔴 Sounds aus lizenzfreien Quellen (CC0) auswählen oder selbst aufnehmen. Ein echtes „Stöck!" aus der Familie wäre ein schöner Akzent.

### Phase 4 – Spieltisch

#### AP 4.1 Adaptives Tisch-Layout · 🟢 Claude · L

- Ein Geometrie-Modell berechnet Sitzplätze, Kartengrössen, Stichmitte und Stapel aus der verfügbaren Fläche. Es deckt 3er- und 4er-Tisch, Hoch- und Querformat sowie Handy bis Desktop ab und ersetzt die vier CSS-Breakpoints samt Einzelkorrekturen.
- Safe Areas (Notch, Home-Indicator) sind von Anfang an berücksichtigt.
- **Fertig, wenn** Golden-Screenshots in mindestens sechs Grössen, von iPhone SE bis 1440 px Desktop und jeweils für 3er- und 4er-Tisch, keine Überlappungen zeigen.

#### AP 4.2 Karten und Hand · 🟢 Claude · M

- Kartenwidget mit Schatten und Anheben bei Hover oder Berührung. Unspielbare Karten sind gedimmt; auf Nachfrage erscheint die Begründung aus AP 1.2.
- Der Fächer passt sich an 9 oder 12 Karten an.
- Ausspielen per Tippen, Doppeltippen oder Ziehen auf den Tisch, wählbar in den Einstellungen.
- Die Busdriver-Widgets `reveal_flip_card.dart` und `visual_card_stack.dart` als möglichen Ausgangspunkt prüfen.

#### AP 4.3 Animationen · 🟢 Claude · L

- Die Animations-Warteschlange spielt die Engine-Events der Reihe nach ab. Die Tempo-Einstellung skaliert alle Dauern.
- Austeilen in 3er-Paketen, Kartenflug vom richtigen Sitzplatz, Stich gleitet zum Gewinner, Trumpf-Enthüllung.
- Gemeldete Weis-Karten der Gegner werden kurz aufgedeckt (Befund 8). Stöck und Match bekommen einen Effekt, die Punkte zählen in der Abrechnung hoch.
- Die Systemeinstellung „Bewegung reduzieren" wird respektiert.

#### AP 4.4 Bedien-Panels · 🟢 Claude · M

- Bieten mit Wert-Chips statt Dropdown; das aktuelle Höchstgebot ist gut sichtbar.
- Spielartwahl als grosse Kacheln mit Farbsymbol und Multiplikator; Schieben ist eine eigene Kachel.
- Weis-Auswahl mit Kartenvorschau. Rundenabrechnung und Spielende erscheinen als Bottom-Sheets.

#### AP 4.5 Jasstafel und Verlauf · 🟢 Claude · M

- Jasstafel mit allen Runden, Spielart, Multiplikator und Markierungen für Weis, Stöck und Match. Darstellung wahlweise mit klassischen Strichen (Z-Tafel) oder mit Zahlen.
- Stich-Rückblick je nach Hausregel: letzter Stich, erster Stich oder alle (Befund 8).
- Spielverlauf als Timeline aus den Events.

#### AP 4.6 Regeln und Tutorial · 🟡 Claude + Input · M

- Der Regel-Screen wird wie heute aus der Engine erzeugt, neu aus dem aktiven `RuleSet`, und zeigt damit auch Hausregeln an.
- Eine geführte erste Runde erklärt Bedienpflicht, Weis und Stöck.
- 🟡 Du liest die Texte und gibst sie frei.

### Phase 5 – Steuerbarkeit

#### AP 5.1 Spieler-Einstellungen · 🟢 Claude · M

- Stufenloses Tempo mit den Presets Langsam, Normal und Schnell, dazu eine Pause.
- Automatisch spielen, wenn nur eine Karte erlaubt ist.
- Tipp-Knopf: zeigt die Karte, die die Stufe „Schwer" spielen würde.
- Zug zurücknehmen, nur gegen Computer und abschaltbar.
- Bestätigung vor dem Ausspielen, Layout für Links- und Rechtshänder.

#### AP 5.2 Hausregel-Editor · 🟡 Claude + Input · M

- Alle Werte des `RuleSet` sind im App-Menü einstellbar: letzter Stich, Match, Stöck, vier Sechser, Vier Gleiche gegen Folge, Multiplikatoren je Spielart, Zielpunkte, Zählweise und Gebotsschritte im Bieterjass, „Bedanken" und welcher Stich angeschaut werden darf.
- Eigene Presets lassen sich speichern. Eine laufende Partie behält ihre Regeln.
- 🟡 Du bestätigst, dass das Preset „Bachmann" genau euren Hausregeln entspricht (D5).

#### AP 5.3 Gegner und Profile · 🟡 Claude + Input · S

- Name, Avatar und Stufe pro Computergegner (Befund 3).
- 🟡 Du legst den Avatar-Stil fest oder lieferst Fotos oder Zeichnungen.

#### AP 5.4 Statistik · 🟢 Claude · S

- Anzahl Partien, Siegquote je Jassart und Stufe, Gebotserfüllung, höchster Weis, Matchs. Alles bleibt lokal gespeichert.

#### AP 5.5 Debug-Menü · 🟢 Claude · S

- Nur in Debug-Builds: Seed setzen, Gegnerkarten aufdecken, Handverteilung vorgeben (zum Beispiel für ein Stöck-Szenario), KI gegen KI zuschauen, Partie aus Seed und Aktionen nachspielen.

### Phase 6 – Qualität

#### AP 6.1 Automatisierte Tests · 🟢 Claude · M

- Die Engine-Tests aus Phase 1 laufen weiter in der CI.
- Widget-Tests für alle Panels. Golden-Tests für das Layout ersetzen den bisherigen Browsertest.
- Integrationstest: je eine volle Runde Schieber und Bieterjass per Tipp.

#### AP 6.2 Performance und Barrierefreiheit · 🟡 Claude + Input · M

- Flüssige Animationen auf einem Android-Mittelklassegerät, geprüft mit Profile-Build und DevTools.
- Kartenbilder vorladen. Semantics-Labels für Karten und Knöpfe (wie die heutigen `aria-label`), grosse Schrift, genügend Kontrast.
- 🔴 Test auf deinem Gerät, idealerweise zusätzlich auf einem älteren Handy.

#### AP 6.3 Spieltests · 🔴 Deine Hilfe · M

- Mit Familie und Freunden spielen. Stimmen Regeln und Wertung mit eurem Spiel überein? Fühlen sich die Gegner echt an?
- Rückmeldungen als GitHub-Issues. Ich stelle Fehler anschliessend mit dem Seed aus dem Debug-Menü nach.

### Phase 7 – Veröffentlichung

#### AP 7.1 Web-Version · 🟡 Claude + Input · S

- `flutter build web` und Deploy per GitHub Action.
- 🟡 Hosting wählen (D7). GitHub Pages funktioniert nur mit öffentlichem Repo oder kostenpflichtigem GitHub-Plan. Cloudflare Pages und Firebase Hosting haben beide eine Gratisstufe.

#### AP 7.2 Android-Release · 🔴 Deine Hilfe · M

- Ich bereite vor: App Bundle, Signatur-Konfiguration, Store-Texte, Screenshots, Datenschutzerklärung („keine Daten erhoben") und den Fragebogen zur Altersfreigabe.
- 🔴 Von dir: Google-Play-Konto (einmalig 25 USD, Identitätsprüfung), Upload-Schlüssel sicher aufbewahren, Tester stellen. Neue private Konten brauchen vor der Veröffentlichung einen geschlossenen Test (zuletzt 12 Tester über 14 Tage – aktuelle Vorgaben prüfen).

#### AP 7.3 iOS-Release · 🔴 Deine Hilfe · M

- iOS-Builds brauchen macOS. Ohne Mac richte ich einen Cloud-Build über Codemagic oder einen macOS-Runner in GitHub Actions ein.
- 🔴 Von dir: Apple Developer Program (99 USD pro Jahr), Zugang zu App Store Connect, TestFlight-Test auf deinem iPhone.

#### AP 7.4 Web-App ablösen · 🟡 Claude + Input · S

- Sobald die Flutter-Web-Version live ist: Hinweis und Link in der alten App und im README.
- 🔴 Die alte App liegt im Konto YannickLuca (`bachmann_jass_game`). Ob sie archiviert oder weiter betrieben wird, entscheidest du.

### Phase 8 – Nach Version 1.0 (optional)

- **8.1 Online-Spiel** 🔴: Dank reiner Dart-Engine mit Aktionen und Events kann ein Server dieselben Regeln ausführen (Räume mit Code, echte Mitspieler statt Computer). Braucht Backend-Wahl, Konten, Datenschutz und laufende Kosten.
- **8.2 Mehrere Spielende an einem Gerät** 🟢: Karten verdeckt weitergeben.
- **8.3 Weitere Jassarten** 🟡: zum Beispiel Differenzler oder Coiffeur. Welche, bestimmst du.

---

## 4. Entscheidungen von dir

| # | Frage | Mein Vorschlag | Nötig vor | Entscheid |
| --- | --- | --- | --- | --- |
| D1 | Zielplattformen und Reihenfolge | Android und Web zuerst, iOS danach | AP 0.1 | offen |
| D2 | App-ID | `com.simple42science.bachmannjass`, passend zu Busdriver. Nach der ersten Store-Veröffentlichung nicht mehr änderbar | AP 0.1, spätestens 7.2 | offen |
| D3 | Monetarisierung | keine – wie bisher offline und ohne Datenerhebung | AP 3.1 | offen |
| D4 | Designrichtung | nach den Mockups aus AP 3.1 | AP 3.2 | offen |
| D5 | Standard-Hausregeln | heutige Werte der Web-App als Preset „Bachmann" | AP 5.2 | offen |
| D6 | Rechte an den Kartenbildern | klären, bevor Store-Screenshots entstehen | AP 7.2 | offen |
| D7 | Web-Hosting und Repo-Sichtbarkeit | Repo privat lassen, Web auf Cloudflare Pages | AP 7.1 | offen |
| D8 | Online-Spiel nach 1.0 | erst nach den Spieltests entscheiden | Phase 8 | offen |

---

## 5. Meilensteine und Reihenfolge

| Meilenstein | Enthält | Ergebnis |
| --- | --- | --- |
| **M1 Engine-Parität** | Phase 1 | Dart-Engine und KI spielen nachweislich wie die Web-App |
| **M2 Spielbarer Prototyp** | 2.1–2.3, 4.1, 4.2, 4.4 (schlichtes Design) | Schieber und Bieterjass komplett spielbar auf Android und Web |
| **M3 Look & Feel** | Phase 3, 4.3, 4.5, 4.6 | neues Design, Animationen, Jasstafel |
| **M4 Feature-komplett** | Phase 5, 6.1, 6.2 | Einstellungen, Hausregeln, Statistik, Tests |
| **M5 Version 1.0** | 6.3, Phase 7 | im Web und in den Stores |

**Sofort startklar, ohne Entscheid von dir:** Engine-Paket und CI aus AP 0.1, danach Phase 1 und AP 3.3 (Konvertierung).
**Parallel bei dir:** AP 0.2 (Handy anschliessen, OK für PATH und Upgrade) und die Entscheide D1, D2, D3 und D6.

---

## 6. Risiken

| Risiko | Auswirkung | Gegenmassnahme |
| --- | --- | --- |
| Die Kartenbilder dürfen nicht in einer Store-App verwendet werden | Release blockiert | D6 früh klären; Rückfallebene eigenes Deck |
| Kleine Abweichungen zwischen JS- und Dart-Engine (32-Bit-Arithmetik im Web, Sortier-Stabilität) | falsche Punkte, andere KI-Züge | Golden-Master-Fixtures (AP 1.4), Tests auf VM und Web |
| Kein Mac für iOS-Builds | kein iOS-Release | Cloud-Build (AP 7.3) |
| Animationen ruckeln auf älteren Geräten | schlechtes Spielgefühl | früh Profile-Builds auf echtem Gerät, „Bewegung reduzieren" |
| Der Umfang wächst (Online-Spiel, weitere Jassarten) | Version 1.0 verzögert sich | Phase 8 strikt nach 1.0 |
| Testpflicht für neue Google-Play-Konten | etwa zwei Wochen Verzug | Testergruppe früh aus Familie und Freunden bilden |
