// The voice-token Edge Function with a fake env, the push to LiveKit with a
// fake RoomService, and the whole path on the real migrations and engine in
// PGlite: lobby, the card, the night opening only after the server start.
//
//   deno test -A supabase/functions/tests/voice_token_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.7';
import { jwtVerify } from 'npm:jose@5.9.6';
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { handleVoiceToken, tokenTtlSeconds, type VoiceTokenDeps } from '../voice-token/handler.ts';
import { apiOrigin, type LiveParticipant, type Permission, roomService, type RoomService } from '../_shared/livekit.ts';
import { sqlVoiceStore, syncVoice, type VoiceSession, type VoiceStore } from '../_shared/voice_sync.ts';
import { defaultVoiceConfig, voiceGrant, type VoiceMember, type VoiceRoom } from '../_shared/voice_rules.ts';
import { step } from '../game/engine.ts';
import { type Db, runDue, type Tx } from '../game/runner.ts';

const secret = 'test-secret-that-is-long-enough-for-hs256';
const env: Record<string, string> = { LIVEKIT_URL: 'wss://oberta-test.livekit.cloud', LIVEKIT_API_KEY: 'APItest', LIVEKIT_API_SECRET: secret };
const roomId = 'aaaaaaaa-0000-4000-8000-000000000001';
const game = 'bbbbbbbb-0000-4000-8000-000000000002';
const t0 = 1_800_000_000_000;

const member = (n: number, extra: Partial<VoiceMember> = {}): VoiceMember => ({
  profile: `p${n}`,
  memberSeat: n,
  gameSeat: `s${n}`,
  alive: true,
  family: false,
  silenced: false,
  ...extra,
});

function memoryStore(room: VoiceRoom, session: VoiceSession | null = null) {
  const state = { room, session };
  const store: VoiceStore = {
    room: (id) => Promise.resolve(id === state.room.id ? state.room : null),
    config: () => Promise.resolve({ ...defaultVoiceConfig }),
    session: () => Promise.resolve(state.session ? { ...state.session, rooms: [...state.session.rooms] } : null),
    remember: (_, name) => {
      state.session ??= { signature: null, rooms: [] };
      if (!state.session.rooms.includes(name)) state.session.rooms.push(name);
      return Promise.resolve();
    },
    settle: (_, signature, forget) => {
      state.session = { signature, rooms: state.session!.rooms.filter((r) => !forget.includes(r)) };
      return Promise.resolve();
    },
  };
  return { store, state };
}

/** A LiveKit that remembers who is where, and every call made to it. */
function fakeLiveKit(rooms: Record<string, LiveParticipant[]> = {}) {
  const calls: string[] = [];
  const service: RoomService = {
    list: (room) => {
      calls.push(`list ${room}`);
      return Promise.resolve([...(rooms[room] ?? [])]);
    },
    update: (room, identity, p: Permission) => {
      calls.push(`update ${room} ${identity} publish=${p.canPublish} subscribe=${p.canSubscribe}`);
      rooms[room] = rooms[room].map((x) => (x.identity === identity ? { identity, ...p } : x));
      return Promise.resolve();
    },
    remove: (room, identity) => {
      calls.push(`remove ${room} ${identity}`);
      rooms[room] = rooms[room].filter((x) => x.identity !== identity);
      return Promise.resolve();
    },
  };
  return { service, calls, rooms };
}

function deps(room: VoiceRoom, extra: Partial<VoiceTokenDeps> = {}) {
  const memory = memoryStore(room);
  const d: VoiceTokenDeps = {
    env: (name) => env[name],
    userFor: (jwt) => Promise.resolve(jwt.startsWith('jwt-') ? jwt.slice(4) : null),
    store: memory.store,
    service: null,
    now: () => t0 + 5000,
    ...extra,
  };
  return { d, memory };
}

const post = (body: unknown, jwt: string | null = 'jwt-p1') =>
  new Request('https://x.supabase.co/functions/v1/voice-token', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(jwt ? { authorization: `Bearer ${jwt}` } : {}) },
    body: JSON.stringify(body),
  });

async function answer(response: Response) {
  return { status: response.status, body: await response.json() };
}

const nightRoom: VoiceRoom = {
  id: roomId,
  status: 'playing',
  ranked: false,
  gameId: game,
  schedule: { stage: 'night', round: 1, startsAt: t0 },
  members: [member(1, { family: true }), member(2), member(3, { alive: false })],
};

Deno.test('voice-token: refuses without LiveKit secrets, sign-in, a room or membership', async () => {
  const { d } = deps(nightRoom);
  assertEquals(await answer(await handleVoiceToken(post({ room: roomId }), { ...d, env: () => undefined })), {
    status: 501,
    body: { error: 'not_configured' },
  });
  assertEquals((await handleVoiceToken(post({ room: roomId }, null), d)).status, 401);
  assertEquals((await handleVoiceToken(post({ room: roomId }, 'garbage'), d)).status, 401);
  assertEquals((await handleVoiceToken(post({ room: 'not-a-uuid' }), d)).status, 400);
  assertEquals(await answer(await handleVoiceToken(post({ room: roomId }, 'jwt-p9'), d)), { status: 403, body: { error: 'not_member' } });
  assertEquals((await handleVoiceToken(new Request('https://x/', { method: 'GET' }), d)).status, 405);
  const ranked = deps({ ...nightRoom, ranked: true }).d;
  assertEquals(await answer(await handleVoiceToken(post({ room: roomId }), ranked)), { status: 403, body: { error: 'voice_off' } });
});

Deno.test('voice-token: the family gets a short token for its room, microphone only, no admin or recording rights', async () => {
  const { d, memory } = deps(nightRoom);
  const { status, body } = await answer(await handleVoiceToken(post({ room: roomId }), d));
  assertEquals(status, 200);
  assertEquals(body.room, `ob-${roomId}-family-${game}-1`);
  assertEquals([body.kind, body.identity, body.url, body.canPublish, body.canSubscribe], ['family', 's1', env.LIVEKIT_URL, true, true]);
  assert(!JSON.stringify(body).includes(secret), 'the secret never leaves');
  const { payload, protectedHeader } = await jwtVerify(body.token, new TextEncoder().encode(secret), {
    issuer: 'APItest',
    currentDate: new Date(t0 + 5000),
  });
  assertEquals(protectedHeader.alg, 'HS256');
  assertEquals(payload.sub, 's1', 'LiveKit sees a seat, never the account');
  assertEquals(payload.exp! - payload.iat!, tokenTtlSeconds);
  assert(tokenTtlSeconds <= 300, 'tokens expire within minutes');
  assertEquals(payload.video, {
    room: body.room,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: false,
    canPublishSources: ['microphone'],
    canUpdateOwnMetadata: false,
  });
  for (const power of ['roomAdmin', 'roomCreate', 'roomList', 'roomRecord', 'ingressAdmin', 'recorder', 'agent', 'hidden']) {
    assert(!(power in (payload.video as Record<string, unknown>)), power);
  }
  assertEquals(memory.state.session?.rooms, [body.room], 'the room is watched from now on');
});

Deno.test('voice-token: the town at night gets no room; before the start everyone is told when to ask again', async () => {
  const { d } = deps(nightRoom);
  assertEquals(await answer(await handleVoiceToken(post({ room: roomId }, 'jwt-p2'), d)), { status: 200, body: { room: null, retryIn: null } });
  const early = deps(nightRoom, { now: () => t0 - 700 }).d;
  assertEquals(await answer(await handleVoiceToken(post({ room: roomId }), early)), { status: 200, body: { room: null, retryIn: 1700 } });
  // The dead listen to the day, never speak in it.
  const day = deps({ ...nightRoom, schedule: { stage: 'vote', round: 1, startsAt: t0 } }).d;
  const dead = (await answer(await handleVoiceToken(post({ room: roomId }, 'jwt-p3'), day))).body;
  assertEquals([dead.kind, dead.canPublish, dead.canSubscribe], ['day', false, true]);
  const { payload } = await jwtVerify(dead.token, new TextEncoder().encode(secret), { currentDate: new Date(t0 + 5000) });
  assertEquals((payload.video as Record<string, unknown>).canPublish, false);
  assertEquals((payload.video as Record<string, unknown>).canPublishSources, []);
});

Deno.test('sync: the end of a stage removes whoever may not stay and fixes the rights of the others', async () => {
  const day = `ob-${roomId}-day-${game}-1`;
  const family = `ob-${roomId}-family-${game}-1`;
  const { service, calls, rooms } = fakeLiveKit({
    [family]: [{ identity: 's1', canPublish: true, canSubscribe: true }],
    [day]: [
      { identity: 's2', canPublish: true, canSubscribe: true },
      { identity: 's3', canPublish: true, canSubscribe: true },
    ],
  });
  // The day of round 1: the family's night is over, s3 died in it.
  const { store, state } = memoryStore(
    { ...nightRoom, schedule: { stage: 'discussion', round: 1, startsAt: t0 } },
    { signature: 'old', rooms: [family, day] },
  );
  const result = await syncVoice(store, service, roomId, t0 + 5000);
  assertEquals(result, { pushed: true, removed: 1, updated: 1 });
  assertEquals(calls, [`list ${family}`, `remove ${family} s1`, `list ${day}`, `update ${day} s3 publish=false subscribe=true`]);
  assertEquals(rooms[family], []);
  assertEquals(state.session?.rooms, [day], 'the empty family room of a past night is forgotten');

  // Nothing changed: no call at all.
  calls.length = 0;
  assertEquals(await syncVoice(store, service, roomId, t0 + 9000), { pushed: false, removed: 0, updated: 0 });
  assertEquals(calls, []);

  // The vote ends: the day closes at once, nobody is left speaking.
  state.room = { ...state.room, schedule: { stage: 'verdictFilm', round: 1, startsAt: t0 + 60_000 } };
  await syncVoice(store, service, roomId, t0 + 58_500);
  assertEquals(rooms[day], []);
  assertEquals(state.session?.rooms, []);
});

Deno.test('sync: a stale identity, or someone who left the room, is removed from the lobby', async () => {
  const lobby = `ob-${roomId}-lobby-${game}`;
  const { service, calls } = fakeLiveKit({
    [lobby]: [
      { identity: 'm1', canPublish: true, canSubscribe: true },
      { identity: 'm2', canPublish: true, canSubscribe: true },
      { identity: 's1', canPublish: true, canSubscribe: true },
    ],
  });
  const { store } = memoryStore(
    { ...nightRoom, status: 'lobby', schedule: null, members: [member(1)] },
    { signature: null, rooms: [lobby] },
  );
  await syncVoice(store, service, roomId, t0);
  assertEquals(calls, [`list ${lobby}`, `remove ${lobby} m2`, `remove ${lobby} s1`]);
});

Deno.test('RoomService speaks Twirp JSON with a short admin token for that room only', async () => {
  const seen: { url: string; body: Record<string, unknown>; video: Record<string, unknown> }[] = [];
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const auth = new Headers(init?.headers).get('authorization')!.replace('Bearer ', '');
    const { payload } = await jwtVerify(auth, new TextEncoder().encode(secret), { currentDate: new Date(t0) });
    assert(payload.exp! - Math.floor(t0 / 1000) <= 60);
    seen.push({ url: String(input), body: JSON.parse(String(init?.body)), video: payload.video as Record<string, unknown> });
    if (String(input).endsWith('/ListParticipants')) {
      return new Response(JSON.stringify({ participants: [{ identity: 's1', permission: { canSubscribe: true } }] }));
    }
    return new Response('{}');
  }) as typeof fetch;
  const lk = roomService({ url: env.LIVEKIT_URL, key: 'APItest', secret }, fetcher, () => t0);
  assertEquals(apiOrigin('wss://a.livekit.cloud/'), 'https://a.livekit.cloud');
  assertEquals(await lk.list('r1'), [{ identity: 's1', canPublish: false, canSubscribe: true }]);
  await lk.update('r1', 's1', { canPublish: false, canSubscribe: true });
  await lk.remove('r1', 's1');
  assertEquals(seen.map((s) => s.url), [
    'https://oberta-test.livekit.cloud/twirp/livekit.RoomService/ListParticipants',
    'https://oberta-test.livekit.cloud/twirp/livekit.RoomService/UpdateParticipant',
    'https://oberta-test.livekit.cloud/twirp/livekit.RoomService/RemoveParticipant',
  ]);
  assertEquals(seen[1].body.permission, {
    canSubscribe: true,
    canPublish: false,
    canPublishData: false,
    canPublishSources: [],
    canUpdateMetadata: false,
  });
  for (const s of seen) assertEquals(s.video, { room: 'r1', roomAdmin: true });
});

// ---------------------------------------------------------------------------
// End to end on the real schema and engine.

const users = {
  anna: '11111111-1111-1111-1111-111111111111',
  bruno: '22222222-2222-2222-2222-222222222222',
  carla: '33333333-3333-3333-3333-333333333333',
};
type Who = keyof typeof users;
const root = new URL('../../', import.meta.url);

Deno.test('on the real schema: lobby voice, nothing during the card, the night opens only after its server start', async () => {
  const pg = new PGlite();
  await pg.exec(await Deno.readTextFile(new URL('functions/tests/pglite_prelude.sql', root)));
  for (const name of [...Deno.readDirSync(new URL('migrations/', root))].map((e) => e.name).sort()) {
    await pg.exec(`begin;\n${await Deno.readTextFile(new URL(`migrations/${name}`, root))}\ncommit;`);
  }
  const tx = (q: { query: PGlite['query'] }): Tx => ({ query: async (text, params = []) => (await q.query(text, params)).rows as never[] });
  const db: Db = { ...tx(pg), transaction: (work) => pg.transaction((t) => work(tx(t))) };
  for (const [name, id] of Object.entries(users)) {
    await pg.query(`insert into auth.users (id) values ($1)`, [id]);
    await pg.query(`update public.profiles set handle = $1 where id = $2`, [name, id]);
  }
  async function as<T = Record<string, unknown>>(who: Who, text: string, params: unknown[] = []): Promise<T[]> {
    await pg.exec(`set role authenticated; set request.jwt.claims to '{"sub": "${users[who]}", "role": "authenticated"}'`);
    try {
      return (await pg.query(text, params)).rows as T[];
    } finally {
      await pg.exec('reset role; reset request.jwt.claims');
    }
  }
  const store = sqlVoiceStore(tx(pg));
  const config = await store.config();
  assertEquals(config, { friends: true, ranked: false, ghosts: true, settleMs: 1000 }, 'the switches of the migration');

  const [{ id: room, code }] = await as<{ id: string; code: string }>('anna', `select id, code from public.create_room('it')`);
  await as('bruno', `select public.join_room($1)`, [code]);
  await as('carla', `select public.join_room($1)`, [code]);
  const now = () => pg.query<{ now: number }>(`select extract(epoch from now()) * 1000 as now`).then((r) => Number(r.rows[0].now));

  // The lobby: everyone, with a member seat; LiveKit is told nothing else.
  let world = (await store.room(room))!;
  const lobby = voiceGrant(world, users.bruno, config, await now());
  assert(lobby.ok && lobby.room === `ob-${room}-lobby-new` && lobby.identity === 'm2' && lobby.canPublish);
  await store.remember(room, lobby.room!);
  await store.remember(room, lobby.room!);
  assertEquals((await store.session(room))?.rooms, [lobby.room], 'remembered once');
  const { service, calls, rooms } = fakeLiveKit({ [lobby.room!]: [{ identity: 'm2', canPublish: true, canSubscribe: true }] });
  await syncVoice(store, service, room, await now());
  assertEquals(calls, [`list ${lobby.room}`], 'nothing to change in the lobby');

  // The game starts: the card. Nobody is in any room, the lobby room is emptied.
  await pg.query(`insert into internal.config (key, value) values ('friends_test_bots', '1'), ('friends_test_size', '6')
                  on conflict (key) do update set value = excluded.value`);
  await as('anna', `select public.start_game($1)`, [room]);
  const touched = new Set<string>();
  assertEquals(await runDue(db, step, { now: await now(), room, onStep: (r) => touched.add(r) }), 1);
  assertEquals([...touched], [room], 'the game function is told which room stepped');
  world = (await store.room(room))!;
  assertEquals(world.schedule?.stage, 'reveal');
  for (const who of Object.values(users)) {
    const g = voiceGrant(world, who, config, (await now()) + 3_600_000);
    assert(g.ok && g.room === null && g.retryAt === null, 'nobody speaks while the cards are looked at');
  }
  await syncVoice(store, service, room, await now());
  assertEquals(rooms[lobby.room!], [], 'the lobby voice closes with the start');

  // Everyone saw the card: the night is published, starting a little later.
  const seats = await pg.query<{ profile_id: string; seat: string; family: boolean }>(
    `select profile_id::text, seat, family from public.game_seats where room_id = $1 and profile_id is not null`,
    [room],
  ).then((r) => r.rows);
  for (const s of seats) {
    const who = (Object.keys(users) as Who[]).find((k) => users[k] === s.profile_id)!;
    await as(who, `select public.submit_intent($1, $2::jsonb)`, [room, JSON.stringify({ type: 'ack', seat: s.seat, stage: 'reveal-1' })]);
  }
  const published = await now();
  await runDue(db, step, { now: published, room });
  world = (await store.room(room))!;
  assertEquals(world.schedule?.stage, 'night');
  const startsAt = world.schedule!.startsAt;
  assert(startsAt > published, 'the night starts after it is published');
  for (const s of seats) {
    const before = voiceGrant(world, s.profile_id, config, startsAt + config.settleMs - 1);
    assert(before.ok && before.room === null && before.retryAt === startsAt + config.settleMs, 'closed until the server start + settle');
    const after = voiceGrant(world, s.profile_id, config, startsAt + config.settleMs);
    assert(after.ok);
    if (s.family) {
      assertEquals([after.kind, after.identity, after.canPublish], ['family', s.seat, true]);
    } else {
      assertEquals(after.room, null, 'the town hears nothing at night');
    }
  }
  await pg.close();
});
