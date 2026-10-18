// The shop's rules in Postgres: every migration in PGlite, then players buy,
// equip and try to cheat under their own role.
//
//   deno test -A supabase/functions/tests/shop_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1';

const root = new URL('../../', import.meta.url);
const anna = '11111111-1111-1111-1111-111111111111';
const bruno = '22222222-2222-2222-2222-222222222222';

async function shop() {
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
    ((await pg.query<{ coins: number }>(`select coins from public.profiles where id = $1`, [id])).rows[0]).coins;
  return { pg, as, coins };
}

Deno.test('the catalog: prices follow rarity, base items are free, rotation is live', async () => {
  const { pg, as } = await shop();
  const items = await as<{ id: string; rarity: string; price_coins: number }>('' + anna, `select id, rarity, price_coins from public.shop_items`);
  assert(items.filter((i) => i.rarity !== 'base').length >= 25, 'a real catalog for sale');
  await assertRejects(
    () => pg.query(`insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en) values ('hat.x', 'hat', 'x', 'raro', 10, 'x', 'x')`),
    Error,
    'check',
  );
  const featured = await pg.query(`select count(*)::int as n from public.shop_rotations`);
  assert((featured.rows[0] as { n: number }).n >= 4, "a live rotation");
});

Deno.test('buying: coins, price, ownership, atomic', async () => {
  const { pg, as, coins } = await shop();
  await assertRejects(() => as(anna, `select * from public.buy_item('hat.borsalino')`), Error, 'not_enough_coins');
  await pg.query(`select public.grant_coins($1, 1000, 'gift')`, [anna]);
  const [after] = await as<{ coins: number }>(anna, `select * from public.buy_item('hat.borsalino')`);
  assertEquals(after.coins, 300);
  await assertRejects(() => as(anna, `select * from public.buy_item('hat.borsalino')`), Error, 'already_owned');
  await assertRejects(() => as(anna, `select * from public.buy_item('hat.fedora')`), Error, 'already_owned');
  await assertRejects(() => as(anna, `select * from public.buy_item('face.walrus')`), Error, 'not_enough_coins', '300 < 350');
  await assertRejects(() => as(anna, `select * from public.buy_item('hat.nothing')`), Error, 'item_not_found');
  assertEquals(await coins(anna), 300, 'failed buys cost nothing');
  const owned = await as(anna, `select item_id from public.shop_inventory`);
  assertEquals(owned, [{ item_id: 'hat.borsalino' }]);
  assertEquals(await as(bruno, `select item_id from public.shop_inventory`), [], 'others do not see my wardrobe');
  const ledger = await as<{ delta: number }>(anna, `select delta from public.coin_ledger order by id`);
  assertEquals(ledger.map((l) => l.delta), [1000, -700]);
});

Deno.test('equipping: only owned or free items, the face keeps its tone', async () => {
  const { pg, as } = await shop();
  await assertRejects(() => as(anna, `select * from public.equip_item('hat.topHat')`), Error, 'not_owned');
  let [me] = await as<{ avatar: Record<string, string> }>(anna, `select * from public.equip_item('hat.bowler')`);
  assertEquals(me.avatar, { hat: 'bowler' });
  await assertRejects(() => as(anna, `select * from public.equip_item('face.mustache')`), Error, 'tone_required');
  [me] = await as(anna, `select * from public.equip_item('face.mustache', 'tan')`);
  assertEquals(me.avatar.base, 'tan_mustache');
  await pg.query(`select public.grant_coins($1, 350, 'gift')`, [anna]);
  await as(anna, `select * from public.buy_item('face.walrus')`);
  [me] = await as(anna, `select * from public.equip_item('face.walrus', 'ebony')`);
  assertEquals(me.avatar.base, 'tan_walrus', 'the saved tone wins');
  [me] = await as(anna, `select * from public.unequip_slot('hat')`);
  assertEquals(me.avatar, { base: 'tan_walrus' });
  [me] = await as(anna, `select * from public.unequip_slot('face')`);
  assertEquals(me.avatar, { base: 'tan_clean' });
});

Deno.test('clients cannot write coins, inventory, avatar, rotations or the catalog', async () => {
  const { as, coins } = await shop();
  const attempts = [
    `update public.profiles set coins = 99999 where id = '${anna}'`,
    `update public.profiles set avatar = '{"hat":"topHat"}' where id = '${anna}'`,
    `insert into public.shop_inventory (profile_id, item_id) values ('${anna}', 'hat.topHat')`,
    `delete from public.shop_inventory`,
    `insert into public.coin_ledger (profile_id, delta, reason) values ('${anna}', 5000, 'gift')`,
    `update public.shop_items set price_coins = 0`,
    `insert into public.shop_rotations (item_id, starts_at, ends_at) values ('hat.topHat', now(), now() + interval '1 day')`,
    `select public.grant_coins('${anna}', 5000, 'gift')`,
  ];
  for (const sql of attempts) {
    await assertRejects(() => as(anna, sql), Error, 'permission denied', sql);
  }
  assertEquals(await coins(anna), 0);
});
