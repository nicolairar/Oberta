// The earn-only economy in Postgres: claiming missions, the mission-only
// pieces, the coins of a game, and what a client can never do to itself.
//
//   deno test -A supabase/functions/tests/missions_test.ts
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
    (await pg.query<{ coins: number }>(`select coins from public.profiles where id = $1`, [id])).rows[0].coins;
  const record = (who: string, p: unknown) =>
    pg.query(`select internal.record_progress($1, $2, $3::jsonb)`, [who, game, JSON.stringify(p)]);
  return { pg, as, coins, record };
}

type Mission = { id: string; cadence: string; claimed: boolean; coins: number; reputation: number };

Deno.test('claiming a daily: once, only when the server completed it, coins and reputation', async () => {
  const { pg, as, coins, record } = await world();
  const [{ p }] = await as<{ p: { missions: Mission[] } }>(anna, `select public.my_progress() as p`);
  const daily = p.missions.find((m) => m.cadence === 'daily')!;
  await assertRejects(() => as(anna, `select public.claim_mission($1)`, [daily.id]), Error, 'not_completed');
  await assertRejects(() => as(anna, `select public.claim_mission('nope')`), Error, 'mission_not_found');
  const [{ period }] = (await pg.query<{ period: string }>(`select internal.mission_period('daily')::text as period`)).rows;
  await record(anna, {
    tally: { games: 1, reputation: 1 },
    missions: [{ id: daily.id, cadence: 'daily', period, progress: 99, completed: true }],
  });
  assertEquals(await coins(anna), 0, 'completing pays no coins yet');
  const [{ r }] = await as<{ r: { coins: number; balance: number } }>(anna, `select public.claim_mission($1) as r`, [daily.id]);
  assertEquals(r.coins, daily.coins);
  assertEquals(r.balance, daily.coins);
  await assertRejects(() => as(anna, `select public.claim_mission($1)`, [daily.id]), Error, 'already_claimed');
  assertEquals(await coins(anna), daily.coins, 'never twice');
  await assertRejects(() => as(bruno, `select public.claim_mission($1)`, [daily.id]), Error);
  assertEquals(await coins(bruno), 0, 'nobody claims for someone else');
  const [{ p: after }] = await as<{ p: { missions: Mission[]; stats: Record<string, number> } }>(
    anna,
    `select public.my_progress() as p`,
  );
  assert(after.missions.find((m) => m.id === daily.id)!.claimed);
  assertEquals(after.stats.reputation, 1 + daily.reputation, 'one from the game, the rest from the claim');
});

Deno.test('a long mission: progress from the lifetime counters, its piece only by claiming', async () => {
  const { pg, as, coins, record } = await world();
  await assertRejects(() => as(anna, `select public.claim_mission('long_detective_wins_5')`), Error, 'not_completed');
  await pg.query(`select public.grant_coins($1, 99999, 'gift')`, [anna]);
  await assertRejects(() => as(anna, `select * from public.buy_item('hat.sbirro')`), Error, 'mission_only');
  const [{ price }] = (await pg.query<{ price: number }>(`select price_coins as price from public.shop_items where id = 'hat.sbirro'`)).rows;
  assertEquals(price, 0);
  await record(anna, { tally: { 'role_win:detective': 5 } });
  const before = await coins(anna);
  const [{ r }] = await as<{ r: { coins: number; item: string } }>(anna, `select public.claim_mission('long_detective_wins_5') as r`);
  assertEquals([r.coins, r.item], [400, 'hat.sbirro']);
  assertEquals(await coins(anna), before + 400);
  const owned = await as<{ item_id: string; source: string }>(anna, `select item_id, source from public.shop_inventory`);
  assertEquals(owned, [{ item_id: 'hat.sbirro', source: 'gift' }]);
  await assertRejects(() => as(anna, `select public.claim_mission('long_detective_wins_5')`), Error, 'already_claimed');
  const [me] = await as<{ avatar: Record<string, string> }>(anna, `select * from public.equip_item('hat.sbirro')`);
  assertEquals(me.avatar.hat, 'sbirro');
});

Deno.test('a game pays its own coins only through record_match, in one ledger row', async () => {
  const { pg, coins, record } = await world();
  await record(anna, { tally: { games: 1, wins: 1 }, matchCoins: 55 });
  assertEquals(await coins(anna), 0, 'record_progress alone never pays the game');
  const room = '44444444-4444-4444-4444-444444444444';
  await pg.query(`insert into public.rooms (id, code, host, language, status, max_players) values ($1, 'ZZZZ55', $2, 'it', 'playing', 12)`, [room, anna]);
  await pg.query(`insert into public.game_public (room_id, host, version, view, game_id, chat_mode) values ($1, $2, 1, null, '55555555-5555-5555-5555-555555555555', 'day')`, [room, anna]);
  await pg.query(`insert into public.game_seats (room_id, seat, profile_id, name, alive, family) values ($1, 's1', $2, 'anna', true, false)`, [room, anna]);
  const settlement = {
    players: [{
      profile: anna, seat: 's1', role: 'cittadino', team: 'citizens', won: true, survived: true, abandoned: false,
      level: 2, xp: 10, levelBefore: 1, xpGained: 200, coins: 90, levelCoins: 50, matchCoins: 40,
      tally: { games: 1, wins: 1 }, missions: [], unlocked: [],
    }],
  };
  await pg.query(`select internal.record_match($1, 'citizens', $2::jsonb)`, [room, JSON.stringify(settlement)]);
  await pg.query(`select internal.record_match($1, 'citizens', $2::jsonb)`, [room, JSON.stringify(settlement)]);
  assertEquals(await coins(anna), 90, 'level + game, once');
  const rows = (await pg.query<{ reason: string; delta: number }>(
    `select reason, delta from public.coin_ledger where profile_id = $1`,
    [anna],
  )).rows;
  assertEquals(rows, [{ reason: 'match', delta: 90 }]);
});

Deno.test('anti-cheat: a client cannot give itself progress, missions, coins or pieces', async () => {
  const { as, coins } = await world();
  await as(anna, `select public.my_progress()`);
  const attempts = [
    `update internal.player_missions set completed_at = now()`,
    `insert into internal.player_stats (profile_id, metric, value) values ('${anna}', 'role_win:detective', 99)`,
    `update internal.mission_defs set coins = 1000`,
    `select internal.record_progress('${anna}', '${game}', '{"matchCoins": 999}'::jsonb)`,
    `select internal.ensure_missions('${anna}')`,
    `insert into public.shop_inventory (profile_id, item_id, source) values ('${anna}', 'hat.sbirro', 'gift')`,
    `update public.shop_items set unlock = null where id = 'hat.sbirro'`,
    `insert into public.coin_ledger (profile_id, delta, reason) values ('${anna}', 500, 'match')`,
    `select public.grant_coins('${anna}', 500, 'mission')`,
  ];
  for (const sql of attempts) {
    await assertRejects(() => as(anna, sql), Error, undefined, sql);
  }
  await assertRejects(() => as(anna, `select public.claim_mission('long_wins_50')`), Error, 'not_completed');
  assertEquals(await coins(anna), 0);
});

Deno.test('earn only: no real-money reason or source, prices on the earned scale', async () => {
  const { pg } = await world();
  await assertRejects(() => pg.query(`select public.grant_coins($1, 500, 'purchase')`, [anna]), Error, 'check');
  await assertRejects(
    () => pg.query(`insert into public.shop_inventory (profile_id, item_id, source) values ($1, 'hat.borsalino', 'purchase')`, [anna]),
    Error,
    'check',
  );
  const prices = (await pg.query<{ rarity: string; lo: number; hi: number }>(
    `select rarity, min(price_coins)::int as lo, max(price_coins)::int as hi from public.shop_items
     where unlock is null and enabled group by rarity`,
  )).rows;
  const by = Object.fromEntries(prices.map((p) => [p.rarity, [p.lo, p.hi]]));
  assertEquals(by.comune, [120, 120]);
  assertEquals(by.raro, [700, 700]);
  assert(by.epico[0] >= 1100 && by.epico[1] <= 1799);
  assert(by.leggendario[0] >= 2900 && by.leggendario[1] <= 8000);
});
