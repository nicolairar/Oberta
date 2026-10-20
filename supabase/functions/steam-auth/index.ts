// "Accedi con Steam" for the desktop app: Steam OpenID 2.0 (Phase 1 of
// docs/steam.md; no Steamworks partner account, no Web API key).
//
//   GET  ?action=start&port=<loopback port>&state=<app random>
//        -> 302 to https://steamcommunity.com/openid/login (checkid_setup),
//           return_to = this function with the same port and state.
//   GET  ?action=return&port=..&state=..&openid.*=..   (Steam comes back)
//        -> checks the assertion with Steam (check_authentication), reads the
//           SteamID64, finds or creates the Supabase user tied to it
//           (internal.steam_identities), issues a one-time code bound to the
//           state, and 302s the browser to http://127.0.0.1:<port>/steam with
//           the code and state, where the app is listening.
//   POST {action: "exchange", code, state}
//        -> the code once, for {token_hash}: a magic-link token the app turns
//           into a normal Supabase session with auth.verifyOtp().
//
// verify_jwt = false (config.toml): the browser legs carry no JWT. The
// service role key is the one Supabase gives every function; it never
// leaves the server.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

const steamLogin = 'https://steamcommunity.com/openid/login';
const openidNs = 'http://specs.openid.net/auth/2.0';
const identifierSelect = 'http://specs.openid.net/auth/2.0/identifier_select';
const claimedPattern = /^https:\/\/steamcommunity\.com\/openid\/id\/(\d{17})$/;
const selfUrl = `${supabaseUrl.replace(/\/$/, '')}/functions/v1/steam-auth`;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

function page(message: string, status = 400) {
  const html = `<!doctype html><meta charset="utf-8"><title>Obertà</title>` +
    `<body style="background:#07070b;color:#e8dcc0;font-family:Georgia,serif;text-align:center;padding-top:20vh">` +
    `<h1 style="color:#c9a227">Obertà</h1><p>${message}</p></body>`;
  return new Response(html, { status, headers: { 'content-type': 'text/html; charset=utf-8' } });
}

function validPort(value: string | null): number | null {
  const port = Number(value);
  return Number.isInteger(port) && port >= 1024 && port <= 65535 ? port : null;
}

function validState(value: string | null): string | null {
  return value && /^[A-Za-z0-9_-]{16,128}$/.test(value) ? value : null;
}

function returnTo(port: number, state: string) {
  const url = new URL(selfUrl);
  url.searchParams.set('action', 'return');
  url.searchParams.set('port', String(port));
  url.searchParams.set('state', state);
  return url.toString();
}

function start(params: URLSearchParams) {
  const port = validPort(params.get('port'));
  const state = validState(params.get('state'));
  if (!port || !state) return page('Richiesta non valida. / Invalid request.');
  const login = new URL(steamLogin);
  login.searchParams.set('openid.ns', openidNs);
  login.searchParams.set('openid.mode', 'checkid_setup');
  login.searchParams.set('openid.return_to', returnTo(port, state));
  login.searchParams.set('openid.realm', new URL(selfUrl).origin);
  login.searchParams.set('openid.identity', identifierSelect);
  login.searchParams.set('openid.claimed_id', identifierSelect);
  return Response.redirect(login.toString(), 302);
}

/// Asks Steam whether it really signed these parameters.
async function steamConfirms(params: URLSearchParams): Promise<boolean> {
  const check = new URLSearchParams();
  for (const [key, value] of params) {
    if (key.startsWith('openid.')) check.set(key, value);
  }
  check.set('openid.mode', 'check_authentication');
  const response = await fetch(steamLogin, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: check.toString(),
  });
  if (!response.ok) return false;
  const body = await response.text();
  return body.split('\n').some((line) => line.trim() === 'is_valid:true');
}

async function profileFor(steamId: string): Promise<string> {
  const { data: existing, error } = await admin.rpc('steam_identity_profile', { p_steam_id: steamId });
  if (error) throw error;
  if (existing) return existing as string;
  // A synthetic address: Supabase needs one for magic-link tokens. Nothing
  // is ever sent to it (generateLink does not send mail).
  const email = `steam-${steamId}@steam.oberta.invalid`;
  let userId: string | undefined;
  const created = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    app_metadata: { provider: 'steam', providers: ['steam'] },
    user_metadata: { steam_id: steamId },
  });
  if (created.data.user) {
    userId = created.data.user.id;
  } else {
    // Already there (a login that broke half-way): find it through a link.
    const link = await admin.auth.admin.generateLink({ type: 'magiclink', email });
    if (link.error || !link.data.user) throw created.error ?? link.error;
    userId = link.data.user.id;
  }
  const { data: owner, error: attachError } = await admin.rpc('steam_identity_attach', {
    p_steam_id: steamId,
    p_profile_id: userId,
  });
  if (attachError) throw attachError;
  return owner as string;
}

async function finish(params: URLSearchParams) {
  const port = validPort(params.get('port'));
  const state = validState(params.get('state'));
  if (!port || !state) return page('Richiesta non valida. / Invalid request.');
  if (params.get('openid.mode') !== 'id_res') return page('Accesso annullato. / Sign-in cancelled.');
  if (params.get('openid.op_endpoint') !== steamLogin) return page('Risposta non di Steam. / Not a Steam answer.');
  if (params.get('openid.return_to') !== returnTo(port, state)) return page('Ritorno non valido. / Bad return_to.');
  const claimed = params.get('openid.claimed_id') ?? '';
  const match = claimedPattern.exec(claimed);
  const nonce = params.get('openid.response_nonce');
  if (!match || params.get('openid.identity') !== claimed || !nonce) {
    return page('Identità Steam non valida. / Invalid Steam identity.');
  }
  const signed = (params.get('openid.signed') ?? '').split(',');
  for (const field of ['op_endpoint', 'claimed_id', 'identity', 'return_to', 'response_nonce', 'assoc_handle']) {
    if (!signed.includes(field)) return page('Firma incompleta. / Incomplete signature.');
  }
  if (!(await steamConfirms(params))) return page('Steam non conferma l\'accesso. / Steam did not confirm.');

  const profileId = await profileFor(match[1]);
  const { data: code, error } = await admin.rpc('steam_login_code_issue', {
    p_profile_id: profileId,
    p_state: state,
    p_nonce: nonce,
  });
  if (error) return page('Accesso già usato. / Sign-in already used.');
  const back = new URL(`http://127.0.0.1:${port}/steam`);
  back.searchParams.set('code', code as string);
  back.searchParams.set('state', state);
  return Response.redirect(back.toString(), 302);
}

async function exchange(request: Request) {
  let body: { code?: unknown; state?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const code = typeof body.code === 'string' ? body.code : '';
  const state = validState(typeof body.state === 'string' ? body.state : null);
  if (!/^[a-f0-9]{64}$/.test(code) || !state) return json({ error: 'bad_request' }, 400);
  const { data: profileId, error } = await admin.rpc('steam_login_code_consume', { p_code: code, p_state: state });
  if (error || !profileId) return json({ error: 'steam_code_invalid' }, 400);

  const { data: found, error: userError } = await admin.auth.admin.getUserById(profileId as string);
  if (userError || !found.user) return json({ error: 'user_not_found' }, 400);
  let email = found.user.email;
  if (!email) {
    // A linked profile without an address (rare): give it the Steam one.
    const { data: identity } = await admin.rpc('steam_identity_of_profile', { p_profile_id: profileId });
    email = `steam-${identity ?? profileId}@steam.oberta.invalid`;
    const updated = await admin.auth.admin.updateUserById(found.user.id, { email, email_confirm: true });
    if (updated.error) return json({ error: 'user_update_failed' }, 500);
  }
  const link = await admin.auth.admin.generateLink({ type: 'magiclink', email });
  const tokenHash = link.data?.properties?.hashed_token;
  if (link.error || !tokenHash) return json({ error: 'link_failed' }, 500);
  return json({ token_hash: tokenHash });
}

Deno.serve(async (request) => {
  try {
    const url = new URL(request.url);
    if (request.method === 'POST') return await exchange(request);
    if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);
    const action = url.searchParams.get('action');
    if (action === 'start') return start(url.searchParams);
    if (action === 'return') return await finish(url.searchParams);
    return page('Richiesta non valida. / Invalid request.');
  } catch (error) {
    console.error('steam-auth', error);
    return request.method === 'POST' ? json({ error: 'server_error' }, 500) : page('Errore del server. / Server error.', 500);
  }
});
