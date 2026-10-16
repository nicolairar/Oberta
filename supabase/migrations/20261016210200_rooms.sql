-- Rooms for "play with friends": a host opens one, the others join with a
-- six-character code (typed or scanned from a QR). Clients only read the
-- rooms they sit in; creating, joining and leaving go through functions
-- that check capacity and status.

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  -- No 0/O, 1/I/L: a code read across the table must not be ambiguous.
  code text not null check (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$'),
  host uuid not null references public.profiles (id) on delete cascade,
  language text not null check (language in ('it', 'en')),
  status text not null default 'lobby' check (status in ('lobby', 'playing', 'ended')),
  max_players smallint not null default 16 check (max_players between 2 and 16),
  created_at timestamptz not null default now()
);

-- A code belongs to one open room at a time; ended rooms give it back.
create unique index if not exists rooms_open_code on public.rooms (code) where status <> 'ended';

create table if not exists public.room_members (
  room_id uuid not null references public.rooms (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  -- The place at the table, 1..max_players. Free again once someone leaves.
  seat smallint not null check (seat between 1 and 16),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (room_id, profile_id)
);

create unique index if not exists room_members_seat_taken
  on public.room_members (room_id, seat) where left_at is null;
create index if not exists room_members_by_profile
  on public.room_members (profile_id) where left_at is null;

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;

grant select on public.rooms to authenticated;
grant select on public.room_members to authenticated;

-- Outside RLS on purpose: a policy on room_members that reads room_members
-- would recurse.
create or replace function public.is_room_member(room uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.room_members
    where room_id = room and profile_id = auth.uid() and left_at is null
  );
$$;

revoke all on function public.is_room_member(uuid) from public, anon;
grant execute on function public.is_room_member(uuid) to authenticated;

drop policy if exists "members see their room" on public.rooms;
create policy "members see their room"
  on public.rooms for select
  to authenticated
  using ((select public.is_room_member(id)));

drop policy if exists "members see who is in their room" on public.room_members;
create policy "members see who is in their room"
  on public.room_members for select
  to authenticated
  using ((select public.is_room_member(room_id)));

-- Leaves a room on behalf of [who]: if the host goes, the longest-seated
-- player takes over; if nobody is left, the room ends.
create or replace function public._leave_room(room uuid, who uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  heir uuid;
begin
  update public.room_members set left_at = now()
  where room_id = room and profile_id = who and left_at is null;
  if not found then
    return;
  end if;

  select profile_id into heir from public.room_members
  where room_id = room and left_at is null
  order by joined_at, seat
  limit 1;

  if heir is null then
    update public.rooms set status = 'ended' where id = room;
  else
    update public.rooms set host = heir where id = room and host = who;
  end if;
end;
$$;

revoke all on function public._leave_room(uuid, uuid) from public, anon, authenticated;

-- Requires a signed-in player who has picked a handle; returns their id.
create or replace function public._ready_player()
returns uuid
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
  if not exists (select 1 from public.profiles where id = me and handle is not null) then
    raise exception 'profile_incomplete';
  end if;
  return me;
end;
$$;

revoke all on function public._ready_player() from public, anon, authenticated;

create or replace function public.create_room(room_language text)
returns public.rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  new_code text;
  room public.rooms;
  other uuid;
begin
  if room_language is null or room_language not in ('it', 'en') then
    raise exception 'invalid_language';
  end if;

  -- One table at a time: opening a room means leaving the previous one.
  for other in
    select room_id from public.room_members where profile_id = me and left_at is null
  loop
    perform public._leave_room(other, me);
  end loop;

  loop
    -- gen_random_uuid() draws from a cryptographic source.
    select string_agg(
             substr(alphabet, get_byte(uuid_send(gen_random_uuid()), 0) % length(alphabet) + 1, 1), ''
           )
      into new_code
      from generate_series(1, 6);
    begin
      insert into public.rooms (code, host, language)
      values (new_code, me, room_language)
      returning * into room;
      exit;
    exception when unique_violation then
      -- Code already open somewhere: draw again.
    end;
  end loop;

  insert into public.room_members (room_id, profile_id, seat) values (room.id, me, 1);
  return room;
end;
$$;

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

create or replace function public.leave_room(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  perform public._leave_room(room, auth.uid());
end;
$$;

revoke all on function public.create_room(text) from public, anon;
revoke all on function public.join_room(text) from public, anon;
revoke all on function public.leave_room(uuid) from public, anon;
grant execute on function public.create_room(text) to authenticated;
grant execute on function public.join_room(text) to authenticated;
grant execute on function public.leave_room(uuid) to authenticated;

-- Lobbies update live: Realtime sends member changes to whoever may read them.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_members'
     ) then
    alter publication supabase_realtime add table public.room_members;
  end if;
end;
$$;
