-- Ranked waiting lobbies: no endless loading screen. Queueing seats a
-- player at once in an open ranked lobby (same language, same conduct
-- class, rating band widening with the wait) or opens a new one. Everyone
-- in it sees the seats fill live and can chat (moderated as any lobby chat).
--
-- The table size is fixed: exactly internal.config 'ranked_size' (12)
-- players, never fewer, never more. When the lobby is full a short
-- countdown ('ranked_countdown', 10 s) starts; if someone leaves during it,
-- it stops and the lobby waits for a replacement. When it ends the server
-- starts the game from the lobby. Leaving a lobby carries no penalty.
-- Lobbies waiting longer than 'ranked_merge_after' (60 s) merge, but only
-- when together they fit in one table.
--
--   internal.ranked_queue.room_id  the lobby a queued player sits in (null
--                                  for the instant before placement). The
--                                  row stays while in the lobby: ranked_status
--                                  keeps it warm, a phone silent for 20 s
--                                  leaves the lobby.
--   public.rooms.starts_at         the countdown's end, null while waiting.
--
-- TEST ONLY: with 'ranked_test_humans' set, that many people are enough to
-- start the countdown; at the start the table is filled with bots up to the
-- size and the room is test_match, not ranked (as before).

alter table public.rooms add column if not exists starts_at timestamptz;

alter table internal.ranked_queue
  add column if not exists room_id uuid references public.rooms (id) on delete set null;
create index if not exists ranked_queue_by_room on internal.ranked_queue (room_id);

insert into internal.config (key, value) values
  ('ranked_countdown', '10'),
  ('ranked_merge_after', '60')
on conflict (key) do nothing;
update internal.config set value = '12' where key = 'ranked_size';
delete from internal.config where key in ('ranked_min_size', 'ranked_max_size', 'ranked_relax_after');

-- Lobby chat is open in ranked lobbies; once the game starts, only the
-- game's chats.
create or replace function public._no_lobby_chat_in_matched_rooms()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.channel = 'lobby' and exists (
    select 1 from public.rooms where id = new.room_id and (ranked or test_match) and status <> 'lobby'
  ) then
    raise exception 'chat_closed';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lobby helpers

-- How many people make a lobby ready: the fixed size, or the test number.
create or replace function internal.ranked_need(test boolean)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when test then least(internal.config_int('ranked_size', 12),
                                   greatest(1, internal.config_int('ranked_test_humans', 1)))
              else internal.config_int('ranked_size', 12) end;
$$;
revoke all on function internal.ranked_need(boolean) from public, anon, authenticated;

-- Starts the countdown when the lobby is ready, stops it when it is not.
create or replace function internal.ranked_countdown(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.rooms;
  n integer;
begin
  select * into r from public.rooms where id = room for update;
  if not found or r.status <> 'lobby' or not (r.ranked or r.test_match) then
    return;
  end if;
  select count(*) into n from public.room_members where room_id = room and left_at is null;
  if n >= internal.ranked_need(r.test_match) then
    if r.starts_at is null then
      update public.rooms
      set starts_at = now() + make_interval(secs => internal.config_int('ranked_countdown', 10))
      where id = room;
    end if;
  elsif r.starts_at is not null then
    update public.rooms set starts_at = null where id = room;
  end if;
end;
$$;
revoke all on function internal.ranked_countdown(uuid) from public, anon, authenticated;

-- Seats [who] in [room] at the first free seat (matcher only).
create or replace function internal.ranked_seat(room uuid, who uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  free integer;
begin
  select min(s) into free from generate_series(1, internal.config_int('ranked_size', 12)) s
  where not exists (select 1 from public.room_members where room_id = room and seat = s and left_at is null);
  if free is null then
    raise exception 'room_full';
  end if;
  perform set_config('oberta.matcher', 'on', true);
  insert into public.room_members (room_id, profile_id, seat) values (room, who, free)
  on conflict (room_id, profile_id) do update set seat = excluded.seat, joined_at = now(), left_at = null;
  update internal.ranked_queue set room_id = room where profile_id = who;
  perform set_config('oberta.matcher', 'off', true);
end;
$$;
revoke all on function internal.ranked_seat(uuid, uuid) from public, anon, authenticated;

-- Leaving a ranked lobby, whichever way (leave_ranked_queue, leave_room,
-- a silent phone): out of the queue, countdown re-checked. No penalty.
create or replace function internal.ranked_lobby_left()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.left_at is null and new.left_at is not null and exists (
    select 1 from public.rooms where id = new.room_id and (ranked or test_match) and status = 'lobby'
  ) then
    if coalesce(current_setting('oberta.matcher', true), '') <> 'on' then
      delete from internal.ranked_queue where profile_id = new.profile_id;
    end if;
    perform internal.ranked_countdown(new.room_id);
  end if;
  return new;
end;
$$;
revoke all on function internal.ranked_lobby_left() from public, anon, authenticated;
drop trigger if exists ranked_lobby_left on public.room_members;
create trigger ranked_lobby_left
  after update of left_at on public.room_members
  for each row execute function internal.ranked_lobby_left();

-- The rating band for a wait: 5 points, one more every 10 s, anyone after 5 min.
create or replace function internal.ranked_band(waited double precision)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select case when waited > 300 then 1e9 else 5 + waited / 10 end;
$$;
revoke all on function internal.ranked_band(double precision) from public, anon, authenticated;

-- Places a queued player: the fullest fitting lobby, or a new one.
create or replace function internal.ranked_place(who uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  q internal.ranked_queue;
  size integer := internal.config_int('ranked_size', 12);
  test boolean := internal.config_int('ranked_test_humans', 0) > 0;
  mine double precision;
  low boolean;
  target uuid;
  new_code text;
begin
  select * into q from internal.ranked_queue where profile_id = who for update;
  if not found or q.room_id is not null then
    return q.room_id;
  end if;
  mine := internal.ordinal(who, q.language);
  low := coalesce((select score from internal.conduct where profile_id = who), 100) < 70;

  select r.id into target
  from public.rooms r
  cross join lateral (
    select count(*) as n,
           avg(internal.ordinal(m.profile_id, q.language)) as rating,
           bool_and(coalesce(c.score, 100) < 70) as all_low,
           bool_or(coalesce(c.score, 100) < 70) as any_low,
           max(extract(epoch from now() - coalesce(rq.joined_at, m.joined_at))) as waited
    from public.room_members m
    left join internal.conduct c on c.profile_id = m.profile_id
    left join internal.ranked_queue rq on rq.profile_id = m.profile_id
    where m.room_id = r.id and m.left_at is null
  ) s
  where r.status = 'lobby' and r.language = q.language
    and (r.ranked or r.test_match) and r.test_match = test
    and s.n between 1 and size - 1
    and (case when low then s.all_low else not s.any_low end)
    and abs(s.rating - mine) <= internal.ranked_band(greatest(s.waited, extract(epoch from now() - q.joined_at)))
  order by s.n desc, r.created_at
  limit 1
  for update of r skip locked;

  if target is null then
    loop
      select string_agg(substr(alphabet, get_byte(uuid_send(gen_random_uuid()), 0) % length(alphabet) + 1, 1), '')
        into new_code
        from generate_series(1, 6);
      begin
        insert into public.rooms (code, host, language, max_players, ranked, test_match, bots)
        values (new_code, who, q.language, size, not test, test, 0)
        returning id into target;
        exit;
      exception when unique_violation then
      end;
    end loop;
  end if;
  perform internal.ranked_seat(target, who);
  perform internal.ranked_countdown(target);
  return target;
end;
$$;
revoke all on function internal.ranked_place(uuid) from public, anon, authenticated;

-- Starts a lobby whose countdown is over: bots only in a test match.
create or replace function internal.ranked_start(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.rooms;
  n integer;
  size integer := internal.config_int('ranked_size', 12);
  waited double precision;
  first uuid;
begin
  select * into r from public.rooms where id = room for update;
  if not found or r.status <> 'lobby' then
    return;
  end if;
  select count(*) into n from public.room_members where room_id = room and left_at is null;
  if n < internal.ranked_need(r.test_match) or n > size then
    update public.rooms set starts_at = null where id = room;
    return;
  end if;
  select avg(extract(epoch from now() - q.joined_at)) into waited
  from internal.ranked_queue q where q.room_id = room;
  select profile_id into first from public.room_members
  where room_id = room and left_at is null order by seat limit 1;
  update public.rooms
  set bots = case when r.test_match then size - n else 0 end, max_players = size, host = first, starts_at = null
  where id = room;
  delete from internal.ranked_queue where room_id = room;
  insert into internal.ranked_matches (room_id, language, players, wait_seconds, test)
  values (room, r.language, n, coalesce(waited, 0), r.test_match);
  perform internal.begin_game(room, first);
end;
$$;
revoke all on function internal.ranked_start(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The queue, now a door into a lobby

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
  size integer := internal.config_int('ranked_size', 12);
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
  where m.profile_id = me and m.left_at is null and (r.ranked or r.test_match) and r.status in ('lobby', 'playing')
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

-- Queues and seats the caller in a lobby right away. Calling it again with
-- the same language keeps the seat; another language moves them.
create or replace function public.enqueue_ranked(queue_language text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
  c internal.conduct;
  q internal.ranked_queue;
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
  select * into q from internal.ranked_queue where profile_id = me;
  if q.room_id is not null and q.language = queue_language then
    update internal.ranked_queue set seen_at = now() where profile_id = me;
    return public.ranked_status();
  end if;
  for other in
    select room_id from public.room_members where profile_id = me and left_at is null
  loop
    perform public._leave_room(other, me);
  end loop;
  insert into internal.ranked_queue as rq (profile_id, language)
  values (me, queue_language)
  on conflict (profile_id) do update
    set language = excluded.language,
        joined_at = case when rq.language = excluded.language then rq.joined_at else now() end,
        seen_at = now(),
        room_id = null;
  perform internal.ranked_place(me);
  return public.ranked_status();
end;
$$;

-- Out of the queue and out of the lobby (no penalty before the start).
create or replace function public.leave_ranked_queue()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  lobby uuid;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  delete from internal.ranked_queue where profile_id = me returning room_id into lobby;
  for lobby in
    select m.room_id from public.room_members m join public.rooms r on r.id = m.room_id
    where m.profile_id = me and m.left_at is null and (r.ranked or r.test_match) and r.status = 'lobby'
  loop
    perform public._leave_room(lobby, me);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- The matcher: places, merges, starts.

create or replace function internal.ranked_match()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  size integer := internal.config_int('ranked_size', 12);
  merge_after integer := internal.config_int('ranked_merge_after', 60);
  q record;
  small record;
  big uuid;
  who uuid;
  started integer := 0;
begin
  if not pg_try_advisory_xact_lock(hashtext('oberta.ranked_match')) then
    return 0;
  end if;

  -- Phones gone quiet leave their lobby and the queue.
  for q in select profile_id, room_id from internal.ranked_queue where seen_at < now() - interval '20 seconds' loop
    if q.room_id is not null then
      perform public._leave_room(q.room_id, q.profile_id);
    end if;
    delete from internal.ranked_queue where profile_id = q.profile_id;
  end loop;
  delete from internal.ranked_queue rq
  where exists (
    select 1 from public.room_members m join public.rooms r on r.id = m.room_id
    where m.profile_id = rq.profile_id and m.left_at is null and r.status = 'playing'
  );

  -- Anyone not seated yet (or whose lobby vanished) gets a seat.
  for q in select profile_id from internal.ranked_queue where room_id is null order by joined_at loop
    perform internal.ranked_place(q.profile_id);
  end loop;

  -- Lobbies waiting too long merge, smaller into larger, only to fit one table.
  for small in
    select r.id, r.language, r.test_match, count(m.*) as n
    from public.rooms r join public.room_members m on m.room_id = r.id and m.left_at is null
    where r.status = 'lobby' and (r.ranked or r.test_match) and r.starts_at is null
      and r.created_at < now() - make_interval(secs => merge_after)
    group by r.id
    order by count(m.*), r.created_at
  loop
    continue when not exists (select 1 from public.rooms where id = small.id and status = 'lobby');
    select r.id into big
    from public.rooms r
    where r.id <> small.id and r.status = 'lobby' and r.language = small.language
      and r.test_match = small.test_match and (r.ranked or r.test_match) and r.starts_at is null
      and (select count(*) from public.room_members m where m.room_id = r.id and m.left_at is null)
          between small.n and size - small.n
      and (
        (select bool_and(coalesce(c.score, 100) < 70) from public.room_members m
           left join internal.conduct c on c.profile_id = m.profile_id
           where m.room_id = r.id and m.left_at is null)
        = (select bool_and(coalesce(c.score, 100) < 70) from public.room_members m
           left join internal.conduct c on c.profile_id = m.profile_id
           where m.room_id = small.id and m.left_at is null)
      )
    order by r.created_at
    limit 1;
    continue when big is null;
    for who in select profile_id from public.room_members where room_id = small.id and left_at is null order by seat loop
      perform set_config('oberta.matcher', 'on', true);
      perform public._leave_room(small.id, who);
      perform internal.ranked_seat(big, who);
    end loop;
    perform internal.ranked_countdown(big);
  end loop;

  -- Countdowns over: the game starts.
  for q in
    select id from public.rooms
    where status = 'lobby' and (ranked or test_match) and starts_at is not null and starts_at <= now()
    order by starts_at
  loop
    perform internal.ranked_start(q.id);
    started := started + 1;
  end loop;
  return started;
end;
$$;
revoke all on function internal.ranked_match() from public, anon, authenticated;

-- Rooms rows are read by members through realtime/selects already; the
-- new column needs nothing more. The old one-shot opener stays unused.
