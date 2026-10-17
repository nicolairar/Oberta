-- The server runs online games. Until now the host's phone held the engine
-- (and every role) and published what each seat may see; if it left, the
-- game stopped. Now the Edge Function `game` runs the same Dart engine,
-- compiled to JavaScript, and no phone ever holds a secret:
--
--   internal.game_state   the engine snapshot and the game's clock. In a
--                         schema the API does not expose, with no grants and
--                         RLS on: only the Edge Function (connecting as
--                         postgres) reads and writes it;
--   game_public           the public board, with the current phase and its
--                         server-clock start and end, readable by the room;
--   game_seat_views       one row per human seat, readable only by its player;
--   game_intents          moves and acknowledgements, written only through
--                         submit_intent (the caller's own seat); read by the
--                         function only;
--   game_chat             lobby, day and family chat, through send_chat;
--   internal.game_abandons  who left a game for good (grace expired), kept
--                         for future ranked penalties; no client reads it.
--
-- How the function runs: start_game, submit_intent and game_ping (when an
-- offline seat comes back) wake it at once through pg_net; a pg_cron job
-- every 2 seconds wakes it when a game has something due (a bot, a phase
-- deadline, a seat going offline). The wake carries a secret generated
-- here, which the function reads back from internal.config. Every run takes
-- a row lock on the game (skip locked), so two runs never step the same game.

-- Extensions. On Supabase both exist and can be created from a migration;
-- elsewhere (local tests) they are skipped.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
  end if;
end;
$$;

create schema if not exists internal;
revoke all on schema internal from public, anon, authenticated;

create table if not exists internal.config (
  key text primary key,
  value text not null
);
alter table internal.config enable row level security;
revoke all on internal.config from public, anon, authenticated;

insert into internal.config (key, value) values
  ('function_url', 'https://iklohzudrdwjzqgesakq.supabase.co/functions/v1/game'),
  ('wake_secret', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (key) do nothing;

create table if not exists internal.game_state (
  room_id uuid primary key references public.rooms (id) on delete cascade,
  -- Null until the function deals the cards.
  state jsonb,
  next_due_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists game_state_due on internal.game_state (next_due_at) where next_due_at is not null;
alter table internal.game_state enable row level security;
revoke all on internal.game_state from public, anon, authenticated;

-- The host's phone is no longer the authority: its saved state (with every
-- role), its publishing function and its right to read intents go.
drop policy if exists "only the host reads intents" on public.game_intents;
revoke all on public.game_intents from anon, authenticated;
drop function if exists public.publish_game(uuid, integer, jsonb, jsonb, jsonb, bigint, boolean);
drop function if exists public.start_game(uuid, jsonb);
drop table if exists public.game_host_state;
drop function if exists public.is_game_host(uuid);

alter table public.game_public
  add column if not exists game_id uuid not null default gen_random_uuid(),
  add column if not exists chat_mode text not null default 'closed';
alter table public.game_public drop constraint if exists game_public_chat_mode_check;
alter table public.game_public
  add constraint game_public_chat_mode_check check (chat_mode in ('day', 'night', 'closed'));
comment on column public.game_public.host is 'Who started the game. It gives no power once the game runs.';

-- What the server knows about each seat, for presence and chat. Nobody
-- reads game_seats directly (no grants): family is a secret.
alter table public.game_seats
  add column if not exists last_seen timestamptz,
  add column if not exists offline boolean not null default false,
  add column if not exists alive boolean not null default true,
  add column if not exists family boolean not null default false,
  add column if not exists silenced boolean not null default false;

-- Server-side only, for future ranked penalties: never shown in the app,
-- never readable by any client role.
create table if not exists internal.game_abandons (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  room_id uuid,
  game_id uuid not null,
  seat text not null,
  abandoned_at timestamptz not null default now(),
  ranked boolean not null default false
);
create index if not exists game_abandons_by_profile on internal.game_abandons (profile_id, abandoned_at);
alter table internal.game_abandons enable row level security;
revoke all on internal.game_abandons from public, anon, authenticated;

create table if not exists public.game_chat (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms (id) on delete cascade,
  -- Null for the lobby; day and family messages belong to one game.
  game_id uuid,
  channel text not null check (channel in ('lobby', 'day', 'family')),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  seat text,
  name text not null,
  body text not null check (char_length(body) between 1 and 300),
  created_at timestamptz not null default now()
);
create index if not exists game_chat_by_room on public.game_chat (room_id, id);
create index if not exists game_chat_by_sender on public.game_chat (profile_id, created_at);
alter table public.game_chat enable row level security;
revoke all on public.game_chat from anon, authenticated;
grant select on public.game_chat to authenticated;

-- Outside RLS on purpose: true when the caller is a living member of the
-- family in the room's current game.
create or replace function public.is_family_reader(room uuid, game uuid)
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
      and s.family and s.alive and g.game_id = game
  );
$$;
revoke all on function public.is_family_reader(uuid, uuid) from public, anon;
grant execute on function public.is_family_reader(uuid, uuid) to authenticated;

drop policy if exists "members read the room chat" on public.game_chat;
create policy "members read the room chat"
  on public.game_chat for select
  to authenticated
  using (
    (channel in ('lobby', 'day') and (select public.is_room_member(room_id)))
    or (channel = 'family' and (select public.is_family_reader(room_id, game_id)))
  );

-- Chat moderation reuses the handle word list, minus the words that are
-- only reserved as names (staff, the app's name...).
alter table public.reserved_words add column if not exists in_chat boolean not null default true;
update public.reserved_words set in_chat = false
where word in (
  'admin', 'administrator', 'amministratore', 'moderator', 'moderatore', 'mod', 'oberta', 'omerta',
  'support', 'supporto', 'assistenza', 'staff', 'official', 'ufficiale', 'narrator', 'narratore'
);

create or replace function public._chat_blocked(body text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.reserved_words as w, public._handle_forms(body) as f
    where w.in_chat and w.match = 'contains'
      and position(regexp_replace(w.word, '(.)\1+', '\1', 'g') in f.collapsed) > 0
  ) or exists (
    select 1
    from public.reserved_words as w,
         regexp_split_to_table(body, '\s+') as token,
         public._handle_forms(token) as f
    where w.in_chat and w.match = 'exact' and f.plain = w.word
  );
$$;
revoke all on function public._chat_blocked(text) from public, anon, authenticated;

-- Wakes the Edge Function for a room (or for every game due, with null).
-- Without pg_net (local tests) it does nothing.
create or replace function internal.wake_game(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  url text;
  secret text;
begin
  if not exists (select 1 from pg_namespace where nspname = 'net') then
    return;
  end if;
  select value into url from internal.config where key = 'function_url';
  select value into secret from internal.config where key = 'wake_secret';
  if url is null or secret is null then
    return;
  end if;
  execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 10000)'
  using url,
        jsonb_build_object('room', room),
        jsonb_build_object('Content-Type', 'application/json', 'x-oberta-wake', secret);
end;
$$;
revoke all on function internal.wake_game(uuid) from public, anon, authenticated;

-- Every 2 seconds: one wake if any game has something due.
create or replace function internal.game_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
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

-- The function saves a step: the secret state, the public board, each human
-- seat's view (to the profile seated there, whatever the step says), the
-- seats' chat rights and presence, the intents handled, the abandons, and
-- when to look at the game again. [step] is the engine's output.
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

-- The host starts a game. The server seats everyone: the people in the
-- room in their seat order, then the room's bots (bot.alfa, bot.bravo...).
-- The cards are dealt by the function, with the server's randomness.
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
  i integer := 0;
  m record;
  nato text[] := array['alfa', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel',
                       'india', 'juliett', 'kilo', 'lima', 'mike', 'november', 'oscar'];
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
  if people + r.bots < 4 or people + r.bots > r.max_players then
    raise exception 'invalid_seats';
  end if;

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

  insert into public.game_public (room_id, host, version, view) values (room, me, 0, null);
  insert into internal.game_state (room_id, state, next_due_at) values (room, null, now());
  update public.rooms set status = 'playing' where id = room;
  perform internal.wake_game(room);
end;
$$;

-- A player sends a move or an acknowledgement ({"type": "ack", "stage":
-- "night-2"}). The seat is the caller's own, never one picked by the client.
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
  update public.game_seats set last_seen = now() where room_id = room and seat = my_seat;
  perform internal.wake_game(room);
  return new_id;
end;
$$;

-- The phone in a game says it is there, every few seconds. A seat that was
-- offline wakes the function, so everyone sees it back at once.
create or replace function public.game_ping(room uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  was_offline boolean;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  update public.game_seats set last_seen = now()
  where room_id = room and profile_id = me
  returning offline into was_offline;
  if was_offline then
    perform internal.wake_game(room);
  end if;
  return (extract(epoch from clock_timestamp()) * 1000)::bigint;
end;
$$;

-- The server's clock, in milliseconds: phones measure their offset from it.
create or replace function public.server_now()
returns bigint
language sql
volatile
set search_path = ''
as $$
  select (extract(epoch from clock_timestamp()) * 1000)::bigint;
$$;

-- A chat message. Lobby: anyone in the room, while it is in the lobby. Day:
-- living players during the discussion and the vote, except whoever the
-- Tailor silenced. Family: living members of the family, at night. Dead
-- players only read. Max 300 characters, 3 messages every 3 seconds, and
-- the same word list as the handles.
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
    if g.chat_mode <> 'night' or not s.family then
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

revoke all on function public.start_game(uuid) from public, anon;
revoke all on function public.submit_intent(uuid, jsonb) from public, anon;
revoke all on function public.game_ping(uuid) from public, anon;
revoke all on function public.server_now() from public, anon;
revoke all on function public.send_chat(uuid, text, text) from public, anon;
grant execute on function public.start_game(uuid) to authenticated;
grant execute on function public.submit_intent(uuid, jsonb) to authenticated;
grant execute on function public.game_ping(uuid) to authenticated;
grant execute on function public.server_now() to authenticated;
grant execute on function public.send_chat(uuid, text, text) to authenticated;

-- Realtime: the chat joins; intents leave (no phone reads them any more).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_chat'
    ) then
      alter publication supabase_realtime add table public.game_chat;
    end if;
    if exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_intents'
    ) then
      alter publication supabase_realtime drop table public.game_intents;
    end if;
  end if;
end;
$$;

-- The clock: every 2 seconds the tick, once a day the cron log is trimmed.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('oberta-game-tick', '2 seconds', 'select internal.game_tick()');
    perform cron.schedule(
      'oberta-trim-cron-log',
      '17 4 * * *',
      $job$delete from cron.job_run_details where end_time < now() - interval '1 day'$job$
    );
  end if;
end;
$$;
