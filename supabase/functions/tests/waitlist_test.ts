// The waitlist Edge Function with an in-memory list and a fake Brevo: only a
// new address gets the confirmation email, a known one gets nothing and the
// same answer, no secrets means saved but not sent, only the site's origins
// get in. The database side is supabase/tests/waitlist.sql.
//
//   deno test -A supabase/functions/tests/waitlist_test.ts
import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { brevoUrl, handleWaitlist, type JoinResult, type WaitlistDeps } from '../waitlist/handler.ts';
import { confirmEmail } from '../waitlist/templates/confirm.ts';
import { preview, previewDir } from '../waitlist/templates/preview.ts';

const site = 'https://charliemobile.dev';
const secrets = {
  BREVO_API_KEY: 'test-key',
  BREVO_SENDER_EMAIL: 'ciao@example.com',
  BREVO_SENDER_NAME: 'Obertà',
  SUPABASE_URL: 'https://ref.supabase.co',
};

function world(env: Record<string, string> = secrets, brevoStatus = 201) {
  const list = new Map<string, { lang: string; confirm: string; unsubscribe: string; confirmed: boolean }>();
  const mails: { url: string; headers: Headers; body: Record<string, unknown> }[] = [];
  const logs: string[] = [];
  const joins: { ip: string | null; consent: string }[] = [];
  const sent: string[] = [];
  const failed: string[] = [];
  let n = 0;
  const deps: WaitlistDeps = {
    env: (name) => env[name],
    join: (email, lang, consent, ip): Promise<JoinResult> => {
      joins.push({ ip, consent });
      if (consent !== '2026-10-v1') return Promise.resolve({ ok: false, error: 'consent_required' });
      const addr = email.trim().toLowerCase();
      if (!/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/.test(addr)) return Promise.resolve({ ok: false, error: 'invalid_email' });
      if (list.has(addr)) return Promise.resolve({ ok: true, new: false });
      n += 1;
      const row = {
        lang,
        confirm: `c0000000-0000-4000-8000-00000000000${n}`,
        unsubscribe: `u0000000-0000-4000-8000-00000000000${n}`.replace('u', 'a'),
        confirmed: false,
      };
      list.set(addr, row);
      return Promise.resolve({ ok: true, new: true, lang, confirm_token: row.confirm, unsubscribe_token: row.unsubscribe });
    },
    confirm: (token) => {
      for (const row of list.values()) if (row.confirm === token) row.confirmed = true;
      return Promise.resolve();
    },
    unsubscribe: (token) => {
      for (const [k, row] of list) if (row.unsubscribe === token) list.delete(k);
      return Promise.resolve();
    },
    noteMail: (token, error) => {
      if (error === null) sent.push(token);
      else failed.push(error);
      return Promise.resolve();
    },
    fetch: ((input: string | URL | Request, init?: RequestInit) => {
      mails.push({ url: String(input), headers: new Headers(init?.headers), body: JSON.parse(String(init?.body)) });
      const answer = brevoStatus < 300 ? '{"messageId":"x"}' : `{"message":"bad key ${env.BREVO_API_KEY}"}`;
      return Promise.resolve(new Response(answer, { status: brevoStatus }));
    }) as typeof fetch,
    log: (...args) => logs.push(args.join(' ')),
  };
  return { deps, list, mails, logs, joins, sent, failed };
}

const call = (deps: WaitlistDeps, body: unknown, origin: string | null = site, extra: Record<string, string> = {}) =>
  handleWaitlist(
    new Request('https://ref.supabase.co/functions/v1/waitlist', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(origin ? { origin } : {}), ...extra },
      body: JSON.stringify(body),
    }),
    deps,
  );

const join = (email: string, lang = 'it') => ({ action: 'join', email, lang, consent: '2026-10-v1', website: '' });

Deno.test('a new address is saved and gets one confirmation email from Brevo', async () => {
  const w = world();
  const res = await call(w.deps, join('Zz.Aiko@Example.com'), site, { 'x-forwarded-for': '203.0.113.7, 10.0.0.1' });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ok: true });
  assertEquals(res.headers.get('access-control-allow-origin'), site);
  assertEquals(w.joins[0].ip, '203.0.113.7');
  assertEquals(w.mails.length, 1);
  const mail = w.mails[0];
  assertEquals(mail.url, brevoUrl);
  assertEquals(mail.headers.get('api-key'), 'test-key');
  assertEquals(mail.body.to, [{ email: 'zz.aiko@example.com' }]);
  assertEquals(mail.body.sender, { email: 'ciao@example.com', name: 'Obertà' });
  assertEquals(mail.body.replyTo, { email: 'oberta@charliemobile.dev' });
  assertEquals(mail.body.subject, 'La Famiglia ti ha notato');
  const row = w.list.get('zz.aiko@example.com')!;
  assertStringIncludes(String(mail.body.htmlContent), `https://charliemobile.dev/oberta/conferma.html?t=${row.confirm}`);
  assertStringIncludes(String(mail.body.htmlContent), `https://charliemobile.dev/oberta/disiscriviti.html?t=${row.unsubscribe}`);
  assertStringIncludes(String(mail.body.htmlContent), 'Grazie per l’interesse');
  assertStringIncludes(String(mail.body.textContent), `conferma.html?t=${row.confirm}`);
  const headers = mail.body.headers as Record<string, string>;
  assertStringIncludes(headers['List-Unsubscribe'], `https://ref.supabase.co/functions/v1/waitlist?unsubscribe=${row.unsubscribe}`);
  assertEquals(headers['List-Unsubscribe-Post'], 'List-Unsubscribe=One-Click');
  assertEquals(w.sent, [row.confirm]);
});

Deno.test('an address already on the list, confirmed or not, gets nothing and the same answer', async () => {
  const w = world();
  await call(w.deps, join('zz@example.com'));
  const again = await call(w.deps, join(' ZZ@example.com '));
  assertEquals(await again.json(), { ok: true });
  w.list.get('zz@example.com')!.confirmed = true;
  const third = await call(w.deps, join('zz@example.com', 'en'));
  assertEquals(await third.json(), { ok: true });
  assertEquals(w.mails.length, 1);
  assertEquals(w.sent.length, 1);
});

Deno.test('English sign-ups (and any other language) get the English email', async () => {
  const w = world();
  await call(w.deps, join('zz_en@example.com', 'en'));
  await call(w.deps, join('zz_ja@example.com', 'ja'));
  assertEquals(w.mails.map((m) => m.body.subject), ['The Family has noticed you', 'The Family has noticed you']);
  assertStringIncludes(String(w.mails[0].body.htmlContent), 'The Family has noticed you.');
});

Deno.test('without the Brevo secrets the sign-up is saved and the mail skipped', async () => {
  const w = world({ SUPABASE_URL: 'https://ref.supabase.co' });
  const res = await call(w.deps, join('zz@example.com'));
  assertEquals(await res.json(), { ok: true });
  assert(w.list.has('zz@example.com'));
  assertEquals(w.mails.length, 0);
  assert(w.logs.some((l) => l.includes('secrets missing')));
  assertEquals(w.sent, []);
  assertEquals(w.failed, ['secrets_missing']);
});

Deno.test('Brevo failing does not change the answer', async () => {
  const w = world(secrets, 500);
  const res = await call(w.deps, join('zz@example.com'));
  assertEquals(await res.json(), { ok: true });
  assert(w.logs.some((l) => l.includes('500')));
  assert(!w.logs.some((l) => l.includes('test-key')));
  assertEquals(w.sent, []);
  assertEquals(w.failed.length, 1);
  assert(w.failed[0].startsWith('brevo 500') && !w.failed[0].includes('test-key'));
});

Deno.test('no consent, bad address, rate limit: the error comes back, no mail', async () => {
  const w = world();
  assertEquals(await (await call(w.deps, { ...join('zz@example.com'), consent: undefined })).json(), { ok: false, error: 'consent_required' });
  assertEquals(await (await call(w.deps, join('not-an-address'))).json(), { ok: false, error: 'invalid_email' });
  assertEquals(await (await call(w.deps, { action: 'join', email: 42, consent: '2026-10-v1' })).json(), { ok: false, error: 'invalid_email' });
  w.deps.join = () => Promise.resolve({ ok: false, error: 'rate_limited' });
  assertEquals(await (await call(w.deps, join('zz2@example.com'))).json(), { ok: false, error: 'rate_limited' });
  assertEquals(w.mails.length, 0);
});

Deno.test('the honeypot gets a quiet ok and nothing is saved', async () => {
  const w = world();
  const res = await call(w.deps, { ...join('zz@example.com'), website: 'http://spam.example' });
  assertEquals(await res.json(), { ok: true });
  assertEquals(w.joins.length, 0);
  assertEquals(w.mails.length, 0);
});

Deno.test('only the site origins get in', async () => {
  const w = world();
  assertEquals((await call(w.deps, join('zz@example.com'), 'https://evil.example')).status, 403);
  assertEquals((await call(w.deps, join('zz@example.com'), null)).status, 403);
  const evil = await handleWaitlist(new Request('https://ref.supabase.co/functions/v1/waitlist', { method: 'OPTIONS', headers: { origin: 'https://evil.example' } }), w.deps);
  assertEquals(evil.status, 403);
  assertEquals(evil.headers.get('access-control-allow-origin'), null);
  const pre = await handleWaitlist(new Request('https://ref.supabase.co/functions/v1/waitlist', { method: 'OPTIONS', headers: { origin: 'https://oberta.pages.dev' } }), w.deps);
  assertEquals(pre.status, 204);
  assertEquals(pre.headers.get('access-control-allow-origin'), 'https://oberta.pages.dev');
  assertEquals((await call(w.deps, join('zz@example.com'), 'https://abc123.oberta.pages.dev')).status, 200);
  assertEquals(w.joins.length, 1);
});

Deno.test('confirm and unsubscribe by token, always ok', async () => {
  const w = world();
  await call(w.deps, join('zz@example.com'));
  const row = w.list.get('zz@example.com')!;
  assertEquals(await (await call(w.deps, { action: 'confirm', token: 'nonsense' })).json(), { ok: true });
  assert(!row.confirmed);
  assertEquals(await (await call(w.deps, { action: 'confirm', token: row.confirm.toUpperCase() })).json(), { ok: true });
  assert(row.confirmed);
  assertEquals(await (await call(w.deps, { action: 'unsubscribe', token: row.unsubscribe })).json(), { ok: true });
  assert(!w.list.has('zz@example.com'));
});

Deno.test('one-click unsubscribe from the mail client needs no origin', async () => {
  const w = world();
  await call(w.deps, join('zz@example.com'));
  const token = w.list.get('zz@example.com')!.unsubscribe;
  const res = await handleWaitlist(
    new Request(`https://ref.supabase.co/functions/v1/waitlist?unsubscribe=${token}`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: 'List-Unsubscribe=One-Click',
    }),
    w.deps,
  );
  assertEquals(res.status, 200);
  assert(!w.list.has('zz@example.com'));
});

Deno.test('the email escapes what it is given and has a plain-text twin', () => {
  const mail = confirmEmail('it', {
    confirmUrl: 'https://x.example/c?t=1&"<b>',
    unsubscribeUrl: 'https://x.example/u',
    privacyUrl: 'https://x.example/p',
    assetBase: 'https://x.example/email/',
  });
  assert(!mail.html.includes('"<b>'));
  assertStringIncludes(mail.html, 'https://x.example/email/oberta-neon.jpg');
  assertStringIncludes(mail.text, 'https://x.example/u');
  assert(!/<[a-z]/i.test(preview('it').text) && !/<[a-z]/i.test(preview('en').text));
});

Deno.test('the previews on the site match the templates', async () => {
  for (const lang of ['it', 'en'] as const) {
    const mail = preview(lang);
    assertEquals(await Deno.readTextFile(new URL(`conferma-${lang}.html`, previewDir)), mail.html, `run templates/preview.ts (${lang})`);
    assertEquals(await Deno.readTextFile(new URL(`conferma-${lang}.txt`, previewDir)), mail.text, `run templates/preview.ts (${lang})`);
  }
});
