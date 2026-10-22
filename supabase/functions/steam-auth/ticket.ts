// Phase 2 of docs/steam.md: sign-in with a Steam Web API ticket, no browser.
//
//   POST {action: "ticket", ticket: "<hex from GetAuthTicketForWebApi('oberta')>"}
//     -> ISteamUserAuth/AuthenticateUserTicket (publisher key, identity "oberta")
//        gives the SteamID64; ISteamUser/CheckAppOwnership says whether that
//        account owns the game. Then the same path as OpenID: SteamID ->
//        profile -> magic-link token_hash.
//
// Needs the secrets STEAM_WEB_API_KEY (publisher key) and STEAM_APP_ID. Until
// they exist the path answers 501 {error: "not_configured"} and the app falls
// back to OpenID. Kept apart from index.ts so the Deno tests can drive it
// with a mocked fetch and no Supabase.

export const webApiIdentity = 'oberta';
const partnerApi = 'https://partner.steam-api.com';

export type TicketDeps = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  /// SteamID64 -> {token_hash} for a Supabase session (find or create the profile).
  sessionFor: (steamId: string) => Promise<{ token_hash: string }>;
};

export type TicketCheck =
  | { ok: true; steamId: string; ownerSteamId: string }
  | { ok: false; status: number; error: string };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

const steamIdPattern = /^\d{17}$/;

/// Verifies the ticket and the ownership with Steam's Web API.
export async function checkTicket(
  ticket: string,
  key: string,
  appId: string,
  doFetch: typeof fetch,
): Promise<TicketCheck> {
  const auth = new URL(`${partnerApi}/ISteamUserAuth/AuthenticateUserTicket/v1/`);
  auth.searchParams.set('key', key);
  auth.searchParams.set('appid', appId);
  auth.searchParams.set('ticket', ticket);
  auth.searchParams.set('identity', webApiIdentity);
  const authResponse = await doFetch(auth.toString());
  if (!authResponse.ok) return { ok: false, status: 502, error: 'steam_unavailable' };
  // deno-lint-ignore no-explicit-any
  const authBody: any = await authResponse.json().catch(() => null);
  const params = authBody?.response?.params;
  if (!params || params.result !== 'OK') return { ok: false, status: 401, error: 'ticket_invalid' };
  const steamId = String(params.steamid ?? '');
  const ownerSteamId = String(params.ownersteamid ?? steamId);
  if (!steamIdPattern.test(steamId)) return { ok: false, status: 401, error: 'ticket_invalid' };
  if (params.publisherbanned === true) return { ok: false, status: 403, error: 'banned' };

  const owns = new URL(`${partnerApi}/ISteamUser/CheckAppOwnership/v2/`);
  owns.searchParams.set('key', key);
  owns.searchParams.set('steamid', steamId);
  owns.searchParams.set('appid', appId);
  const ownsResponse = await doFetch(owns.toString());
  if (!ownsResponse.ok) return { ok: false, status: 502, error: 'steam_unavailable' };
  // deno-lint-ignore no-explicit-any
  const ownsBody: any = await ownsResponse.json().catch(() => null);
  const ownership = ownsBody?.appownership;
  if (!ownership || ownership.result !== 'OK' || ownership.ownsapp !== true) {
    return { ok: false, status: 403, error: 'not_owner' };
  }
  return { ok: true, steamId, ownerSteamId };
}

export async function handleTicket(body: { ticket?: unknown }, deps: TicketDeps): Promise<Response> {
  const key = deps.env('STEAM_WEB_API_KEY');
  const appId = deps.env('STEAM_APP_ID');
  if (!key || !appId) return json({ error: 'not_configured' }, 501);
  const ticket = typeof body.ticket === 'string' ? body.ticket : '';
  if (!/^[0-9a-fA-F]{16,10240}$/.test(ticket) || ticket.length % 2 !== 0 || !/^\d+$/.test(appId)) {
    return json({ error: 'bad_request' }, 400);
  }
  const check = await checkTicket(ticket, key, appId, deps.fetch);
  if (!check.ok) return json({ error: check.error }, check.status);
  return json(await deps.sessionFor(check.steamId));
}
