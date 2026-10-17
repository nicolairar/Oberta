// The compiled engine and the Edge Function's runner, end to end.
//
//   deno test -A supabase/functions/tests/game_test.ts
//
// The first test plays whole games through engine.js alone. The second runs
// every migration in PGlite (Postgres in WebAssembly, with the stubs in
// pglite_prelude.sql standing in for Supabase), starts a game as the host,
// and plays it to the end: phones call the same RPCs as the app, under their
// own role, and the runner steps the game exactly as the Edge Function does.
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { step, type StepOutput } from '../game/engine.ts';
import { type Db, runDue, type Tx } from '../game/runner.ts';

const root = new URL('../../', import.meta.url);

type View = {
  seat: string;
  alive: boolean;
  role: string;
  action: { type: string; targets: string[] } | null;
};

/** A phone that always picks the first allowed target. */
function moveFor(view: View): Record<string, unknown> | null {
  const action = view.action;
  if (!action) return null;
  const target = action.targets[0];
  if (!target) return { type: 'pass', seat: view.seat };
  return { type: action.type, seat: view.seat, target };
}

const ackStages = new Set(['reveal', 'dawnFilms', 'dawn', 'discussion', 'verdictFilm', 'verdict']);

Deno.test('engine.js plays whole games: deal, moves, acks, bots, deadlines, the end', () => {
  for (let seed = 1; seed <= 5; seed++) {
    const seats = [
      { seat: 's1', profile_id: 'p1', name: 'anna' },
      { seat: 's2', profile_id: 'p2', name: 'bruno' },
      { seat: 's3', profile_id: null, name: 'bot.alfa' },
      { seat: 's4', profile_id: null, name: 'bot.bravo' },
      { seat: 's5', profile_id: null, name: 'bot.charlie' },
    ];
    let now = Date.UTC(2026, 9, 17, 20);
    let out: StepOutput = step({ state: null, seats, language: 'it', now, intents: [], seed });
    let id = 0;
    const acted = new Map<string, string>();
    for (let i = 0; i < 2000 && !out.finished; i++) {
      const schedule = out.board.schedule as { stage: string; key: string };
      const intents = [];
      for (const [seat, payload] of Object.entries(out.seatViews)) {
        const view = payload.view as View;
        assertEquals(view.seat, seat, 'each seat gets its own view');
        if (acted.get(seat) === schedule.key) continue;
        const move = moveFor(view);
        if (move) intents.push({ id: ++id, seat, intent: move });
        else if (ackStages.has(schedule.stage) && view.alive) intents.push({ id: ++id, seat, intent: { type: 'ack', seat, stage: schedule.key } });
        else continue;
        acted.set(seat, schedule.key);
      }
      if (intents.length === 0) now = Math.max(now, out.nextDue!);
      out = step({ state: out.state, seats, language: 'it', now, intents, seed: seed * 1000 + i });
      const board = out.board.board as { finalRoles: unknown[]; phase: string };
      if (board.phase !== 'ended') assertEquals(board.finalRoles, [], 'cards stay hidden until the end');
      assertEquals(Object.keys(out.seatViews).sort(), ['s1', 's2'], 'bots have no views');
    }
    assert(out.finished, `game ${seed} ends`);
    const board = out.board.board as { winner: string | null; finalRoles: unknown[] };
    assert(board.winner, 'somebody wins');
    assertEquals(board.finalRoles.length, 5);
    assertEquals(out.nextDue, null);
  }
});

// ---------------------------------------------------------------------------

function pgliteDb(pg: PGlite): Db {
  const tx = (q: { query: PGlite['query'] }): Tx => ({
    query: async (text, params = []) => (await q.query(text, params)).rows as never[],
  });
  return { ...tx(pg), transaction: (work) => pg.transaction((t) => work(tx(t))) };
}

const users = {
  anna: '11111111-1111-1111-1111-111111111111',
  bruno: '22222222-2222-2222-2222-222222222222',
  carla: '33333333-3333-3333-3333-333333333333',
};
type Who = keyof typeof users;

Deno.test('the runner plays a whole game in Postgres: phones see only their own seat', async () => {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  const migrations = [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort();
  for (const name of migrations) {
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  const db = pgliteDb(pg);

  for (const [name, id] of Object.entries(users)) {
    await pg.query(`insert into auth.users (id) values ($1)`, [id]);
    await pg.query(`update public.profiles set handle = $1 where id = $2`, [name, id]);
  }

  /** A query from a phone: the authenticated role, as that user. */
  async function as<T = Record<string, unknown>>(who: Who, text: string, params: unknown[] = []): Promise<T[]> {
    await pg.exec(`set role authenticated; set request.jwt.claims to '{"sub": "${users[who]}", "role": "authenticated"}'`);
    try {
      return (await pg.query(text, params)).rows as T[];
    } finally {
      await pg.exec('reset role; reset request.jwt.claims');
    }
  }

  const [{ id: room, code }] = await as<{ id: string; code: string }>('anna', `select id, code from public.create_room('it')`);
  await as('bruno', `select public.join_room($1)`, [code]);
  await as('carla', `select public.join_room($1)`, [code]);
  await as('anna', `select public.set_room_bots($1, 3)`, [room]);
  await as('anna', `select public.start_game($1)`, [room]);
  const [{ calls }] = await pg.query<{ calls: number }>(`select count(*)::int as calls from net.calls`).then((r) => r.rows);
  assert(calls >= 1, 'starting wakes the function');

  let now = Number((await pg.query<{ now: number }>(`select extract(epoch from now()) * 1000 as now`)).rows[0].now);
  assertEquals(await runDue(db, step, { now, room }), 1, 'the runner deals the cards');

  const seatOf: Record<Who, string> = { anna: 's1', bruno: 's2', carla: 's3' };
  const acted = new Map<Who, string>();
  let finished = false;
  for (let i = 0; i < 1500 && !finished; i++) {
    // The phones are all there.
    await pg.query(`update public.game_seats set last_seen = to_timestamp($1::float8 / 1000) where room_id = $2`, [now, room]);
    let sent = false;
    for (const who of Object.keys(users) as Who[]) {
      const views = await as<{ seat: string; view: { view: View } }>(who, `select seat, view from public.game_seat_views`);
      assertEquals(views.map((v) => v.seat), [seatOf[who]], `${who} reads only their own seat`);
      const [board] = await as<{ view: { schedule: { stage: string; key: string } } }>(who, `select view from public.game_public`);
      const schedule = board.view.schedule;
      if (acted.get(who) === schedule.key) continue;
      const view = views[0].view.view;
      const move = moveFor(view);
      if (move) {
        await as(who, `select public.submit_intent($1, $2::jsonb)`, [room, JSON.stringify(move)]);
      } else if (ackStages.has(schedule.stage) && view.alive) {
        await as(who, `select public.submit_intent($1, $2::jsonb)`, [room, JSON.stringify({ type: 'ack', seat: view.seat, stage: schedule.key })]);
      } else {
        continue;
      }
      acted.set(who, schedule.key);
      sent = true;
    }
    if (!sent) {
      const [{ due }] = (await pg.query<{ due: number | null }>(
        `select extract(epoch from next_due_at) * 1000 as due from internal.game_state where room_id = $1`,
        [room],
      )).rows;
      assert(due !== null, 'a running game always has a next appointment');
      now = Math.max(now, Number(due));
    }
    await runDue(db, step, { now });
    const [{ status }] = (await pg.query<{ status: string }>(`select status from public.rooms where id = $1`, [room])).rows;
    finished = status === 'lobby';
  }
  assert(finished, 'the game ends and the room goes back to the lobby');
  const [end] = await as<{ view: { board: { winner: string; finalRoles: unknown[] }; schedule: { stage: string } } }>(
    'bruno',
    `select view from public.game_public`,
  );
  assertEquals(end.view.schedule.stage, 'ended');
  assert(end.view.board.winner);
  assertEquals(end.view.board.finalRoles.length, 6);
  const [{ left }] = (await pg.query<{ left: number }>(`select count(*)::int as left from public.game_intents`)).rows;
  assertEquals(left, 0, 'every intent was handled');

  // No phone ever reads the secret state.
  for (const who of Object.keys(users) as Who[]) {
    let refused = false;
    try {
      await as(who, `select state from internal.game_state`);
    } catch {
      refused = true;
    }
    assert(refused, `${who} cannot read the engine state`);
  }
  await pg.close();
});
