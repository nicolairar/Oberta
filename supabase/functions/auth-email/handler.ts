// Supabase Auth's "Send Email Hook": every auth email of the project ("Entra
// con email", no passwords) goes out from here, through Brevo, instead of
// Supabase's own sender (2 emails an hour, unbranded).
//
//   POST (from Supabase Auth, signed with standard-webhooks)  -> 200 {} | 401 | 400 | 500 {error}
//   GET  /img/<name>   the email's images (the waitlist's, waitlist/templates/images.ts)
//
// The payload is {user, email_data: {token, token_hash, redirect_to,
// email_action_type, site_url, token_new, token_hash_new}}. Every mail carries
// the six digits; where the app can open it (redirect_to is oberta://, the
// phones) also a button with the magic link: Supabase's /auth/v1/verify,
// which sends the browser back to oberta://login-callback?code=... and
// supabase_flutter signs in. On the computer the app asks for no redirect
// (redirect_to is then the Site URL) and the mail has only the code.
//
// Kinds: magiclink and recovery are a sign-in, signup and invite the first
// sign-in, email_change a new address (one mail, or two with Secure email
// change on: token_hash goes to the new address, token_hash_new to the
// current one, as Supabase documents it), reauthentication a code only.
//
// Language: user_metadata.lang (the app sends it on the first sign-in):
// Italian for `it`, English for any other; unknown: both in one mail.
//
// Recipients under the .invalid top-level domain (RFC 2606, never
// deliverable) go to Brevo's sandbox (X-Sib-Sandbox: drop): an end-to-end test
// through Supabase Auth that sends nothing (docs/release.md).
//
// Secrets (Edge Function secrets, never in the repository):
//   SEND_EMAIL_HOOK_SECRET   "v1,whsec_<base64>", the same as in Auth > Hooks
//   BREVO_API_KEY, BREVO_SENDER_EMAIL, BREVO_SENDER_NAME   (the waitlist's)
import { images } from '../waitlist/templates/images.ts';
import { codeEmail, type Kind, type MailLang } from './templates/code.ts';

export interface HookDeps {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  log: (...args: unknown[]) => void;
  /** Seconds since the epoch; for the signature's freshness. */
  now?: () => number;
}

export const brevoUrl = 'https://api.brevo.com/v3/smtp/email';
export const replyTo = 'oberta@charliemobile.dev';
const site = 'https://charliemobile.dev/oberta';
export const privacyUrl = { it: `${site}/privacy.html`, en: `${site}/privacy-en.html` };
/** The app's scheme: only links back to it get a button. */
const appScheme = 'oberta://';
/** How far a signature's timestamp may drift (standard-webhooks). */
const tolerance = 5 * 60;

export interface HookUser {
  id?: string;
  email?: string;
  new_email?: string;
  user_metadata?: Record<string, unknown>;
}

export interface EmailData {
  token?: string;
  token_hash?: string;
  redirect_to?: string;
  email_action_type?: string;
  site_url?: string;
  token_new?: string;
  token_hash_new?: string;
}

/** One mail to send. */
export interface Planned {
  to: string;
  kind: Kind;
  code: string;
  link: string | null;
  action: string;
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

/** The error shape Supabase Auth reads from a hook. */
function failure(status: number, message: string) {
  return json({ error: { http_code: status, message } }, status);
}

const decode64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const encode64 = (bytes: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(bytes)));

/** HMAC-SHA256 of `${id}.${timestamp}.${body}` with the whsec_ key, base64. */
export async function sign(secret: string, id: string, timestamp: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    decode64(secret.replace(/^v1,/, '').replace(/^whsec_/, '')),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return encode64(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${id}.${timestamp}.${body}`)));
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** True when the standard-webhooks headers sign [body] with [secret], recently. */
export async function verified(secret: string, headers: Headers, body: string, now: number): Promise<boolean> {
  const id = headers.get('webhook-id');
  const timestamp = headers.get('webhook-timestamp');
  const signatures = headers.get('webhook-signature');
  if (!id || !timestamp || !signatures || !/^\d+$/.test(timestamp)) return false;
  if (Math.abs(now - Number(timestamp)) > tolerance) return false;
  const expected = await sign(secret, id, timestamp, body);
  return signatures.split(' ').some((part) => {
    const [version, signature] = part.split(',', 2);
    return version === 'v1' && signature !== undefined && sameText(signature, expected);
  });
}

/** Italian, English, or both when the account never said. */
export function mailLang(user: HookUser): MailLang {
  const lang = user.user_metadata?.lang;
  if (typeof lang !== 'string' || lang.trim() === '') return 'both';
  return lang.toLowerCase().startsWith('it') ? 'it' : 'en';
}

/** The Supabase project URL, for the verify link. */
function projectUrl(env: HookDeps['env'], data: EmailData): string {
  const fromEnv = env('SUPABASE_URL');
  if (fromEnv) return fromEnv.replace(/\/$/, '');
  return (data.site_url ?? '').replace(/\/auth\/v1\/?$/, '').replace(/\/$/, '');
}

/** The mails a hook call asks for: usually one, two for a secure email change. */
export function plan(user: HookUser, data: EmailData, env: HookDeps['env']): Planned[] {
  const action = data.email_action_type ?? '';
  const redirect = data.redirect_to ?? '';
  const project = projectUrl(env, data);
  const link = (hash: string | undefined, type: string): string | null => {
    if (!hash || !redirect.startsWith(appScheme) || !project) return null;
    const query = new URLSearchParams({ token: hash, type, redirect_to: redirect });
    return `${project}/auth/v1/verify?${query}`;
  };
  const mail = (to: string | undefined, kind: Kind, code: string | undefined, hash: string | undefined, type: string) =>
    to && code ? [{ to, kind, code, link: kind === 'reauthentication' ? null : link(hash, type), action }] : [];

  switch (action) {
    case 'signup':
    case 'invite':
      return mail(user.email, 'signup', data.token, data.token_hash, action);
    case 'reauthentication':
      return mail(user.email, 'reauthentication', data.token, undefined, action);
    case 'email_change': {
      const newAddress = user.new_email ?? user.email;
      if (data.token_hash && data.token_hash_new) {
        return [
          ...mail(newAddress, 'email_change', data.token, data.token_hash, action),
          ...mail(user.email, 'email_change', data.token_new, data.token_hash_new, action),
        ];
      }
      return mail(newAddress, 'email_change', data.token || data.token_new, data.token_hash || data.token_hash_new, action);
    }
    case 'recovery':
      return mail(user.email, 'signin', data.token, data.token_hash, 'recovery');
    default:
      // magiclink, and anything new: a sign-in with code and link.
      return mail(user.email, 'signin', data.token, data.token_hash, 'magiclink');
  }
}

/** Sends one mail: null when Brevo took it, else why not (no secrets in it). */
export async function send(deps: HookDeps, mail: Planned, lang: MailLang, minutes: number, assetBase: string) {
  const key = deps.env('BREVO_API_KEY');
  const sender = deps.env('BREVO_SENDER_EMAIL');
  if (!key || !sender) return 'brevo secrets missing';
  const email = codeEmail({ kind: mail.kind, lang, code: mail.code, link: mail.link, minutes, assetBase, privacyUrl });
  const sandbox = /\.invalid$/i.test(mail.to);
  try {
    const res = await deps.fetch(brevoUrl, {
      method: 'POST',
      headers: { 'api-key': key, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        sender: { email: sender, name: deps.env('BREVO_SENDER_NAME') || 'Obertà' },
        replyTo: { email: replyTo },
        to: [{ email: mail.to }],
        subject: email.subject,
        htmlContent: email.html,
        textContent: email.text,
        tags: [`auth-${mail.action || 'email'}`],
        ...(sandbox ? { headers: { 'X-Sib-Sandbox': 'drop' } } : {}),
      }),
    });
    const answer = (await res.text().catch(() => '')).replaceAll(key, '***').slice(0, 300);
    if (!res.ok) return `brevo ${res.status}: ${answer}`;
    return null;
  } catch (error) {
    return `brevo unreachable: ${(error instanceof Error ? error.message : 'failed').replaceAll(key, '***').slice(0, 200)}`;
  }
}

export async function handleAuthEmail(req: Request, deps: HookDeps): Promise<Response> {
  const url = new URL(req.url);
  const picture = url.pathname.match(/\/img\/([a-z0-9-]+\.(?:jpg|png))$/);
  if (picture && (req.method === 'GET' || req.method === 'HEAD')) {
    const image = images[picture[1]];
    if (!image) return new Response('not found', { status: 404 });
    return new Response(req.method === 'HEAD' ? null : decode64(image.base64), {
      headers: { 'content-type': image.type, 'cache-control': 'public, max-age=604800', 'access-control-allow-origin': '*' },
    });
  }
  if (req.method !== 'POST') return failure(405, 'method not allowed');

  const secret = deps.env('SEND_EMAIL_HOOK_SECRET');
  if (!secret) {
    deps.log('auth-email: SEND_EMAIL_HOOK_SECRET missing');
    return failure(500, 'hook secret missing');
  }
  const body = await req.text();
  const now = deps.now?.() ?? Math.floor(Date.now() / 1000);
  if (!(await verified(secret, req.headers, body, now))) return failure(401, 'invalid signature');

  let payload: { user?: HookUser; email_data?: EmailData };
  try {
    payload = JSON.parse(body);
  } catch {
    return failure(400, 'invalid payload');
  }
  const user = payload.user ?? {};
  const data = payload.email_data ?? {};
  const mails = plan(user, data, deps.env);
  if (mails.length === 0) {
    deps.log('auth-email: nothing to send for', data.email_action_type ?? '?');
    return failure(400, 'no recipient or no code');
  }
  const minutes = Math.round(Number(deps.env('AUTH_EMAIL_MINUTES') ?? '15')) || 15;
  const assetBase = deps.env('AUTH_EMAIL_ASSET_BASE') ??
    `${(deps.env('SUPABASE_URL') ?? url.origin).replace(/\/$/, '')}/functions/v1/auth-email/img`;
  const lang = mailLang(user);
  for (const mail of mails) {
    const error = await send(deps, mail, lang, minutes, assetBase);
    if (error) {
      deps.log('auth-email:', mail.action, 'not sent:', error);
      return failure(500, `email not sent (${error})`);
    }
  }
  return json({}, 200);
}
