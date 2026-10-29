// The launch waitlist's door, called by the landing page (no JWT).
//
//   POST {action: "join", email, lang, consent, website}   -> {ok: true} | {ok: false, error}
//   POST {action: "confirm", token}                         -> {ok: true}
//   POST {action: "unsubscribe", token}                     -> {ok: true}
//   POST ?unsubscribe=<token>  (RFC 8058 one-click from the mail client) -> {ok: true}
//
// Only the site's origins get through (CORS and a check here). A join goes to
// internal.waitlist_join (consent, shape, rate limit per hashed IP), which
// says whether the address is new: only a NEW address gets the confirmation
// email (double opt-in) through Brevo. An address already on the list,
// confirmed or not, gets nothing and the same {ok: true}: the answer never
// tells whether someone is on the list. Without the Brevo secrets the sign-up
// is still saved and the mail is skipped (logged).
import { confirmEmail, type Lang } from './templates/confirm.ts';

export interface JoinResult {
  ok: boolean;
  error?: string;
  new?: boolean;
  lang?: string;
  confirm_token?: string;
  unsubscribe_token?: string;
}

export interface WaitlistDeps {
  env: (name: string) => string | undefined;
  join: (email: string, lang: string, consent: string, ip: string | null) => Promise<JoinResult>;
  confirm: (token: string) => Promise<void>;
  unsubscribe: (token: string) => Promise<void>;
  /** Notes how the confirmation email went: confirm_sent_at, or the reason in confirm_error. */
  noteMail: (confirmToken: string, error: string | null) => Promise<void>;
  fetch: typeof fetch;
  log: (...args: unknown[]) => void;
}

export const brevoUrl = 'https://api.brevo.com/v3/smtp/email';
const defaultSite = 'https://charliemobile.dev/oberta';
/** The only contact address in the mails (and where replies go). */
export const replyTo = 'oberta@charliemobile.dev';
const defaultOrigins = ['https://charliemobile.dev', 'https://www.charliemobile.dev', 'https://oberta.pages.dev'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The site origins allowed to call: WAITLIST_ORIGINS (comma separated) or the defaults, plus Pages previews. */
export function allowedOrigin(origin: string | null, env: WaitlistDeps['env']): boolean {
  if (!origin) return false;
  const list = (env('WAITLIST_ORIGINS') ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  if ((list.length ? list : defaultOrigins).includes(origin)) return true;
  return /^https:\/\/[a-z0-9-]+\.oberta\.pages\.dev$/.test(origin);
}

function cors(origin: string | null, env: WaitlistDeps['env']): Record<string, string> {
  const headers: Record<string, string> = { vary: 'Origin' };
  if (allowedOrigin(origin, env)) {
    headers['access-control-allow-origin'] = origin!;
    headers['access-control-allow-methods'] = 'POST, OPTIONS';
    headers['access-control-allow-headers'] = 'content-type';
    headers['access-control-max-age'] = '86400';
  }
  return headers;
}

function json(body: unknown, status: number, extra: Record<string, string>) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...extra } });
}

export function clientIp(req: Request): string | null {
  const h = req.headers;
  return h.get('cf-connecting-ip') ?? h.get('x-forwarded-for')?.split(',')[0]?.trim() ?? h.get('x-real-ip') ?? null;
}

export function siteUrl(env: WaitlistDeps['env']): string {
  return (env('WAITLIST_SITE_URL') ?? defaultSite).replace(/\/$/, '');
}

/** Sends the confirmation email: null when Brevo took it, else why not (no secrets ever in it). */
export async function sendConfirmation(
  deps: WaitlistDeps,
  to: string,
  lang: Lang,
  confirmToken: string,
  unsubscribeToken: string,
  functionUrl: string,
): Promise<string | null> {
  const key = deps.env('BREVO_API_KEY');
  const sender = deps.env('BREVO_SENDER_EMAIL');
  if (!key || !sender) {
    deps.log('waitlist: Brevo secrets missing, confirmation email skipped');
    return 'secrets_missing';
  }
  const site = siteUrl(deps.env);
  const unsubscribeUrl = `${site}/disiscriviti.html?t=${unsubscribeToken}`;
  const mail = confirmEmail(lang, {
    confirmUrl: `${site}/conferma.html?t=${confirmToken}`,
    unsubscribeUrl,
    privacyUrl: `${site}/privacy.html#lista`,
    assetBase: `${site}/email`,
  });
  try {
    const res = await deps.fetch(brevoUrl, {
      method: 'POST',
      headers: { 'api-key': key, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        sender: { email: sender, name: deps.env('BREVO_SENDER_NAME') || 'Obertà' },
        replyTo: { email: replyTo },
        to: [{ email: to }],
        subject: mail.subject,
        htmlContent: mail.html,
        textContent: mail.text,
        tags: ['waitlist-confirm'],
        headers: {
          'List-Unsubscribe': `<${unsubscribeUrl}>, <${functionUrl}?unsubscribe=${unsubscribeToken}>`,
          'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
        },
      }),
    });
    const answer = (await res.text().catch(() => '')).replaceAll(key, '***').slice(0, 300);
    if (!res.ok) {
      deps.log('waitlist: Brevo answered', res.status, answer);
      return `brevo ${res.status}: ${answer}`;
    }
    return null;
  } catch (error) {
    const reason = (error instanceof Error ? error.message : 'failed').replaceAll(key, '***').slice(0, 300);
    deps.log('waitlist: Brevo unreachable', reason);
    return `unreachable: ${reason}`;
  }
}

export async function handleWaitlist(req: Request, deps: WaitlistDeps): Promise<Response> {
  const url = new URL(req.url);
  const origin = req.headers.get('origin');
  const headers = cors(origin, deps.env);

  // One-click unsubscribe from the mail client: no origin, just the token.
  const oneClick = url.searchParams.get('unsubscribe');
  if (oneClick !== null && req.method === 'POST') {
    if (uuid.test(oneClick)) await deps.unsubscribe(oneClick.toLowerCase());
    return json({ ok: true }, 200, headers);
  }

  if (req.method === 'OPTIONS') return new Response(null, { status: allowedOrigin(origin, deps.env) ? 204 : 403, headers });
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405, headers);
  if (!allowedOrigin(origin, deps.env)) return json({ ok: false, error: 'forbidden' }, 403, headers);

  const body = await req.json().catch(() => null);
  if (!body || typeof body !== 'object') return json({ ok: false, error: 'bad_request' }, 400, headers);
  const { action } = body as Record<string, unknown>;

  if (action === 'confirm' || action === 'unsubscribe') {
    const token = (body as Record<string, unknown>).token;
    if (typeof token === 'string' && uuid.test(token)) {
      await (action === 'confirm' ? deps.confirm : deps.unsubscribe)(token.toLowerCase());
    }
    return json({ ok: true }, 200, headers);
  }
  if (action !== 'join') return json({ ok: false, error: 'bad_request' }, 400, headers);

  const { email, lang, consent, website } = body as Record<string, unknown>;
  // The honeypot: a field people never see. Bots that fill it get a quiet ok.
  if (typeof website === 'string' && website.trim() !== '') return json({ ok: true }, 200, headers);
  if (typeof email !== 'string' || email.length > 320) return json({ ok: false, error: 'invalid_email' }, 200, headers);

  const result = await deps.join(
    email,
    typeof lang === 'string' ? lang.slice(0, 8) : 'it',
    typeof consent === 'string' ? consent.slice(0, 40) : '',
    clientIp(req),
  );
  if (!result.ok) return json({ ok: false, error: result.error ?? 'failed' }, 200, headers);
  if (result.new && result.confirm_token && result.unsubscribe_token) {
    const mailLang: Lang = result.lang === 'it' ? 'it' : 'en';
    const functionUrl = `${(deps.env('SUPABASE_URL') ?? url.origin).replace(/\/$/, '')}/functions/v1/waitlist`;
    const error = await sendConfirmation(deps, email.trim().toLowerCase(), mailLang, result.confirm_token, result.unsubscribe_token, functionUrl);
    await deps.noteMail(result.confirm_token, error).catch(() => deps.log('waitlist: could not note the mail outcome'));
  }
  // New or already there, mail sent or not: the same answer.
  return json({ ok: true }, 200, headers);
}
