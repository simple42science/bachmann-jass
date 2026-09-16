/**
 * Laesst die JS-Engine der Web-App ganze Partien mit festen Seeds spielen und
 * schreibt Aktionen und Rundenstaende als Fixtures fuer den Paritaetstest.
 *
 * Alle Sitze spielen mit der KI der Web-App, genau wie im Spielablauf von
 * app.js. Jede aufgezeichnete Aktion ist damit zugleich eine KI-Entscheidung.
 *
 * Aktionscodes (durch Leerzeichen getrennt):
 *   s          Runde starten            n          naechster Stich
 *   b<p>:<v>   Gebot                    x<p>       passen
 *   u<p>       schieben                 m<p>:<mode> Spielart waehlen
 *   w<p>       hoechsten Weis melden    c<p><k>    Karte k (Deck-Index 0-9, a-z)
 *
 * Zwei Konfigurationen sind teilweise gescriptet, weil die KI diese Faelle nie
 * von selbst waehlt: Slalom und "alle passen". Der Paritaetstest der KI
 * ueberspringt die gescripteten Entscheidungen (Feld `scripted`).
 *
 * Usage: node tool/export_parity_fixtures.mjs [pfad-zur-web-app]
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const webApp = path.resolve(
  process.argv[2] ?? process.env.JASS_WEB_APP ?? path.join(root, '..', 'bachmann_jass_game'),
);
const engine = await import(pathToFileURL(path.join(webApp, 'public', 'game-engine.js')).href);
const ai = await import(pathToFileURL(path.join(webApp, 'public', 'ai.js')).href);
const outDir = path.join(root, 'packages', 'jass_engine', 'test', 'fixtures', 'parity');

const MAX_ROUNDS = 60;
const CHARS = '0123456789abcdefghijklmnopqrstuvwxyz';
const deckIndex = new Map(engine.createDeck().map((card, index) => [card.id, index]));
const cardChar = (card) => CHARS[deckIndex.get(card.id)];
const encodeHand = (hand) => hand.map(cardChar).join('');

// Nur Schieber: Der Bieterjass der App folgt den Familienregeln (Steigern fuer die
// ganze Partie), nicht mehr dem Bieterjass der Web-App.
const CONFIGS = [
  ['schieber_1000_einfach', 'schieber', { targetScore: 1000, difficulty: 'einfach' }, 8],
  ['schieber_1000_normal', 'schieber', { targetScore: 1000, difficulty: 'normal' }, 8],
  ['schieber_1000_schwer', 'schieber', { targetScore: 1000, difficulty: 'schwer' }, 8],
  ['schieber_2500_normal', 'schieber', { targetScore: 2500, difficulty: 'normal' }, 3],
  ['schieber_slalom_schwer', 'schieber', { targetScore: 1000, difficulty: 'schwer' }, 3, { mode: 'slalom' }],
];

const coverage = {
  games: 0, finished: 0, rounds: 0, pushes: 0, allPassed: 0, bidsMade: 0, bidsFailed: 0,
  stoeck: 0, stoeckInWeis: 0, weisAwarded: 0, match: 0, modes: {},
};

function summaryOf(summary) {
  if (summary.type === 'bieter') {
    return ['bieter', summary.soloPlayer, summary.bid, summary.soloPoints, summary.succeeded,
      summary.soloGain, summary.defenderGain, summary.roundMode, summary.multiplier];
  }
  return ['schieber',
    summary.results.map((r) => [r.teamId, r.trickPoints, r.weisPoints, r.stoeckPoints,
      r.matchPoints, r.basePoints, r.roundPoints, r.tricksWon]),
    summary.roundWinnerTeamId, summary.trumpChooser, summary.pushed, summary.roundMode,
    summary.multiplier, summary.targetScore, summary.weisWinnerTeamId,
    summary.highestWeis?.id ?? null, summary.stoeckPlayer, summary.matchTeamId];
}

/** Stand am Rundenende; der Dart-Test baut dieselbe Struktur nach. */
function snapshot(game) {
  const first = game.firstCapturedTrick;
  return {
    phase: game.phase,
    round: game.roundNumber,
    dealer: game.dealer,
    forehand: game.forehandPlayer,
    mode: game.roundMode,
    chooser: game.chooserPlayer,
    pushed: game.trumpWasPushed,
    bid: [game.highestBid, game.highestBidder, game.soloPlayer],
    players: game.players.map((p) => [p.bid, p.tricksWon, p.pointsWon, p.totalScore]),
    teams: game.teams.map((team) => team.totalScore),
    piles: [game.capturedTricks[0], game.capturedTricks[1], game.capturedPileOwners[0],
      game.capturedPileOwners[1], game.lastCapturedPile],
    firstTrick: first
      ? [first.pileId, first.winner, first.cards.map((e) => `${e.playerIndex}${cardChar(e.card)}`).join('')]
      : null,
    weis: [game.teamWeisScores[0], game.teamWeisScores[1],
      game.teamWeisBreakdown[0].map((w) => w.id).join('|'),
      game.teamWeisBreakdown[1].map((w) => w.id).join('|'),
      game.weisState?.winningDeclaration?.playerIndex ?? null],
    stoeck: [game.teamStoeckPoints[0], game.teamStoeckPoints[1], game.stoeckPlayer, game.stoeckAnnounced],
    summary: summaryOf(game.roundSummary),
    totals: Object.values(game.roundHistory.at(-1).totals),
  };
}

/** Eine KI-Entscheidung wie im Spielablauf von app.js ausfuehren. */
function aiStep(game, script) {
  const seat = game.currentPlayer;
  const hand = game.players[seat].hand;

  switch (game.phase) {
    case 'bidding': {
      const value = script.bid === 'pass' ? 0 : ai.aiBidDecision(hand, game.highestBid);
      engine.submitBid(game, seat, value);
      return value === 0 ? `x${seat}` : `b${seat}:${value}`;
    }
    case 'chooseTrump': {
      if (script.mode) {
        engine.chooseTrump(game, script.mode);
        coverage.modes[script.mode] = (coverage.modes[script.mode] ?? 0) + 1;
        return `m${seat}:${script.mode}`;
      }
      if (engine.canPushTrump(game) && ai.shouldPushTrump(hand)) {
        engine.pushTrumpChoice(game);
        coverage.pushes += 1;
        return `u${seat}`;
      }
      const mode = engine.isSchieber(game)
        ? ai.bestSchieberMode(hand)
        : ai.bestModeFrom(hand, engine.getAllowedRoundModes(game), {
          multipliers: engine.usesRoundMultipliers(game),
        });
      engine.chooseTrump(game, mode);
      coverage.modes[mode] = (coverage.modes[mode] ?? 0) + 1;
      return `m${seat}:${mode}`;
    }
    case 'announceWeis': {
      const before = game.stoeckAnnounced;
      engine.submitWeisDeclaration(game, seat);
      if (!before && game.stoeckAnnounced) {
        coverage.stoeckInWeis += 1;
      }
      return `w${seat}`;
    }
    case 'playing': {
      const card = ai.aiChooseCard(game, seat);
      if (engine.playCard(game, seat, card.id)) {
        engine.resolveTrick(game);
      }
      return `c${seat}${cardChar(card)}`;
    }
    case 'trickEnd':
      engine.startNextTrick(game);
      return 'n';
    default:
      throw new Error(`Unerwartete Phase ${game.phase}`);
  }
}

function playGame(variantId, matchConfig, seed, script) {
  engine.setRandomSeed(seed);
  const game = engine.createGame({ variantId, playerName: 'Du', matchConfig });
  const rounds = [];

  while (game.phase !== 'gameOver' && rounds.length < MAX_ROUNDS) {
    engine.startRound(game);
    const hands = game.players.map((player) => encodeHand(player.hand));
    const actions = ['s'];
    while (game.phase !== 'roundEnd' && game.phase !== 'gameOver') {
      actions.push(aiStep(game, script));
    }

    const end = snapshot(game);
    rounds.push({ hands, actions: actions.join(' '), end });

    coverage.rounds += 1;
    if (game.stoeckAnnounced) coverage.stoeck += 1;
    if (game.weisState?.awardedTeamId != null) coverage.weisAwarded += 1;
    if (game.roundSummary.matchTeamId != null) coverage.match += 1;
    if (engine.isBieter(game)) {
      if (!actions.some((action) => action.startsWith('b'))) {
        coverage.allPassed += 1;
      }
      if (game.roundSummary.succeeded) coverage.bidsMade += 1; else coverage.bidsFailed += 1;
    }
  }

  coverage.games += 1;
  if (game.phase === 'gameOver') coverage.finished += 1;
  return { seed, finished: game.phase === 'gameOver', rounds };
}

fs.mkdirSync(outDir, { recursive: true });
let totalBytes = 0;

for (const [name, variantId, matchConfig, games, script = {}] of CONFIGS) {
  const fixture = {
    generator: 'tool/export_parity_fixtures.mjs',
    variant: variantId,
    matchConfig: {
      targetScore: matchConfig.targetScore ?? 1500,
      difficulty: matchConfig.difficulty,
      scoring: matchConfig.scoring ?? 'einfach',
    },
    scripted: Object.keys(script),
    games: Array.from(
      { length: games },
      (_, index) => playGame(variantId, matchConfig, 1000 + index * 7919, script),
    ),
  };
  const json = JSON.stringify(fixture);
  fs.writeFileSync(path.join(outDir, `${name}.json`), `${json}\n`);
  totalBytes += json.length;
}
engine.setRandomSeed(null);

console.log(`Fixtures nach ${path.relative(root, outDir)} geschrieben (${(totalBytes / 1024).toFixed(0)} KB).`);
console.log(JSON.stringify(coverage, null, 2));
