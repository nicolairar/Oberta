-- Pre-launch cleanup of the live server: switch off everything that exists
-- only for the test period. NOT a migration (supabase/migrations applies
-- itself on every push to main; this folder never does): run it by hand,
-- once, on launch day, before the store build goes live. docs/app-store.md,
-- "Server e chiavi".
--
-- As written it is a DRY RUN: it makes the changes inside a transaction,
-- prints one row per check and rolls everything back. Read the rows, then
-- run it again with the last line changed from `rollback;` to `commit;`.
-- Every `ok` must be true after the commit (except the old password test
-- accounts, which go by hand: step 3 below).
--
--   SQL editor:      paste the whole file, Run.
--   Management API:  POST /v1/projects/<ref>/database/query with the file
--                    as "query" (SUPABASE_ACCESS_TOKEN from fastlane/.env,
--                    never printed; docs/release.md, section 12).
--
-- What it changes (all reversible by hand, see each step):
--   1. internal.config: deletes 'ranked_test_humans' (ranked tables filled
--      with bots down to that many people), 'friends_test_bots' and
--      'friends_test_size' (a friends room may start with two people and the
--      server deals bots into the empty seats). Every reader defaults to 0,
--      so a missing key means off. Undo: insert the row again.
--   2. public.rooms: clears the bot count of friends rooms still waiting in
--      the lobby (start_game sets it again from the config, now 0).
-- What it only checks (outside SQL, by hand):
--   - Email stays ON, passwordless (docs/release.md, "Entra con email"):
--     Management API GET /v1/projects/<ref>/config/auth shows
--     external_email_enabled true, mailer_autoconfirm false, mailer_otp_length
--     6, mailer_otp_exp 900, hook_send_email_enabled true with the auth-email
--     function as hook_send_email_uri.
--   - Apple and Google providers ON (the Apple key for token revocation is
--     already set on the `account` function).
--   - The old test accounts with a password (the hidden email + password
--     login of the test builds, gone now; listed at the end): delete them one
--     by one, with the template in step 3, or from Authentication > Users
--     (after `select public.forget_account(<id>)`). Players who sign in with
--     the email code have no password and are never listed. So is the
--     end-to-end probe e2e@oberta.invalid (an address nobody can own): delete
--     it the same way, or leave it, it never signed in.

begin;

create temp table _r (n serial, check_name text, ok boolean, detail text);

-- What is there now, before anything changes.
insert into _r (check_name, ok, detail)
select 'before: ' || key, null, value
from internal.config
where key in ('ranked_test_humans', 'friends_test_bots', 'friends_test_size')
order by key;

-- 1. Test-period switches off.
delete from internal.config
where key in ('ranked_test_humans', 'friends_test_bots', 'friends_test_size');

-- 2. No bots left in friends rooms that have not started.
update public.rooms set bots = 0
where status = 'lobby' and not ranked and not test_match and bots <> 0;

-- 3. Old test accounts with a password: NOT deleted here. Copy the ids
-- from the last rows, then (after the commit of this file) run, per id:
--
--   select public.forget_account('<id>');
--   delete from auth.users where id = '<id>';
--
-- forget_account is what the `account` Edge Function calls before it
-- deletes the auth user: the profile and every personal row cascade.

-- Checks.
insert into _r (check_name, ok, detail)
select 'ranked: no test minimum (no bots at ranked tables)',
  internal.config_int('ranked_test_humans', 0) = 0,
  (select value from internal.config where key = 'ranked_test_humans');

insert into _r (check_name, ok, detail)
select 'friends rooms: no test bots, four people needed',
  internal.config_int('friends_test_bots', 0) = 0,
  (select value from internal.config where key = 'friends_test_bots');

insert into _r (check_name, ok, detail)
select 'no friends room waiting with bots',
  not exists (select 1 from public.rooms where status = 'lobby' and not ranked and not test_match and bots <> 0),
  null;

insert into _r (check_name, ok, detail)
select 'nobody can set bots by hand',
  not has_function_privilege('authenticated', 'public.set_room_bots(uuid, integer)', 'execute')
  and not has_function_privilege('anon', 'public.set_room_bots(uuid, integer)', 'execute'),
  null;

-- Ranked test matches still open finish on their own; with the switch off
-- no new one starts. Listed so nobody is surprised.
insert into _r (check_name, ok, detail)
select 'no ranked test match still open',
  not exists (select 1 from public.rooms where test_match and status <> 'ended'),
  (select string_agg(code || ' ' || status, ', ') from public.rooms where test_match and status <> 'ended');

-- Nobody signs in with a password any more: an account that has one is
-- from the old test login.
insert into _r (check_name, ok, detail)
select 'no account with a password left (step 3, by hand)',
  not exists (select 1 from auth.users where coalesce(encrypted_password, '') <> ''),
  (select count(*)::text || ' account(s)' from auth.users where coalesce(encrypted_password, '') <> '');

insert into _r (check_name, ok, detail)
select 'password account: ' || coalesce(p.handle, '(no handle)'), false,
  u.id::text || ' ' || coalesce(u.email, '') || ' last sign-in ' || coalesce(u.last_sign_in_at::text, 'never')
from auth.users u
left join public.profiles p on p.id = u.id
where coalesce(u.encrypted_password, '') <> ''
order by u.created_at;

-- For the record: the minimum builds (docs/release.md, section 9). Raise
-- them only when the new build can really be downloaded.
insert into _r (check_name, ok, detail)
select 'info: ' || key, null, value
from internal.config
where key like 'min_build_%'
order by key;

select n, check_name, ok, detail from _r order by n;

rollback;
