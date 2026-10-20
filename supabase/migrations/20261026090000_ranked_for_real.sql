-- Ranked with real people only (no bots), checked by a load simulation of
-- 60 players against the real database. What changes:
--
-- * Lobbies fill one another. Lobbies waiting longer than
--   'ranked_merge_after' (60 s) used to merge only when both fitted in one
--   table, so three lobbies of 8 waited forever. Now the fullest lobby takes
--   players from the emptiest until it has 12; the rest keep waiting.
--   After that minute the rating band no longer matters.
-- * Placement survives concurrency: the chosen lobby is counted again once
--   locked (someone may have sat down just before), a full one is skipped.
-- * Conduct degrades gracefully. Low-conduct players (score < 70: repeat
--   quitters, reported players) still sit only with each other, but once a
--   lobby has waited 'ranked_mix_after' (120 s) the classes may mix, so a
--   handful of low-conduct players is not stuck forever. Same class always
--   comes first.
-- * Anonymous waiting room. Before the start a ranked lobby shows nobody:
--   a member reads only their own room_members row, the lobby has no host
--   (null until the game starts), there is no lobby chat, and the number
--   of people seated is in rooms.seated (realtime, no ids).
-- * public.online_counts(): players online and queued per language, from a
--   cache refreshed at most every 30 s. Counts only, no personal data.

insert into internal.config (key, value) values ('ranked_mix_after', '120')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Anonymous lobbies

alter table public.rooms add column if not exists seated smallint not null default 0;
alter table public.rooms alter column host drop not null;
update public.rooms set host = null where (ranked or test_match) and status = 'lobby';
alter table public.rooms drop constraint if exists rooms_host_only_ranked_lobby;
alter table public.rooms add constraint rooms_host_only_ranked_lobby
  check (host is not null or ((ranked or test_match) and status = 'lobby'));
update public.rooms r
set seated = (select count(*) from public.room_members m where m.room_id = r.id and m.left_at is null)
where r.status = 'lobby';

-- True when [member]'s row in [room] may be read by the caller: always their
-- own, the others only outside a waiting ranked lobby.
create or replace function public.can_see_room_member(room uuid, member uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_room_member(room) and (
    member = auth.uid()
    or not exists (
      select 1 from public.rooms where id = room and (ranked or test_match) and status = 'lobby'
    )
  );
$$;
revoke all on function public.can_see_room_member(uuid, uuid) from public, anon;
grant execute on function public.can_see_room_member(uuid, uuid) to authenticated;

drop policy if exists "members see who is in their room" on public.room_members;
create policy "members see who is in their room"
  on public.room_members for select
  to authenticated
  using ((select public.can_see_room_member(room_id, profile_id)));

-- No lobby chat in ranked rooms at all: strangers meet at the start.
create or replace function public._no_lobby_chat_in_matched_rooms()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.channel = 'lobby' and exists (
    select 1 from public.rooms where id = new.room_id and (ranked or test_match)
  ) then
    raise exception 'chat_closed';
  end if;
  return new;
end;
$$;

-- Starts or stops the countdown, and keeps the seated count.
create or replace function internal.ranked_countdown(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
    when n < internal.ranked_need(r.test_match) then null
    when r.starts_at is not null then r.starts_at
    else now() + make_interval(secs => internal.config_int('ranked_countdown', 5))
  end;
  if ends is distinct from r.starts_at or n <> r.seated then
    update public.rooms set starts_at = ends, seated = n where id = room;
  end if;
end;
$$;
revoke all on function internal.ranked_countdown(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Placement

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
  mix_after integer := internal.config_int('ranked_mix_after', 120);
  mine double precision;
  low boolean;
  target uuid;
  tried uuid[] := '{}';
  n integer;
  new_code text;
begin
  perform public._sweep_rooms();
  select * into q from internal.ranked_queue where profile_id = who for update;
  if not found or q.room_id is not null then
    return q.room_id;
  end if;
  mine := internal.ordinal(who, q.language);
  low := coalesce((select score from internal.conduct where profile_id = who), 100) < 70;

  for attempt in 1 .. 5 loop
    target := null;
    select r.id into target
    from public.rooms r
    cross join lateral (
      select count(*) as n,
             avg(internal.ordinal(m.profile_id, q.language)) as rating,
             bool_and(coalesce(c.score, 100) < 70) as all_low,
             bool_or(coalesce(c.score, 100) < 70) as any_low,
             bool_or(internal.blocked_between(who, m.profile_id)) as blocked,
             max(extract(epoch from now() - coalesce(rq.joined_at, m.joined_at))) as waited
      from public.room_members m
      left join internal.conduct c on c.profile_id = m.profile_id
      left join internal.ranked_queue rq on rq.profile_id = m.profile_id
      where m.room_id = r.id and m.left_at is null
    ) s
    where r.status = 'lobby' and r.language = q.language
      and (r.ranked or r.test_match) and r.test_match = test
      and r.id <> all (tried)
      and s.n between 1 and size - 1
      and ((case when low then s.all_low else not s.any_low end) or s.waited > mix_after)
      and abs(s.rating - mine) <= internal.ranked_band(greatest(s.waited, extract(epoch from now() - q.joined_at)))
    order by (case when low then not s.all_low else s.any_low end),
             coalesce(s.blocked, false), s.n desc, r.created_at
    limit 1
    for update of r skip locked;
    exit when target is null;
    -- Locked now: count again, someone may have sat down just before.
    select count(*) into n from public.room_members where room_id = target and left_at is null;
    exit when n between 1 and size - 1
      and exists (select 1 from public.rooms where id = target and status = 'lobby');
    tried := tried || target;
    target := null;
  end loop;

  if target is null then
    loop
      select string_agg(substr(alphabet, get_byte(uuid_send(gen_random_uuid()), 0) % length(alphabet) + 1, 1), '')
        into new_code
        from generate_series(1, 6);
      begin
        insert into public.rooms (code, host, language, max_players, ranked, test_match, bots)
        values (new_code, null, q.language, size, not test, test, 0)
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

-- ---------------------------------------------------------------------------
-- The matcher: drops silent phones, seats the unseated, fills lobbies from
-- one another, starts the countdowns that are over.

create or replace function internal.ranked_match()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  size integer := internal.config_int('ranked_size', 12);
  merge_after integer := internal.config_int('ranked_merge_after', 60);
  mix_after integer := internal.config_int('ranked_mix_after', 120);
  q record;
  small record;
  small_n integer;
  small_low boolean;
  small_waited double precision;
  big uuid;
  big_n integer;
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

  -- Lobbies waiting too long fill one another: the emptiest gives its
  -- players (longest waiting first) to the fullest that still has room,
  -- same conduct class first, any class after mix_after.
  for small in
    select r.id, r.language, r.test_match
    from public.rooms r
    where r.status = 'lobby' and (r.ranked or r.test_match) and r.starts_at is null
      and r.created_at < now() - make_interval(secs => merge_after)
    order by r.seated, r.created_at
  loop
    perform 1 from public.rooms
    where id = small.id and status = 'lobby' and starts_at is null
    for update skip locked;
    continue when not found;
    select count(*), bool_and(coalesce(c.score, 100) < 70),
           max(extract(epoch from now() - coalesce(rq.joined_at, m.joined_at)))
      into small_n, small_low, small_waited
    from public.room_members m
    left join internal.conduct c on c.profile_id = m.profile_id
    left join internal.ranked_queue rq on rq.profile_id = m.profile_id
    where m.room_id = small.id and m.left_at is null;
    continue when small_n = 0;

    big := null;
    select r.id into big
    from public.rooms r
    cross join lateral (
      select count(*) as n,
             bool_and(coalesce(c.score, 100) < 70) as all_low,
             max(extract(epoch from now() - coalesce(rq.joined_at, m.joined_at))) as waited
      from public.room_members m
      left join internal.conduct c on c.profile_id = m.profile_id
      left join internal.ranked_queue rq on rq.profile_id = m.profile_id
      where m.room_id = r.id and m.left_at is null
    ) s
    where r.id <> small.id and r.status = 'lobby' and r.language = small.language
      and r.test_match = small.test_match and (r.ranked or r.test_match) and r.starts_at is null
      and s.n between small_n and size - 1
      and (s.all_low = small_low or least(s.waited, small_waited) > mix_after)
    order by (s.all_low <> small_low), s.n desc, r.created_at
    limit 1
    for update of r skip locked;
    continue when big is null;

    select count(*) into big_n from public.room_members where room_id = big and left_at is null;
    continue when big_n >= size;
    for who in
      select m.profile_id from public.room_members m
      left join internal.ranked_queue rq on rq.profile_id = m.profile_id
      where m.room_id = small.id and m.left_at is null
      order by coalesce(rq.joined_at, m.joined_at), m.seat
      limit size - big_n
    loop
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

-- ranked_status also says how many sit in the lobby (never who).
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
  seated integer;
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
  select r.id, r.test_match, r.seated into matched, is_test, seated
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
    'seated', seated,
    'test', coalesce(is_test, false),
    'cooldown_until', case when c.cooldown_until > now()
                           then (extract(epoch from c.cooldown_until) * 1000)::bigint end,
    'warning', c.strikes between 1 and 2 and c.last_abandon_at > now() - interval '24 hours'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- How many are around, for the home screen: counts only, cached 30 s.

create table if not exists internal.online_counts_cache (
  id boolean primary key default true check (id),
  counts jsonb not null,
  computed_at timestamptz not null
);
alter table internal.online_counts_cache enable row level security;
revoke all on internal.online_counts_cache from public, anon, authenticated;

create or replace function public.online_counts()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  cached internal.online_counts_cache;
  fresh jsonb;
begin
  select * into cached from internal.online_counts_cache where id;
  if found and cached.computed_at > now() - interval '30 seconds' then
    return cached.counts;
  end if;
  -- Only one caller recomputes; the others get the last numbers.
  if not pg_try_advisory_xact_lock(hashtext('oberta.online_counts')) then
    return coalesce(cached.counts, '{"online": 0, "queued": {"it": 0, "en": 0}}'::jsonb);
  end if;
  select jsonb_build_object(
    'online', (
      select count(distinct p) from (
        select profile_id as p from internal.ranked_queue
        union all
        select m.profile_id from public.room_members m join public.rooms r on r.id = m.room_id
        where m.left_at is null and r.status = 'lobby' and m.joined_at > now() - interval '30 minutes'
        union all
        select profile_id from public.game_seats
        where profile_id is not null and last_seen > now() - interval '2 minutes'
      ) people
    ),
    'queued', jsonb_build_object(
      'it', (select count(*) from internal.ranked_queue where language = 'it'),
      'en', (select count(*) from internal.ranked_queue where language = 'en')
    )
  ) into fresh;
  insert into internal.online_counts_cache (id, counts, computed_at) values (true, fresh, now())
  on conflict (id) do update set counts = excluded.counts, computed_at = excluded.computed_at;
  return fresh;
end;
$$;
revoke all on function public.online_counts() from public, anon;
grant execute on function public.online_counts() to authenticated;
