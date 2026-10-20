-- Small tables when few players are around: a ranked lobby still aims for
-- 12, but once its longest-waiting member has waited 'ranked_small_after'
-- seconds (180) it may start with as few as 'ranked_small_min' (8). The deck
-- adapts to the table size on its own. No bots in ranked.
insert into internal.config (key, value) values
  ('ranked_small_after', '180'),
  ('ranked_small_min', '8')
on conflict (key) do nothing;

create or replace function internal.ranked_need_room(room uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r public.rooms;
  waited double precision;
begin
  select * into r from public.rooms where id = room;
  if not found or r.test_match then
    return internal.ranked_need(coalesce(r.test_match, false));
  end if;
  select max(extract(epoch from now() - coalesce(q.joined_at, m.joined_at))) into waited
  from public.room_members m
  left join internal.ranked_queue q on q.profile_id = m.profile_id
  where m.room_id = room and m.left_at is null;
  if coalesce(waited, 0) >= internal.config_int('ranked_small_after', 180) then
    return least(internal.ranked_need(false), internal.config_int('ranked_small_min', 8));
  end if;
  return internal.ranked_need(false);
end;
$$;
revoke all on function internal.ranked_need_room(uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION internal.ranked_countdown(room uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r public.rooms;
  n integer;
  ends timestamptz;
begin
  select * into r from public.rooms where id = room for update;
  if not found or r.status <> 'lobby' or not (r.ranked or r.test_match) then
    return;
  end if;
  select count(*) into n from public.room_members where room_id = room and left_at is null;
  ends := case
    when n < internal.ranked_need_room(room) then null
    when r.starts_at is not null then r.starts_at
    else now() + make_interval(secs => internal.config_int('ranked_countdown', 5))
  end;
  if ends is distinct from r.starts_at or n <> r.seated then
    update public.rooms set starts_at = ends, seated = n where id = room;
  end if;
end;
$function$

;
revoke all on function internal.ranked_countdown(uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION internal.ranked_start(room uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if n < internal.ranked_need_room(room) or n > size then
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
$function$

;
revoke all on function internal.ranked_start(uuid) from public, anon, authenticated;

-- The waiting time grows on its own: re-check open lobbies every tick so a
-- lobby that reached the small-table threshold starts its countdown.
create or replace function internal.ranked_small_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  q record;
begin
  for q in select id from public.rooms where status = 'lobby' and ranked and starts_at is null loop
    perform internal.ranked_countdown(q.id);
  end loop;
end;
$$;
revoke all on function internal.ranked_small_tick() from public, anon, authenticated;

CREATE OR REPLACE FUNCTION internal.game_tick()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform internal.ranked_small_tick();
  perform internal.ranked_match();
  if exists (
    select 1 from internal.game_state g
    where g.next_due_at <= now()
       or exists (select 1 from public.game_intents i where i.room_id = g.room_id)
  ) then
    perform internal.wake_game(null);
  end if;
end;
$function$
;
revoke all on function internal.game_tick() from public, anon, authenticated;
