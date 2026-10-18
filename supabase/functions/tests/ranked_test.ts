// Ranked, in Postgres: the queue, the matcher, penalties, and a whole ranked
// game settled by the runner (experience, coins, ratings, history), with the
// row-level security a phone runs under.
//
//   deno test -A supabase/functions/tests/ranked_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { step } from '../game/engine.ts';
import { type Db, runDue, type Tx } from '../game/runner.ts';

const root = new URL('../../', import.meta.url);

function pgliteDb(pg: PGlite): Db {
  const tx = (q: { query: PGlite['query'] }): Tx => ({
    query: async (text, params = []) => (await q.query(text, params)).rows as never[],
  });
  return { ...tx(pg), transaction: (work) => pg.transaction((t) => work(tx(t))) };
}

const ids = Array.from({ length: 12 }, (_, i) => `00000000-0000-0000-0000-${String(i + 1).padStart(12, '0')}`);

async function world(people = 12) {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  const migrations = [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort();
  for (const name of migrations) {
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  for (let i = 0; i < people; i++) {
    await pg.query(`insert into auth.users (id) values ($1)`, [ids[i]]);
    await pg.query(`update public.profiles set handle = $1 where id = $2`, [`player${String.fromCharCode(97 + i)}`, ids[i]]);
  }
  async function as<T = Record<string, unknown>>(who: string, text: string, params: unknown[] = []): Promise<T[]> {
    await pg.exec(`set role authenticated; set request.jwt.claims to '{"sub": "${who}", "role": "authenticated"}'`);
    try {
      return (await pg.query(text, params)).rows as T[];
    } finally {
      await pg.exec('reset role; reset request.jwt.claims');
    }
  }
  const one = async <T = Record<string, unknown>>(text: string, params: unknown[] = []) =>
    (await pg.query(text, params)).rows[0] as T;
  const enqueue = (who: string, lang = 'it') => as(who, `select public.enqueue_ranked($1)`, [lang]);
  const match = async () => (await one<{ n: number }>(`select internal.ranked_match() as n`)).n;
  const queued = async () => (await one<{ n: number }>(`select count(*)::int as n from internal.ranked_queue`)).n;
  return { pg, db: pgliteDb(pg), as, one, enqueue, match, queued };
}

Deno.test('the queue: signed in with a handle, one entry per person, a language each', async () => {
  const { pg, as, enqueue, queued, one } = await world(2);
  await pg.query(`insert into auth.users (id) values ('99999999-9999-9999-9999-999999999999')`);
  await assertRejects(() => enqueue('99999999-9999-9999-9999-999999999999'), Error, 'profile_incomplete');
  await assertRejects(() => enqueue(ids[0], 'fr'), Error, 'invalid_language');
  await enqueue(ids[0]);
  await enqueue(ids[0]);
  assertEquals(await queued(), 1, 'no double queue');
  await enqueue(ids[0], 'en');
  assertEquals((await one<{ language: string }>(`select language from internal.ranked_queue`)).language, 'en');
  const [{ status }] = await as<{ status: { queued: boolean; language: string; estimate: number } }>(
    ids[0],
    `select public.ranked_status() as status`,
  );
  assert(status.queued && status.language === 'en' && status.estimate > 0);
  await as(ids[0], `select public.leave_ranked_queue()`);
  assertEquals(await queued(), 0);
  // Phones read nothing of the queue or the conduct table.
  await assertRejects(() => as(ids[0], `select * from internal.ranked_queue`));
  await assertRejects(() => as(ids[0], `select * from internal.conduct`));
  await pg.close();
});

Deno.test('the matcher: eight at once, six to ten after a minute, never bots, never twice', async () => {
  const { pg, as, enqueue, match, queued, one } = await world(12);
  for (let i = 0; i < 7; i++) await enqueue(ids[i]);
  assertEquals(await match(), 0, 'seven are not enough');
  await enqueue(ids[7]);
  assertEquals(await match(), 1);
  assertEquals(await queued(), 0);
  const room = await one<{ id: string; ranked: boolean; bots: number; status: string; test_match: boolean }>(
    `select id, ranked, bots, status, test_match from public.rooms where ranked`,
  );
  assert(room.ranked && !room.test_match);
  assertEquals(room.bots, 0);
  assertEquals(room.status, 'playing');
  const seats = await one<{ humans: number; bots: number }>(
    `select count(profile_id)::int as humans, count(*) filter (where profile_id is null)::int as bots from public.game_seats where room_id = $1`,
    [room.id],
  );
  assertEquals(seats, { humans: 8, bots: 0 });
  const [{ status }] = await as<{ status: { room: string; queued: boolean } }>(ids[3], `select public.ranked_status() as status`);
  assertEquals(status.room, room.id, 'the phone learns its room');
  await assertRejects(() => enqueue(ids[3]), Error, 'already_in_game');

  // Bots can never be added, by the host or by anyone.
  await assertRejects(() => pg.query(`update public.rooms set bots = 2 where id = $1`, [room.id]), Error, 'rooms_ranked_without_bots');
  await assertRejects(() => as(ids[0], `select public.set_room_bots($1, 2)`, [room.id]), Error, 'not_allowed');
  await assertRejects(
    () => pg.query(`insert into public.game_seats (room_id, seat, profile_id, name) values ($1, 's9', null, 'bot.x')`, [room.id]),
    Error,
    'no_bots_in_ranked',
  );
  // No host powers, no joining by code, no lobby chat among strangers.
  await pg.query(`update public.rooms set status = 'lobby' where id = $1`, [room.id]);
  await assertRejects(() => as(ids[0], `select public.start_game($1)`, [room.id]), Error, 'not_allowed');
  const { code } = await one<{ code: string }>(`select code from public.rooms where id = $1`, [room.id]);
  await assertRejects(() => as(ids[9], `select public.join_room($1)`, [code]), Error, 'room_');
  await pg.query(`update public.room_members set left_at = now() where room_id = $1 and profile_id = $2`, [room.id, ids[7]]);
  await assertRejects(() => as(ids[9], `select public.join_room($1)`, [code]), Error, 'room_closed', 'even with a free seat');
  await assertRejects(() => as(ids[1], `select public.send_chat($1, 'lobby', 'ciao')`, [room.id]), Error, 'chat_closed');

  // Six who waited over a minute play; six fresh ones do not.
  for (let i = 8; i < 12; i++) await enqueue(ids[i], 'en');
  await pg.query(`update public.rooms set status = 'ended' where id = $1`, [room.id]);
  for (let i = 0; i < 2; i++) await enqueue(ids[i], 'en');
  assertEquals(await match(), 0, 'six fresh players wait for eight');
  await pg.query(`update internal.ranked_queue set joined_at = now() - interval '70 seconds'`);
  assertEquals(await match(), 1, 'after a minute six are enough');
  assertEquals((await one<{ n: number }>(`select max_players::int as n from public.rooms where ranked and language = 'en'`)).n, 6);
  await pg.close();
});

Deno.test('the matcher pairs by rating band and by conduct, and drops silent phones', async () => {
  const { pg, enqueue, match, queued } = await world(12);
  // Four new players and four far stronger ones.
  for (let i = 4; i < 8; i++) {
    await pg.query(`insert into public.ratings (profile_id, language, mu, sigma) values ($1, 'it', 45, 2)`, [ids[i]]);
  }
  for (let i = 0; i < 8; i++) await enqueue(ids[i]);
  assertEquals(await match(), 0, 'too far apart while the wait is short');
  await pg.query(`update internal.ranked_queue set joined_at = now() - interval '6 minutes', seen_at = now()`);
  assertEquals(await match(), 1, 'after a long wait the band opens');

  // Two frequent leavers never land with the others.
  await pg.exec(`delete from public.room_members; delete from public.rooms; delete from public.ratings`);
  await pg.query(`insert into internal.conduct (profile_id, score) values ($1, 40), ($2, 40)
                  on conflict (profile_id) do update set score = 40`, [ids[0], ids[1]]);
  for (let i = 0; i < 8; i++) await enqueue(ids[i]);
  assertEquals(await match(), 0, 'six well-behaved and two leavers are not a table of eight');
  for (let i = 8; i < 10; i++) await enqueue(ids[i]);
  assertEquals(await match(), 1);
  const left = (await pg.query<{ profile_id: string }>(`select profile_id from internal.ranked_queue order by profile_id`)).rows;
  assertEquals(left.map((r) => r.profile_id), [ids[0], ids[1]], 'the leavers wait for their own kind');

  // A phone silent for 20 seconds leaves the queue.
  await pg.query(`update internal.ranked_queue set seen_at = now() - interval '30 seconds'`);
  await match();
  assertEquals(await queued(), 0);
  await pg.close();
});

Deno.test('TEST ONLY flag: two people and bots, never ranked', async () => {
  const { pg, enqueue, match, one } = await world(2);
  await enqueue(ids[0]);
  await enqueue(ids[1]);
  assertEquals(await match(), 0, 'off by default');
  await pg.query(`insert into internal.config values ('ranked_test_humans', '2')`);
  assertEquals(await match(), 1);
  const room = await one<{ ranked: boolean; test_match: boolean; bots: number; status: string }>(
    `select ranked, test_match, bots, status from public.rooms`,
  );
  assertEquals(room, { ranked: false, test_match: true, bots: 6, status: 'playing' });
  await pg.close();
});

Deno.test('penalties: two warnings, then 5/15/30/60 minutes; clean games and 24 hours forgive', async () => {
  const { pg, as, enqueue, one } = await world(1);
  const me = ids[0];
  await pg.query(`insert into public.rooms (id, code, host, language, ranked) values
                  ('aaaaaaaa-0000-0000-0000-000000000001', 'ABCDEF', $1, 'it', true),
                  ('aaaaaaaa-0000-0000-0000-000000000002', 'ABCDEG', $1, 'it', false)`, [me]);
  const abandon = (room: string) =>
    pg.query(`insert into internal.game_abandons (profile_id, room_id, game_id, seat) values ($1, $2, gen_random_uuid(), 's1')`, [me, room]);
  const status = async () => (await as<{ s: { cooldown_until: number | null; warning: boolean } }>(me, `select public.ranked_status() as s`))[0].s;
  const minutesLeft = async () => {
    const s = await status();
    return s.cooldown_until === null ? 0 : Math.round((s.cooldown_until - Date.now()) / 60000);
  };

  await abandon('aaaaaaaa-0000-0000-0000-000000000002');
  assertEquals((await status()).warning, false, 'friends games never count');
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 0);
  assertEquals((await status()).warning, true, 'first time: a warning');
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 0, 'second time: a warning');
  await enqueue(me);
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 5);
  await assertRejects(() => enqueue(me), Error, 'ranked_cooldown');
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 15);
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 30);
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 60);
  await abandon('aaaaaaaa-0000-0000-0000-000000000001');
  assertEquals(await minutesLeft(), 60, 'never more than an hour');
  assert((await one<{ score: number }>(`select score from internal.conduct`)).score < 70, 'the conduct score sinks');

  // 24 clean hours wipe the strikes (the cooldown already ran out).
  await pg.query(`update internal.conduct set last_abandon_at = now() - interval '25 hours', cooldown_until = now() - interval '1 hour'`);
  await enqueue(me);
  assertEquals((await one<{ strikes: number }>(`select strikes from internal.conduct`)).strikes, 0);
  await pg.close();
});

type View = { seat: string; alive: boolean; action: { type: string; targets: string[] } | null };
const ackStages = new Set(['reveal', 'dawnFilms', 'dawn', 'discussion', 'verdictFilm', 'verdict']);

Deno.test('a whole ranked game: XP, levels, coins, ratings and history, written only by the server', async () => {
  const { pg, db, as, enqueue, match, one } = await world(8);
  const players = ids.slice(0, 8);
  for (const p of players) await enqueue(p);
  assertEquals(await match(), 1);
  const { id: room } = await one<{ id: string }>(`select id from public.rooms where ranked`);
  let now = Number((await one<{ now: number }>(`select extract(epoch from now()) * 1000 as now`)).now);
  await runDue(db, step, { now, room });

  const acted = new Map<string, string>();
  for (let i = 0; i < 3000; i++) {
    let sent = false;
    for (const who of players) {
      const [mine] = await as<{ view: { view: View } }>(who, `select view from public.game_seat_views`);
      const [board] = await as<{ view: { schedule: { stage: string; key: string } } }>(who, `select view from public.game_public`);
      const schedule = board.view.schedule;
      if (acted.get(who) === schedule.key) continue;
      const view = mine.view.view;
      let intent: Record<string, unknown> | null = null;
      if (view.action) {
        intent = view.action.targets[0]
          ? { type: view.action.type, seat: view.seat, target: view.action.targets[0] }
          : { type: 'pass', seat: view.seat };
      } else if (ackStages.has(schedule.stage) && view.alive) {
        intent = { type: 'ack', seat: view.seat, stage: schedule.key };
      }
      if (!intent) continue;
      await as(who, `select public.submit_intent($1, $2::jsonb)`, [room, JSON.stringify(intent)]);
      acted.set(who, schedule.key);
      sent = true;
    }
    if (!sent) {
      const { due } = await one<{ due: number | null }>(
        `select extract(epoch from next_due_at) * 1000 as due from internal.game_state where room_id = $1`,
        [room],
      );
      if (due === null) break;
      now = Math.max(now, Number(due));
    }
    // The phones are all there (submit_intent stamps the real clock).
    await pg.query(`update public.game_seats set last_seen = to_timestamp($1::float8 / 1000) where room_id = $2`, [now, room]);
    await runDue(db, step, { now });
    if ((await one<{ status: string }>(`select status from public.rooms where id = $1`, [room])).status !== 'playing') break;
  }

  const history = (await pg.query<{
    abandoned: boolean;
    profile_id: string; won: boolean; xp_gained: number; level_after: number; coins_gained: number; rating_delta: number; ranked: boolean;
  }>(`select * from public.match_history order by seat`)).rows;
  assertEquals(history.length, 8, 'everyone settled once');
  assert(history.every((h) => h.ranked && !h.abandoned));
  const winners = history.filter((h) => h.won);
  const losers = history.filter((h) => !h.won);
  assert(winners.length > 0 && losers.length > 0);
  for (const w of winners) {
    assertEquals(w.xp_gained, 200, 'a win plus the first win of the day');
    assertEquals(w.level_after, 2);
    assertEquals(w.coins_gained, 150);
    assert(w.rating_delta > 0, 'winners go up');
  }
  for (const l of losers) {
    assertEquals(l.xp_gained, 30);
    assert(l.rating_delta < 0, 'losers go down');
  }
  const ratings = (await pg.query<{ profile_id: string; mu: number; sigma: number; games: number }>(`select * from public.ratings`)).rows;
  assertEquals(ratings.length, 8);
  for (const r of ratings) {
    assert(r.sigma < 25 / 3, 'uncertainty shrinks');
    assertEquals(r.games, 1);
    const won = winners.some((w) => w.profile_id === r.profile_id);
    assert(won ? r.mu > 25 : r.mu < 25, `${won ? 'winner' : 'loser'} mu ${r.mu}`);
  }
  const winner = winners[0].profile_id;
  assertEquals((await one<{ level: number; xp: number; coins: number }>(`select level, xp, coins from public.profiles where id = $1`, [winner])),
    { level: 2, xp: 25, coins: 150 });
  assertEquals((await one<{ n: number }>(`select count(*)::int as n from public.coin_ledger where reason = 'level_up'`)).n, winners.length);

  // Settling twice changes nothing.
  await pg.query(`select internal.record_match($1, 'mafia', '{"players": []}')`, [room]);
  assertEquals((await one<{ n: number }>(`select count(*)::int as n from public.match_history`)).n, 8);

  // Each phone reads only its own history and rating; nobody writes them.
  const mine = await as<{ profile_id: string }>(winner, `select profile_id from public.match_history`);
  assertEquals(mine.map((r) => r.profile_id), [winner]);
  assertEquals((await as(winner, `select * from public.ratings`)).length, 1);
  await assertRejects(() => as(winner, `update public.ratings set mu = 99`));
  await assertRejects(() => as(winner, `insert into public.ratings (profile_id, language) values ($1, 'en')`, [winner]));
  await assertRejects(() => as(winner, `update public.match_history set won = true`));
  await assertRejects(() => as(winner, `delete from public.match_history`));
  await assertRejects(() => as(winner, `update public.profiles set xp = 9999, level = 50 where id = $1`, [winner]));
  await assertRejects(() => as(winner, `select internal.record_match($1, 'mafia', '{}')`, [room]));
  await assertRejects(() => as(winner, `select public.grant_coins($1, 1000, 'gift')`, [winner]));
  await pg.close();
});
