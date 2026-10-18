// Steps the games that have something due: a bot, a deadline, a seat going
// offline, or intents waiting. Each game is stepped in its own transaction,
// with its state row locked (select ... for update skip locked): two runs
// never step the same game at once, and the step is computed from the state
// read under that lock. game_commit also refuses a version that does not go
// forward, so a stale step can never overwrite a newer one. One broken game
// does not stop the others. The function keeps nothing between calls.
import type { Engine, Settle, StepInput } from './engine.ts';
import { settle as dartSettle } from './engine.ts';

export interface Tx {
  query<T = Record<string, unknown>>(text: string, params?: unknown[]): Promise<T[]>;
}

export interface Db extends Tx {
  transaction<T>(work: (tx: Tx) => Promise<T>): Promise<T>;
}

export interface RunOptions {
  /** Step this room first (the one that woke us), then the others due. */
  room?: string | null;
  /** The clock, in milliseconds. Default: the database's. */
  now?: number;
  /** How many games at most in one run. */
  limit?: number;
}

const due = `(g.next_due_at <= to_timestamp($1::float8 / 1000)
   or exists (select 1 from public.game_intents i where i.room_id = g.room_id))`;

async function clock(db: Tx, now?: number): Promise<number> {
  if (now !== undefined) return now;
  const [row] = await db.query<{ now: number }>(`select extract(epoch from now()) * 1000 as now`);
  return Number(row.now);
}

/** Steps one game if it is due and nobody else holds it. True if stepped. */
export async function stepRoom(
  db: Db,
  engine: Engine,
  room: string,
  now?: number,
  settle: Settle = dartSettle,
): Promise<boolean> {
  return await db.transaction(async (tx) => {
    const at = await clock(tx, now);
    const games = await tx.query<{ state: unknown; language: string }>(
      `select g.state, r.language
       from internal.game_state g join public.rooms r on r.id = g.room_id
       where g.room_id = $2 and ${due}
       for update of g skip locked`,
      [at, room],
    );
    if (games.length === 0) return false;
    const seats = await tx.query<{ seat: string; profile_id: string | null; name: string; seen: number | null }>(
      `select seat, profile_id::text as profile_id, name, extract(epoch from last_seen) * 1000 as seen
       from public.game_seats where room_id = $1`,
      [room],
    );
    const intents = await tx.query<{ id: number; seat: string; intent: Record<string, unknown> }>(
      `select id::float8 as id, seat, intent from public.game_intents where room_id = $1 order by id limit 200`,
      [room],
    );
    const seen: Record<string, number> = {};
    for (const s of seats) {
      if (s.profile_id !== null && s.seen !== null) seen[s.seat] = Number(s.seen);
    }
    const input: StepInput = {
      state: games[0].state ?? null,
      seats: seats.map((s) => ({ seat: s.seat, profile_id: s.profile_id, name: s.name })),
      language: games[0].language,
      now: at,
      intents: intents.map((i) => ({ id: Number(i.id), seat: i.seat, intent: i.intent })),
      seen,
    };
    const out = engine(input);
    await tx.query(`select internal.game_commit($1::uuid, $2::text::jsonb)`, [room, JSON.stringify(out)]);
    if (out.finished && out.result) await settleGame(tx, settle, room, out.result);
    return true;
  });
}

/**
 * The end of a game, in the same transaction that saved it: experience,
 * levels, coins, ratings (ranked) and the history. settle_input returns
 * null once the game is settled, so a second finished step changes nothing.
 */
export async function settleGame(tx: Tx, settle: Settle, room: string, result: { winner: string }): Promise<void> {
  const [row] = await tx.query<{ input: Record<string, unknown> | null }>(
    `select internal.settle_input($1::uuid, $2::text::jsonb) as input`,
    [room, JSON.stringify(result)],
  );
  if (!row?.input) return;
  const settled = settle(row.input);
  await tx.query(`select internal.record_match($1::uuid, $2, $3::text::jsonb)`, [room, result.winner, JSON.stringify(settled)]);
}

/** Steps every game due (the woken room first). Returns how many. */
export async function runDue(db: Db, engine: Engine, options: RunOptions = {}): Promise<number> {
  const at = await clock(db, options.now);
  const rows = await db.query<{ room_id: string }>(
    `select g.room_id::text as room_id from internal.game_state g where ${due}
     order by g.next_due_at nulls first limit $2`,
    [at, options.limit ?? 50],
  );
  const rooms = [...new Set([...(options.room ? [options.room] : []), ...rows.map((r) => r.room_id)])];
  let stepped = 0;
  for (const room of rooms) {
    try {
      // Intents that arrived while another run held the game are due again
      // right after: a few more steps, while there is something to do.
      for (let round = 0; round < 3 && await stepRoom(db, engine, room, options.now); round++) stepped++;
    } catch (error) {
      console.error(`game ${room}:`, error);
    }
  }
  return stepped;
}
