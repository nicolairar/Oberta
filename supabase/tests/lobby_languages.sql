-- Lobby languages (20261123090000_lobby_languages): rooms, ranked queues,
-- ratings and the leaderboard take any ISO 639-1 code and nothing else, and
-- a player can still only change their own profile. Runs on the real
-- database and changes nothing:
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

insert into auth.users (id) values
  ('a3000000-0000-4000-8000-00000000000a'),
  ('b3000000-0000-4000-8000-00000000000b');
insert into public.profiles (id) values
  ('a3000000-0000-4000-8000-00000000000a'),
  ('b3000000-0000-4000-8000-00000000000b')
on conflict (id) do nothing;
update public.profiles set handle = 'zz_aiko_ll' where id = 'a3000000-0000-4000-8000-00000000000a';
update public.profiles set handle = 'zz_bruno_ll' where id = 'b3000000-0000-4000-8000-00000000000b';

insert into _r (check_name, ok, detail)
select 'the list has every ISO 639-1 code and only those', cardinality(internal.lobby_languages()) = 183
  and internal.is_lobby_language('ja') and internal.is_lobby_language('ar') and internal.is_lobby_language('it')
  and not internal.is_lobby_language('xx') and not internal.is_lobby_language('EN')
  and not internal.is_lobby_language('pt-BR') and not internal.is_lobby_language(null),
  cardinality(internal.lobby_languages())::text;

insert into _r (check_name, ok, detail)
select 'each language column has the new check, and only it', count(*) = 5, string_agg(c.conname, ', ')
from pg_constraint c join pg_class r on r.oid = c.conrelid
where c.contype = 'c' and pg_get_constraintdef(c.oid) like '%language%'
  and r.relname in ('profiles', 'rooms', 'ratings', 'ranked_queue', 'leaderboard_cache');

insert into _r (check_name, ok, detail)
select 'the language helpers stay internal',
  not has_function_privilege('authenticated', 'internal.is_lobby_language(text)', 'EXECUTE')
  and not has_function_privilege('anon', 'internal.lobby_languages()', 'EXECUTE'), null;

-- ---- Aiko, a Japanese phone, through the API.
set local role authenticated;
set local request.jwt.claims to '{"sub": "a3000000-0000-4000-8000-00000000000a", "role": "authenticated"}';

insert into _r (check_name, ok, detail)
select 'aiko sets her lobby to Japanese',
  pg_temp.fails($q$update public.profiles set language = 'ja' where id = 'a3000000-0000-4000-8000-00000000000a'$q$) is null, null;
insert into _r (check_name, ok, detail)
select 'a made-up language is refused',
  pg_temp.fails($q$update public.profiles set language = 'xx' where id = 'a3000000-0000-4000-8000-00000000000a'$q$) is not null, null;
insert into _r (check_name, ok, detail)
select 'upper case and regions are refused',
  pg_temp.fails($q$update public.profiles set language = 'JA' where id = 'a3000000-0000-4000-8000-00000000000a'$q$) is not null
  and pg_temp.fails($q$update public.profiles set language = 'pt-BR' where id = 'a3000000-0000-4000-8000-00000000000a'$q$) is not null, null;
update public.profiles set language = 'it' where id = 'b3000000-0000-4000-8000-00000000000b';
insert into _r (check_name, ok, detail)
select 'aiko cannot change bruno''s lobby', (select language from public.profiles
  where id = 'b3000000-0000-4000-8000-00000000000b') = 'it', null;

insert into _r (check_name, ok, detail)
select 'a friends room opens in Japanese', pg_temp.fails($q$select public.create_room('ja')$q$) is null,
  pg_temp.fails($q$select public.create_room('ja')$q$);
insert into _r (check_name, ok, detail)
select 'the Japanese room says Japanese', exists (select 1 from public.rooms
  where host = 'a3000000-0000-4000-8000-00000000000a' and language = 'ja'), null;
insert into _r (check_name, ok, detail)
select 'a room in a made-up language is refused',
  coalesce(pg_temp.fails($q$select public.create_room('zz')$q$), '') like '%invalid_language%', null;

insert into _r (check_name, ok, detail)
select 'the ranked queue takes Japanese (whatever else it asks)',
  coalesce(pg_temp.fails($q$select public.enqueue_ranked('ja')$q$), '') not like '%invalid_language%',
  pg_temp.fails($q$select public.enqueue_ranked('ja')$q$);
insert into _r (check_name, ok, detail)
select 'the ranked queue refuses a made-up language',
  coalesce(pg_temp.fails($q$select public.enqueue_ranked('zz')$q$), '') like '%invalid_language%', null;

insert into _r (check_name, ok, detail)
select 'the Japanese leaderboard opens, empty or not', pg_temp.fails($q$select public.leaderboard('ja')$q$) is null,
  pg_temp.fails($q$select public.leaderboard('ja')$q$);
insert into _r (check_name, ok, detail)
select 'a made-up leaderboard is refused', pg_temp.fails($q$select public.leaderboard('zz')$q$) is not null, null;

insert into _r (check_name, ok, detail)
select 'the counts give the queue as an object per language',
  jsonb_typeof(public.online_counts() -> 'queued') = 'object', (public.online_counts() -> 'queued')::text;

reset role;
select n, check_name, ok, detail from _r order by n;
rollback;
