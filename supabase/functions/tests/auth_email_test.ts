// The Send Email Hook (auth-email) with a fake Brevo: only a call signed with
// the hook secret gets through, every mail has the code and, only where the
// app can open it, the magic link; the language follows the account; Brevo
// failing is an error Supabase Auth can show.
//
//   deno test -A supabase/functions/tests/auth_email_test.ts
import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { Webhook } from 'npm:standardwebhooks@1.0.0';
import { brevoUrl, handleAuthEmail, type HookDeps, plan, sign, verified } from '../auth-email/handler.ts';
import { codeEmail } from '../auth-email/templates/code.ts';
import { preview, previewDir, previews } from '../auth-email/templates/preview.ts';

const secret = 'v1,whsec_' + btoa('0123456789abcdef0123456789abcdef');
const now = 1_800_000_000;
const env: Record<string, string> = {
  SEND_EMAIL_HOOK_SECRET: secret,
  BREVO_API_KEY: 'test-key',
  BREVO_SENDER_EMAIL: 'oberta@charliemobile.dev',
  BREVO_SENDER_NAME: 'Obertà',
  SUPABASE_URL: 'https://ref.supabase.co',
};

function world(vars: Record<string, string> = env, brevoStatus = 201) {
  const mails: { url: string; body: Record<string, unknown> }[] = [];
  const logs: string[] = [];
  const deps: HookDeps = {
    env: (name) => vars[name],
    fetch: ((input: string | URL | Request, init?: RequestInit) => {
      mails.push({ url: String(input), body: JSON.parse(String(init?.body)) });
      const answer = brevoStatus < 300 ? '{"messageId":"x"}' : `{"message":"bad key ${vars.BREVO_API_KEY}"}`;
      return Promise.resolve(new Response(answer, { status: brevoStatus }));
    }) as typeof fetch,
    log: (...args) => logs.push(args.join(' ')),
    now: () => now,
  };
  return { deps, mails, logs };
}

const payload = (action: string, extra: Record<string, unknown> = {}, user: Record<string, unknown> = {}) => ({
  user: { id: 'u1', email: 'anna@example.com', user_metadata: {}, ...user },
  email_data: {
    token: '428913',
    token_hash: 'pkce_abc123',
    redirect_to: 'oberta://login-callback',
    email_action_type: action,
    site_url: 'https://ref.supabase.co/auth/v1',
    token_new: '',
    token_hash_new: '',
    ...extra,
  },
});

async function call(deps: HookDeps, body: unknown, opts: { secret?: string; at?: number } = {}) {
  const text = JSON.stringify(body);
  const timestamp = String(opts.at ?? now);
  const signature = await sign(opts.secret ?? secret, 'msg_1', timestamp, text);
  return handleAuthEmail(
    new Request('https://ref.supabase.co/functions/v1/auth-email', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'webhook-id': 'msg_1',
        'webhook-timestamp': timestamp,
        'webhook-signature': `v1,${signature}`,
      },
      body: text,
    }),
    deps,
  );
}

Deno.test('a signed sign-in sends one mail with the code and the magic link', async () => {
  const w = world();
  const res = await call(w.deps, payload('magiclink', {}, { user_metadata: { lang: 'it' } }));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {});
  assertEquals(w.mails.length, 1);
  const mail = w.mails[0];
  assertEquals(mail.url, brevoUrl);
  assertEquals(mail.body.to, [{ email: 'anna@example.com' }]);
  assertEquals(mail.body.subject, 'Il tuo codice per Obertà: 428913');
  assertEquals(mail.body.replyTo, { email: 'oberta@charliemobile.dev' });
  const html = String(mail.body.htmlContent);
  assertStringIncludes(html, '428913');
  assertStringIncludes(
    html,
    'https://ref.supabase.co/auth/v1/verify?token=pkce_abc123&amp;type=magiclink&amp;redirect_to=oberta%3A%2F%2Flogin-callback',
  );
  assertStringIncludes(html, 'https://ref.supabase.co/functions/v1/auth-email/img/oberta-neon.jpg');
  assertStringIncludes(String(mail.body.textContent), 'Il tuo codice: 428913');
  assertEquals(mail.body.headers, undefined, 'a real mail, not the sandbox');
});

Deno.test('a wrong secret, a stale or missing signature: 401 and nothing sent', async () => {
  const w = world();
  assertEquals((await call(w.deps, payload('magiclink'), { secret: 'v1,whsec_' + btoa('another-secret-another-secret!!') })).status, 401);
  assertEquals((await call(w.deps, payload('magiclink'), { at: now - 3600 })).status, 401);
  const bare = await handleAuthEmail(
    new Request('https://ref.supabase.co/functions/v1/auth-email', { method: 'POST', body: JSON.stringify(payload('magiclink')) }),
    w.deps,
  );
  assertEquals(bare.status, 401);
  assertEquals(w.mails.length, 0);
});

Deno.test('the signature is the standard-webhooks one Supabase Auth uses', async () => {
  const body = JSON.stringify(payload('magiclink'));
  const at = new Date(now * 1000);
  const header = new Webhook(secret.replace('v1,whsec_', '')).sign('msg_2', at, body);
  const headers = new Headers({ 'webhook-id': 'msg_2', 'webhook-timestamp': String(now), 'webhook-signature': header });
  assert(await verified(secret, headers, body, now));
  assert(!(await verified(secret, headers, body + ' ', now)), 'a changed body is refused');
});

Deno.test('on the computer (no oberta:// redirect) the mail has only the code', async () => {
  const w = world();
  await call(w.deps, payload('magiclink', { redirect_to: 'http://localhost:3000' }));
  const html = String(w.mails[0].body.htmlContent);
  assertStringIncludes(html, '428913');
  assert(!html.includes('/auth/v1/verify'), 'no button');
  assertStringIncludes(html, 'Il codice vale 15 minuti');
});

Deno.test('every kind: first sign-in, recovery, reauthentication, email change', () => {
  const read = (body: ReturnType<typeof payload>) => plan(body.user, body.email_data, (n) => env[n]);
  const [signup] = read(payload('signup'));
  assertEquals(signup.kind, 'signup');
  assertStringIncludes(signup.link!, 'type=signup');
  const [recovery] = read(payload('recovery'));
  assertEquals(recovery.kind, 'signin');
  assertStringIncludes(recovery.link!, 'type=recovery');
  const [reauth] = read(payload('reauthentication', { token_hash: '' }));
  assertEquals(reauth.kind, 'reauthentication');
  assertEquals(reauth.link, null);
  const change = read(payload('email_change', {}, { new_email: 'nuova@example.com' }));
  assertEquals(change.map((m) => m.to), ['nuova@example.com']);
  assertStringIncludes(change[0].link!, 'type=email_change');
  const secure = read(payload('email_change', { token_new: '135790', token_hash_new: 'pkce_new' }, { new_email: 'nuova@example.com' }));
  assertEquals(secure.map((m) => [m.to, m.code]), [['nuova@example.com', '428913'], ['anna@example.com', '135790']]);
  assertEquals(read(payload('magiclink', { token: '' })), [], 'no code, no mail');
});

Deno.test('the language follows the account; unknown means Italian and English together', async () => {
  const w = world();
  await call(w.deps, payload('magiclink', {}, { user_metadata: { lang: 'en' } }));
  await call(w.deps, payload('magiclink', {}, { user_metadata: { lang: 'de' } }));
  await call(w.deps, payload('magiclink'));
  assertEquals(w.mails.map((m) => m.body.subject), [
    'Your Obertà code: 428913',
    'Your Obertà code: 428913',
    'Il tuo codice per Obertà: 428913 · Your Obertà code: 428913',
  ]);
  assertStringIncludes(String(w.mails[2].body.htmlContent), 'privacy-en.html');
});

Deno.test('Brevo failing or missing secrets: an error Supabase Auth reads, no key in it', async () => {
  const failing = world(env, 401);
  const res = await call(failing.deps, payload('magiclink'));
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.http_code, 500);
  assert(!JSON.stringify(body).includes('test-key'));
  const { BREVO_API_KEY: _, ...noKey } = env;
  assertEquals((await call(world(noKey).deps, payload('magiclink'))).status, 500);
  const { SEND_EMAIL_HOOK_SECRET: __, ...noSecret } = env;
  assertEquals((await call(world(noSecret).deps, payload('magiclink'))).status, 500);
});

Deno.test('an address under .invalid goes to the Brevo sandbox', async () => {
  const w = world();
  assertEquals((await call(w.deps, payload('magiclink', {}, { email: 'prova@oberta.invalid' }))).status, 200);
  assertEquals(w.mails[0].body.headers, { 'X-Sib-Sandbox': 'drop' });
});

Deno.test('the function serves the images, the same as the site has', async () => {
  for (const name of ['oberta-neon.jpg', 'brick.jpg', 'deco-tl.png', 'role-detective.png']) {
    const res = await handleAuthEmail(new Request(`https://ref.supabase.co/functions/v1/auth-email/img/${name}`), world().deps);
    assertEquals(res.status, 200, name);
    assertEquals(new Uint8Array(await res.arrayBuffer()), await Deno.readFile(new URL(name, previewDir)), name);
  }
  assertEquals((await handleAuthEmail(new Request('https://ref.supabase.co/functions/v1/auth-email/img/x.png'), world().deps)).status, 404);
  assertEquals((await handleAuthEmail(new Request('https://ref.supabase.co/functions/v1/auth-email'), world().deps)).status, 405);
});

Deno.test('the mail escapes what it is given, keeps only digits, and has a plain-text twin', () => {
  const mail = codeEmail({
    kind: 'signin',
    lang: 'it',
    code: '12 34<b>56',
    link: 'https://x.example/v?a=1&"<b>',
    minutes: 15,
    assetBase: 'https://x.example/img/',
    privacyUrl: { it: 'https://x.example/p', en: 'https://x.example/pe' },
  });
  assert(!mail.html.includes('"<b>'));
  assertStringIncludes(mail.html, '>123456<');
  assertStringIncludes(mail.html, 'https://x.example/img/brick.jpg');
  for (const { lang, link } of previews) assert(!/<[a-z]/i.test(preview(lang, link).text));
});

Deno.test('the previews on the site match the template', async () => {
  for (const { name, lang, link } of previews) {
    const mail = preview(lang, link);
    assertEquals(await Deno.readTextFile(new URL(`${name}.html`, previewDir)), mail.html, `run templates/preview.ts (${name})`);
    assertEquals(await Deno.readTextFile(new URL(`${name}.txt`, previewDir)), mail.text, `run templates/preview.ts (${name})`);
  }
});
