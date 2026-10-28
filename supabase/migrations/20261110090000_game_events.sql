-- Game events in the chat: the system lines the server writes next to the
-- players' messages (night falls, who died at dawn, the verdict with its
-- tally, the Mayor, the scoop, who left, the end) and the private ones that
-- only one player reads ("only you": an investigation, the Doorman's door,
-- the bounty, the doused, the family's target, a protection).
--
-- The engine computes them from what it publishes anyway (the board and
-- each seat's own view) and game_commit stores them here. A public event
-- has no recipient; a private one names the profile that alone may read
-- it. Clients only read, through the policy, and only for the game being
-- played in their room.
--
-- No shared counter: the id is random and `n` counts only within what one
-- reader sees (the public lines of a step; one recipient's private lines),
-- so the gaps between the lines you read never tell how many secret lines
-- the others got. The phones sort by created_at, then n.

create table if not exists public.game_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  game_id uuid not null,
  recipient uuid references public.profiles (id) on delete cascade,
  n smallint not null default 0,
  kind text not null check (kind ~ '^[a-zA-Z]{1,24}$'),
  data jsonb not null default '{}'::jsonb
    check (jsonb_typeof(data) = 'object' and octet_length(data::text) <= 4000),
  created_at timestamptz not null default now()
);

create index if not exists game_events_room_idx on public.game_events (room_id, created_at);

alter table public.game_events enable row level security;
revoke all on public.game_events from public, anon, authenticated;
grant select on public.game_events to authenticated;

drop policy if exists "the table's events and only your own secrets" on public.game_events;
create policy "the table's events and only your own secrets" on public.game_events
  for select to authenticated
  using (
    (select public.is_room_member(game_events.room_id))
    and (recipient is null or recipient = (select auth.uid()))
    and game_id = (select g.game_id from public.game_public g where g.room_id = game_events.room_id)
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_events'
  ) then
    alter publication supabase_realtime add table public.game_events;
  end if;
end;
$$;

-- game_commit, as before, plus the events of the step.
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
