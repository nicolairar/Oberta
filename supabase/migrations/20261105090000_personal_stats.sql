-- Personal stats: the "Statistiche" page of the dossier.
--
-- * game_public.started_at: when the cards were dealt. The row is deleted
--   and inserted again for every new game, so the default is enough. Games
--   already running when this lands have no start (null).
-- * match_history.duration_seconds: how long the game lasted, written by
--   record_match. Games settled before this migration stay null (their
--   start was never recorded), and the stats say how many were measured.
-- * my_stats(): the caller's own numbers, computed here from their
--   match_history and lifetime counters. Abandons and AFK are only ever
--   shown to the player themselves.

alter table public.game_public add column if not exists started_at timestamptz;
alter table public.game_public alter column started_at set default now();

alter table public.match_history add column if not exists duration_seconds integer
  check (duration_seconds is null or duration_seconds >= 0);
-- Backfill: nothing to measure for older games, they stay null.

-- record_match as before, plus the game's length.
create or replace function internal.record_match(room uuid, winner text, settlement jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_public;
  r public.rooms;
  p jsonb;
  who uuid;
  level_coins integer;
  saved integer := 0;
begin
  select * into g from public.game_public where room_id = room;
  select * into r from public.rooms where id = room;
  if g.room_id is null or r.id is null then
    return 0;
  end if;
  if exists (select 1 from public.match_history where game_id = g.game_id) then
    return 0;
  end if;
  for p in select * from jsonb_array_elements(coalesce(settlement -> 'players', '[]'::jsonb)) loop
    who := (p ->> 'profile')::uuid;
    update public.profiles
    set level = (p ->> 'level')::integer, xp = (p ->> 'xp')::integer
    where id = who;
    level_coins := coalesce((p ->> 'levelCoins')::integer, (p ->> 'coins')::integer);
    if level_coins > 0 then
      perform public.grant_coins(who, level_coins, 'level_up', g.game_id::text || ':' || who::text);
    end if;
    perform internal.record_progress(who, g.game_id, p);
    if r.ranked then
      insert into public.ratings as rt (profile_id, language, mu, sigma, games, wins, updated_at)
      values (who, r.language, (p ->> 'mu')::double precision, (p ->> 'sigma')::double precision, 1,
              case when (p ->> 'won')::boolean and not coalesce((p ->> 'afk')::boolean, false)
                        and not coalesce((p ->> 'leftDead')::boolean, false) then 1 else 0 end, now())
      on conflict (profile_id, language) do update
        set mu = excluded.mu, sigma = excluded.sigma, games = rt.games + 1,
            wins = rt.wins + excluded.wins, updated_at = now();
      if (p ->> 'abandoned')::boolean then
        null; -- the abandon trigger already took its strike
      elsif coalesce((p ->> 'afk')::boolean, false) then
        -- A soft abandon: a smaller hit, no strike, no cooldown.
        perform internal.conduct_of(who);
        update internal.conduct set score = greatest(0, score - 7) where profile_id = who;
      elsif coalesce((p ->> 'leftDead')::boolean, false) then
        null; -- left after dying: no penalty, no credit
      else
        perform internal.conduct_of(who);
        update internal.conduct
        set strikes = greatest(0, strikes - 1), score = least(100, score + 5)
        where profile_id = who;
      end if;
    end if;
    insert into public.match_history (
      game_id, room_id, profile_id, language, ranked, test_match, players, seat, role, team, winner,
      won, survived, abandoned, afk, xp_gained, level_before, level_after, coins_gained, rating_delta, ordinal_after,
      duration_seconds)
    values (
      g.game_id, room, who, r.language, r.ranked, r.test_match,
      (select count(*) from public.game_seats where room_id = room),
      p ->> 'seat', coalesce(p ->> 'role', '?'), coalesce(p ->> 'team', '?'), coalesce(winner, '?'),
      (p ->> 'won')::boolean, (p ->> 'survived')::boolean, (p ->> 'abandoned')::boolean,
      coalesce((p ->> 'afk')::boolean, false),
      (p ->> 'xpGained')::integer, (p ->> 'levelBefore')::integer, (p ->> 'level')::integer,
      (p ->> 'coins')::integer,
      case when r.ranked then (p ->> 'ratingDelta')::double precision end,
      case when r.ranked then (p ->> 'mu')::double precision - 3 * (p ->> 'sigma')::double precision end,
      case when g.started_at is not null then greatest(0, extract(epoch from now() - g.started_at))::integer end);
    saved := saved + 1;
  end loop;
  return saved;
end;
$$;
revoke all on function internal.record_match(uuid, text, jsonb) from public, anon, authenticated;

-- One slice of the caller's history: with or without the test matches.
create or replace function internal.stats_slice(who uuid, with_tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with h as (
    select * from public.match_history
    where profile_id = who and (with_tests or not test_match)
  ),
  runs as (
    select count(*) as n
    from (
      select won,
             row_number() over (order by played_at, id)
               - row_number() over (partition by won order by played_at, id) as run
      from h
    ) s
    where won
    group by run
  )
  select jsonb_build_object(
    'games', count(*),
    'wins', count(*) filter (where won),
    'survived', count(*) filter (where survived),
    'abandoned', count(*) filter (where abandoned),
    'afk', count(*) filter (where afk),
    'seconds', coalesce(sum(duration_seconds), 0),
    'timed', count(duration_seconds),
    'friends', jsonb_build_object('games', count(*) filter (where not ranked),
                                  'wins', count(*) filter (where not ranked and won)),
    'ranked', jsonb_build_object('games', count(*) filter (where ranked),
                                 'wins', count(*) filter (where ranked and won)),
    'longest_streak', coalesce((select max(n) from runs), 0),
    'teams', coalesce((
      select jsonb_object_agg(team, jsonb_build_object('games', g, 'wins', w))
      from (select team, count(*) as g, count(*) filter (where won) as w from h group by team) t), '{}'::jsonb),
    'roles', coalesce((
      select jsonb_object_agg(role, jsonb_build_object('games', g, 'wins', w))
      from (select role, count(*) as g, count(*) filter (where won) as w from h group by role) t), '{}'::jsonb)
  )
  from h;
$$;
revoke all on function internal.stats_slice(uuid, boolean) from public, anon, authenticated;

-- The caller's stats: every game and only the real ones (the dossier's
-- "include test matches" switch picks one), how many were tests, and the
-- lifetime counters kept for missions and achievements.
create or replace function public.my_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  return jsonb_build_object(
    'all', internal.stats_slice(me, true),
    'real', internal.stats_slice(me, false),
    'tests', (select count(*) from public.match_history where profile_id = me and test_match),
    'counters', coalesce((
      select jsonb_object_agg(metric, value) from internal.player_stats
      where profile_id = me and metric not like 'role\_win:%'), '{}'::jsonb)
  );
end;
$$;
revoke all on function public.my_stats() from public, anon;
grant execute on function public.my_stats() to authenticated;
