// The Dart game engine, compiled to JavaScript by tool/edge/build.sh.
// engine.js sets globalThis.obertaStep (see tool/edge/engine_main.dart and
// lib/online/game/game_server.dart for the JSON in and out).
import './self_shim.ts';
import './engine.js';

export interface StepInput {
  state: unknown | null;
  seats: { seat: string; profile_id: string | null; name: string }[];
  language: string;
  now: number;
  intents: { id: number; token?: string; seat: string; intent: Record<string, unknown> }[];
  seen?: Record<string, number> | null;
  /** Square (day) chat messages after state.lastChat, id = their n: who spoke, for the AFK rule. */
  chat?: { id: number; seat: string | null }[];
  seed?: number;
  /** When dealing: the oldest app build among the people at the table. */
  minBuild?: number;
}

export interface StepOutput {
  changed: boolean;
  version: number;
  state: Record<string, unknown>;
  board: Record<string, unknown>;
  seatViews: Record<string, Record<string, unknown>>;
  lastIntent: number | null;
  nextDue: number | null;
  finished: boolean;
  chat: { mode: string; seats: Record<string, { alive: boolean; family: boolean; silenced: boolean; familyDay: boolean }> };
  departed: string[];
  /** At the end of a game with a winner: the winner and each human seat's outcome. */
  result: { winner: string; seats: Record<string, Record<string, unknown>> } | null;
}

export type Engine = (input: StepInput) => StepOutput;

/** Experience, levels, coins and ratings for a finished game (lib/online/game/match_rewards.dart). */
export type Settle = (input: Record<string, unknown>) => { players: Record<string, unknown>[] };

const g = globalThis as unknown as { obertaStep?: (input: string) => string; obertaSettle?: (input: string) => string };
if (typeof g.obertaStep !== 'function' || typeof g.obertaSettle !== 'function') throw new Error('engine.js did not load');
const obertaStep = g.obertaStep;
const obertaSettle = g.obertaSettle;

/** One server step: in and out as JSON, through the Dart engine. */
export const step: Engine = (input) => JSON.parse(obertaStep(JSON.stringify(input)));

/** Settles a finished game, through the same Dart rules the app tests. */
export const settle: Settle = (input) => JSON.parse(obertaSettle(JSON.stringify(input)));
