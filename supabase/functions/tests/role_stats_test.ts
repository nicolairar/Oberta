// The roles collection in Postgres: record_match writes role_stats in the
// same transaction as the history, only for games that counted; the card
// unlocks with the first win; each player reads only their own; nobody
// writes them from a phone; the backfill from older history.
//
//   deno test -A supabase/functions/tests/role_stats_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';

const root = new URL('../../', import.meta.url);
const anna = '11111111-1111-1111-1111-111111111111';
const bruno = '22222222-2222-2222-2222-222222222222';
const room = '44444444-4444-4444-4444-444444444444';
const mine = '20261122090000_role_collection.sql';

/** The database with every migration; [before] runs between the ones
 * before the roles collection and the rest (to test the backfill). */
async function world(before?: (pg: PGlite) => Promise<void>) {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  const migrations = [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort();
  const people = async () => {
    for (const [handle, id] of [['anna', anna], ['bruno', bruno]]) {
      await pg.query(`insert into auth.users (id) values ($1) on conflict do nothing`, [id]);
      await pg.query(`update public.profiles set handle = $1 where id = $2`, [handle, id]);
    }
  };
  for (const name of migrations) {
    if (name === mine && before) {
      await people();
      await before(pg);
    }
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  await people();
  await pg.query(
    `insert into public.rooms (id, code, host, language, status, max_players) values ($1, 'RQKE22', $2, 'it', 'playing', 12)`,
    [room, anna],
  );
  async function as<T = Record<string, unknown>>(who: string, text: string, params: unknown[] = []): Promise<T[]> {
    await pg.exec(`set role authenticated; set request.jwt.claims to '{"sub": "${who}", "role": "authenticated"}'`);
    try {
      return (await pg.query(text, params)).rows as T[];
    } finally {
      await pg.exec('reset role; reset request.jwt.claims');
    }
  }
  return { pg, as };
}

type Seat = { profile: string; seat: string; role: string; won: boolean; counts?: boolean };

/** One settled game, written the way runner.ts writes it. */
async function settle(pg: PGlite, seats: Seat[]) {
  const game = crypto.randomUUID();
  await pg.query(`delete from public.game_seats where room_id = $1`, [room]);
  await pg.query(`delete from public.game_public where room_id = $1`, [room]);
  await pg.query(
    `insert into public.game_public (room_id, host, version, game_id, chat_mode) values ($1, $2, 1, $3, 'day')`,
    [room, anna, game],
  );
  for (const s of seats) {
    await pg.query(
      `insert into public.game_seats (room_id, seat, profile_id, name, alive, family) values ($1, $2, $3, $2, true, false)`,
      [room, s.seat, s.profile],
    );
  }
  const players = seats.map((s) => ({
    profile: s.profile, seat: s.seat, role: s.role, team: 'citizens', won: s.won, survived: true,
    abandoned: false, afk: !(s.counts ?? true), level: 1, xp: 0, levelBefore: 1, xpGained: 0, coins: 0,
    tally: (s.counts ?? true) ? { games: 1, ...(s.won ? { wins: 1, [`role_win:${s.role}`]: 1 } : {}) } : {},
    missions: [], unlocked: s.won && (s.counts ?? true) ? [{ id: `role_${s.role}`, xp: 0, coins: 0 }] : [],
  }));
  await pg.query(`select internal.record_match($1, 'citizens', $2::jsonb)`, [room, JSON.stringify({ players })]);
  return game;
}

type Card = { role: string; played: number; wins: number; losses: number; streak: number; best_streak: number };

Deno.test('a counted game writes the role card; the first win unlocks it; replays change nothing', async () => {
  const { pg, as } = await world();
  await settle(pg, [
    { profile: anna, seat: 's1', role: 'medico', won: false },
    { profile: bruno, seat: 's2', role: 'detective', won: true },
  ]);
  let [{ c }] = await as<{ c: Card[] }>(anna, `select public.my_role_stats() as c`);
  assertEquals(c.map(({ role, played, wins, losses }) => ({ role, played, wins, losses })),
    [{ role: 'medico', played: 1, wins: 0, losses: 1 }], 'played, still locked');

  const game = await settle(pg, [{ profile: anna, seat: 's1', role: 'medico', won: true }]);
  await settle(pg, [{ profile: anna, seat: 's1', role: 'medico', won: true }]);
  // The same game settled again: record_match refuses it.
  await pg.query(`select internal.record_match($1, 'citizens', '{"players": []}')`, [room]);
  [{ c }] = await as<{ c: Card[] }>(anna, `select public.my_role_stats() as c`);
  assertEquals(c[0].played, 3);
  assertEquals(c[0].wins, 2);
  assertEquals(c[0].streak, 2);
  assertEquals(c[0].best_streak, 2);
  const [{ u }] = await as<{ u: { achievements: { id: string }[] } }>(anna, `select public.game_unlocks($1) as u`, [game]);
  assertEquals(u.achievements.map((a) => a.id), ['role_medico'], 'the card achievement, confirmed by the server');

  await settle(pg, [{ profile: anna, seat: 's1', role: 'medico', won: false }]);
  [{ c }] = await as<{ c: Card[] }>(anna, `select public.my_role_stats() as c`);
  assertEquals([c[0].streak, c[0].best_streak, c[0].losses], [0, 2, 2]);
  await pg.close();
});

Deno.test('games that did not count (no tally: AFK, abandoned, bots only) never touch the cards', async () => {
  const { pg, as } = await world();
  await settle(pg, [{ profile: anna, seat: 's1', role: 'sicario', won: true, counts: false }]);
  const [{ c }] = await as<{ c: Card[] }>(anna, `select public.my_role_stats() as c`);
  assertEquals(c, []);
  await pg.close();
});

Deno.test('anti-cheat: own rows only, no writes, no internal access, the public profile shows only the count', async () => {
  const { pg, as } = await world();
  await settle(pg, [
    { profile: anna, seat: 's1', role: 'padrino', won: true },
    { profile: bruno, seat: 's2', role: 'cittadino', won: false },
  ]);
  const [{ c }] = await as<{ c: Card[] }>(bruno, `select public.my_role_stats() as c`);
  assertEquals(c.map((r) => r.role), ['cittadino'], 'bruno never sees anna\'s padrino');
  await assertRejects(() => as(bruno, `select * from internal.role_stats`), Error);
  await assertRejects(() => as(bruno, `insert into internal.role_stats (profile_id, role, played, wins) values ($1, 'sicario', 9, 9)`, [bruno]), Error);
  await assertRejects(() => as(bruno, `select internal.record_role($1, 'sicario', true)`, [bruno]), Error);
  await assertRejects(() => as(bruno, `select internal.record_match($1, 'citizens', '{"players": []}')`, [room]), Error);
  await assertRejects(() => pg.query(`select public.my_role_stats()`), Error, 'not_signed_in');
  await pg.exec(`set role anon`);
  await assertRejects(() => pg.query(`select public.my_role_stats()`), Error);
  await pg.exec(`reset role`);

  const [{ p }] = await as<{ p: Record<string, unknown> }>(bruno, `select public.public_stats('anna') as p`);
  assertEquals(p.roles_unlocked, 1);
  assert(!JSON.stringify(p).includes('best_streak'), 'no per-role card numbers in the public profile');
  await pg.query(`update public.profiles set public_profile = false where id = $1`, [anna]);
  const [{ q }] = await as<{ q: Record<string, unknown> }>(bruno, `select public.public_stats('anna') as q`);
  assertEquals(q.roles_unlocked, undefined, 'a private profile shows nothing');

  const [{ e }] = await as<{ e: { role_stats: { role: string }[] } }>(anna, `select public.export_my_data() as e`);
  assertEquals(e.role_stats.map((r) => r.role), ['padrino']);
  await pg.close();
});

Deno.test('backfill: older history and the lifetime counters become cards and card achievements', async () => {
  const { pg, as } = await world(async (pg) => {
    const rows: [string, boolean, boolean, number][] = [
      // role, won, abandoned, xp
      ['detective', true, false, 100],
      ['detective', true, false, 100],
      ['detective', false, false, 30],
      ['detective', true, false, 100],
      ['detective', true, true, 0], // abandoned: never counts
      ['mafioso', false, false, 0], // no XP (a game that did not count)
    ];
    let i = 0;
    for (const [role, won, abandoned, xp] of rows) {
      await pg.query(
        `insert into public.match_history (game_id, profile_id, language, ranked, players, seat, role, team, winner,
           won, survived, abandoned, xp_gained, level_before, level_after, coins_gained, played_at)
         values ($1, $2, 'it', false, 6, 's1', $3, 'citizens', 'citizens', $4, true, $5, $6, 1, 1, 0,
                 now() - make_interval(days => 10 - $7::int))`,
        [crypto.randomUUID(), anna, role, won, abandoned, xp, i++],
      );
    }
    await pg.query(`insert into internal.player_stats (profile_id, metric, value) values ($1, 'role_win:sarto', 2)`, [anna]);
  });
  const [{ c }] = await as<{ c: Card[] }>(anna, `select public.my_role_stats() as c`);
  const by = Object.fromEntries(c.map((r) => [r.role, r]));
  assertEquals(Object.keys(by).sort(), ['detective', 'sarto']);
  assertEquals([by.detective.played, by.detective.wins, by.detective.streak, by.detective.best_streak], [4, 3, 1, 2]);
  assertEquals([by.sarto.played, by.sarto.wins], [2, 2]);
  const [{ p }] = await as<{ p: { achievements: { id: string }[] } }>(anna, `select public.my_progress() as p`);
  assertEquals(p.achievements.map((a) => a.id).sort(), ['role_detective', 'role_sarto']);
  const [{ n }] = (await pg.query<{ n: number }>(`select count(*)::int as n from public.coin_ledger where reason = 'achievement'`)).rows;
  assertEquals(n, 0, 'the card achievements pay nothing');
  await pg.close();
});
