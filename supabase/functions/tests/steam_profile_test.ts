// Steam persona name and avatar for the profile (steam-auth/profile.ts),
// read from fixtures and a mocked fetch.
//
//   deno test -A supabase/functions/tests/steam_profile_test.ts
import { assert, assertEquals } from 'jsr:@std/assert@1';
import {
  cleanPersona,
  fetchSteamProfile,
  parsePlayerSummaries,
  parseProfileXml,
  safeAvatarUrl,
} from '../steam-auth/profile.ts';

const player = '76561197960287930';
const fixture = (name: string) => Deno.readTextFileSync(new URL(`./fixtures/steam/${name}`, import.meta.url));

Deno.test('a public profile gives persona and full avatar', () => {
  assertEquals(parseProfileXml(fixture('public.xml'), player), {
    persona: 'Don Vito Corleone ☕',
    avatar: 'https://avatars.fastly.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg',
  });
});

Deno.test('a private profile: escaped persona, a bad avatarFull falls back to avatarMedium', () => {
  assertEquals(parseProfileXml(fixture('private.xml'), player), {
    persona: 'Tom & Sonny <3',
    avatar: 'https://avatars.steamstatic.com/b5bd56c1aa4644a474a2e4972be27ef9e82e517e_medium.jpg',
  });
});

Deno.test('an error page or another SteamID is no profile', () => {
  assertEquals(parseProfileXml(fixture('not_found.xml'), player), null);
  assertEquals(parseProfileXml(fixture('public.xml'), '76561197960287931'), null);
  assertEquals(parseProfileXml('<html>busy</html>', player), null);
});

Deno.test('avatar URLs: https on *.steamstatic.com only', () => {
  assertEquals(safeAvatarUrl('https://avatars.steamstatic.com/abc_full.jpg'), 'https://avatars.steamstatic.com/abc_full.jpg');
  assertEquals(
    safeAvatarUrl('https://avatars.akamai.steamstatic.com/abc_full.jpg'),
    'https://avatars.akamai.steamstatic.com/abc_full.jpg',
  );
  for (const bad of [
    'http://avatars.steamstatic.com/abc.jpg',
    'https://avatars.steamstatic.com.evil.com/abc.jpg',
    'https://evilsteamstatic.com/abc.jpg',
    'https://user@avatars.steamstatic.com/abc.jpg',
    'https://avatars.steamstatic.com:8443/abc.jpg',
    'https://avatars.steamstatic.com/abc.jpg?x=1',
    'https://avatars.steamstatic.com/a%20b.jpg',
    'javascript:alert(1)',
    '',
    42,
    null,
  ]) {
    assertEquals(safeAvatarUrl(bad), null, String(bad));
  }
});

Deno.test('persona: control and direction characters out, trimmed, 64 code points', () => {
  assertEquals(cleanPersona('  Fredo\u0000‮  '), 'Fredo');
  assertEquals(cleanPersona('​ \n'), null);
  assertEquals(cleanPersona('🙂'.repeat(70)), '🙂'.repeat(64));
  assertEquals(cleanPersona(undefined), null);
});

Deno.test('GetPlayerSummaries picks the right player', () => {
  const body = {
    response: {
      players: [
        { steamid: '76561197960287931', personaname: 'Other' },
        {
          steamid: player,
          personaname: 'Michael',
          avatarmedium: 'https://avatars.steamstatic.com/m_medium.jpg',
          avatarfull: 'https://avatars.steamstatic.com/m_full.jpg',
        },
      ],
    },
  };
  assertEquals(parsePlayerSummaries(body, player), { persona: 'Michael', avatar: 'https://avatars.steamstatic.com/m_full.jpg' });
  assertEquals(parsePlayerSummaries({ response: { players: [] } }, player), null);
  assertEquals(parsePlayerSummaries(null, player), null);
});

function mockedFetch(routes: Record<string, () => Response>, calls: URL[]) {
  return ((input: string | URL | Request) => {
    const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
    calls.push(url);
    const route = routes[url.host];
    return Promise.resolve(route ? route() : new Response('nope', { status: 404 }));
  }) as typeof fetch;
}

Deno.test('without a key: the community XML, no API call', async () => {
  const calls: URL[] = [];
  const found = await fetchSteamProfile(player, {
    env: () => undefined,
    fetch: mockedFetch({ 'steamcommunity.com': () => new Response(fixture('public.xml')) }, calls),
  });
  assertEquals(found?.persona, 'Don Vito Corleone ☕');
  assertEquals(calls.map((u) => u.toString()), [`https://steamcommunity.com/profiles/${player}/?xml=1`]);
});

Deno.test('with a key: GetPlayerSummaries first, XML when it fails', async () => {
  const calls: URL[] = [];
  const summaries = {
    response: { players: [{ steamid: player, personaname: 'Sonny', avatarfull: 'https://avatars.steamstatic.com/s_full.jpg' }] },
  };
  const found = await fetchSteamProfile(player, {
    env: (name) => (name === 'STEAM_WEB_API_KEY' ? 'k3y' : undefined),
    fetch: mockedFetch({ 'api.steampowered.com': () => new Response(JSON.stringify(summaries)) }, calls),
  });
  assertEquals(found, { persona: 'Sonny', avatar: 'https://avatars.steamstatic.com/s_full.jpg' });
  assertEquals(calls.length, 1);
  assertEquals(calls[0].searchParams.get('steamids'), player);

  const fallback: URL[] = [];
  const again = await fetchSteamProfile(player, {
    env: (name) => (name === 'STEAM_WEB_API_KEY' ? 'k3y' : undefined),
    fetch: mockedFetch({
      'api.steampowered.com': () => new Response('down', { status: 503 }),
      'steamcommunity.com': () => new Response(fixture('private.xml')),
    }, fallback),
  });
  assertEquals(again?.persona, 'Tom & Sonny <3');
  assertEquals(fallback.length, 2);
});

Deno.test('Steam down or a bad SteamID: null, no throw', async () => {
  const calls: URL[] = [];
  const down = await fetchSteamProfile(player, {
    env: () => undefined,
    fetch: (() => Promise.reject(new Error('offline'))) as typeof fetch,
  });
  assertEquals(down, null);
  assertEquals(await fetchSteamProfile('123', { env: () => undefined, fetch: mockedFetch({}, calls) }), null);
  assert(calls.length === 0);
});
