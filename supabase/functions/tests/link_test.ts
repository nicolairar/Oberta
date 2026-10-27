// Account linking without codes (20261107100000_link_identities.sql): the
// Edge Function proves both identities, then Postgres merges the profiles.
// Steam profile fields and platform marks (20261107090000_steam_profile.sql).
//
//   deno test -A supabase/functions/tests/link_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { assertEquals, assertRejects } from 'jsr:@std/assert@1';

const root = new URL('../../', import.meta.url);
const old = '11111111-1111-1111-1111-111111111111';
const young = '22222222-2222-2222-2222-222222222222';
const fresh = '33333333-3333-3333-3333-333333333333';

async function world() {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  const migrations = [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort();
  for (const name of migrations) {
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  for (const [handle, id, age] of [['vecchio', old, 3], ['giovane', young, 2], ['nuovo', fresh, 1]] as const) {
    await pg.query(`insert into auth.users (id) values ($1)`, [id]);
    await pg.query(
      `update public.profiles set handle = $1, created_at = now() - make_interval(days => $3) where id = $2`,
      [handle, id, age],
    );
  }
  const profile = async (id: string) =>
    (await pg.query<{ handle: string | null; on_steam: boolean; on_apple: boolean; steam_persona: string | null }>(
      `select handle, on_steam, on_apple, steam_persona from public.profiles where id = $1`,
      [id],
    )).rows[0];
  return { pg, profile };
}

Deno.test('Collega Apple from Steam: the older profile stays, identities and Steam data move to it', async () => {
  const { pg, profile } = await world();
  await pg.query(`insert into auth.identities (user_id, provider) values ($1, 'apple')`, [old]);
  await pg.query(`insert into internal.steam_identities (steam_id, profile_id) values ('76561197960287930', $1)`, [young]);
  await pg.query(
    `select public.steam_profile_store('76561197960287930', 'Don Vito', 'https://avatars.steamstatic.com/a_full.jpg')`,
  );
  assertEquals(await profile(old), { handle: 'vecchio', on_steam: false, on_apple: true, steam_persona: null });

  const { rows: [{ r }] } = await pg.query<{ r: { kept: string; merged: string } }>(
    `select public.link_profiles($1, $2) as r`,
    [young, old],
  );
  assertEquals(r, { kept: old, merged: young });
  assertEquals(await profile(old), { handle: 'vecchio', on_steam: true, on_apple: true, steam_persona: 'Don Vito' });
  assertEquals(await profile(young), { handle: null, on_steam: false, on_apple: false, steam_persona: null });
  const { rows: [{ banned }] } = await pg.query<{ banned: boolean }>(
    `select banned_until is not null as banned from auth.users where id = $1`,
    [young],
  );
  assertEquals(banned, true);
  await assertRejects(
    () => pg.query(`select public.steam_link($1, '76561197960287930')`, [old]),
    Error,
    'link_same_account',
  );
});

Deno.test('Collega Steam from the phone: a new SteamID joins, a used one merges, two Steams conflict', async () => {
  const { pg, profile } = await world();
  const { rows: [{ r }] } = await pg.query<{ r: { kept: string } }>(
    `select public.steam_link($1, '76561197960287931') as r`,
    [fresh],
  );
  assertEquals(r.kept, fresh);
  assertEquals((await profile(fresh)).on_steam, true);
  await pg.query(`insert into internal.steam_identities (steam_id, profile_id) values ('76561197960287932', $1)`, [young]);
  await assertRejects(() => pg.query(`select public.link_profiles($1, $2)`, [fresh, young]), Error, 'link_conflict');
  const { rows: [{ m }] } = await pg.query<{ m: { kept: string } }>(
    `select public.steam_link($1, '76561197960287932') as m`,
    [old],
  );
  assertEquals(m.kept, old, 'the older profile stays even when the phone is the older one');
  assertEquals((await profile(old)).on_steam, true);
});

Deno.test('the code of Collega Steam: once, with its state, no replay; old code RPCs gone; clients cannot merge', async () => {
  const { pg } = await world();
  const { rows: [{ code }] } = await pg.query<{ code: string }>(
    `select public.steam_link_code_issue('76561197960287933', 'state-state-state-1', 'nonce-1') as code`,
  );
  await assertRejects(() => pg.query(`select public.steam_link_code_consume($1, 'state-state-state-X')`, [code]));
  const { rows: [{ id }] } = await pg.query<{ id: string }>(
    `select public.steam_link_code_consume($1, 'state-state-state-1') as id`,
    [code],
  );
  assertEquals(id, '76561197960287933');
  await assertRejects(() => pg.query(`select public.steam_link_code_consume($1, 'state-state-state-1')`, [code]));
  await assertRejects(
    () => pg.query(`select public.steam_link_code_issue('76561197960287933', 'state-state-state-2', 'nonce-1')`),
    Error,
    'steam_replay',
  );
  const { rows: [{ n }] } = await pg.query<{ n: number }>(
    `select count(*)::int as n from pg_proc where proname in ('link_code_create', 'link_code_redeem')`,
  );
  assertEquals(n, 0);
  await pg.exec(`set role authenticated; set request.jwt.claims to '{"sub": "${old}", "role": "authenticated"}'`);
  try {
    await assertRejects(() => pg.query(`select public.link_profiles($1, $2)`, [old, young]));
    await assertRejects(() => pg.query(`select public.steam_link($1, '76561197960287934')`, [old]));
    await assertRejects(() => pg.query(`select steam_persona from public.profiles`));
    const { rows } = await pg.query(`select on_steam, on_apple, picture_url from public.profiles where id = $1`, [old]);
    assertEquals(rows.length, 1);
  } finally {
    await pg.exec('reset role; reset request.jwt.claims');
  }
});
