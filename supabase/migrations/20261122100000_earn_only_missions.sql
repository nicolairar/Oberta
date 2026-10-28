-- Earn-only economy: nothing is sold for real money, ever. Coins come from
-- playing (every game, the first win of the day, every level) and from
-- missions; prices are tuned so that everything can be earned in a sensible
-- time (docs/economia.md has the targets and the numbers).
--
-- * coin_ledger / shop_inventory: the 'purchase' reason and source go away
--   when no row uses them (none ever did), so a real-money credit has no way
--   in. New reason 'match': the coins of the game itself.
-- * Prices: comune 120, raro 700, epico 1100-1799 as before, leggendario
--   2900-8000 (every legendary x1.6 to the fifty). Repriced once, guarded by
--   the new constraint's name.
-- * Mission-only pieces: shop_items.unlock names the long mission that gives
--   one. Price 0, never sold: a trigger on shop_inventory lets them in only
--   as a gift (claim_mission), so buy_item and buy_bundle fail.
-- * Missions: daily and weekly are dealt one per pool (three pools each), by
--   a hash of person, period and mission: deterministic, no cron. Long
--   missions ("obiettivi") are always there; their progress is the lifetime
--   counter (internal.player_stats) the results transaction already writes,
--   so they cost no row until claimed. XP still arrives with the game that
--   completes a daily or weekly; coins, reputation and the item arrive when
--   the player claims it (claim_mission): one row update, one ledger row.
-- * Lean on the free plan: one row per person per daily/weekly mission per
--   period, one per claimed long mission; rows older than 35 days are pruned
--   when the person's missions are dealt (no cron). No realtime on any of
--   these tables.

-- ---------------------------------------------------------------------------
-- No real money.

do $$
begin
  alter table public.coin_ledger drop constraint if exists coin_ledger_reason_check;
  if exists (select 1 from public.coin_ledger where reason = 'purchase') then
    alter table public.coin_ledger add constraint coin_ledger_reason_check
      check (reason in ('buy', 'level_up', 'purchase', 'gift', 'refund', 'mission', 'achievement', 'match'));
  else
    alter table public.coin_ledger add constraint coin_ledger_reason_check
      check (reason in ('buy', 'level_up', 'gift', 'refund', 'mission', 'achievement', 'match'));
  end if;
  alter table public.shop_inventory drop constraint if exists shop_inventory_source_check;
  if exists (select 1 from public.shop_inventory where source = 'purchase') then
    alter table public.shop_inventory add constraint shop_inventory_source_check check (source in ('coins', 'purchase', 'gift'));
  else
    alter table public.shop_inventory add constraint shop_inventory_source_check check (source in ('coins', 'gift'));
  end if;
end;
$$;

comment on function public.grant_coins(uuid, integer, text, text) is
  'Credits earned coins (levels, games, missions, achievements). Service role and SECURITY DEFINER code only. There are no real-money purchases.';

-- ---------------------------------------------------------------------------
-- Prices and mission-only pieces.

alter table public.shop_items add column if not exists unlock text
  check (unlock is null or unlock ~ '^[a-z0-9_]{3,40}$');

do $$
declare
  c record;
begin
  if exists (select 1 from pg_constraint where conrelid = 'public.shop_items'::regclass and conname = 'shop_items_price_earned') then
    return;
  end if;
  for c in
    select conname from pg_constraint
    where conrelid = 'public.shop_items'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%price_coins%'
  loop
    execute format('alter table public.shop_items drop constraint %I', c.conname);
  end loop;
  update public.shop_items set price_coins = case rarity
    when 'comune' then 120
    when 'leggendario' then (round(price_coins * 1.6 / 50) * 50)::integer
    else price_coins
  end;
  alter table public.shop_items add constraint shop_items_price_earned check (
    case
      when unlock is not null then price_coins = 0 and rarity <> 'base'
      else case rarity
        when 'base' then price_coins = 0
        when 'comune' then price_coins = 120
        when 'raro' then price_coins = 700
        when 'epico' then price_coins between 1100 and 1799
        when 'leggendario' then price_coins between 2900 and 8000
      end
    end);
end;
$$;

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand, collection, unlock) values
  ('hat.sbirro', 'hat', 'sbirro', 'leggendario', 0, 'Berretto da sbirro', 'Cop''s cap', '2026-11-22', 160, null, null, 'long_detective_wins_5'),
  ('border.badge', 'border', 'badge', 'epico', 0, 'Il distintivo', 'The badge', '2026-11-22', 820, null, null, 'long_finds_5'),
  ('border.noose', 'border', 'noose', 'raro', 0, 'Il cappio', 'The noose', '2026-11-22', 821, null, null, 'long_lynch_hits_3'),
  ('border.laurel', 'border', 'laurel', 'leggendario', 0, 'Alloro d''oro', 'Golden laurel', '2026-11-22', 822, null, null, 'long_wins_50'),
  ('nameStyle.moonlight', 'nameStyle', 'moonlight', 'raro', 0, 'Chiaro di luna', 'Moonlight', '2026-11-22', 920, null, null, 'long_nights_10'),
  ('nameStyle.bloodInk', 'nameStyle', 'bloodInk', 'epico', 0, 'Inchiostro di sangue', 'Blood ink', '2026-11-22', 921, null, null, 'long_mafia_wins_10'),
  ('nameStyle.siren', 'nameStyle', 'siren', 'epico', 0, 'Sirena', 'Siren', '2026-11-22', 922, null, null, 'long_town_wins_10')
on conflict (id) do update set
  name_it = excluded.name_it, name_en = excluded.name_en, rarity = excluded.rarity,
  price_coins = excluded.price_coins, unlock = excluded.unlock, enabled = true;

-- A mission-only piece enters an inventory only as a gift.
create or replace function internal.mission_only_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source <> 'gift' and exists (select 1 from public.shop_items where id = new.item_id and unlock is not null) then
    raise exception 'mission_only';
  end if;
  return new;
end;
$$;
revoke all on function internal.mission_only_guard() from public, anon, authenticated;
drop trigger if exists shop_inventory_mission_only on public.shop_inventory;
create trigger shop_inventory_mission_only before insert or update on public.shop_inventory
  for each row execute function internal.mission_only_guard();

-- ---------------------------------------------------------------------------
-- The mission pool: pools, reputation, items, long missions.

alter table internal.mission_defs drop constraint if exists mission_defs_cadence_check;
alter table internal.mission_defs add constraint mission_defs_cadence_check check (cadence in ('daily', 'weekly', 'long'));
alter table internal.mission_defs drop constraint if exists mission_defs_coins_check;
alter table internal.mission_defs add constraint mission_defs_coins_check check (coins between 0 and 1000);
alter table internal.mission_defs add column if not exists pool smallint not null default 1 check (pool between 0 and 3);
alter table internal.mission_defs add column if not exists reputation integer not null default 0 check (reputation between 0 and 100);
alter table internal.mission_defs add column if not exists item text references public.shop_items (id);

alter table internal.player_missions drop constraint if exists player_missions_cadence_check;
alter table internal.player_missions add constraint player_missions_cadence_check check (cadence in ('daily', 'weekly', 'long'));
alter table internal.player_missions add column if not exists claimed_at timestamptz;
-- Completed before this migration: already paid at completion.
update internal.player_missions set claimed_at = completed_at where completed_at is not null and claimed_at is null;
create index if not exists player_missions_open on internal.player_missions (profile_id)
  where completed_at is not null and claimed_at is null;

-- The pool, the same as missionPool in lib/online/game/progress.dart.
insert into internal.mission_defs (id, cadence, pool, metric, target, xp, coins, reputation, item) values
  ('daily_play_3', 'daily', 1, 'games', 3, 60, 30, 2, null),
  ('daily_nights_2', 'daily', 1, 'nights', 2, 60, 25, 2, null),
  ('daily_ranked_1', 'daily', 1, 'ranked_games', 1, 80, 35, 2, null),
  ('daily_friends_play_2', 'daily', 1, 'friends_games', 2, 60, 30, 2, null),
  ('daily_win_1', 'daily', 2, 'wins', 1, 80, 40, 3, null),
  ('daily_town_win_1', 'daily', 2, 'town_wins', 1, 90, 45, 3, null),
  ('daily_mafia_win_1', 'daily', 2, 'mafia_wins', 1, 100, 50, 3, null),
  ('daily_friends_win_2', 'daily', 2, 'friends_wins', 2, 100, 50, 3, null),
  ('daily_win_alive_1', 'daily', 2, 'wins_alive', 1, 90, 45, 3, null),
  ('daily_lynch_hits_3', 'daily', 3, 'lynch_hits', 3, 100, 45, 3, null),
  ('daily_survive_1', 'daily', 3, 'survived', 1, 70, 35, 2, null),
  ('daily_survive_2', 'daily', 3, 'survived', 2, 90, 45, 3, null),
  ('weekly_play_10', 'weekly', 1, 'games', 10, 200, 120, 8, null),
  ('weekly_play_15', 'weekly', 1, 'games', 15, 250, 160, 10, null),
  ('weekly_nights_12', 'weekly', 1, 'nights', 12, 250, 140, 8, null),
  ('weekly_ranked_5', 'weekly', 1, 'ranked_games', 5, 300, 180, 10, null),
  ('weekly_wins_4', 'weekly', 2, 'wins', 4, 250, 150, 10, null),
  ('weekly_wins_7', 'weekly', 2, 'wins', 7, 300, 200, 12, null),
  ('weekly_town_wins_3', 'weekly', 2, 'town_wins', 3, 250, 160, 10, null),
  ('weekly_mafia_wins_2', 'weekly', 2, 'mafia_wins', 2, 300, 180, 10, null),
  ('weekly_ranked_wins_3', 'weekly', 2, 'ranked_wins', 3, 350, 220, 12, null),
  ('weekly_neutral_win_1', 'weekly', 2, 'neutral_wins', 1, 300, 250, 12, null),
  ('weekly_lynch_hits_10', 'weekly', 3, 'lynch_hits', 10, 300, 180, 10, null),
  ('weekly_saves_2', 'weekly', 3, 'saves', 2, 300, 200, 12, null),
  ('weekly_finds_3', 'weekly', 3, 'finds', 3, 300, 180, 12, null),
  ('weekly_kills_5', 'weekly', 3, 'kills', 5, 300, 180, 10, null),
  ('weekly_detective_win_1', 'weekly', 3, 'role_win:detective', 1, 250, 160, 10, null),
  ('weekly_doctor_win_1', 'weekly', 3, 'role_win:medico', 1, 250, 160, 10, null),
  ('long_nights_10', 'long', 0, 'nights', 10, 0, 150, 15, 'nameStyle.moonlight'),
  ('long_lynch_hits_3', 'long', 0, 'lynch_hits', 3, 0, 150, 15, 'border.noose'),
  ('long_detective_wins_5', 'long', 0, 'role_win:detective', 5, 0, 400, 50, 'hat.sbirro'),
  ('long_finds_5', 'long', 0, 'finds', 5, 0, 300, 30, 'border.badge'),
  ('long_mafia_wins_10', 'long', 0, 'mafia_wins', 10, 0, 400, 40, 'nameStyle.bloodInk'),
  ('long_town_wins_10', 'long', 0, 'town_wins', 10, 0, 400, 40, 'nameStyle.siren'),
  ('long_wins_50', 'long', 0, 'wins', 50, 0, 800, 80, 'border.laurel'),
  ('long_games_25', 'long', 0, 'games', 25, 0, 300, 25, null),
  ('long_friends_games_20', 'long', 0, 'friends_games', 20, 0, 300, 30, null),
  ('long_ranked_games_20', 'long', 0, 'ranked_games', 20, 0, 400, 30, null),
  ('long_saves_5', 'long', 0, 'saves', 5, 0, 400, 40, null),
  ('long_survived_25', 'long', 0, 'survived', 25, 0, 400, 30, null),
  ('long_neutral_wins_3', 'long', 0, 'neutral_wins', 3, 0, 500, 40, null)
on conflict (id) do update
  set cadence = excluded.cadence, pool = excluded.pool, metric = excluded.metric, target = excluded.target,
      xp = excluded.xp, coins = excluded.coins, reputation = excluded.reputation, item = excluded.item, enabled = true;

-- ---------------------------------------------------------------------------
-- Dealing: one daily and one weekly from each pool, the same whoever asks
-- first; rows older than 35 days go at the same time.

create or replace function internal.ensure_missions(who uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c text;
  p date;
  k smallint;
begin
  delete from internal.player_missions
  where profile_id = who and cadence in ('daily', 'weekly') and period < (now() at time zone 'utc')::date - 35;
  foreach c in array array['daily', 'weekly'] loop
    p := internal.mission_period(c);
    if (select count(*) from internal.player_missions
        where profile_id = who and cadence = c and period = p) >= 3 then
      continue;
    end if;
    for k in 1..3 loop
      if exists (select 1 from internal.player_missions m join internal.mission_defs d on d.id = m.mission_id
                 where m.profile_id = who and m.cadence = c and m.period = p and d.pool = k) then
        continue;
      end if;
      insert into internal.player_missions (profile_id, cadence, period, mission_id)
      select who, c, p, d.id
      from internal.mission_defs d
      where d.cadence = c and d.pool = k and d.enabled
      order by md5(who::text || ':' || p::text || ':' || d.id)
      limit 1
      on conflict do nothing;
    end loop;
  end loop;
end;
$$;
revoke all on function internal.ensure_missions(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The results transaction: counters, missions (progress only: their coins
-- wait for the claim) and achievements. Called by record_match, in the same
-- transaction that saves the game.

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
    where pm.profile_id = who and pm.cadence = m ->> 'cadence' and pm.cadence <> 'long'
      and pm.period = (m ->> 'period')::date and pm.mission_id = m ->> 'id'
      and pm.completed_at is null;
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

-- record_match as in 20261122090000_role_collection, with the coins of the
-- game itself (Progression.winCoins and friends) added to the level coins
-- in a single 'match' ledger row.
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
    -- One ledger row per player per game: the game's own coins and the
    -- levels it reached ('match'). Achievements keep theirs.
    level_coins := coalesce((p ->> 'levelCoins')::integer, (p ->> 'coins')::integer, 0)
                   + coalesce((p ->> 'matchCoins')::integer, 0);
    if level_coins > 0 then
      perform public.grant_coins(who, level_coins, 'match', g.game_id::text || ':' || who::text);
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
-- Claiming: the only way mission coins, reputation and mission-only pieces
-- come in. Everything is checked here against what the server wrote.

create or replace function public.claim_mission(p_mission text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  d internal.mission_defs;
  done record;
  n integer := 0;
  balance integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into d from internal.mission_defs where id = p_mission and enabled;
  if not found then
    raise exception 'mission_not_found';
  end if;
  -- One claim at a time per person.
  perform 1 from public.profiles where id = me for update;
  if d.cadence = 'long' then
    if exists (select 1 from internal.player_missions where profile_id = me and cadence = 'long' and mission_id = d.id) then
      raise exception 'already_claimed';
    end if;
    if coalesce((select value from internal.player_stats where profile_id = me and metric = d.metric), 0) < d.target then
      raise exception 'not_completed';
    end if;
    insert into internal.player_missions (profile_id, cadence, period, mission_id, progress, completed_at, claimed_at)
    values (me, 'long', date '2000-01-01', d.id, d.target, now(), now());
    if d.coins > 0 then
      perform public.grant_coins(me, d.coins, 'mission', 'mission:' || me::text || ':long:' || d.id);
    end if;
    n := 1;
  else
    for done in
      update internal.player_missions set claimed_at = now()
      where profile_id = me and mission_id = d.id and cadence = d.cadence
        and completed_at is not null and claimed_at is null
      returning period
    loop
      if d.coins > 0 then
        perform public.grant_coins(me, d.coins, 'mission', 'mission:' || me::text || ':' || done.period::text || ':' || d.id);
      end if;
      n := n + 1;
    end loop;
    if n = 0 then
      if exists (select 1 from internal.player_missions where profile_id = me and mission_id = d.id and claimed_at is not null) then
        raise exception 'already_claimed';
      end if;
      raise exception 'not_completed';
    end if;
  end if;
  if d.reputation > 0 then
    insert into internal.player_stats as st (profile_id, metric, value)
    values (me, 'reputation', d.reputation * n)
    on conflict (profile_id, metric) do update set value = st.value + excluded.value;
  end if;
  if d.item is not null then
    insert into public.shop_inventory (profile_id, item_id, source) values (me, d.item, 'gift')
    on conflict do nothing;
  end if;
  select coins into balance from public.profiles where id = me;
  return jsonb_build_object('coins', d.coins * n, 'reputation', d.reputation * n, 'item', d.item, 'balance', balance);
end;
$$;
revoke all on function public.claim_mission(text) from public, anon;
grant execute on function public.claim_mission(text) to authenticated;

-- ---------------------------------------------------------------------------
-- What the phone reads: this period's missions, older ones still to claim,
-- every long mission with its progress, the counters (reputation among
-- them) and the achievements.

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
               'progress', m.progress, 'xp', d.xp, 'coins', d.coins, 'reputation', d.reputation,
               'item', d.item, 'pool', d.pool,
               'completed', m.completed_at is not null,
               'claimed', m.claimed_at is not null,
               'late', m.period <> internal.mission_period(m.cadence),
               'ends_at', extract(epoch from (
                 (m.period + case m.cadence when 'weekly' then 7 else 1 end)::timestamp
                 at time zone 'utc')) * 1000)
             order by m.cadence, d.pool, m.period, m.mission_id)
      from internal.player_missions m
      join internal.mission_defs d on d.id = m.mission_id
      where m.profile_id = me and m.cadence in ('daily', 'weekly')
        and (m.period = internal.mission_period(m.cadence)
             or (m.completed_at is not null and m.claimed_at is null))), '[]'::jsonb)
      || coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', d.id, 'cadence', 'long', 'metric', d.metric, 'target', d.target,
               'progress', least(d.target, coalesce(st.value, 0)), 'xp', 0, 'coins', d.coins,
               'reputation', d.reputation, 'item', d.item, 'pool', 0,
               'completed', coalesce(st.value, 0) >= d.target,
               'claimed', m.claimed_at is not null)
             order by (m.claimed_at is not null), d.target, d.id)
      from internal.mission_defs d
      left join internal.player_stats st on st.profile_id = me and st.metric = d.metric
      left join internal.player_missions m on m.profile_id = me and m.cadence = 'long' and m.mission_id = d.id
      where d.cadence = 'long' and d.enabled), '[]'::jsonb),
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
