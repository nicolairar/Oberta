// The public face of a Steam account: persona name and avatar URL, stored on
// the profile (migration 20261107090000_steam_profile.sql) on every Steam
// sign-in and when the app asks for a refresh.
//
// Without a Web API key it reads the public community profile as XML:
//   https://steamcommunity.com/profiles/<steamid64>/?xml=1
//   <profile><steamID64>…</steamID64><steamID><![CDATA[persona]]></steamID>
//            <avatarMedium>…</avatarMedium><avatarFull>…</avatarFull>…</profile>
// With STEAM_WEB_API_KEY set it uses ISteamUser/GetPlayerSummaries instead.
// Kept apart from index.ts so the Deno tests can drive it with fixtures.

export type SteamProfile = { persona: string | null; avatar: string | null };

const steamIdPattern = /^\d{17}$/;
const maxPersona = 64;

/// Only https images from Steam's CDN (*.steamstatic.com), with a plain path.
export function safeAvatarUrl(value: unknown): string | null {
  if (typeof value !== 'string' || value.length > 300) return null;
  let url: URL;
  try {
    url = new URL(value.trim());
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' || url.port !== '' || url.username !== '' || url.password !== '') return null;
  const host = url.hostname.toLowerCase();
  if (host !== 'steamstatic.com' && !/^([a-z0-9-]+\.)+steamstatic\.com$/.test(host)) return null;
  if (url.search !== '' || url.hash !== '') return null;
  if (!/^\/[A-Za-z0-9/_.-]{1,200}$/.test(url.pathname)) return null;
  return `https://${host}${url.pathname}`;
}

/// The persona as it can be stored: no control characters, trimmed, at most
/// 64 characters (code points). Null when nothing is left.
export function cleanPersona(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  // deno-lint-ignore no-control-regex
  const clean = [...value.replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁦-⁩]/g, '').trim()]
    .slice(0, maxPersona)
    .join('')
    .trim();
  return clean === '' ? null : clean;
}

function decodeEntities(text: string): string {
  return text.replace(/&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);/g, (_, entity: string) => {
    switch (entity) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
    }
    const code = entity.startsWith('#x') ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
    return Number.isFinite(code) && code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : '';
  });
}

/// The text of the first top-level <tag> (CDATA or escaped text), or null.
function tagText(xml: string, tag: string): string | null {
  const match = new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`).exec(xml);
  if (!match) return null;
  const inner = match[1].trim();
  const cdata = /^<!\[CDATA\[([\s\S]*?)\]\]>$/.exec(inner);
  return cdata ? cdata[1] : decodeEntities(inner);
}

/// Reads persona and avatar from the community XML. Null when the document
/// is not that profile (an error page, another SteamID, no <profile>).
export function parseProfileXml(xml: string, steamId: string): SteamProfile | null {
  if (typeof xml !== 'string' || xml.length > 512 * 1024) return null;
  const start = xml.indexOf('<profile>');
  if (start < 0) return null;
  // The profile's own fields come before any nested group/game lists.
  let body = xml.slice(start);
  for (const nested of ['<groups>', '<mostPlayedGames>', '<inGameInfo>']) {
    const at = body.indexOf(nested);
    if (at >= 0) body = body.slice(0, at);
  }
  if (tagText(body, 'steamID64') !== steamId) return null;
  const persona = cleanPersona(tagText(body, 'steamID'));
  const avatar = safeAvatarUrl(tagText(body, 'avatarFull')) ?? safeAvatarUrl(tagText(body, 'avatarMedium'));
  return { persona, avatar };
}

/// Reads persona and avatar from GetPlayerSummaries v2 JSON.
// deno-lint-ignore no-explicit-any
export function parsePlayerSummaries(body: any, steamId: string): SteamProfile | null {
  const player = body?.response?.players?.find?.((p: { steamid?: unknown }) => p?.steamid === steamId);
  if (!player) return null;
  return {
    persona: cleanPersona(player.personaname),
    avatar: safeAvatarUrl(player.avatarfull) ?? safeAvatarUrl(player.avatarmedium),
  };
}

export type ProfileDeps = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
};

/// Fetches the public persona and avatar. Null when Steam does not answer
/// (in time) or answers with something else.
export async function fetchSteamProfile(steamId: string, deps: ProfileDeps, timeoutMs = 4000): Promise<SteamProfile | null> {
  if (!steamIdPattern.test(steamId)) return null;
  const signal = AbortSignal.timeout(timeoutMs);
  try {
    const key = deps.env('STEAM_WEB_API_KEY');
    if (key) {
      const url = new URL('https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/');
      url.searchParams.set('key', key);
      url.searchParams.set('steamids', steamId);
      const response = await deps.fetch(url.toString(), { signal });
      if (response.ok) {
        const parsed = parsePlayerSummaries(await response.json().catch(() => null), steamId);
        if (parsed) return parsed;
      }
    }
    const response = await deps.fetch(`https://steamcommunity.com/profiles/${steamId}/?xml=1`, {
      signal,
      headers: { accept: 'text/xml' },
      redirect: 'follow',
    });
    if (!response.ok) return null;
    return parseProfileXml(await response.text(), steamId);
  } catch {
    return null;
  }
}
