-- Anti-cheat for the roles collection (20261122090000_role_collection):
-- a player calling the API directly can neither read someone else's cards
-- nor unlock one. Runs on the real database and changes nothing:
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
  ('a1000000-0000-4000-8000-00000000000a'),
  ('b1000000-0000-4000-8000-00000000000b');
insert into public.profiles (id) values
  ('a1000000-0000-4000-8000-00000000000a'),
  ('b1000000-0000-4000-8000-00000000000b')
on conflict (id) do nothing;
update public.profiles set handle = 'zz_anna_rc' where id = 'a1000000-0000-4000-8000-00000000000a';
update public.profiles set handle = 'zz_bruno_rc' where id = 'b1000000-0000-4000-8000-00000000000b';

insert into public.rooms (id, code, host, language, status, max_players)
values ('e1000000-0000-4000-8000-00000000000e', 'ZZZZ33', 'a1000000-0000-4000-8000-00000000000a', 'it', 'playing', 12);
insert into public.game_public (room_id, host, version, view, game_id, chat_mode)
values ('e1000000-0000-4000-8000-00000000000e', 'a1000000-0000-4000-8000-00000000000a', 1, null,
        'f1000000-0000-4000-8000-00000000000f', 'day');
insert into public.game_seats (room_id, seat, profile_id, name, alive, family) values
  ('e1000000-0000-4000-8000-00000000000e', 's1', 'a1000000-0000-4000-8000-00000000000a', 'anna', true, true),
  ('e1000000-0000-4000-8000-00000000000e', 's2', 'b1000000-0000-4000-8000-00000000000b', 'bruno', true, false);

-- The game server settles: Anna wins as the Godfather, Bruno loses as a
-- citizen and an idle third game of Bruno's never counts.
select internal.record_match('e1000000-0000-4000-8000-00000000000e', 'mafia', $j${"players": [
  {"profile": "a1000000-0000-4000-8000-00000000000a", "seat": "s1", "role": "padrino", "team": "mafia",
   "won": true, "survived": true, "abandoned": false, "level": 1, "xp": 0, "levelBefore": 1, "xpGained": 0, "coins": 0,
   "tally": {"games": 1, "wins": 1, "role_win:padrino": 1}, "missions": [],
   "unlocked": [{"id": "role_padrino", "xp": 0, "coins": 0}]},
  {"profile": "b1000000-0000-4000-8000-00000000000b", "seat": "s2", "role": "cittadino", "team": "citizens",
   "won": false, "survived": true, "abandoned": false, "level": 1, "xp": 0, "levelBefore": 1, "xpGained": 0, "coins": 0,
   "tally": {"games": 1}, "missions": [], "unlocked": []}
]}$j$::jsonb);

insert into _r (check_name, ok, detail)
select 'record_match wrote both cards', count(*) = 2, count(*)::text
from internal.role_stats where profile_id in ('a1000000-0000-4000-8000-00000000000a', 'b1000000-0000-4000-8000-00000000000b');
insert into _r (check_name, ok, detail)
select 'the card achievement arrived with the win', count(*) = 1, null
from internal.player_achievements
where profile_id = 'a1000000-0000-4000-8000-00000000000a' and achievement_id = 'role_padrino';

-- ---- Bruno, calling the API by hand.
set local role authenticated;
set local request.jwt.claims to '{"sub": "b1000000-0000-4000-8000-00000000000b", "role": "authenticated"}';

insert into _r (check_name, ok, detail)
select 'bruno reads only his own card',
  (select string_agg(x ->> 'role', ',') from jsonb_array_elements(public.my_role_stats()) x) = 'cittadino', null;
insert into _r (check_name, ok, detail)
select 'bruno''s citizen card is still locked',
  (select (x ->> 'wins')::int from jsonb_array_elements(public.my_role_stats()) x) = 0, null;
insert into _r (check_name, ok, detail) select 'internal.role_stats is out of reach',
  pg_temp.fails('select 1 from internal.role_stats') is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot write a card',
  pg_temp.fails($q$insert into internal.role_stats (profile_id, role, played, wins) values ('b1000000-0000-4000-8000-00000000000b', 'sicario', 1, 1)$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot call record_role',
  pg_temp.fails($q$select internal.record_role('b1000000-0000-4000-8000-00000000000b', 'sicario', true)$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot settle a game',
  pg_temp.fails($q$select internal.record_match('e1000000-0000-4000-8000-00000000000e', 'citizens', '{"players": []}')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot grant himself the achievement',
  pg_temp.fails($q$insert into internal.player_achievements (profile_id, achievement_id) values ('b1000000-0000-4000-8000-00000000000b', 'role_sicario')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot record progress',
  pg_temp.fails($q$select internal.record_progress('b1000000-0000-4000-8000-00000000000b', 'f1000000-0000-4000-8000-00000000000f', '{"unlocked": [{"id": "role_sicario"}]}')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'anna''s public profile shows only her unlocked count',
  (public.public_stats('zz_anna_rc') ->> 'roles_unlocked')::int = 1
  and public.public_stats('zz_anna_rc')::text not like '%best_streak%', null;

-- ---- Anonymous: nothing.
set local role anon;
insert into _r (check_name, ok, detail) select 'anon cannot read cards',
  pg_temp.fails('select public.my_role_stats()') is not null, null;

reset role;
insert into _r (check_name, ok, detail)
select 'my_role_stats is not executable by anon',
  not has_function_privilege('anon', 'public.my_role_stats()', 'EXECUTE'), null;
insert into _r (check_name, ok, detail)
select 'no client privilege on internal.role_stats',
  not has_table_privilege('authenticated', 'internal.role_stats', 'SELECT')
  and not has_table_privilege('anon', 'internal.role_stats', 'SELECT'), null;

select n, check_name, ok, detail from _r order by n;
rollback;
