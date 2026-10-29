-- The launch waitlist ("Avvisami quando esce" on the landing page), built for
-- the GDPR and the Garante's rules on marketing email:
--
-- * The emails live in the internal schema: nobody reaches them through the
--   API. The site signs up through the `waitlist` Edge Function (which also
--   sends the confirmation email); the anon key can only call three functions:
--     public.join_waitlist(email, lang, consent_version) -> {"ok": true} | {"ok": false, "error": ...}
--     public.confirm_waitlist(token)                     -> {"ok": true}, always
--     public.unsubscribe_waitlist(token)                 -> {"ok": true}, always
-- * Proof of consent: every row keeps the version id of the consent text the
--   visitor ticked (internal.waitlist_consents holds the exact wording) and
--   the time. No IP is kept with the row (data minimisation).
-- * Double opt-in: a row starts with confirmed = false. The first email ever
--   sent is the confirmation link (conferma.html?t=<confirm_token>); only
--   confirmed addresses get the launch mailing (docs/release.md).
-- * join_waitlist never says whether an address was already on the list, and
--   is rate limited per client and overall. The per-client counter uses a
--   secret-salted hash of the IP, kept at most one hour.
-- * Unsubscribing deletes the row.
-- Idempotent.

create schema if not exists internal;

-- The consent texts, word for word, by version. A new wording gets a new id
-- here and on the site; old ids stay so old consents can still be proven.
create table if not exists internal.waitlist_consents (
  version text primary key,
  text_it text not null,
  shown_from timestamptz not null default now()
);
revoke all on table internal.waitlist_consents from public, anon, authenticated;
alter table internal.waitlist_consents enable row level security;
insert into internal.waitlist_consents (version, text_it) values
  ('2026-10-v1', 'Ho almeno 14 anni e voglio ricevere una mail quando esce Obertà. Niente spam, cancellazione in un clic. Informativa privacy: https://charliemobile.dev/oberta/privacy.html#lista')
on conflict (version) do nothing;

create table if not exists internal.waitlist (
  id bigint generated always as identity primary key,
  email text not null unique check (email = lower(email) and length(email) between 6 and 254),
  lang text not null default 'it',
  source text not null default 'site',
  created_at timestamptz not null default now(),
  consent_at timestamptz not null default now(),
  consent_version text not null references internal.waitlist_consents (version),
  confirmed boolean not null default false,
  confirmed_at timestamptz,
  -- When the confirmation email went out (set by the Edge Function); null
  -- while Brevo was not configured yet.
  confirm_sent_at timestamptz,
  confirm_token uuid not null unique default gen_random_uuid(),
  unsubscribe_token uuid not null unique default gen_random_uuid()
);
revoke all on table internal.waitlist from public, anon, authenticated;
alter table internal.waitlist enable row level security;

-- Sign-up counters, one row per client and minute. The client is a hash of
-- the IP with a secret salt; rows older than an hour are swept on every call.
create table if not exists internal.waitlist_hits (
  bucket text not null,
  minute timestamptz not null,
  hits integer not null default 0,
  primary key (bucket, minute)
);
revoke all on table internal.waitlist_hits from public, anon, authenticated;
alter table internal.waitlist_hits enable row level security;

insert into internal.config (key, value)
values ('waitlist_salt', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (key) do nothing;

-- The sign-up itself, for the two doors: the public RPC below (anon, IP from
-- the request headers) and the `waitlist` Edge Function (database
-- connection, IP from its own request), which alone gets the tokens back to
-- send the confirmation email. Returns
--   {"ok": true, "new": bool, "lang", "confirm_token", "unsubscribe_token"} (tokens only when new)
--   {"ok": false, "error": "consent_required" | "invalid_email" | "rate_limited"}
create or replace function internal.waitlist_join(email text, lang text, consent_version text, ip text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  addr text := lower(btrim(coalesce(waitlist_join.email, '')));
  code text := lower(btrim(coalesce(waitlist_join.lang, '')));
  consent text := btrim(coalesce(waitlist_join.consent_version, ''));
  client text;
  now_minute timestamptz := date_trunc('minute', now());
  client_hits integer;
  client_hour integer;
  all_hits integer;
  added internal.waitlist;
begin
  -- No ticked box (or an unknown wording), no sign-up.
  if not exists (select 1 from internal.waitlist_consents c where c.version = consent) then
    return jsonb_build_object('ok', false, 'error', 'consent_required');
  end if;
  -- Shape: one @, a plain local part, a dotted domain with a 2+ letter end.
  if length(addr) > 254
    or addr !~ '^[a-z0-9._%+''-]{1,64}@[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]{2,63}$'
    or addr ~ '\.\.' or addr ~ '^\.' or addr ~ '\.@' then
    return jsonb_build_object('ok', false, 'error', 'invalid_email');
  end if;
  if not internal.is_lobby_language(code) then
    code := 'it';
  end if;

  -- Who is asking: the client address, hashed with the secret salt.
  client := md5(coalesce((select c.value from internal.config c where c.key = 'waitlist_salt'), '')
    || ':' || coalesce(nullif(btrim(split_part(coalesce(waitlist_join.ip, ''), ',', 1)), ''), 'unknown'));

  delete from internal.waitlist_hits where minute < now() - interval '1 hour';

  select coalesce(sum(h.hits) filter (where h.minute = now_minute), 0),
         coalesce(sum(h.hits), 0)
    into client_hits, client_hour
    from internal.waitlist_hits h where h.bucket = client;
  select coalesce(sum(h.hits), 0) into all_hits
    from internal.waitlist_hits h where h.minute = now_minute;
  -- 5 a minute and 20 an hour from one client, 120 a minute overall.
  if client_hits >= 5 or client_hour >= 20 or all_hits >= 120 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  insert into internal.waitlist_hits as h (bucket, minute, hits)
  values (client, now_minute, 1)
  on conflict (bucket, minute) do update set hits = h.hits + 1;

  -- Already there: nothing changes (the first consent stays the proof).
  insert into internal.waitlist (email, lang, source, consent_at, consent_version)
  values (addr, code, 'site', now(), consent)
  on conflict do nothing
  returning * into added;

  if added.id is null then
    return jsonb_build_object('ok', true, 'new', false);
  end if;
  return jsonb_build_object('ok', true, 'new', true, 'lang', added.lang,
    'confirm_token', added.confirm_token, 'unsubscribe_token', added.unsubscribe_token);
end;
$$;
revoke all on function internal.waitlist_join(text, text, text, text) from public, anon, authenticated;

-- The public door: same rules, and the answer never says more than ok.
create or replace function public.join_waitlist(email text, lang text default 'it', consent_version text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  headers json;
  result jsonb;
begin
  begin
    headers := nullif(current_setting('request.headers', true), '')::json;
  exception when others then
    headers := null;
  end;
  result := internal.waitlist_join(join_waitlist.email, join_waitlist.lang, join_waitlist.consent_version,
    coalesce(headers ->> 'cf-connecting-ip', headers ->> 'x-forwarded-for', headers ->> 'x-real-ip'));
  if (result ->> 'ok')::boolean then
    return jsonb_build_object('ok', true);
  end if;
  return result;
end;
$$;
revoke all on function public.join_waitlist(text, text, text) from public;
grant execute on function public.join_waitlist(text, text, text) to anon, authenticated;

create or replace function public.confirm_waitlist(token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  t text := lower(btrim(coalesce(confirm_waitlist.token, '')));
begin
  if t ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    update internal.waitlist w set confirmed = true, confirmed_at = coalesce(w.confirmed_at, now())
    where w.confirm_token = t::uuid;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.confirm_waitlist(text) from public;
grant execute on function public.confirm_waitlist(text) to anon, authenticated;

create or replace function public.unsubscribe_waitlist(token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  t text := lower(btrim(coalesce(unsubscribe_waitlist.token, '')));
begin
  if t ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    delete from internal.waitlist w where w.unsubscribe_token = t::uuid;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.unsubscribe_waitlist(text) from public;
grant execute on function public.unsubscribe_waitlist(text) to anon, authenticated;
