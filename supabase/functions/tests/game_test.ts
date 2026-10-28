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

/** Every migration in a fresh PGlite, three players in a room with three bots, the game started. */
async function startedGame() {
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
  // The test period: the server fills the table with bots up to six seats.
  await pg.query(
    `insert into internal.config (key, value) values ('friends_test_bots', '1'), ('friends_test_size', '6')
     on conflict (key) do update set value = excluded.value`,
  );
  await as('anna', `select public.start_game($1)`, [room]);
  return { pg, db, as, room };
}

Deno.test('the runner plays a whole game in Postgres: phones see only their own seat', async () => {
  const { pg, db, as, room } = await startedGame();
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

Deno.test('runs that overlap never step a game twice from the same state, and a stale step is refused', async () => {
  const { pg, db, as, room } = await startedGame();
  const now = Number((await pg.query<{ now: number }>(`select extract(epoch from now()) * 1000 as now`)).rows[0].now);
  await runDue(db, step, { now, room });
  const version = async () =>
    Number((await pg.query<{ v: number }>(`select version as v from public.game_public where room_id = $1`, [room])).rows[0].v);
  const before = await version();

  // Three phones confirm their card while two runs (a wake and a tick) go at once.
  const seats: Record<Who, string> = { anna: 's1', bruno: 's2', carla: 's3' };
  for (const who of Object.keys(users) as Who[]) {
    await as(who, `select public.submit_intent($1, $2::jsonb)`, [room, JSON.stringify({ type: 'ack', seat: seats[who], stage: 'reveal-1' })]);
  }
  const [a, b] = await Promise.all([runDue(db, step, { now, room }), runDue(db, step, { now, room })]);
  assertEquals(a + b, 1, 'only one of the runs stepped the game');
  assertEquals(await version(), before + 1);
  const [{ left }] = (await pg.query<{ left: number }>(`select count(*)::int as left from public.game_intents`)).rows;
  assertEquals(left, 0, 'no intent was lost');
  const [board] = await as<{ view: { schedule: { stage: string } } }>('anna', `select view from public.game_public`);
  assertEquals(board.view.schedule.stage, 'night', 'every acknowledgement counted');

  // A step computed from an old snapshot can never overwrite a newer one.
  const stale = { changed: true, state: { stale: true }, board: {}, seatViews: {}, chat: { mode: 'closed', seats: {} } };
  let refused = '';
  try {
    await pg.query(`select internal.game_commit($1::uuid, $2::jsonb)`, [room, JSON.stringify({ ...stale, version: before })]);
  } catch (error) {
    refused = String(error);
  }
  assert(refused.includes('stale_version'), refused);
  assertEquals(await version(), before + 1);
  await pg.close();
});

Deno.test('the cell: only the Jailer and the prisoner read it, and the Jailer has no name', async () => {
  const { pg, db, as, room } = await startedGame();
  const now = Number((await pg.query<{ now: number }>(`select extract(epoch from now()) * 1000 as now`)).rows[0].now);
  await runDue(db, step, { now, room });
  // A night with anna (s1) the Jailer and bruno (s2) in her cell; carla (s3) outside.
  const [current] = (await pg.query<{ version: number; view: unknown; state: unknown }>(
    `select g.version, g.view, s.state from public.game_public g join internal.game_state s using (room_id) where g.room_id = $1`,
    [room],
  )).rows;
  const rights = (extra: Record<string, unknown>) => ({ alive: true, family: false, silenced: false, familyDay: false, ...extra });
  const commit = {
    changed: true,
    version: current.version + 1,
    state: current.state,
    board: current.view,
    seatViews: {},
    chat: {
      mode: 'night',
      seats: {
        s1: rights({ jail: 'jail:1', jailer: true }),
        s2: rights({ jail: 'jail:1', jailed: true, family: true }),
        s3: rights({ family: true }),
      },
    },
  };
  await pg.query(`select internal.game_commit($1::uuid, $2::jsonb)`, [room, JSON.stringify(commit)]);

  const [{ send_chat: fromJailer }] = await as<{ send_chat: string }>('anna', `select public.send_chat($1, 'jail', 'Chi sei?')`, [room]);
  await as('bruno', `select public.send_chat($1, 'jail', 'Nessuno.')`, [room]);
  type Row = { id: string; channel: string; profile_id: string | null; seat: string | null; name: string; body: string };
  const read = (who: Who) =>
    as<Row>(who, `select id, channel, profile_id, seat, name, body from public.game_chat where channel like 'jail:%' order by n`);
  const prisoner = await read('bruno');
  assertEquals(prisoner.map((r) => r.body), ['Chi sei?', 'Nessuno.']);
  assertEquals(prisoner[0], { id: fromJailer, channel: 'jail:1', profile_id: null, seat: null, name: '', body: 'Chi sei?' });
  assertEquals((await read('anna')).length, 2, 'the Jailer reads the cell');
  assertEquals(await read('carla'), [], 'nobody else reads it');

  // Outsiders cannot write in it; the prisoner cannot write to the family.
  for (const [who, channel] of [['carla', 'jail'], ['bruno', 'family']] as [Who, string][]) {
    let refused = '';
    try {
      await as(who, `select public.send_chat($1, $2, 'ciao')`, [room, channel]);
    } catch (error) {
      refused = String(error);
    }
    assert(refused.includes('chat_closed'), `${who} ${channel}: ${refused}`);
  }
  await as('carla', `select public.send_chat($1, 'family', 'ci sono')`, [room]);
  assertEquals(await as('bruno', `select body from public.game_chat where channel = 'family'`), [], 'the prisoner does not read the family');

  // Who wrote it stays on the server, out of every phone's reach.
  const [{ author }] = (await pg.query<{ author: string }>(
    `select profile_id::text as author from internal.jail_authors where message_id = $1`,
    [fromJailer],
  )).rows;
  assertEquals(author, users.anna);
  let hidden = false;
  try {
    await as('anna', `select * from internal.jail_authors`);
  } catch {
    hidden = true;
  }
  assert(hidden, 'no phone reads the authors');
  await pg.close();
});

const newRoles = ['prostituta', 'carceriere', 'pacifista'];
const dealt = (out: StepOutput) => (out.board.board as { deck: { role: string }[] }).deck.map((d) => d.role);

Deno.test('a table with an old build is never dealt a role that build cannot read', () => {
  const seats = Array.from({ length: 12 }, (_, i) => ({
    seat: `s${i + 1}`,
    profile_id: i < 2 ? `p${i + 1}` : null,
    name: i < 2 ? `human${i + 1}` : `bot.${i}`,
  }));
  const now = Date.UTC(2026, 9, 28, 16);
  let seenNew = false;
  for (let seed = 1; seed <= 40; seed++) {
    const old = dealt(step({ state: null, seats, language: 'it', now, intents: [], seed, minBuild: 65 }));
    for (const role of newRoles) assert(!old.includes(role), `seed ${seed}: build 65 is dealt ${role}`);
    const fresh = dealt(step({ state: null, seats, language: 'it', now, intents: [], seed, minBuild: 66 }));
    if (fresh.some((r) => newRoles.includes(r))) seenNew = true;
  }
  assert(seenNew, 'build 66 tables still get the new roles');
});

Deno.test('two people on build 65 in a friends room: bots fill the table and the game goes on', async () => {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  const migrations = [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort();
  for (const name of migrations) {
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  const db = pgliteDb(pg);
  const people = { anna: users.anna, bruno: users.bruno };
  for (const [name, id] of Object.entries(people)) {
    await pg.query(`insert into auth.users (id) values ($1)`, [id]);
    await pg.query(`update public.profiles set handle = $1 where id = $2`, [name, id]);
  }
  const headers = JSON.stringify({ 'x-app-build': '65', 'x-app-platform': 'ios' });
  async function as<T = Record<string, unknown>>(who: 'anna' | 'bruno', text: string, params: unknown[] = []): Promise<T[]> {
    await pg.exec(
      `set role authenticated; set request.jwt.claims to '{"sub": "${people[who]}", "role": "authenticated"}'; set request.headers to '${headers}'`,
    );
    try {
      return (await pg.query(text, params)).rows as T[];
    } finally {
      await pg.exec('reset role; reset request.jwt.claims; reset request.headers');
    }
  }
  const [{ id: room, code }] = await as<{ id: string; code: string }>('anna', `select id, code from public.create_room('it')`);
  await as('bruno', `select public.join_room($1)`, [code]);
  // Production: the test period on, no size cap (the room's own size).
  await pg.query(`delete from internal.config where key = 'friends_test_size'`);
  await pg.query(
    `insert into internal.config (key, value) values ('friends_test_bots', '1') on conflict (key) do update set value = excluded.value`,
  );
  const builds = (await pg.query<{ build: number }>(`select build from internal.client_builds order by build`)).rows;
  assertEquals(builds.map((b) => b.build), [65, 65], 'both builds are recorded');
  await as('anna', `select public.start_game($1)`, [room]);

  let now = Number((await pg.query<{ now: number }>(`select extract(epoch from now()) * 1000 as now`)).rows[0].now);
  assertEquals(await runDue(db, step, { now, room }), 1, 'the runner deals the cards');
  const [{ seats }] = (await pg.query<{ seats: number }>(`select count(*)::int as seats from public.game_seats where room_id = $1`, [room])).rows;
  assertEquals(seats, 12, 'bots fill the room up to its size');
  const [first] = await as<{ view: { board: { deck: { role: string }[] }; schedule: { stage: string } } }>(
    'anna',
    `select view from public.game_public`,
  );
  assertEquals(first.view.schedule.stage, 'reveal');
  for (const { role } of first.view.board.deck) assert(!newRoles.includes(role), `build 65 is dealt ${role}`);

  // Nobody does anything: the clock alone moves the game on.
  const stages = new Set<string>();
  for (let i = 0; i < 6; i++) {
    const [{ due }] = (await pg.query<{ due: number }>(
      `select extract(epoch from next_due_at) * 1000 as due from internal.game_state where room_id = $1`,
      [room],
    )).rows;
    now = Math.max(now, Number(due));
    await pg.query(`update public.game_seats set last_seen = to_timestamp($1::float8 / 1000) where room_id = $2`, [now, room]);
    await runDue(db, step, { now });
    const [board] = await as<{ view: { schedule: { stage: string } } }>('bruno', `select view from public.game_public`);
    stages.add(board.view.schedule.stage);
  }
  assert(stages.has('night'), `the game reaches the night: ${[...stages]}`);
  await pg.close();
});
