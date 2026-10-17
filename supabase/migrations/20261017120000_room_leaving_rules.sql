-- Leaving a room, the way the table expects it:
-- * the host can't just walk out while others are seated: they hand the
--   room to someone first (leave_room with new_host);
-- * when the last player leaves, the room is deleted with its members, so
--   nothing lingers on the server;
-- * rooms forgotten in the lobby (everyone closed the app) are swept away
--   after six hours, every time someone opens or joins a room.

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
    -- Nobody left at the table: the room goes, members cascade with it.
    delete from public.rooms where id = room;
  else
    update public.rooms set host = heir where id = room and host = who;
  end if;
end;
$$;

revoke all on function public._leave_room(uuid, uuid) from public, anon, authenticated;

create or replace function public._sweep_rooms()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.rooms
  where status = 'ended'
     or (status = 'lobby' and created_at < now() - interval '6 hours');
$$;

revoke all on function public._sweep_rooms() from public, anon, authenticated;

drop function if exists public.leave_room(uuid);

create or replace function public.leave_room(room uuid, new_host uuid default null, auto_heir boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  current_host uuid;
  others integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;

  select host into current_host from public.rooms where id = room for update;
  if not found then
    return;
  end if;

  select count(*) into others from public.room_members
  where room_id = room and left_at is null and profile_id <> me;

  if current_host = me and others > 0 and not auto_heir then
    if new_host is null then
      raise exception 'host_must_choose';
    end if;
    if not exists (
      select 1 from public.room_members
      where room_id = room and profile_id = new_host and left_at is null and profile_id <> me
    ) then
      raise exception 'invalid_new_host';
    end if;
    update public.rooms set host = new_host where id = room;
  end if;

  perform public._leave_room(room, me);
end;
$$;

revoke all on function public.leave_room(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.leave_room(uuid, uuid, boolean) to authenticated;

-- Opening or joining a room sweeps the forgotten ones first.
create or replace function public._sweep_before_room()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._sweep_rooms();
  return new;
end;
$$;

revoke all on function public._sweep_before_room() from public, anon, authenticated;

drop trigger if exists sweep_rooms_on_member on public.room_members;
create trigger sweep_rooms_on_member
  before insert on public.room_members
  for each statement execute function public._sweep_before_room();

-- Rooms already ended before this migration go now.
select public._sweep_rooms();
