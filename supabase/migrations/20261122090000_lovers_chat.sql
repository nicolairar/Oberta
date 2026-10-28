-- Cupid's lovers (docs/ruoli.md 3.7): a private chat for the two of them,
-- at night, while both are alive and out of the Jailer's cell. The server's
-- step publishes the right (chat rights `lovers`); game_commit stores it in
-- game_seats.lovers, send_chat checks it, and the read policy shows the
-- channel only to whoever holds it now. The lovers know each other's name,
-- so their lines are signed as usual.

alter table public.game_seats add column if not exists lovers boolean not null default false;

alter table public.game_chat drop constraint if exists game_chat_channel_check;
alter table public.game_chat
  add constraint game_chat_channel_check
  check (channel in ('lobby', 'day', 'family', 'lovers') or channel ~ '^jail:[0-9]{1,3}$');

create or replace function public.is_lovers_reader(room uuid, game uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_room_member(room) and exists (
    select 1
    from public.game_seats s
    join public.game_public g on g.room_id = s.room_id
    where s.room_id = room and s.profile_id = auth.uid()
      and s.alive and s.lovers and g.game_id = game
  );
$$;
revoke all on function public.is_lovers_reader(uuid, uuid) from public, anon;
grant execute on function public.is_lovers_reader(uuid, uuid) to authenticated;

-- The read policy, as before, plus the lovers.
drop policy if exists "members read the room chat" on public.game_chat;
create policy "members read the room chat"
  on public.game_chat for select
  to authenticated
  using (
    (
      (channel in ('lobby', 'day') and (select public.is_room_member(room_id)))
      or (channel = 'family' and (select public.is_family_reader(room_id, game_id)))
      or (channel like 'jail:%' and (select public.is_jail_reader(room_id, game_id, channel)))
      or (channel = 'lovers' and (select public.is_lovers_reader(room_id, game_id)))
    )
    and not exists (
      select 1 from public.player_blocks b
      where b.blocker = (select auth.uid()) and b.blocked = game_chat.profile_id
    )
  );

-- send_chat, as before, plus the channel `lovers`.
create or replace function public.send_chat(room uuid, channel text, body text)
returns uuid
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
  new_id uuid;
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
  select count(*) into recent from (
    select 1 from public.game_chat where profile_id = me and created_at > now() - interval '3 seconds'
    union all
    select 1 from internal.jail_authors where profile_id = me and created_at > now() - interval '3 seconds'
  ) sent;
  if recent >= 3 then
    raise exception 'too_many_messages';
  end if;
  text_ := public._chat_clean(text_);
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
    if not s.family or s.jailed
       or not (g.chat_mode = 'night' or (g.chat_mode = 'day' and s.family_day)) then
      raise exception 'chat_closed';
    end if;
  elsif channel = 'lovers' then
    if g.chat_mode <> 'night' or not s.lovers then
      raise exception 'chat_closed';
    end if;
  elsif channel = 'jail' then
    if g.chat_mode <> 'night' or s.jail is null then
      raise exception 'chat_closed';
    end if;
    if s.jailer then
      -- The Jailer has no name in the cell.
      insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body)
      values (room, g.game_id, s.jail, null, null, '', text_)
      returning id into new_id;
      insert into internal.jail_authors (message_id, profile_id) values (new_id, me);
      return new_id;
    end if;
    insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body)
    values (room, g.game_id, s.jail, me, s.seat, s.name, text_)
    returning id into new_id;
    return new_id;
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

-- game_commit, as before, plus the lovers' right.
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
        jail = case when rights ->> 'jail' ~ '^jail:[0-9]{1,3}$' then rights ->> 'jail' end,
        jailer = coalesce((rights ->> 'jailer')::boolean, false),
        jailed = coalesce((rights ->> 'jailed')::boolean, false),
        lovers = coalesce((rights ->> 'lovers')::boolean, false),
        offline = coalesce(step -> 'board' -> 'offline', '[]'::jsonb) ? seated.seat
    where room_id = room and seat = seated.seat;
  end loop;

  -- The events: public ones for everyone in the room, private ones for the
  -- profile sitting at that seat (a seat with no person gets nothing).
  -- Events of earlier games in this room are not needed any more.
  if jsonb_typeof(step -> 'events') = 'array' and jsonb_array_length(step -> 'events') > 0 then
    delete from public.game_events where room_id = room and game_id is distinct from g.game_id;
    insert into public.game_events (room_id, game_id, recipient, n, kind, data)
    select room, g.game_id, s.profile_id,
           row_number() over (partition by s.profile_id order by e.n),
           e.value ->> 'kind', coalesce(e.value -> 'data', '{}'::jsonb)
    from jsonb_array_elements(step -> 'events') with ordinality as e (value, n)
    left join public.game_seats s on s.room_id = room and s.seat = e.value ->> 'to'
    where g.game_id is not null
      and (e.value ->> 'to' is null or s.profile_id is not null);
  end if;

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

notify pgrst, 'reload schema';
