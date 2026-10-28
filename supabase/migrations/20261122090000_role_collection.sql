-- The roles collection ("I ruoli"): one card per role, locked until the
-- player wins a game with it.
--
-- * internal.role_stats: per player and role, the games that counted
--   (played), the wins, the current and best run of wins with that role,
--   the first win and the last game. Written only by record_match, in the
--   same transaction as the match history, and only for a game whose
--   settle produced a tally (the same rule as missions and achievements:
--   never abandoned, AFK, left, short or bots-only games). The role comes
--   from the engine's result, never from a phone.
-- * A card is unlocked when wins > 0. The Dart settle also unlocks the
--   achievement `role_<name in snake_case>` (lib/online/game/progress.dart), mirrored to
--   Steam / Game Center / Play Games once the server confirms it.
-- * my_role_stats(): the caller's own rows. public_stats() gains
--   `roles_unlocked` (just the count) for open profiles.
-- * Backfill from match_history (games that paid XP, not abandoned or AFK)
--   and the lifetime `role_win:` counters, plus the matching card
--   achievements (no coins: they pay none).

create table if not exists internal.role_stats (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role ~ '^[a-zA-Z]{2,30}$'),
  played integer not null default 0 check (played >= 0),
  wins integer not null default 0 check (wins >= 0 and wins <= played),
  streak integer not null default 0 check (streak >= 0 and streak <= wins),
  best_streak integer not null default 0 check (best_streak >= streak and best_streak <= wins),
  first_win_at timestamptz,
  last_played_at timestamptz,
  primary key (profile_id, role)
);
alter table internal.role_stats enable row level security;
revoke all on internal.role_stats from public, anon, authenticated;

-- One counted game with [role] for [who].
create or replace function internal.record_role(p_who uuid, p_role text, p_won boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  w integer := case when p_won then 1 else 0 end;
begin
  if p_who is null or p_role is null or p_role !~ '^[a-zA-Z]{2,30}$' then
    return;
  end if;
  insert into internal.role_stats as rs
    (profile_id, role, played, wins, streak, best_streak, first_win_at, last_played_at)
  values (p_who, p_role, 1, w, w, w, case when p_won then now() end, now())
  on conflict (profile_id, role) do update
    set played = rs.played + 1,
        wins = rs.wins + w,
        streak = case when p_won then rs.streak + 1 else 0 end,
        best_streak = greatest(rs.best_streak, case when p_won then rs.streak + 1 else 0 end),
        first_win_at = coalesce(rs.first_win_at, excluded.first_win_at),
        last_played_at = now();
end;
$$;
revoke all on function internal.record_role(uuid, text, boolean) from public, anon, authenticated;

-- record_match as before (20261105090000_personal_stats), plus the role.
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
    -- The roles collection: only a game that counted (it has a tally).
    if coalesce(p -> 'tally', '{}'::jsonb) ? 'games' then
      perform internal.record_role(who, p ->> 'role', coalesce((p ->> 'won')::boolean, false));
    end if;
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

-- ---------------------------------------------------------------------------
-- Backfill. A game counted when it paid XP and was not abandoned or AFK
-- (the settle's own rule, as far as the history can tell).

with h as (
  select profile_id, role, won, played_at,
         row_number() over (partition by profile_id, role order by played_at, id) as n,
         row_number() over (partition by profile_id, role, won order by played_at, id) as k
  from public.match_history
  where role ~ '^[a-zA-Z]{2,30}$' and not abandoned and not afk and coalesce(xp_gained, 0) > 0
),
runs as (
  select profile_id, role, count(*) as len
  from h where won
  group by profile_id, role, n - k
),
per as (
  select profile_id, role,
         count(*)::integer as played,
         (count(*) filter (where won))::integer as wins,
         coalesce(max(n) filter (where not won), 0) as last_loss,
         min(played_at) filter (where won) as first_win_at,
         max(played_at) as last_played_at
  from h group by profile_id, role
)
insert into internal.role_stats (profile_id, role, played, wins, streak, best_streak, first_win_at, last_played_at)
select per.profile_id, per.role, per.played, per.wins,
       (select count(*) from h where h.profile_id = per.profile_id and h.role = per.role
                                 and h.won and h.n > per.last_loss)::integer,
       coalesce((select max(len) from runs where runs.profile_id = per.profile_id and runs.role = per.role), 0)::integer,
       per.first_win_at, per.last_played_at
from per
on conflict (profile_id, role) do nothing;

-- The lifetime counters win over a thinner history (games settled before
-- match_history kept every row): never fewer wins than the counter says.
insert into internal.role_stats as rs (profile_id, role, played, wins, streak, best_streak, first_win_at, last_played_at)
select st.profile_id, substr(st.metric, 10), st.value::integer, st.value::integer, 0, 1, null, null
from internal.player_stats st
join public.profiles p on p.id = st.profile_id
where st.metric like 'role\_win:%' and st.value > 0 and substr(st.metric, 10) ~ '^[a-zA-Z]{2,30}$'
on conflict (profile_id, role) do update
  set wins = greatest(rs.wins, excluded.wins),
      played = greatest(rs.played, excluded.wins),
      best_streak = greatest(rs.best_streak, 1);

-- The card achievements for what was already won (they pay nothing). The
-- id is the role name in snake_case (Achievement.roleId in progress.dart).
insert into internal.player_achievements (profile_id, achievement_id, title, unlocked_at, game_id)
select rs.profile_id, a.id, null, coalesce(rs.first_win_at, now()), null
from internal.role_stats rs,
     lateral (select 'role_' || lower(regexp_replace(rs.role, '([A-Z])', '_\1', 'g')) as id) a
where rs.wins > 0 and a.id ~ '^[a-z0-9_]{3,40}$'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- What the phone reads.

-- The caller's own cards: one row per role ever played (a role with no row
-- is locked and unplayed).
create or replace function public.my_role_stats()
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
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'role', role, 'played', played, 'wins', wins, 'losses', played - wins,
             'streak', streak, 'best_streak', best_streak,
             'first_win', extract(epoch from first_win_at) * 1000,
             'last_played', extract(epoch from last_played_at) * 1000) order by role)
    from internal.role_stats where profile_id = me), '[]'::jsonb);
end;
$$;
revoke all on function public.my_role_stats() from public, anon;
grant execute on function public.my_role_stats() to authenticated;

-- public_stats as before (20261108090000_public_profiles), plus how many
-- cards are unlocked (only the count, only for an open profile).
create or replace function public.public_stats(target text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  p public.profiles;
  s jsonb;
  best public.ratings;
  base jsonb;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if target ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select * into p from public.profiles where id = target::uuid;
  else
    select * into p from public.profiles where handle = lower(ltrim(trim(target), '@'));
  end if;
  if p.id is null or p.handle is null then
    raise exception 'profile_not_found';
  end if;
  if p.id <> me and internal.blocked_between(me, p.id) then
    raise exception 'profile_blocked';
  end if;
  base := jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'level', p.level, 'avatar', p.avatar,
    'picture_url', p.picture_url, 'public', p.public_profile);
  if not p.public_profile and p.id <> me then
    return base;
  end if;
  s := internal.stats_slice(p.id, false);
  select * into best from public.ratings
  where profile_id = p.id and games > 0
  order by mu - 3 * sigma desc
  limit 1;
  return base || jsonb_build_object(
    'on_steam', p.on_steam,
    'on_apple', p.on_apple,
    'tier', case when best.profile_id is not null then internal.rank_tier(best.mu - 3 * best.sigma) end,
    'title', (select title from internal.player_achievements
              where profile_id = p.id and title is not null
              order by unlocked_at desc limit 1),
    'featured', coalesce((
      select jsonb_agg(achievement_id order by holders, unlocked_at desc)
      from (
        select a.achievement_id, a.unlocked_at,
               (select count(*) from internal.player_achievements b
                where b.achievement_id = a.achievement_id) as holders
        from internal.player_achievements a
        where a.profile_id = p.id and a.achievement_id not like 'role\_%'
        order by holders, a.unlocked_at desc
        limit 3
      ) f), '[]'::jsonb),
    'roles_unlocked', (select count(*) from internal.role_stats where profile_id = p.id and wins > 0),
    'games', s -> 'games',
    'wins', s -> 'wins',
    'longest_streak', s -> 'longest_streak',
    'seconds', s -> 'seconds',
    'timed', s -> 'timed',
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object('role', key, 'games', g, 'wins', w) order by g desc, w desc, key)
      from (
        select key, (value ->> 'games')::integer as g, (value ->> 'wins')::integer as w
        from jsonb_each(s -> 'roles')
        where key <> '?'
        order by g desc, w desc, key
        limit 5
      ) r), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.public_stats(text) from public, anon;
grant execute on function public.public_stats(text) to authenticated;

-- The data export names the role cards too (20261107090000_steam_profile).
create or replace function public.export_my_data()
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
  return internal.export_my_data_base() || jsonb_build_object(
    'missions', coalesce((select jsonb_agg(to_jsonb(m) - 'profile_id') from internal.player_missions m
                          where m.profile_id = me), '[]'::jsonb),
    'stats', coalesce((select jsonb_object_agg(metric, value) from internal.player_stats
                       where profile_id = me), '{}'::jsonb),
    'achievements', coalesce((select jsonb_agg(to_jsonb(a) - 'profile_id') from internal.player_achievements a
                              where a.profile_id = me), '[]'::jsonb),
    'role_stats', coalesce((select jsonb_agg(to_jsonb(rs) - 'profile_id' order by rs.role) from internal.role_stats rs
                            where rs.profile_id = me), '[]'::jsonb),
    'steam', (select jsonb_build_object('steam_id', s.steam_id, 'linked_at', s.created_at, 'refreshed_at', s.refreshed_at)
                from internal.steam_identities s where s.profile_id = me)
  );
end;
$$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;
