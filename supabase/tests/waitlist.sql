-- Launch waitlist (20261125090000_waitlist): the site (anon) can sign up and
-- confirm and unsubscribe, never read the list, never learn whether an address was
-- already there, and cannot flood it. Runs on the real database and changes
-- nothing:
--
--   begin; <this file>; rollback;    (the file ends with its own rollback)
--
-- through the SQL editor or the Management API (docs/sicurezza.md). To try
-- the migration before it ships, paste it right after the `begin`.
-- One row per check; every `ok` must be true.
begin;

create temp table _r (n serial, check_name text, ok boolean, detail text);
grant all on _r to authenticated, anon;
grant all on sequence _r_n_seq to authenticated, anon;

create function pg_temp.fails(q text) returns text language plpgsql as $f$
begin
  execute q;
  return null;
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$f$;

insert into _r (check_name, ok, detail)
select 'the list and the counters are closed to the API',
  not has_table_privilege('anon', 'internal.waitlist', 'SELECT')
  and not has_table_privilege('anon', 'internal.waitlist', 'INSERT')
  and not has_table_privilege('anon', 'internal.waitlist', 'UPDATE')
  and not has_table_privilege('authenticated', 'internal.waitlist', 'SELECT')
  and not has_table_privilege('anon', 'internal.waitlist_hits', 'SELECT')
  and not has_table_privilege('anon', 'internal.waitlist_hits', 'INSERT')
  and not has_table_privilege('anon', 'internal.waitlist_consents', 'SELECT'), null;

insert into _r (check_name, ok, detail)
select 'the salt is secret and set', length(value) >= 32 and not has_table_privilege('anon', 'internal.config', 'SELECT'), null
from internal.config where key = 'waitlist_salt';

insert into _r (check_name, ok, detail)
select 'only the three functions are open to anon',
  has_function_privilege('anon', 'public.join_waitlist(text, text, text)', 'EXECUTE')
  and has_function_privilege('anon', 'public.confirm_waitlist(text)', 'EXECUTE')
  and has_function_privilege('anon', 'public.unsubscribe_waitlist(text)', 'EXECUTE'), null;

insert into _r (check_name, ok, detail)
select 'the sign-up core (with the tokens) is not open to the API',
  not has_function_privilege('anon', 'internal.waitlist_join(text, text, text, text)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'internal.waitlist_join(text, text, text, text)', 'EXECUTE'), null;

-- ---- The Edge Function's door (database connection): tokens only when new.
insert into _r (check_name, ok, detail)
select 'a new address gets its tokens back, once',
  a ->> 'new' = 'true' and a ->> 'confirm_token' is not null and a ->> 'unsubscribe_token' is not null and a ->> 'lang' = 'en'
  and b = '{"ok": true, "new": false}'::jsonb, b::text
from (select internal.waitlist_join('zz_edge@example.com', 'en', '2026-10-v1', '192.0.2.1') a) x,
     lateral (select internal.waitlist_join('ZZ_Edge@example.com', 'it', '2026-10-v1', '192.0.2.1') b where x.a is not null) y;

-- ---- A visitor of the landing page, through the API.
set local role anon;
set local request.headers to '{"x-forwarded-for": "203.0.113.7, 10.0.0.1"}';

insert into _r (check_name, ok, detail)
select 'anon cannot read the list',
  pg_temp.fails('select count(*) from internal.waitlist') is not null,
  pg_temp.fails('select count(*) from internal.waitlist');

insert into _r (check_name, ok, detail)
select 'anon cannot write the list directly',
  pg_temp.fails($q$insert into internal.waitlist (email) values ('zz_direct@example.com')$q$) is not null, null;

insert into _r (check_name, ok, detail)
select 'no consent, no sign-up (and it does not count)',
  public.join_waitlist('zz_noconsent@example.com', 'it') ->> 'error' = 'consent_required'
  and public.join_waitlist('zz_noconsent@example.com', 'it', 'made-up') ->> 'error' = 'consent_required'
  and public.join_waitlist('zz_noconsent@example.com', 'it', null) ->> 'error' = 'consent_required', null;

insert into _r (check_name, ok, detail)
select 'a valid address joins', (public.join_waitlist('  ZZ_Aiko.Test+site@Example.COM ', 'ja', '2026-10-v1') ->> 'ok')::boolean, null;

insert into _r (check_name, ok, detail)
select 'the same address again is fine and says the same',
  public.join_waitlist('zz_aiko.test+site@example.com', 'it', '2026-10-v1') = '{"ok": true}'::jsonb, null;

insert into _r (check_name, ok, detail)
select 'bad addresses are refused', bool_and(public.join_waitlist(e, 'it', '2026-10-v1') ->> 'error' = 'invalid_email'), string_agg(e, ' ')
from unnest(array['', 'plain', 'a@b', 'zz@@example.com', 'zz@example', 'zz..x@example.com', '.zz@example.com',
  'zz@-example.com', 'zz @example.com', '<script>@example.com', repeat('a', 65) || '@example.com',
  'zz@' || repeat('a', 250) || '.com']) e;

insert into _r (check_name, ok, detail)
select 'a null address is refused', public.join_waitlist(null, null, '2026-10-v1') ->> 'error' = 'invalid_email', null;

-- Two valid sign-ups so far from this client: three more pass, then it stops.
insert into _r (check_name, ok, detail)
select 'five sign-ups a minute from one client, then rate_limited',
  public.join_waitlist('zz_b1@example.com', 'it', '2026-10-v1') ->> 'ok' = 'true'
  and public.join_waitlist('zz_b2@example.com', 'it', '2026-10-v1') ->> 'ok' = 'true'
  and public.join_waitlist('zz_b3@example.com', 'it', '2026-10-v1') ->> 'ok' = 'true'
  and public.join_waitlist('zz_b4@example.com', 'it', '2026-10-v1') ->> 'error' = 'rate_limited'
  and public.join_waitlist('zz_aiko.test+site@example.com', 'it', '2026-10-v1') ->> 'error' = 'rate_limited', null;

set local request.headers to '{"x-forwarded-for": "198.51.100.9"}';
insert into _r (check_name, ok, detail)
select 'another client is not blocked', public.join_waitlist('zz_c1@example.com', 'xx', '2026-10-v1') ->> 'ok' = 'true', null;

reset role;

insert into _r (check_name, ok, detail)
select 'the address is stored once, normalised, with consent time and a token',
  count(*) = 1 and min(lang) = 'ja' and min(source) = 'site' and bool_and(consent_at is not null)
  and min(consent_version) = '2026-10-v1' and bool_and(not confirmed) and bool_and(confirmed_at is null)
  and bool_and(unsubscribe_token is not null) and bool_and(confirm_token <> unsubscribe_token) and bool_and(confirm_sent_at is null),
  count(*)::text
from internal.waitlist where email = 'zz_aiko.test+site@example.com';

insert into _r (check_name, ok, detail)
select 'no address without consent', not exists (select 1 from internal.waitlist where email = 'zz_noconsent@example.com'), null;

insert into _r (check_name, ok, detail)
select 'the consent wording is kept with its version', text_it like 'Ho almeno 14 anni%', version
from internal.waitlist_consents where version = '2026-10-v1';

insert into _r (check_name, ok, detail)
select 'an unknown language falls back to Italian', lang = 'it', lang
from internal.waitlist where email = 'zz_c1@example.com';

insert into _r (check_name, ok, detail)
select 'the rate-limited address was not added', not exists (select 1 from internal.waitlist where email = 'zz_b4@example.com'), null;

insert into _r (check_name, ok, detail)
select 'the counters keep no clear IP', not exists (select 1 from internal.waitlist_hits where bucket like '%203.0.113%'), null;

create temp table _tok as select unsubscribe_token::text as t, confirm_token::text as c from internal.waitlist where email = 'zz_b1@example.com';
grant select on _tok to anon;

set local role anon;
insert into _r (check_name, ok, detail)
select 'unsubscribing with a wrong or broken token says ok and removes nothing',
  public.unsubscribe_waitlist(gen_random_uuid()::text) = '{"ok": true}'::jsonb
  and public.unsubscribe_waitlist('nonsense') = '{"ok": true}'::jsonb
  and public.unsubscribe_waitlist(null) = '{"ok": true}'::jsonb, null;
insert into _r (check_name, ok, detail)
select 'confirming with a wrong token or the unsubscribe token changes nothing',
  public.confirm_waitlist(gen_random_uuid()::text) = '{"ok": true}'::jsonb
  and public.confirm_waitlist((select t from _tok)) = '{"ok": true}'::jsonb
  and public.confirm_waitlist('x') = '{"ok": true}'::jsonb, null;
reset role;
insert into _r (check_name, ok, detail)
select 'still unconfirmed', not confirmed, null from internal.waitlist where email = 'zz_b1@example.com';
set local role anon;
insert into _r (check_name, ok, detail)
select 'confirming with the confirm token says ok', public.confirm_waitlist((select c from _tok)) = '{"ok": true}'::jsonb, null;
reset role;
insert into _r (check_name, ok, detail)
select 'now confirmed, with the time', confirmed and confirmed_at is not null, null from internal.waitlist where email = 'zz_b1@example.com';
set local role anon;

insert into _r (check_name, ok, detail)
select 'unsubscribing with the token says ok', public.unsubscribe_waitlist((select t from _tok)) = '{"ok": true}'::jsonb, null;
reset role;

insert into _r (check_name, ok, detail)
select 'the unsubscribed address is gone, the others stay',
  not exists (select 1 from internal.waitlist where email = 'zz_b1@example.com')
  and exists (select 1 from internal.waitlist where email = 'zz_b2@example.com'), null;

select n, check_name, ok, detail from _r order by n;

rollback;
