-- Anti-cheat for the earn-only economy (20261122100000_earn_only_missions):
-- a player calling the API directly can neither move a mission, nor claim
-- one twice or before the server completed it, nor buy a mission-only piece,
-- nor credit coins. Runs on the real database and changes nothing:
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
  ('a2000000-0000-4000-8000-00000000000a'),
  ('b2000000-0000-4000-8000-00000000000b');
insert into public.profiles (id) values
  ('a2000000-0000-4000-8000-00000000000a'),
  ('b2000000-0000-4000-8000-00000000000b')
on conflict (id) do nothing;
update public.profiles set handle = 'zz_anna_mi' where id = 'a2000000-0000-4000-8000-00000000000a';
update public.profiles set handle = 'zz_bruno_mi' where id = 'b2000000-0000-4000-8000-00000000000b';

insert into public.rooms (id, code, host, language, status, max_players)
values ('e2000000-0000-4000-8000-00000000000e', 'ZZZZ44', 'a2000000-0000-4000-8000-00000000000a', 'it', 'playing', 12);
insert into public.game_public (room_id, host, version, view, game_id, chat_mode)
values ('e2000000-0000-4000-8000-00000000000e', 'a2000000-0000-4000-8000-00000000000a', 1, null,
        'f2000000-0000-4000-8000-00000000000f', 'day');
insert into public.game_seats (room_id, seat, profile_id, name, alive, family) values
  ('e2000000-0000-4000-8000-00000000000e', 's1', 'a2000000-0000-4000-8000-00000000000a', 'anna', true, false),
  ('e2000000-0000-4000-8000-00000000000e', 's2', 'b2000000-0000-4000-8000-00000000000b', 'bruno', true, true);

-- Anna's missions are dealt, then the game server settles: Anna wins as the
-- Detective (her fifth win with the role) and completes her daily; Bruno
-- loses. One ledger row each for the game.
select internal.ensure_missions('a2000000-0000-4000-8000-00000000000a');
select internal.record_match('e2000000-0000-4000-8000-00000000000e', 'citizens', jsonb_build_object('players', jsonb_build_array(
  jsonb_build_object('profile', 'a2000000-0000-4000-8000-00000000000a', 'seat', 's1', 'role', 'detective', 'team', 'citizens',
    'won', true, 'survived', true, 'abandoned', false, 'level', 1, 'xp', 0, 'levelBefore', 1, 'xpGained', 200,
    'coins', 40, 'levelCoins', 0, 'matchCoins', 40,
    'tally', jsonb_build_object('games', 1, 'wins', 1, 'role_win:detective', 5, 'reputation', 3),
    'missions', (select jsonb_agg(jsonb_build_object('id', mission_id, 'cadence', cadence, 'period', period::text,
                                                     'progress', 99, 'completed', true))
                 from internal.player_missions
                 where profile_id = 'a2000000-0000-4000-8000-00000000000a' and cadence = 'daily'
                   and period = internal.mission_period('daily')),
    'unlocked', '[]'::jsonb),
  jsonb_build_object('profile', 'b2000000-0000-4000-8000-00000000000b', 'seat', 's2', 'role', 'mafioso', 'team', 'mafia',
    'won', false, 'survived', true, 'abandoned', false, 'level', 1, 'xp', 0, 'levelBefore', 1, 'xpGained', 30,
    'coins', 4, 'levelCoins', 0, 'matchCoins', 4,
    'tally', jsonb_build_object('games', 1, 'reputation', 1), 'missions', '[]'::jsonb, 'unlocked', '[]'::jsonb)
)));

insert into _r (check_name, ok, detail)
select 'the game paid its coins in one match row each', count(*) = 2 and sum(delta) = 44, count(*)::text || ' ' || sum(delta)::text
from public.coin_ledger where reason = 'match'
  and profile_id in ('a2000000-0000-4000-8000-00000000000a', 'b2000000-0000-4000-8000-00000000000b');
insert into _r (check_name, ok, detail)
select 'completing a mission pays no coins yet', not exists (
  select 1 from public.coin_ledger where reason = 'mission' and profile_id = 'a2000000-0000-4000-8000-00000000000a'), null;

-- ---- Bruno, calling the API by hand.
set local role authenticated;
set local request.jwt.claims to '{"sub": "b2000000-0000-4000-8000-00000000000b", "role": "authenticated"}';

insert into _r (check_name, ok, detail) select 'bruno cannot complete his missions',
  pg_temp.fails($q$update internal.player_missions set completed_at = now()$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot write a counter',
  pg_temp.fails($q$insert into internal.player_stats (profile_id, metric, value) values ('b2000000-0000-4000-8000-00000000000b', 'wins', 50)$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot record progress',
  pg_temp.fails($q$select internal.record_progress('b2000000-0000-4000-8000-00000000000b', 'f2000000-0000-4000-8000-00000000000f', '{"tally": {"wins": 50}}')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot settle a game',
  pg_temp.fails($q$select internal.record_match('e2000000-0000-4000-8000-00000000000e', 'mafia', '{"players": []}')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot claim a goal he has not reached',
  pg_temp.fails($q$select public.claim_mission('long_wins_50')$q$) like '%not_completed%', null;
insert into _r (check_name, ok, detail) select 'bruno cannot buy a mission-only piece',
  pg_temp.fails($q$select public.buy_item('hat.sbirro')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot gift himself a piece',
  pg_temp.fails($q$insert into public.shop_inventory (profile_id, item_id, source) values ('b2000000-0000-4000-8000-00000000000b', 'hat.sbirro', 'gift')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot credit coins',
  pg_temp.fails($q$select public.grant_coins('b2000000-0000-4000-8000-00000000000b', 500, 'mission')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot rewrite the mission pool',
  pg_temp.fails($q$update internal.mission_defs set coins = 1000$q$) is not null, null;

-- ---- Anna claims what the server completed: once.
set local request.jwt.claims to '{"sub": "a2000000-0000-4000-8000-00000000000a", "role": "authenticated"}';
insert into _r (check_name, ok, detail)
select 'anna claims the cop''s cap goal', (public.claim_mission('long_detective_wins_5') ->> 'item') = 'hat.sbirro', null;
insert into _r (check_name, ok, detail) select 'and never twice',
  pg_temp.fails($q$select public.claim_mission('long_detective_wins_5')$q$) like '%already_claimed%', null;
insert into _r (check_name, ok, detail)
select 'anna claims her daily', (public.claim_mission((
  select x ->> 'id' from jsonb_array_elements(public.my_progress() -> 'missions') x
  where x ->> 'cadence' = 'daily' and (x ->> 'completed')::boolean limit 1)) ->> 'coins')::int > 0, null;

reset role;
insert into _r (check_name, ok, detail)
select 'the cap arrived as a gift', exists (
  select 1 from public.shop_inventory where profile_id = 'a2000000-0000-4000-8000-00000000000a'
    and item_id = 'hat.sbirro' and source = 'gift'), null;
insert into _r (check_name, ok, detail)
select 'no real-money reason is accepted', pg_temp.fails($q$select public.grant_coins('a2000000-0000-4000-8000-00000000000a', 5, 'purchase')$q$) is not null, null;
insert into _r (check_name, ok, detail)
select 'claim_mission is not executable by anon', not has_function_privilege('anon', 'public.claim_mission(text)', 'EXECUTE'), null;
insert into _r (check_name, ok, detail)
select 'no client privilege on the mission tables',
  not has_table_privilege('authenticated', 'internal.player_missions', 'SELECT')
  and not has_table_privilege('authenticated', 'internal.mission_defs', 'SELECT'), null;
insert into _r (check_name, ok, detail)
select 'the mission tables are not in realtime', not exists (
  select 1 from pg_publication_tables where schemaname = 'internal'), null;

select n, check_name, ok, detail from _r order by n;
rollback;
