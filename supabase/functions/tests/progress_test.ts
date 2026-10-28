// Missions, achievements and the leaderboard, in Postgres: assignment, what
// a settled game writes (progress, coins, free items), the results-screen
// banners and a leaderboard with only handles and tiers.
//
//   deno test -A supabase/functions/tests/progress_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';

const root = new URL('../../', import.meta.url);
const anna = '11111111-1111-1111-1111-111111111111';
const bruno = '22222222-2222-2222-2222-222222222222';
const game = '33333333-3333-3333-3333-333333333333';

async function world() {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  const migrations = [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort();
  for (const name of migrations) {
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  for (const [handle, id] of [['anna', anna], ['bruno', bruno]]) {
    await pg.query(`insert into auth.users (id) values ($1)`, [id]);
    await pg.query(`update public.profiles set handle = $1 where id = $2`, [handle, id]);
  }
  async function as<T = Record<string, unknown>>(who: string, text: string, params: unknown[] = []): Promise<T[]> {
    await pg.exec(`set role authenticated; set request.jwt.claims to '{"sub": "${who}", "role": "authenticated"}'`);
    try {
      return (await pg.query(text, params)).rows as T[];
    } finally {
      await pg.exec('reset role; reset request.jwt.claims');
    }
  }
  const coins = async (id: string) =>
    (await pg.query<{ coins: number }>(`select coins from public.wallets where profile_id = $1`, [id])).rows[0].coins;
  return { pg, as, coins };
}

type Mission = {
  id: string;
  cadence: string;
  pool: number;
  progress: number;
  completed: boolean;
  claimed: boolean;
  coins: number;
  reputation: number;
  item: string | null;
};

Deno.test('missions: one daily and one weekly from each pool, the same on every call, plus the long ones', async () => {
  const { as } = await world();
  const [{ p: first }] = await as<{ p: { missions: Mission[] } }>(anna, `select public.my_progress() as p`);
  const [{ p: again }] = await as<{ p: { missions: Mission[] } }>(anna, `select public.my_progress() as p`);
  for (const cadence of ['daily', 'weekly']) {
    const dealt = first.missions.filter((m) => m.cadence === cadence);
    assertEquals(dealt.map((m) => m.pool).sort(), [1, 2, 3], cadence);
  }
  assertEquals(again.missions.map((m) => m.id), first.missions.map((m) => m.id));
  for (const m of first.missions) assert(m.coins <= ({ daily: 60, weekly: 250, long: 1000 } as Record<string, number>)[m.cadence]);
  const long = first.missions.filter((m) => m.cadence === 'long');
  assert(long.length >= 10, 'the obiettivi are always there');
  assert(long.some((m) => m.id === 'long_detective_wins_5' && m.item === 'hat.sbirro' && !m.completed));
});

Deno.test('a settled game writes progress, pays coins and items once, and shows its banners', async () => {
  const { pg, as, coins } = await world();
  const [{ p }] = await as<{ p: { missions: Mission[] } }>(anna, `select public.my_progress() as p`);
  const daily = p.missions.find((m) => m.cadence === 'daily')!;
  const [{ period }] = (await pg.query<{ period: string }>(
    `select internal.mission_period('daily')::text as period`,
  )).rows;
  const before = await coins(anna);
  const settled = {
    tally: { games: 1, wins: 1, 'role_win:medico': 1, 'role_win:detective': 1 },
    missions: [{ id: daily.id, cadence: 'daily', period, progress: 99, completed: true, coins: daily.coins }],
    unlocked: [{ id: 'wins_200', coins: 400, title: 'legend', item: 'border.artDeco' }],
  };
  await pg.query(`select internal.record_progress($1, $2, $3::jsonb)`, [anna, game, JSON.stringify(settled)]);
  await pg.query(`select internal.record_progress($1, $2, $3::jsonb)`, [anna, game, JSON.stringify(settled)]);
  assertEquals(await coins(anna), before + 400, 'achievements paid once, live in the wallet; mission coins wait for the claim');
  const owned = await as<{ item_id: string }>(anna, `select item_id from public.shop_inventory`);
  assertEquals(owned.map((o) => o.item_id), ['border.artDeco']);

  const [{ p: after }] = await as<{ p: { missions: Mission[]; stats: Record<string, number>; achievements: { id: string }[] } }>(
    anna,
    `select public.my_progress() as p`,
  );
  assertEquals(after.stats.roles_won, 2);
  assertEquals(after.stats.games, 2, 'counters add up (the second call was a replay)');
  assertEquals(after.achievements.map((a) => a.id), ['wins_200']);
  assert(after.missions.find((m) => m.id === daily.id)!.completed);

  const [{ u }] = await as<{ u: { missions: { id: string }[]; achievements: { id: string }[] } }>(
    anna,
    `select public.game_unlocks($1) as u`,
    [game],
  );
  assertEquals(u.missions.map((m) => m.id), [daily.id]);
  assertEquals(u.achievements.map((a) => a.id), ['wins_200']);
  const [{ u: theirs }] = await as<{ u: { missions: unknown[] } }>(bruno, `select public.game_unlocks($1) as u`, [game]);
  assertEquals(theirs.missions, [], 'only your own');
});

Deno.test('the leaderboard: handles, tiers and platform marks only, and your place', async () => {
  const { pg, as } = await world();
  await pg.query(`insert into public.ratings (profile_id, language, mu, sigma, games) values
    ($1, 'it', 40, 2, 30), ($2, 'it', 25, 8, 1)`, [anna, bruno]);
  const [{ b }] = await as<{ b: { top: Record<string, unknown>[]; me: { rank: number; tier: string } } }>(
    bruno,
    `select public.leaderboard('it') as b`,
  );
  assertEquals(b.top, [
    { rank: 1, handle: 'anna', tier: 'don', steam: false, apple: false },
    { rank: 2, handle: 'bruno', tier: 'picciotto', steam: false, apple: false },
  ]);
  assertEquals(b.me, { rank: 2, tier: 'picciotto' });
  const [{ e }] = await as<{ e: { top: unknown[]; me: unknown } }>(anna, `select public.leaderboard('en') as e`);
  assertEquals(e, { top: [], me: null });
  await assertRejects(() => as(anna, `select public.leaderboard('fr')`), Error, 'bad_language');
  await assertRejects(() => as(anna, `select * from internal.player_stats`), Error);
  await assertRejects(() => as(anna, `select internal.record_progress($1, $2, '{}'::jsonb)`, [anna, game]), Error);
});
