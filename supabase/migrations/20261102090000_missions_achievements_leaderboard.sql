-- Missions, achievements and the ranked leaderboard. All server side: the
-- client never claims progress.
--
-- * Missions: every player gets 3 daily and 3 weekly missions (UTC day,
--   ISO week), picked from internal.mission_defs. settle_input hands the
--   open ones to the Dart settle (lib/online/game/progress.dart), which
--   moves them with the real game result; record_match saves the progress
--   and pays a completed mission at once (XP inside the settle, coins with
--   grant_coins, so the wallet updates live). AFK, abandoned, left and short
--   games, and bots-only friends rooms, never count.
-- * Achievements: permanent, stable snake_case ids (future Steam ids). The
--   catalog is in Dart; the server keeps lifetime counters
--   (internal.player_stats) and what was unlocked. Some give a title (shown
--   in the dossier) or a shop item for free (shop_inventory, source 'gift').
-- * Leaderboard: per language, top 100 by ordinal (mu - 3 sigma): only the
--   handle and the rank tier, never ids or numbers. Cached 60 s.
--
-- Clients read everything through SECURITY DEFINER functions; the tables
-- live in `internal`, RLS on, no grants.

-- ---------------------------------------------------------------------------
-- Coins from missions and achievements.

alter table public.coin_ledger drop constraint if exists coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check
  check (reason in ('buy', 'level_up', 'purchase', 'gift', 'refund', 'mission', 'achievement'));

-- ---------------------------------------------------------------------------
-- Tables.

create table if not exists internal.mission_defs (
  id text primary key check (id ~ '^[a-z0-9_]{3,40}$'),
  cadence text not null check (cadence in ('daily', 'weekly')),
  metric text not null,
  target integer not null check (target > 0),
  xp integer not null check (xp >= 0),
  coins integer not null check (coins between 0 and 300),
  enabled boolean not null default true
);

create table if not exists internal.player_missions (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  cadence text not null check (cadence in ('daily', 'weekly')),
  period date not null,
  mission_id text not null references internal.mission_defs (id),
  progress integer not null default 0,
  completed_at timestamptz,
  completed_game uuid,
  primary key (profile_id, cadence, period, mission_id)
);

create table if not exists internal.player_stats (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  metric text not null check (char_length(metric) between 1 and 60),
  value bigint not null default 0,
  primary key (profile_id, metric)
);

create table if not exists internal.player_achievements (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  achievement_id text not null check (achievement_id ~ '^[a-z0-9_]{3,40}$'),
  title text,
  unlocked_at timestamptz not null default now(),
  game_id uuid,
  primary key (profile_id, achievement_id)
);

create table if not exists internal.leaderboard_cache (
  language text primary key check (language in ('it', 'en')),
  rows jsonb not null,
  computed_at timestamptz not null
);

alter table internal.mission_defs enable row level security;
alter table internal.player_missions enable row level security;
alter table internal.player_stats enable row level security;
alter table internal.player_achievements enable row level security;
alter table internal.leaderboard_cache enable row level security;
revoke all on internal.mission_defs, internal.player_missions, internal.player_stats,
  internal.player_achievements, internal.leaderboard_cache from public, anon, authenticated;

create index if not exists player_missions_game on internal.player_missions (completed_game)
  where completed_game is not null;
create index if not exists player_achievements_game on internal.player_achievements (game_id)
  where game_id is not null;
create index if not exists ratings_board on public.ratings (language, (mu - 3 * sigma) desc);

-- The pool. Coins are scarce: daily 30-60, weekly 150-250.
insert into internal.mission_defs (id, cadence, metric, target, xp, coins) values
  ('daily_play_3', 'daily', 'games', 3, 60, 30),
  ('daily_win_1', 'daily', 'wins', 1, 80, 40),
  ('daily_friends_win_2', 'daily', 'friends_wins', 2, 100, 60),
  ('daily_lynch_hits_3', 'daily', 'lynch_hits', 3, 100, 50),
  ('daily_nights_2', 'daily', 'nights', 2, 60, 30),
  ('daily_ranked_1', 'daily', 'ranked_games', 1, 80, 40),
  ('daily_survive_1', 'daily', 'survived', 1, 70, 40),
  ('daily_town_win_1', 'daily', 'town_wins', 1, 90, 50),
  ('daily_mafia_win_1', 'daily', 'mafia_wins', 1, 100, 60),
  ('weekly_neutral_win_1', 'weekly', 'neutral_wins', 1, 300, 250),
  ('weekly_wins_7', 'weekly', 'wins', 7, 300, 200),
  ('weekly_play_15', 'weekly', 'games', 15, 250, 150),
  ('weekly_lynch_hits_10', 'weekly', 'lynch_hits', 10, 300, 200),
  ('weekly_ranked_5', 'weekly', 'ranked_games', 5, 300, 200),
  ('weekly_ranked_wins_3', 'weekly', 'ranked_wins', 3, 350, 250),
  ('weekly_saves_2', 'weekly', 'saves', 2, 300, 200),
  ('weekly_finds_3', 'weekly', 'finds', 3, 300, 180),
  ('weekly_kills_5', 'weekly', 'kills', 5, 300, 180),
  ('weekly_nights_12', 'weekly', 'nights', 12, 250, 150)
on conflict (id) do update
  set cadence = excluded.cadence, metric = excluded.metric, target = excluded.target,
      xp = excluded.xp, coins = excluded.coins;

-- ---------------------------------------------------------------------------
-- Assigning missions: 3 per cadence and period, the same 3 whoever asks
-- first (the order is a hash of person, period and mission), so two calls
-- at once can never hand out 6.

create or replace function internal.mission_period(cadence text)
returns date
language sql
stable
set search_path = ''
as $$
  select case cadence
    when 'weekly' then date_trunc('week', now() at time zone 'utc')::date
    else (now() at time zone 'utc')::date
  end;
$$;
revoke all on function internal.mission_period(text) from public, anon, authenticated;

create or replace function internal.ensure_missions(who uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c text;
  p date;
begin
  foreach c in array array['daily', 'weekly'] loop
    p := internal.mission_period(c);
    if (select count(*) from internal.player_missions
        where profile_id = who and cadence = c and period = p) >= 3 then
      continue;
    end if;
    insert into internal.player_missions (profile_id, cadence, period, mission_id)
    select who, c, p, d.id
    from internal.mission_defs d
    where d.cadence = c and d.enabled
    order by md5(who::text || ':' || p::text || ':' || d.id)
    limit 3
    on conflict do nothing;
  end loop;
end;
$$;
revoke all on function internal.ensure_missions(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Settle: the open missions, the counters and the unlocked achievements go
-- in with every seat, next to the feats the engine counted.

create or replace function internal.settle_input(room uuid, result jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_public;
  r public.rooms;
  today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  seats jsonb;
begin
  select * into g from public.game_public where room_id = room;
  select * into r from public.rooms where id = room;
  if g.room_id is null or r.id is null or result is null or result -> 'seats' is null then
    return null;
  end if;
  if exists (select 1 from public.match_history where game_id = g.game_id) then
    return null;
  end if;
  perform internal.ensure_missions(s.profile_id)
  from public.game_seats s
  where s.room_id = room and s.profile_id is not null and result -> 'seats' ? s.seat;
  select coalesce(jsonb_agg(jsonb_build_object(
           'profile', s.profile_id,
           'seat', s.seat,
           'team', result -> 'seats' -> s.seat ->> 'team',
           'role', result -> 'seats' -> s.seat ->> 'role',
           'won', coalesce((result -> 'seats' -> s.seat ->> 'won')::boolean, false),
           'survived', coalesce((result -> 'seats' -> s.seat ->> 'survived')::boolean, false),
           'abandoned', coalesce((result -> 'seats' -> s.seat ->> 'abandoned')::boolean, false),
           'afk', coalesce((result -> 'seats' -> s.seat ->> 'afk')::boolean, false),
           'short', coalesce((result -> 'seats' -> s.seat ->> 'short')::boolean, false),
           'leftDead', not coalesce((result -> 'seats' -> s.seat ->> 'abandoned')::boolean, false)
             and exists (select 1 from internal.game_leaves l
                         where l.game_id = g.game_id and l.profile_id = s.profile_id),
           'feats', coalesce(result -> 'seats' -> s.seat -> 'feats', '{}'::jsonb),
           'level', p.level,
           'xp', p.xp,
           'mu', coalesce(rt.mu, 25),
           'sigma', coalesce(rt.sigma, 25.0 / 3),
           'wonToday', exists (
             select 1 from public.match_history h
             where h.profile_id = s.profile_id and h.won and h.played_at >= today),
           'friendsGamesToday', (
             select count(*) from public.match_history h
             where h.profile_id = s.profile_id and not h.ranked and h.played_at >= today),
           'missions', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', m.mission_id, 'cadence', m.cadence, 'period', m.period::text,
                      'metric', d.metric, 'target', d.target, 'progress', m.progress,
                      'xp', d.xp, 'coins', d.coins) order by m.cadence, m.mission_id)
             from internal.player_missions m
             join internal.mission_defs d on d.id = m.mission_id
             where m.profile_id = s.profile_id and m.completed_at is null
               and m.period = internal.mission_period(m.cadence)), '[]'::jsonb),
           'stats', coalesce((
             select jsonb_object_agg(st.metric, st.value)
             from internal.player_stats st where st.profile_id = s.profile_id), '{}'::jsonb),
           'achieved', coalesce((
             select jsonb_agg(a.achievement_id)
             from internal.player_achievements a where a.profile_id = s.profile_id), '[]'::jsonb)
         ) order by s.seat), '[]'::jsonb)
    into seats
  from public.game_seats s
  join public.profiles p on p.id = s.profile_id
  left join public.ratings rt on rt.profile_id = s.profile_id and rt.language = r.language
  where s.room_id = room and s.profile_id is not null and result -> 'seats' ? s.seat;
  return jsonb_build_object(
    'ranked', r.ranked,
    'humans', (select count(*) from public.game_seats where room_id = room and profile_id is not null),
    'seats', seats
  );
end;
$$;
revoke all on function internal.settle_input(uuid, jsonb) from public, anon, authenticated;

-- What one settled player moved: counters, missions, achievements, with
-- their coins and free items. Called by record_match only.
create or replace function internal.record_progress(who uuid, game uuid, p jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t record;
  m jsonb;
  a jsonb;
begin
  for t in select key, value from jsonb_each_text(coalesce(p -> 'tally', '{}'::jsonb)) loop
    if t.value::bigint <= 0 then
      continue;
    end if;
    insert into internal.player_stats as st (profile_id, metric, value)
    values (who, t.key, t.value::bigint)
    on conflict (profile_id, metric) do update set value = st.value + excluded.value;
  end loop;
  if coalesce(p -> 'tally', '{}'::jsonb) <> '{}'::jsonb then
    insert into internal.player_stats as st (profile_id, metric, value)
    values (who, 'roles_won', (
      select count(*) from internal.player_stats
      where profile_id = who and metric like 'role\_win:%' and value > 0))
    on conflict (profile_id, metric) do update set value = excluded.value;
  end if;

  for m in select * from jsonb_array_elements(coalesce(p -> 'missions', '[]'::jsonb)) loop
    update internal.player_missions pm
    set progress = greatest(pm.progress, (m ->> 'progress')::integer),
        completed_at = case when (m ->> 'completed')::boolean then now() end,
        completed_game = case when (m ->> 'completed')::boolean then game end
    where pm.profile_id = who and pm.cadence = m ->> 'cadence'
      and pm.period = (m ->> 'period')::date and pm.mission_id = m ->> 'id'
      and pm.completed_at is null;
    if found and (m ->> 'completed')::boolean and coalesce((m ->> 'coins')::integer, 0) > 0 then
      perform public.grant_coins(who, (m ->> 'coins')::integer, 'mission',
        'mission:' || who::text || ':' || (m ->> 'period') || ':' || (m ->> 'id'));
    end if;
  end loop;

  for a in select * from jsonb_array_elements(coalesce(p -> 'unlocked', '[]'::jsonb)) loop
    insert into internal.player_achievements (profile_id, achievement_id, title, game_id)
    values (who, a ->> 'id', a ->> 'title', game)
    on conflict do nothing;
    if not found then
      continue;
    end if;
    if coalesce((a ->> 'coins')::integer, 0) > 0 then
      perform public.grant_coins(who, (a ->> 'coins')::integer, 'achievement',
        'achievement:' || who::text || ':' || (a ->> 'id'));
    end if;
    if a ->> 'item' is not null and exists (select 1 from public.shop_items where id = a ->> 'item') then
      insert into public.shop_inventory (profile_id, item_id, source)
      values (who, a ->> 'item', 'gift')
      on conflict do nothing;
    end if;
  end loop;
end;
$$;
revoke all on function internal.record_progress(uuid, uuid, jsonb) from public, anon, authenticated;

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
      won, survived, abandoned, afk, xp_gained, level_before, level_after, coins_gained, rating_delta, ordinal_after)
    values (
      g.game_id, room, who, r.language, r.ranked, r.test_match,
      (select count(*) from public.game_seats where room_id = room),
      p ->> 'seat', coalesce(p ->> 'role', '?'), coalesce(p ->> 'team', '?'), coalesce(winner, '?'),
      (p ->> 'won')::boolean, (p ->> 'survived')::boolean, (p ->> 'abandoned')::boolean,
      coalesce((p ->> 'afk')::boolean, false),
      (p ->> 'xpGained')::integer, (p ->> 'levelBefore')::integer, (p ->> 'level')::integer,
      (p ->> 'coins')::integer,
      case when r.ranked then (p ->> 'ratingDelta')::double precision end,
      case when r.ranked then (p ->> 'mu')::double precision - 3 * (p ->> 'sigma')::double precision end);
    saved := saved + 1;
  end loop;
  return saved;
end;
$$;
revoke all on function internal.record_match(uuid, text, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- What the phone reads.

-- The caller's missions (assigned on first look), counters and achievements.
create or replace function public.my_progress()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  perform internal.ensure_missions(me);
  return jsonb_build_object(
    'missions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', m.mission_id, 'cadence', m.cadence, 'metric', d.metric, 'target', d.target,
               'progress', m.progress, 'xp', d.xp, 'coins', d.coins,
               'completed', m.completed_at is not null,
               'ends_at', extract(epoch from (
                 (m.period + case m.cadence when 'weekly' then 7 else 1 end)::timestamp
                 at time zone 'utc')) * 1000)
             order by m.cadence, d.coins, m.mission_id)
      from internal.player_missions m
      join internal.mission_defs d on d.id = m.mission_id
      where m.profile_id = me and m.period = internal.mission_period(m.cadence)), '[]'::jsonb),
    'stats', coalesce((
      select jsonb_object_agg(metric, value) from internal.player_stats where profile_id = me), '{}'::jsonb),
    'achievements', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', achievement_id, 'title', title,
               'at', extract(epoch from unlocked_at) * 1000) order by unlocked_at)
      from internal.player_achievements where profile_id = me), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.my_progress() from public, anon;
grant execute on function public.my_progress() to authenticated;

-- What one game completed for the caller: the banners on the results screen.
create or replace function public.game_unlocks(game uuid)
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
    'missions', coalesce((
      select jsonb_agg(jsonb_build_object('id', m.mission_id, 'cadence', m.cadence,
               'xp', d.xp, 'coins', d.coins) order by m.cadence, m.mission_id)
      from internal.player_missions m
      join internal.mission_defs d on d.id = m.mission_id
      where m.profile_id = me and m.completed_game = game), '[]'::jsonb),
    'achievements', coalesce((
      select jsonb_agg(jsonb_build_object('id', achievement_id, 'title', title) order by achievement_id)
      from internal.player_achievements
      where profile_id = me and game_id = game), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.game_unlocks(uuid) from public, anon;
grant execute on function public.game_unlocks(uuid) to authenticated;

-- The rank tier from an ordinal: the same thresholds as RankTier in
-- lib/online/game/match_rewards.dart.
create or replace function internal.rank_tier(ordinal double precision)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when ordinal >= 29 then 'don'
    when ordinal >= 22 then 'consigliere'
    when ordinal >= 15 then 'caporegime'
    when ordinal >= 8 then 'capodecina'
    else 'picciotto'
  end;
$$;
revoke all on function internal.rank_tier(double precision) from public, anon, authenticated;

-- Top 100 of a language by ordinal, cached 60 s, plus the caller's place.
-- Only handles and tiers: no ids, no numbers.
create or replace function public.leaderboard(board_language text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  cached internal.leaderboard_cache;
  top jsonb;
  mine public.ratings;
  place bigint;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if board_language not in ('it', 'en') then
    raise exception 'bad_language';
  end if;
  select * into cached from internal.leaderboard_cache where language = board_language;
  if found and cached.computed_at > now() - interval '60 seconds' then
    top := cached.rows;
  elsif not pg_try_advisory_xact_lock(hashtext('oberta.leaderboard.' || board_language)) then
    top := coalesce(cached.rows, '[]'::jsonb);
  else
    select coalesce(jsonb_agg(jsonb_build_object('rank', n, 'handle', handle, 'tier', tier) order by n), '[]'::jsonb)
      into top
    from (
      select row_number() over (order by rt.mu - 3 * rt.sigma desc, rt.games desc, p.handle) as n,
             p.handle, internal.rank_tier(rt.mu - 3 * rt.sigma) as tier
      from public.ratings rt
      join public.profiles p on p.id = rt.profile_id
      where rt.language = board_language and rt.games > 0 and p.handle is not null
      order by rt.mu - 3 * rt.sigma desc, rt.games desc, p.handle
      limit 100
    ) board;
    insert into internal.leaderboard_cache (language, rows, computed_at) values (board_language, top, now())
    on conflict (language) do update set rows = excluded.rows, computed_at = excluded.computed_at;
  end if;
  select * into mine from public.ratings where profile_id = me and language = board_language and games > 0;
  if found then
    select 1 + count(*) into place
    from public.ratings rt
    join public.profiles p on p.id = rt.profile_id
    where rt.language = board_language and rt.games > 0 and p.handle is not null
      and rt.mu - 3 * rt.sigma > mine.mu - 3 * mine.sigma;
  end if;
  return jsonb_build_object(
    'top', top,
    'me', case when place is null then null
               else jsonb_build_object('rank', place, 'tier', internal.rank_tier(mine.mu - 3 * mine.sigma)) end
  );
end;
$$;
revoke all on function public.leaderboard(text) from public, anon;
grant execute on function public.leaderboard(text) to authenticated;

-- ---------------------------------------------------------------------------
-- The data export also carries missions, counters and achievements.

do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'internal' and p.proname = 'export_my_data_base') then
    alter function public.export_my_data() set schema internal;
    alter function internal.export_my_data() rename to export_my_data_base;
  end if;
end;
$$;
revoke all on function internal.export_my_data_base() from public, anon, authenticated;

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
                              where a.profile_id = me), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;
