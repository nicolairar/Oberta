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
  intents: { id: number; seat: string; intent: Record<string, unknown> }[];
  seen?: Record<string, number> | null;
  seed?: number;
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
}

export type Engine = (input: StepInput) => StepOutput;

const g = globalThis as unknown as { obertaStep?: (input: string) => string };
if (typeof g.obertaStep !== 'function') throw new Error('engine.js did not load');
const obertaStep = g.obertaStep;

/** One server step: in and out as JSON, through the Dart engine. */
export const step: Engine = (input) => JSON.parse(obertaStep(JSON.stringify(input)));
