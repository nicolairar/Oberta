// The Phase 2 Steam ticket path of steam-auth, with Steam's Web API mocked.
//
//   deno test -A supabase/functions/tests/steam_ticket_test.ts
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { handleTicket, type TicketDeps } from '../steam-auth/ticket.ts';

const player = '76561197960287930';
const ticket = 'deadbeef'.repeat(30);

type Steam = { auth?: unknown; owns?: unknown; authStatus?: number; ownsStatus?: number };

function deps(steam: Steam, env: Record<string, string> = { STEAM_WEB_API_KEY: 'k3y', STEAM_APP_ID: '480' }) {
  const calls: URL[] = [];
  const sessions: string[] = [];
  const mocked: TicketDeps = {
    env: (name) => env[name],
    fetch: ((input: string | URL | Request) => {
      const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
      calls.push(url);
      if (url.pathname.startsWith('/ISteamUserAuth/AuthenticateUserTicket/')) {
        return Promise.resolve(new Response(JSON.stringify(steam.auth), { status: steam.authStatus ?? 200 }));
      }
      if (url.pathname.startsWith('/ISteamUser/CheckAppOwnership/')) {
        return Promise.resolve(new Response(JSON.stringify(steam.owns), { status: steam.ownsStatus ?? 200 }));
      }
      return Promise.resolve(new Response('not found', { status: 404 }));
    }) as typeof fetch,
    sessionFor: (steamId) => {
      sessions.push(steamId);
      return Promise.resolve({ token_hash: `hash-${steamId}` });
    },
  };
  return { mocked, calls, sessions };
}

const authOk = (extra: Record<string, unknown> = {}) => ({
  response: { params: { result: 'OK', steamid: player, ownersteamid: player, vacbanned: false, publisherbanned: false, ...extra } },
});
const owns = (ownsapp: boolean) => ({ appownership: { ownsapp, permanent: true, ownersteamid: player, result: 'OK' } });

async function answer(response: Response) {
  return { status: response.status, body: await response.json() };
}

Deno.test('without the secrets the path is not configured (501) and Steam is never called', async () => {
  for (const env of [{}, { STEAM_WEB_API_KEY: 'k3y' }, { STEAM_APP_ID: '480' }]) {
    const { mocked, calls } = deps({}, env as Record<string, string>);
    assertEquals(await answer(await handleTicket({ ticket }, mocked)), { status: 501, body: { error: 'not_configured' } });
    assertEquals(calls.length, 0);
  }
});

Deno.test('a valid ticket for an owner gives a session for that SteamID', async () => {
  const { mocked, calls, sessions } = deps({ auth: authOk(), owns: owns(true) });
  assertEquals(await answer(await handleTicket({ ticket }, mocked)), { status: 200, body: { token_hash: `hash-${player}` } });
  assertEquals(sessions, [player]);
  const [auth, ownership] = calls;
  assertEquals(auth.origin, 'https://partner.steam-api.com');
  assertEquals(auth.searchParams.get('key'), 'k3y');
  assertEquals(auth.searchParams.get('appid'), '480');
  assertEquals(auth.searchParams.get('ticket'), ticket);
  assertEquals(auth.searchParams.get('identity'), 'oberta');
  assertEquals(ownership.searchParams.get('steamid'), player);
  assertEquals(ownership.searchParams.get('appid'), '480');
});

Deno.test('a ticket Steam rejects is invalid (401), no session', async () => {
  const { mocked, sessions } = deps({ auth: { response: { error: { errorcode: 101, errordesc: 'Invalid ticket' } } } });
  assertEquals(await answer(await handleTicket({ ticket }, mocked)), { status: 401, body: { error: 'ticket_invalid' } });
  assertEquals(sessions.length, 0);
});

Deno.test('an account without the game is refused (403 not_owner)', async () => {
  const { mocked, sessions } = deps({ auth: authOk(), owns: owns(false) });
  assertEquals(await answer(await handleTicket({ ticket }, mocked)), { status: 403, body: { error: 'not_owner' } });
  assertEquals(sessions.length, 0);
});

Deno.test('a publisher-banned account is refused before the ownership check', async () => {
  const { mocked, calls } = deps({ auth: authOk({ publisherbanned: true }), owns: owns(true) });
  assertEquals(await answer(await handleTicket({ ticket }, mocked)), { status: 403, body: { error: 'banned' } });
  assertEquals(calls.length, 1);
});

Deno.test('Steam down is a 502, not a login', async () => {
  const { mocked } = deps({ auth: {}, authStatus: 503 });
  assertEquals((await handleTicket({ ticket }, mocked)).status, 502);
  const second = deps({ auth: authOk(), owns: {}, ownsStatus: 500 });
  assertEquals((await handleTicket({ ticket }, second.mocked)).status, 502);
  assertEquals(second.sessions.length, 0);
});

Deno.test('malformed tickets never reach Steam', async () => {
  for (const bad of [undefined, 42, '', 'xyz', 'abc', 'zz'.repeat(20)]) {
    const { mocked, calls } = deps({ auth: authOk(), owns: owns(true) });
    const response = await handleTicket({ ticket: bad }, mocked);
    assertEquals(response.status, 400);
    assert(calls.length === 0);
  }
});
