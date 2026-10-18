-- The Compare (Accomplice), an online-only Family role: while he is alive
-- the Family keeps its private chat open by day too. The engine decides it
-- per seat (chat rights 'familyDay'); game_commit stores it and send_chat
-- lets living Family members write in 'family' by day only when it is set.
-- Reading is unchanged: is_family_reader already lets living Family members
-- read their channel at any time.

alter table public.game_seats
  add column if not exists family_day boolean not null default false;

create or replace function internal.game_commit(room uuid, step jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_public;
  seated record;
  rights jsonb;
  due timestamptz;
begin
  due := case when step ->> 'nextDue' is null then null
              else to_timestamp((step ->> 'nextDue')::double precision / 1000) end;
  select * into g from public.game_public where room_id = room for update;
  if not found then
    return;
  end if;
  if not coalesce((step ->> 'changed')::boolean, false) then
    update internal.game_state set next_due_at = due, updated_at = now() where room_id = room;
    return;
  end if;
  if (step ->> 'version')::integer <= g.version then
    raise exception 'stale_version';
  end if;

  update public.game_public
  set version = (step ->> 'version')::integer,
      view = step -> 'board',
      chat_mode = coalesce(step -> 'chat' ->> 'mode', 'closed'),
      updated_at = now()
  where room_id = room;

  for seated in
    select seat, profile_id from public.game_seats where room_id = room and profile_id is not null
  loop
    if step -> 'seatViews' ? seated.seat then
      insert into public.game_seat_views (room_id, seat, profile_id, version, view)
      values (room, seated.seat, seated.profile_id, (step ->> 'version')::integer, step -> 'seatViews' -> seated.seat)
      on conflict (room_id, seat) do update
        set profile_id = excluded.profile_id, version = excluded.version, view = excluded.view;
    end if;
    rights := step -> 'chat' -> 'seats' -> seated.seat;
    update public.game_seats
    set alive = coalesce((rights ->> 'alive')::boolean, alive),
        family = coalesce((rights ->> 'family')::boolean, family),
        silenced = coalesce((rights ->> 'silenced')::boolean, false),
        family_day = coalesce((rights ->> 'familyDay')::boolean, false),
        offline = coalesce(step -> 'board' -> 'offline', '[]'::jsonb) ? seated.seat
    where room_id = room and seat = seated.seat;
  end loop;

  if step ->> 'lastIntent' is not null then
    delete from public.game_intents where room_id = room and id <= (step ->> 'lastIntent')::bigint;
  end if;

  insert into internal.game_abandons (profile_id, room_id, game_id, seat)
  select s.profile_id, room, g.game_id, s.seat
  from public.game_seats s
  where s.room_id = room and s.profile_id is not null
    and s.seat in (select jsonb_array_elements_text(coalesce(step -> 'departed', '[]'::jsonb)));

  update internal.game_state
  set state = step -> 'state', next_due_at = due, updated_at = now()
  where room_id = room;

  if coalesce((step ->> 'finished')::boolean, false) then
    update public.rooms set status = 'lobby' where id = room and status = 'playing';
  end if;
end;
$$;
revoke all on function internal.game_commit(uuid, jsonb) from public, anon, authenticated;

create or replace function public.send_chat(room uuid, channel text, body text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  g public.game_public;
  s public.game_seats;
  text_ text := btrim(coalesce(body, ''));
  recent integer;
  sender text;
  new_id bigint;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  if char_length(text_) = 0 or char_length(text_) > 300 then
    raise exception 'invalid_message';
  end if;
  select count(*) into recent from public.game_chat
  where profile_id = me and created_at > now() - interval '3 seconds';
  if recent >= 3 then
    raise exception 'too_many_messages';
  end if;
  if public._chat_blocked(text_) then
    raise exception 'message_blocked';
  end if;
  select * into r from public.rooms where id = room;

  if channel = 'lobby' then
    if r.status <> 'lobby' then
      raise exception 'chat_closed';
    end if;
    select handle into sender from public.profiles where id = me;
    insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body)
    values (room, null, 'lobby', me, null, coalesce(sender, '?'), text_)
    returning id into new_id;
    return new_id;
  end if;

  select * into g from public.game_public where room_id = room;
  select * into s from public.game_seats where room_id = room and profile_id = me;
  if g.room_id is null or s.seat is null or r.status <> 'playing' or not s.alive then
    raise exception 'chat_closed';
  end if;
  if channel = 'day' then
    if g.chat_mode <> 'day' then
      raise exception 'chat_closed';
    end if;
    if s.silenced then
      raise exception 'silenced';
    end if;
  elsif channel = 'family' then
    if not s.family
       or not (g.chat_mode = 'night' or (g.chat_mode = 'day' and s.family_day)) then
      raise exception 'chat_closed';
    end if;
  else
    raise exception 'chat_closed';
  end if;
  insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body)
  values (room, g.game_id, channel, me, s.seat, s.name, text_)
  returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.send_chat(uuid, text, text) from public, anon;
grant execute on function public.send_chat(uuid, text, text) to authenticated;
