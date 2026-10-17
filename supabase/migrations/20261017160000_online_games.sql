-- Online games in friends rooms. The authority is the host's phone: it runs
-- the game engine, validates every intent and publishes what each seat may
-- see. The database is only the pipe, and its policies make sure secrets
-- never reach the wrong phone:
--
--   game_public      the public board, readable by everyone in the room;
--   game_seat_views  one row per human seat, readable ONLY by that seat's
--                    player (their role, their findings, their moves);
--   game_intents     what players ask to do, written only through
--                    submit_intent (which stamps the caller's own seat) and
--                    readable only by the host who runs the game;
--   game_host_state  the engine snapshot, so a host whose app restarts can
--                    pick the game up again; readable only by that host;
--   game_seats       who sits where (bots have no profile); functions only.
--
-- Clients write nothing directly: start_game, publish_game and
-- submit_intent check who is calling. Realtime postgres_changes respects
-- the select policies, so each phone is only told about rows it may read.
-- Test bots live on the host's phone; the room counts them so the lobby
-- shows them to everyone and keeps a seat for each.

alter table public.rooms
  add column if not exists bots smallint not null default 0 check (bots between 0 and 15);

create table if not exists public.game_public (
  room_id uuid primary key references public.rooms (id) on delete cascade,
  -- The profile whose phone runs this game. It does not follow the room's
  -- host role: if that phone leaves, nobody else inherits the secrets.
  host uuid not null references public.profiles (id) on delete cascade,
  version integer not null default 0 check (version >= 0),
  view jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.game_seats (
  room_id uuid not null references public.rooms (id) on delete cascade,
  seat text not null check (seat ~ '^s[0-9]{1,2}$'),
  -- Null for a bot.
  profile_id uuid references public.profiles (id) on delete cascade,
  name text not null,
  primary key (room_id, seat),
  unique (room_id, profile_id)
);

create table if not exists public.game_seat_views (
  room_id uuid not null references public.rooms (id) on delete cascade,
  seat text not null,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  version integer not null,
  view jsonb not null,
  primary key (room_id, seat)
);

create index if not exists game_seat_views_by_profile on public.game_seat_views (profile_id);

create table if not exists public.game_intents (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms (id) on delete cascade,
  seat text not null,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  intent jsonb not null check (jsonb_typeof(intent) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists game_intents_by_room on public.game_intents (room_id, id);

create table if not exists public.game_host_state (
  room_id uuid primary key references public.rooms (id) on delete cascade,
  host uuid not null references public.profiles (id) on delete cascade,
  version integer not null default 0,
  state jsonb
);

alter table public.game_public enable row level security;
alter table public.game_seats enable row level security;
alter table public.game_seat_views enable row level security;
alter table public.game_intents enable row level security;
alter table public.game_host_state enable row level security;

revoke all on public.game_public from anon, authenticated;
revoke all on public.game_seats from anon, authenticated;
revoke all on public.game_seat_views from anon, authenticated;
revoke all on public.game_intents from anon, authenticated;
revoke all on public.game_host_state from anon, authenticated;

grant select on public.game_public to authenticated;
grant select on public.game_seat_views to authenticated;
grant select on public.game_intents to authenticated;
grant select on public.game_host_state to authenticated;

drop policy if exists "members see the board" on public.game_public;
create policy "members see the board"
  on public.game_public for select
  to authenticated
  using ((select public.is_room_member(room_id)));

drop policy if exists "players see only their own seat" on public.game_seat_views;
create policy "players see only their own seat"
  on public.game_seat_views for select
  to authenticated
  using (profile_id = (select auth.uid()) and (select public.is_room_member(room_id)));

-- Outside RLS on purpose, like is_room_member.
create or replace function public.is_game_host(room uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.game_public
    where room_id = room and host = auth.uid()
  ) and public.is_room_member(room);
$$;

revoke all on function public.is_game_host(uuid) from public, anon;
grant execute on function public.is_game_host(uuid) to authenticated;

drop policy if exists "only the host reads intents" on public.game_intents;
create policy "only the host reads intents"
  on public.game_intents for select
  to authenticated
  using ((select public.is_game_host(room_id)));

drop policy if exists "only the host reads its saved game" on public.game_host_state;
create policy "only the host reads its saved game"
  on public.game_host_state for select
  to authenticated
  using (host = (select auth.uid()) and (select public.is_room_member(room_id)));

-- The host sets how many test bots sit in the lobby.
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
  if not found or r.host <> me then
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

-- Starts a game: [seats] is [{seat, profile_id | null, name}] in seat
-- order. Every player in the room must have exactly one seat; humans are
-- named by their handle (whatever the host sends); bots by a bot name.
create or replace function public.start_game(room uuid, seats jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  s jsonb;
  pid uuid;
  people integer;
  humans integer := 0;
  total integer;
  i integer := 0;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into r from public.rooms where id = room for update;
  if not found or r.host <> me then
    raise exception 'not_allowed';
  end if;
  if r.status <> 'lobby' then
    raise exception 'room_closed';
  end if;
  if seats is null or jsonb_typeof(seats) <> 'array' then
    raise exception 'invalid_seats';
  end if;
  total := jsonb_array_length(seats);
  if total < 4 or total > r.max_players then
    raise exception 'invalid_seats';
  end if;

  delete from public.game_intents where room_id = room;
  delete from public.game_seat_views where room_id = room;
  delete from public.game_seats where room_id = room;
  delete from public.game_host_state where room_id = room;
  delete from public.game_public where room_id = room;

  for s in select value from jsonb_array_elements(seats)
  loop
    i := i + 1;
    if s ->> 'seat' is distinct from 's' || i then
      raise exception 'invalid_seats';
    end if;
    pid := nullif(s ->> 'profile_id', '')::uuid;
    if pid is null then
      if coalesce(s ->> 'name', '') !~ '^bot\.[a-z]{1,8}$' then
        raise exception 'invalid_seats';
      end if;
      insert into public.game_seats (room_id, seat, profile_id, name)
      values (room, s ->> 'seat', null, s ->> 'name');
    else
      if not exists (
        select 1 from public.room_members where room_id = room and profile_id = pid and left_at is null
      ) then
        raise exception 'invalid_seats';
      end if;
      humans := humans + 1;
      insert into public.game_seats (room_id, seat, profile_id, name)
      select room, s ->> 'seat', pid, p.handle from public.profiles p where p.id = pid;
    end if;
  end loop;

  select count(*) into people from public.room_members where room_id = room and left_at is null;
  if humans <> people then
    raise exception 'invalid_seats';
  end if;

  insert into public.game_public (room_id, host, version, view) values (room, me, 0, null);
  insert into public.game_host_state (room_id, host, version, state) values (room, me, 0, null);
  update public.rooms set status = 'playing' where id = room;
exception
  when unique_violation then
    raise exception 'invalid_seats';
end;
$$;

-- The host publishes a new version of the game: the public board, one view
-- per human seat ([seat_views] is {"s1": {...}, ...}), its own saved state,
-- and the last intent it has handled (those are deleted). Each view goes to
-- the profile seated there, whatever the host claims. [finished] reopens
-- the room's lobby.
create or replace function public.publish_game(
  room uuid,
  new_version integer,
  public_view jsonb,
  seat_views jsonb,
  host_state jsonb,
  last_intent bigint default null,
  finished boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  g public.game_public;
  seated record;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into g from public.game_public where room_id = room for update;
  if not found or g.host <> me or not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  if new_version is null or new_version <= g.version then
    raise exception 'stale_version';
  end if;
  if seat_views is null or jsonb_typeof(seat_views) <> 'object' then
    raise exception 'invalid_views';
  end if;

  update public.game_public
  set version = new_version, view = public_view, updated_at = now()
  where room_id = room;

  for seated in
    select seat, profile_id from public.game_seats where room_id = room and profile_id is not null
  loop
    if seat_views ? seated.seat then
      insert into public.game_seat_views (room_id, seat, profile_id, version, view)
      values (room, seated.seat, seated.profile_id, new_version, seat_views -> seated.seat)
      on conflict (room_id, seat) do update
        set profile_id = excluded.profile_id, version = excluded.version, view = excluded.view;
    end if;
  end loop;

  update public.game_host_state set version = new_version, state = host_state where room_id = room;

  if last_intent is not null then
    delete from public.game_intents where room_id = room and id <= last_intent;
  end if;
  if finished then
    update public.rooms set status = 'lobby' where id = room;
  end if;
end;
$$;

-- A player asks to do something. The seat is the caller's own, never one
-- picked by the client. Returns the intent's id.
create or replace function public.submit_intent(room uuid, intent jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  my_seat text;
  pending integer;
  new_id bigint;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room)
     or not exists (select 1 from public.rooms where id = room and status = 'playing') then
    raise exception 'not_allowed';
  end if;
  select seat into my_seat from public.game_seats where room_id = room and profile_id = me;
  if my_seat is null then
    raise exception 'not_allowed';
  end if;
  if intent is null or jsonb_typeof(intent) <> 'object' or intent ->> 'seat' is distinct from my_seat then
    raise exception 'not_your_seat';
  end if;
  if octet_length(intent::text) > 512 then
    raise exception 'invalid_intent';
  end if;
  select count(*) into pending from public.game_intents where room_id = room and profile_id = me;
  if pending >= 20 then
    raise exception 'too_many_intents';
  end if;
  insert into public.game_intents (room_id, seat, profile_id, intent)
  values (room, my_seat, me, intent)
  returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.set_room_bots(uuid, integer) from public, anon;
revoke all on function public.start_game(uuid, jsonb) from public, anon;
revoke all on function public.publish_game(uuid, integer, jsonb, jsonb, jsonb, bigint, boolean) from public, anon;
revoke all on function public.submit_intent(uuid, jsonb) from public, anon;
grant execute on function public.set_room_bots(uuid, integer) to authenticated;
grant execute on function public.start_game(uuid, jsonb) to authenticated;
grant execute on function public.publish_game(uuid, integer, jsonb, jsonb, jsonb, bigint, boolean) to authenticated;
grant execute on function public.submit_intent(uuid, jsonb) to authenticated;

-- Joining counts the bots too: a room with bots has fewer seats for people.
create or replace function public.join_room(join_code text)
returns public.rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
  room public.rooms;
  free_seat smallint;
  people integer;
  other uuid;
begin
  select * into room from public.rooms
  where code = upper(btrim(join_code)) and status <> 'ended'
  for update;
  if not found then
    raise exception 'room_not_found';
  end if;

  if exists (
    select 1 from public.room_members
    where room_id = room.id and profile_id = me and left_at is null
  ) then
    return room;
  end if;

  if room.status <> 'lobby' then
    raise exception 'room_closed';
  end if;

  select count(*) into people from public.room_members where room_id = room.id and left_at is null;
  if people + room.bots >= room.max_players then
    raise exception 'room_full';
  end if;

  select min(s) into free_seat
  from generate_series(1, room.max_players) as s
  where not exists (
    select 1 from public.room_members
    where room_id = room.id and seat = s and left_at is null
  );
  if free_seat is null then
    raise exception 'room_full';
  end if;

  for other in
    select room_id from public.room_members where profile_id = me and left_at is null
  loop
    perform public._leave_room(other, me);
  end loop;

  insert into public.room_members (room_id, profile_id, seat)
  values (room.id, me, free_seat)
  on conflict (room_id, profile_id)
    do update set seat = excluded.seat, joined_at = now(), left_at = null;

  return room;
end;
$$;

revoke all on function public.join_room(text) from public, anon;
grant execute on function public.join_room(text) to authenticated;

-- Realtime: the board, each player's own seat, the host's intents, and the
-- room row (status, bots).
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['game_public', 'game_seat_views', 'game_intents', 'rooms']
    loop
      if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
      ) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end;
$$;
