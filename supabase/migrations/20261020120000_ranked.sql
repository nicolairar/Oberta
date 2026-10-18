-- Ranked, first slice: a matchmaking queue per language, rooms the server
-- opens and starts by itself, results (experience, levels, coins, ratings)
-- written at the end of every online game, a match history, and penalties
-- for leaving ranked games.
--
--   internal.ranked_queue  who is waiting, per language (it/en). Joined with
--                          enqueue_ranked, left with leave_ranked_queue;
--                          ranked_status (polled by the phone every couple
--                          of seconds) says how it is going and keeps the
--                          seat warm: a phone silent for 20 s drops out.
--   internal.ranked_match  the matcher, run by the cron tick every 2 s. It
--                          takes the longest waiting player and the closest
--                          ratings within a band that widens with the wait,
--                          only among players of the same conduct class
--                          (frequent leavers play with frequent leavers).
--                          8 players; after 60 s of waiting, 6 to 10. It
--                          opens a ranked room (no host powers, no bots,
--                          no lobby chat) and starts the game at once.
--   public.ratings         Weng-Lin mu/sigma per profile per language. Only
--                          ranked games move it. Owner reads, nobody writes.
--   public.match_history   one row per person per game: role, outcome, XP,
--                          coins, rating change. Each reads only their own.
--   internal.conduct       hidden: abandon strikes, cooldown, conduct score.
--
-- Settling: the Edge Function, in the transaction that saves the game's
-- end, reads internal.settle_input, runs the Dart rules (engine.js,
-- obertaSettle: lib/online/game/match_rewards.dart) and saves the outcome
-- with internal.record_match. Friends games give XP too; their level-up
-- coins only for the first 5 friends games of the (UTC) day, and nothing at
-- all with fewer than two people at the table.
--
-- Penalties (ranked only): every abandon is a strike; the first two are
-- warnings, then 5, 15, 30, 60 minutes out of the queue. Each ranked game
-- finished without leaving removes a strike, 24 hours without abandons
-- clear them. Nothing about it is ever readable by a client, except the
-- cooldown's end (to say when one can play again) and a generic warning.
--
-- TEST ONLY: with internal.config 'ranked_test_humans' set (say '2'), that
-- many people in a queue are enough: the server fills the table with bots
-- and marks the room test_match, NOT ranked: no rating moves, no penalties.
-- Off by default (the key does not exist). To turn it on, in the SQL editor:
--   insert into internal.config values ('ranked_test_humans', '2')
--     on conflict (key) do update set value = excluded.value;
-- and off again: delete from internal.config where key = 'ranked_test_humans';

-- ---------------------------------------------------------------------------
-- Rooms

alter table public.rooms
  add column if not exists ranked boolean not null default false,
  add column if not exists test_match boolean not null default false;
alter table public.rooms drop constraint if exists rooms_ranked_without_bots;
alter table public.rooms
  add constraint rooms_ranked_without_bots check (not ranked or (bots = 0 and not test_match));

insert into internal.config (key, value) values
  ('ranked_size', '8'),
  ('ranked_min_size', '6'),
  ('ranked_max_size', '10'),
  ('ranked_relax_after', '60')
on conflict (key) do nothing;

create or replace function internal.config_int(name text, fallback integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select nullif(value, '')::integer from internal.config where key = name), fallback);
$$;
revoke all on function internal.config_int(text, integer) from public, anon, authenticated;

-- Bots never sit in a ranked game, whatever calls what.
create or replace function public._no_bots_in_ranked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.profile_id is null and exists (select 1 from public.rooms where id = new.room_id and ranked) then
    raise exception 'no_bots_in_ranked';
  end if;
  return new;
end;
$$;
revoke all on function public._no_bots_in_ranked() from public, anon, authenticated;
drop trigger if exists no_bots_in_ranked on public.game_seats;
create trigger no_bots_in_ranked
  before insert or update on public.game_seats
  for each row execute function public._no_bots_in_ranked();

-- Nobody joins a matched room by its code: only the matcher seats people
-- there. Anybody taking a seat anywhere leaves the ranked queue.
create or replace function public._room_member_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('oberta.matcher', true), '') <> 'on' then
    if exists (select 1 from public.rooms where id = new.room_id and (ranked or test_match)) then
      raise exception 'room_closed';
    end if;
    delete from internal.ranked_queue where profile_id = new.profile_id;
  end if;
  return new;
end;
$$;
revoke all on function public._room_member_rules() from public, anon, authenticated;

-- No lobby chat among strangers: in matched rooms only the game's chats.
create or replace function public._no_lobby_chat_in_matched_rooms()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.channel = 'lobby' and exists (select 1 from public.rooms where id = new.room_id and (ranked or test_match)) then
    raise exception 'chat_closed';
  end if;
  return new;
end;
$$;
revoke all on function public._no_lobby_chat_in_matched_rooms() from public, anon, authenticated;
drop trigger if exists no_lobby_chat_in_matched_rooms on public.game_chat;
create trigger no_lobby_chat_in_matched_rooms
  before insert on public.game_chat
  for each row execute function public._no_lobby_chat_in_matched_rooms();

-- ---------------------------------------------------------------------------
-- Tables

create table if not exists internal.ranked_queue (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  language text not null check (language in ('it', 'en')),
  joined_at timestamptz not null default now(),
  seen_at timestamptz not null default now()
);
create index if not exists ranked_queue_by_language on internal.ranked_queue (language, joined_at);
alter table internal.ranked_queue enable row level security;
revoke all on internal.ranked_queue from public, anon, authenticated;

drop trigger if exists room_member_rules on public.room_members;
create trigger room_member_rules
  before insert on public.room_members
  for each row execute function public._room_member_rules();

-- Matches formed, for the estimated wait.
create table if not exists internal.ranked_matches (
  id bigint generated always as identity primary key,
  room_id uuid,
  language text not null,
  players integer not null,
  wait_seconds double precision not null,
  test boolean not null default false,
  formed_at timestamptz not null default now()
);
create index if not exists ranked_matches_recent on internal.ranked_matches (language, formed_at);
alter table internal.ranked_matches enable row level security;
revoke all on internal.ranked_matches from public, anon, authenticated;

create table if not exists internal.conduct (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  strikes integer not null default 0 check (strikes >= 0),
  last_abandon_at timestamptz,
  cooldown_until timestamptz,
  score integer not null default 100 check (score between 0 and 100)
);
alter table internal.conduct enable row level security;
revoke all on internal.conduct from public, anon, authenticated;

create table if not exists public.ratings (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  language text not null check (language in ('it', 'en')),
  mu double precision not null default 25,
  sigma double precision not null default 8.333333333333334,
  games integer not null default 0,
  wins integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (profile_id, language)
);
alter table public.ratings enable row level security;
revoke all on public.ratings from anon, authenticated;
grant select on public.ratings to authenticated;
drop policy if exists "players read their own ratings" on public.ratings;
create policy "players read their own ratings"
  on public.ratings for select
  to authenticated
  using (profile_id = (select auth.uid()));

create table if not exists public.match_history (
  id bigint generated always as identity primary key,
  game_id uuid not null,
  room_id uuid,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  language text not null,
  ranked boolean not null,
  test_match boolean not null default false,
  players integer not null,
  seat text not null,
  role text not null,
  team text not null,
  winner text not null,
  won boolean not null,
  survived boolean not null,
  abandoned boolean not null,
  xp_gained integer not null,
  level_before integer not null,
  level_after integer not null,
  coins_gained integer not null,
  -- Ranked only: the change of the conservative rating (mu - 3 sigma), and
  -- where it ended up (for the tier).
  rating_delta double precision,
  ordinal_after double precision,
  played_at timestamptz not null default now(),
  unique (game_id, profile_id)
);
create index if not exists match_history_by_profile on public.match_history (profile_id, played_at desc);
alter table public.match_history enable row level security;
revoke all on public.match_history from anon, authenticated;
grant select on public.match_history to authenticated;
drop policy if exists "players read their own games" on public.match_history;
create policy "players read their own games"
  on public.match_history for select
  to authenticated
  using (profile_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Conduct and penalties

-- The conduct row of [who], created if missing, with 24 clean hours applied.
create or replace function internal.conduct_of(who uuid)
returns internal.conduct
language plpgsql
security definer
set search_path = ''
as $$
declare
  c internal.conduct;
begin
  insert into internal.conduct (profile_id) values (who) on conflict (profile_id) do nothing;
  update internal.conduct
  set strikes = case when last_abandon_at < now() - interval '24 hours' then 0 else strikes end
  where profile_id = who
  returning * into c;
  return c;
end;
$$;
revoke all on function internal.conduct_of(uuid) from public, anon, authenticated;

-- An abandon knows whether its game was ranked; a ranked one is a strike.
create or replace function internal.abandon_is_ranked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.ranked := exists (select 1 from public.rooms where id = new.room_id and ranked);
  return new;
end;
$$;
revoke all on function internal.abandon_is_ranked() from public, anon, authenticated;
drop trigger if exists abandon_is_ranked on internal.game_abandons;
create trigger abandon_is_ranked
  before insert on internal.game_abandons
  for each row execute function internal.abandon_is_ranked();

create or replace function internal.abandon_strike()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c internal.conduct;
  total integer;
begin
  if not new.ranked then
    return new;
  end if;
  c := internal.conduct_of(new.profile_id);
  total := c.strikes + 1;
  update internal.conduct
  set strikes = total,
      last_abandon_at = now(),
      score = greatest(0, score - 15),
      cooldown_until = case
        when total >= 3
          then now() + (array[5, 15, 30, 60])[least(total - 2, 4)] * interval '1 minute'
        else cooldown_until
      end
  where profile_id = new.profile_id;
  return new;
end;
$$;
revoke all on function internal.abandon_strike() from public, anon, authenticated;
drop trigger if exists abandon_strike on internal.game_abandons;
create trigger abandon_strike
  after insert on internal.game_abandons
  for each row execute function internal.abandon_strike();

-- ---------------------------------------------------------------------------
-- Starting games

-- Seats everyone in a room and starts the game: the people in seat order,
-- then the room's bots. The cards are dealt by the function.
create or replace function internal.begin_game(room uuid, starter uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.rooms;
  i integer := 0;
  m record;
  nato text[] := array['alfa', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel',
                       'india', 'juliett', 'kilo', 'lima', 'mike', 'november', 'oscar'];
begin
  select * into r from public.rooms where id = room for update;
  delete from public.game_intents where room_id = room;
  delete from public.game_seat_views where room_id = room;
  delete from public.game_seats where room_id = room;
  delete from public.game_chat where room_id = room and channel <> 'lobby';
  delete from internal.game_state where room_id = room;
  delete from public.game_public where room_id = room;

  for m in
    select rm.profile_id, p.handle
    from public.room_members rm join public.profiles p on p.id = rm.profile_id
    where rm.room_id = room and rm.left_at is null
    order by rm.seat
  loop
    i := i + 1;
    insert into public.game_seats (room_id, seat, profile_id, name, last_seen)
    values (room, 's' || i, m.profile_id, coalesce(m.handle, 'player' || i), now());
  end loop;
  for b in 1 .. r.bots loop
    i := i + 1;
    insert into public.game_seats (room_id, seat, profile_id, name)
    values (room, 's' || i, null, 'bot.' || nato[b]);
  end loop;

  insert into public.game_public (room_id, host, version, view) values (room, starter, 0, null);
  insert into internal.game_state (room_id, state, next_due_at) values (room, null, now());
  update public.rooms set status = 'playing' where id = room;
  perform internal.wake_game(room);
end;
$$;
revoke all on function internal.begin_game(uuid, uuid) from public, anon, authenticated;

-- The host starts a friends game. Matched rooms have no host powers.
create or replace function public.start_game(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  people integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into r from public.rooms where id = room for update;
  if not found or r.host <> me or r.ranked or r.test_match then
    raise exception 'not_allowed';
  end if;
  if r.status <> 'lobby' then
    raise exception 'room_closed';
  end if;
  select count(*) into people from public.room_members where room_id = room and left_at is null;
  if people + r.bots < 4 or people + r.bots > r.max_players then
    raise exception 'invalid_seats';
  end if;
  perform internal.begin_game(room, me);
end;
$$;
revoke all on function public.start_game(uuid) from public, anon;
grant execute on function public.start_game(uuid) to authenticated;

create or replace function public.set_room_bots(room uuid, count integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  people integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into r from public.rooms where id = room for update;
  if not found or r.host <> me or r.ranked or r.test_match then
    raise exception 'not_allowed';
  end if;
  if r.status <> 'lobby' then
    raise exception 'room_closed';
  end if;
  select count(*) into people from public.room_members where room_id = room and left_at is null;
  if count is null or count < 0 or count + people > r.max_players then
    raise exception 'room_full';
  end if;
  update public.rooms set bots = count where id = room;
end;
$$;
revoke all on function public.set_room_bots(uuid, integer) from public, anon;
grant execute on function public.set_room_bots(uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- The queue

create or replace function internal.ordinal(who uuid, lang text)
returns double precision
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select mu - 3 * sigma from public.ratings where profile_id = who and language = lang), 0);
$$;
revoke all on function internal.ordinal(uuid, text) from public, anon, authenticated;

-- How it is going, for the caller: in the queue or not, since when, how many
-- are waiting, the estimated wait, the matched room (when the server has
-- opened it), the cooldown's end and a generic warning after a strike.
-- Calling it says "still here": a queued phone silent for 20 s drops out.
create or replace function public.ranked_status()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  q internal.ranked_queue;
  c internal.conduct;
  waiting integer := 0;
  estimate double precision;
  matched uuid;
  is_test boolean;
  size integer := internal.config_int('ranked_size', 8);
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  update internal.ranked_queue set seen_at = now() where profile_id = me returning * into q;
  c := internal.conduct_of(me);
  if q.profile_id is not null then
    select count(*) into waiting from internal.ranked_queue where language = q.language;
    select avg(wait_seconds) into estimate
    from (
      select wait_seconds from internal.ranked_matches
      where language = q.language and not test and formed_at > now() - interval '1 day'
      order by formed_at desc limit 10
    ) recent;
    estimate := coalesce(estimate, 30 + greatest(0, size - waiting) * 15);
  end if;
  select r.id, r.test_match into matched, is_test
  from public.rooms r join public.room_members m on m.room_id = r.id
  where m.profile_id = me and m.left_at is null and (r.ranked or r.test_match) and r.status = 'playing'
  order by r.created_at desc
  limit 1;
  return jsonb_build_object(
    'queued', q.profile_id is not null,
    'language', q.language,
    'since', case when q.profile_id is null then null else (extract(epoch from q.joined_at) * 1000)::bigint end,
    'waiting', waiting,
    'estimate', case when estimate is null then null else round(estimate)::integer end,
    'room', matched,
    'test', coalesce(is_test, false),
    'cooldown_until', case when c.cooldown_until > now()
                           then (extract(epoch from c.cooldown_until) * 1000)::bigint end,
    'warning', c.strikes between 1 and 2 and c.last_abandon_at > now() - interval '24 hours'
  );
end;
$$;

-- Joins the ranked queue for [queue_language]. Signed in, with a handle,
-- not cooling down after abandons, not in a running game. Leaves any lobby.
-- Calling it again only switches the language (one queue per person).
create or replace function public.enqueue_ranked(queue_language text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
  c internal.conduct;
  other uuid;
begin
  if queue_language is null or queue_language not in ('it', 'en') then
    raise exception 'invalid_language';
  end if;
  c := internal.conduct_of(me);
  if c.cooldown_until > now() then
    raise exception 'ranked_cooldown';
  end if;
  if exists (
    select 1 from public.room_members m join public.rooms r on r.id = m.room_id
    where m.profile_id = me and m.left_at is null and r.status = 'playing'
  ) then
    raise exception 'already_in_game';
  end if;
  for other in
    select room_id from public.room_members where profile_id = me and left_at is null
  loop
    perform public._leave_room(other, me);
  end loop;
  insert into internal.ranked_queue as q (profile_id, language)
  values (me, queue_language)
  on conflict (profile_id) do update
    set language = excluded.language,
        joined_at = case when q.language = excluded.language then q.joined_at else now() end,
        seen_at = now();
  return public.ranked_status();
end;
$$;

create or replace function public.leave_ranked_queue()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  delete from internal.ranked_queue where profile_id = auth.uid();
end;
$$;

revoke all on function public.ranked_status() from public, anon;
revoke all on function public.enqueue_ranked(text) from public, anon;
revoke all on function public.leave_ranked_queue() from public, anon;
grant execute on function public.ranked_status() to authenticated;
grant execute on function public.enqueue_ranked(text) to authenticated;
grant execute on function public.leave_ranked_queue() to authenticated;

-- ---------------------------------------------------------------------------
-- The matcher

-- Opens a matched room for [players] (in queue order) and starts it. A test
-- match fills the table with bots and is not ranked.
create or replace function internal.open_matched_room(lang text, players uuid[], test boolean)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  new_code text;
  room public.rooms;
  n integer := array_length(players, 1);
  bots integer := case when test then greatest(0, internal.config_int('ranked_size', 8) - n) else 0 end;
  waited double precision;
  who uuid;
  other uuid;
  i integer := 0;
begin
  select avg(extract(epoch from now() - joined_at)) into waited
  from internal.ranked_queue where profile_id = any(players);
  perform set_config('oberta.matcher', 'on', true);
  foreach who in array players loop
    for other in
      select room_id from public.room_members where profile_id = who and left_at is null
    loop
      perform public._leave_room(other, who);
    end loop;
  end loop;
  loop
    select string_agg(substr(alphabet, get_byte(uuid_send(gen_random_uuid()), 0) % length(alphabet) + 1, 1), '')
      into new_code
      from generate_series(1, 6);
    begin
      insert into public.rooms (code, host, language, max_players, ranked, test_match, bots)
      values (new_code, players[1], lang, n + bots, not test, test, bots)
      returning * into room;
      exit;
    exception when unique_violation then
    end;
  end loop;
  foreach who in array players loop
    i := i + 1;
    insert into public.room_members (room_id, profile_id, seat) values (room.id, who, i);
  end loop;
  perform set_config('oberta.matcher', 'off', true);
  delete from internal.ranked_queue where profile_id = any(players);
  insert into internal.ranked_matches (room_id, language, players, wait_seconds, test)
  values (room.id, lang, n, coalesce(waited, 0), test);
  perform internal.begin_game(room.id, players[1]);
  return room.id;
end;
$$;
revoke all on function internal.open_matched_room(text, uuid[], boolean) from public, anon, authenticated;

-- Forms every game it can. Returns how many rooms it opened.
create or replace function internal.ranked_match()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  size integer := internal.config_int('ranked_size', 8);
  min_size integer := internal.config_int('ranked_min_size', 6);
  max_size integer := internal.config_int('ranked_max_size', 10);
  relax integer := internal.config_int('ranked_relax_after', 60);
  test_humans integer := internal.config_int('ranked_test_humans', 0);
  lang text;
  anchor internal.ranked_queue;
  skipped uuid[];
  waited double precision;
  band double precision;
  low boolean;
  mine double precision;
  picked uuid[];
  opened integer := 0;
begin
  -- One matcher at a time.
  if not pg_try_advisory_xact_lock(hashtext('oberta.ranked_match')) then
    return 0;
  end if;
  -- Phones gone quiet, and people already playing, leave the queue.
  delete from internal.ranked_queue q
  where q.seen_at < now() - interval '20 seconds'
     or exists (
       select 1 from public.room_members m join public.rooms r on r.id = m.room_id
       where m.profile_id = q.profile_id and m.left_at is null and r.status = 'playing'
     );

  foreach lang in array array['it', 'en'] loop
    skipped := array[]::uuid[];
    loop
      select * into anchor from internal.ranked_queue
      where language = lang and not (profile_id = any(skipped))
      order by joined_at, profile_id
      limit 1;
      exit when anchor.profile_id is null;
      waited := extract(epoch from now() - anchor.joined_at);

      if test_humans > 0 then
        -- TEST ONLY: whoever is waiting, with bots; never ranked.
        select array_agg(profile_id order by joined_at) into picked
        from (
          select profile_id, joined_at from internal.ranked_queue
          where language = lang order by joined_at limit size
        ) t;
        if coalesce(array_length(picked, 1), 0) >= test_humans then
          perform internal.open_matched_room(lang, picked, true);
          opened := opened + 1;
          continue;
        end if;
        exit;
      end if;

      -- The rating band widens with the wait: 5 points, then one more every
      -- 10 seconds; after 5 minutes anyone. Conduct classes never mix.
      band := case when waited > 300 then 1e9 else 5 + waited / 10 end;
      mine := internal.ordinal(anchor.profile_id, lang);
      low := coalesce((select score from internal.conduct where profile_id = anchor.profile_id), 100) < 70;
      select array_agg(profile_id order by is_anchor desc, gap, joined_at) into picked
      from (
        select q.profile_id, q.joined_at, q.profile_id = anchor.profile_id as is_anchor,
               abs(internal.ordinal(q.profile_id, lang) - mine) as gap
        from internal.ranked_queue q
        left join internal.conduct c on c.profile_id = q.profile_id
        where q.language = lang
          and (coalesce(c.score, 100) < 70) = low
          and abs(internal.ordinal(q.profile_id, lang) - mine) <= band
        order by is_anchor desc, gap, q.joined_at
        limit case when waited > relax then max_size else size end
      ) t;
      if coalesce(array_length(picked, 1), 0) >= (case when waited > relax then min_size else size end) then
        perform internal.open_matched_room(lang, picked, false);
        opened := opened + 1;
      else
        skipped := skipped || anchor.profile_id;
      end if;
    end loop;
  end loop;
  return opened;
end;
$$;
revoke all on function internal.ranked_match() from public, anon, authenticated;

-- The tick: the matcher, then one wake if any game has something due.
create or replace function internal.game_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform internal.ranked_match();
  if exists (
    select 1 from internal.game_state g
    where g.next_due_at <= now()
       or exists (select 1 from public.game_intents i where i.room_id = g.room_id)
  ) then
    perform internal.wake_game(null);
  end if;
end;
$$;
revoke all on function internal.game_tick() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Results

-- What the rules need to settle a finished game ([result] is the engine's:
-- winner, and per human seat team, role, won, survived, abandoned). Null if
-- it was settled already, or there is nothing to settle.
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
  select coalesce(jsonb_agg(jsonb_build_object(
           'profile', s.profile_id,
           'seat', s.seat,
           'team', result -> 'seats' -> s.seat ->> 'team',
           'role', result -> 'seats' -> s.seat ->> 'role',
           'won', coalesce((result -> 'seats' -> s.seat ->> 'won')::boolean, false),
           'survived', coalesce((result -> 'seats' -> s.seat ->> 'survived')::boolean, false),
           'abandoned', coalesce((result -> 'seats' -> s.seat ->> 'abandoned')::boolean, false),
           'level', p.level,
           'xp', p.xp,
           'mu', coalesce(rt.mu, 25),
           'sigma', coalesce(rt.sigma, 25.0 / 3),
           'wonToday', exists (
             select 1 from public.match_history h
             where h.profile_id = s.profile_id and h.won and h.played_at >= today),
           'friendsGamesToday', (
             select count(*) from public.match_history h
             where h.profile_id = s.profile_id and not h.ranked and h.played_at >= today)
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

-- Saves what the rules decided: levels and experience, coins through the
-- ledger, ratings (ranked), the history, and a strike off for every ranked
-- game finished without leaving. Settles a game once.
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
    if (p ->> 'coins')::integer > 0 then
      perform public.grant_coins(who, (p ->> 'coins')::integer, 'level_up', g.game_id::text || ':' || who::text);
    end if;
    if r.ranked then
      insert into public.ratings as rt (profile_id, language, mu, sigma, games, wins, updated_at)
      values (who, r.language, (p ->> 'mu')::double precision, (p ->> 'sigma')::double precision, 1,
              case when (p ->> 'won')::boolean then 1 else 0 end, now())
      on conflict (profile_id, language) do update
        set mu = excluded.mu, sigma = excluded.sigma, games = rt.games + 1,
            wins = rt.wins + excluded.wins, updated_at = now();
      if not (p ->> 'abandoned')::boolean then
        perform internal.conduct_of(who);
        update internal.conduct
        set strikes = greatest(0, strikes - 1), score = least(100, score + 5)
        where profile_id = who;
      end if;
    end if;
    insert into public.match_history (
      game_id, room_id, profile_id, language, ranked, test_match, players, seat, role, team, winner,
      won, survived, abandoned, xp_gained, level_before, level_after, coins_gained, rating_delta, ordinal_after)
    values (
      g.game_id, room, who, r.language, r.ranked, r.test_match,
      (select count(*) from public.game_seats where room_id = room),
      p ->> 'seat', coalesce(p ->> 'role', '?'), coalesce(p ->> 'team', '?'), coalesce(winner, '?'),
      (p ->> 'won')::boolean, (p ->> 'survived')::boolean, (p ->> 'abandoned')::boolean,
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
