// Deletes the caller's account (App Store guideline 5.1.1(v), GDPR art. 17).
//
// POST with the user's JWT (verify_jwt = true in config.toml). The function
// reads who is calling from that JWT, never from the body, then with the
// built-in service role:
//   1. revokes the Sign in with Apple token, when the Apple secrets are set;
//   2. calls public.forget_account(), which leaves open rooms, keeps the
//      anonymous purchase records and deletes the profile (everything
//      personal cascades from it: see 20261019150000_account_privacy.sql;
//      the Steam identity, persona name and avatar too: 20261107090000);
//   3. deletes the auth user.
//
// Apple revocation (https://developer.apple.com/documentation/
// sign_in_with_apple/revoke_tokens) needs a client secret signed with the
// owner's Sign in with Apple key. Set these Edge Function secrets in the
// Supabase dashboard to turn it on; without them the step is skipped and
// the account is still deleted:
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID (the bundle id),
//   APPLE_PRIVATE_KEY (the .p8 contents).
// The app sends the fresh authorization code from a Sign in with Apple
// sheet as `apple_authorization_code` when it has one.
// TODO(owner): create the key and set the secrets above.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

async function appleClientSecret(): Promise<{ clientId: string; secret: string } | null> {
  const teamId = Deno.env.get('APPLE_TEAM_ID');
  const keyId = Deno.env.get('APPLE_KEY_ID');
  const clientId = Deno.env.get('APPLE_CLIENT_ID');
  const privateKey = Deno.env.get('APPLE_PRIVATE_KEY');
  if (!teamId || !keyId || !clientId || !privateKey) return null;
  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'ES256');
  const secret = await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime('5m')
    .setAudience('https://appleid.apple.com')
    .setSubject(clientId)
    .sign(key);
  return { clientId, secret };
}

async function revokeApple(code: string): Promise<boolean> {
  const client = await appleClientSecret();
  if (!client) return false;
  const form = (body: Record<string, string>) => ({
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(body),
  });
  // The authorization code becomes a refresh token, which is what Apple revokes.
  const tokenRes = await fetch('https://appleid.apple.com/auth/token', form({
    client_id: client.clientId,
    client_secret: client.secret,
    code,
    grant_type: 'authorization_code',
  }));
  if (!tokenRes.ok) return false;
  const tokens = await tokenRes.json();
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) return false;
  const revokeRes = await fetch('https://appleid.apple.com/auth/revoke', form({
    client_id: client.clientId,
    client_secret: client.secret,
    token,
    token_type_hint: tokens.refresh_token ? 'refresh_token' : 'access_token',
  }));
  return revokeRes.ok;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const jwt = req.headers.get('authorization')?.replace(/^Bearer /i, '');
  if (!jwt) return json({ error: 'not_signed_in' }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: who, error: whoError } = await admin.auth.getUser(jwt);
  if (whoError || !who?.user) return json({ error: 'not_signed_in' }, 401);
  const userId = who.user.id;

  const body = await req.json().catch(() => ({}));
  if (body?.action !== 'delete') return json({ error: 'unknown_action' }, 400);

  let appleRevoked = false;
  if (typeof body.apple_authorization_code === 'string') {
    appleRevoked = await revokeApple(body.apple_authorization_code).catch(() => false);
  }

  const { error: forgetError } = await admin.rpc('forget_account', { target: userId });
  if (forgetError) return json({ error: 'forget_failed', detail: forgetError.message }, 500);

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) return json({ error: 'delete_failed', detail: deleteError.message }, 500);

  return json({ deleted: true, apple_revoked: appleRevoked });
});
