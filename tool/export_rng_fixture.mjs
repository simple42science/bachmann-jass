/**
 * Exportiert Zufallszahlen und Kartenverteilungen der Web-App als Dart-Fixture.
 *
 * Die Dart-Engine muss fuer denselben Seed exakt dieselben Zahlen und
 * Verteilungen erzeugen. Die Web-App selbst wird dabei nur gelesen.
 *
 * Usage: node tool/export_rng_fixture.mjs [pfad-zur-web-app]
 * Danach: dart format packages/jass_engine/test/fixtures
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const webApp = path.resolve(
  process.argv[2] ?? process.env.JASS_WEB_APP ?? path.join(root, '..', 'bachmann_jass_game'),
);
const engine = await import(pathToFileURL(path.join(webApp, 'public', 'game-engine.js')).href);
const outFile = path.join(root, 'packages', 'jass_engine', 'test', 'fixtures', 'rng_fixture.g.dart');

const SEEDS = [0, 1, 5, 7, 31, 42, 77, 4242, 123456789, 2147483647, 2147483648, 4294967295];
const VALUES_PER_SEED = 40;
const CHARS = '0123456789abcdefghijklmnopqrstuvwxyz';
const deckIndex = new Map(engine.createDeck().map((card, index) => [card.id, index]));
const encodeHand = (hand) => hand.map((card) => CHARS[deckIndex.get(card.id)]).join('');

/** Wortgetreue Kopie von setRandomSeed, unten gegen die Engine geprueft. */
function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Erste Schieber-Verteilung (Geber 3) mit einer Zahlenfolge nachgebaut. */
function firstSchieberDeal(values) {
  const deck = engine.createDeck();
  let next = 0;
  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(values[next] * (index + 1));
    next += 1;
    [deck[index], deck[swapIndex]] = [deck[swapIndex], deck[index]];
  }
  const hands = [[], [], [], []];
  let position = 0;
  while (position < deck.length) {
    for (const player of [0, 1, 2, 3]) {
      for (let packet = 0; packet < 3 && position < deck.length; packet += 1) {
        hands[player].push(deck[position]);
        position += 1;
      }
    }
  }
  return hands.map(encodeHand);
}

const entries = SEEDS.map((seed) => {
  const random = mulberry32(seed);
  const values = Array.from({ length: VALUES_PER_SEED }, () => random());

  engine.setRandomSeed(seed);
  const deals = [
    engine.dealHands(4, 3, 3),
    engine.dealHands(4, 3, 0),
    engine.dealHands(3, 3, 2),
    engine.dealHands(3, 3, 1),
  ].map((hands) => hands.map(encodeHand));

  if (JSON.stringify(firstSchieberDeal(values)) !== JSON.stringify(deals[0])) {
    throw new Error(`Die kopierte Zufallsfolge weicht bei Seed ${seed} von der Engine ab.`);
  }
  return { seed, values, deals };
});
engine.setRandomSeed(null);

const dartList = (items) => `[${items.join(', ')}]`;
const lines = [
  '// Erzeugt von tool/export_rng_fixture.mjs aus der Web-App. Nicht von Hand bearbeiten.',
  '',
  'class RngFixture {',
  '  const RngFixture(this.seed, this.values, this.deals);',
  '',
  '  final int seed;',
  '  final List<double> values;',
  '',
  '  /// Vier Verteilungen hintereinander: Schieber mit Geber 3 und 0, Bieterjass mit Geber 2 und 1.',
  '  /// Jede Hand ist eine Zeichenkette aus Deck-Indizes (0-9, a-z).',
  '  final List<List<String>> deals;',
  '}',
  '',
  'const List<RngFixture> rngFixtures = [',
  ...entries.map(({ seed, values, deals }) => {
    const dartDeals = dartList(deals.map((hands) => dartList(hands.map((hand) => `'${hand}'`))));
    return `  RngFixture(${seed}, ${dartList(values.map(String))}, ${dartDeals}),`;
  }),
  '];',
  '',
];

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, lines.join('\n'));
console.log(`${entries.length} Seeds nach ${path.relative(root, outFile)} geschrieben.`);
