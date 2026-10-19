-- Reporting and blocking players (App Store guideline 1.2).
--
--   public.player_blocks   one row per block; only the blocker sees it.
--                          Blocks used to live in friendships as a status,
--                          which could not hold a block in each direction.
--   internal.reports       what players report; never readable by clients,
--                          and the target never learns who reported them.
--
-- A block hides the blocked player's chat for the blocker (the chat policy
-- below), ends any friendship, refuses friend requests either way, keeps the
-- blocked player out of rooms the blocker hosts, and the ranked matcher
-- prefers lobbies without either of them.

-- ---------------------------------------------------------------------------
-- Blocks

create table if not exists public.player_blocks (
  blocker uuid not null references public.profiles (id) on delete cascade,
  blocked uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index if not exists player_blocks_blocked on public.player_blocks (blocked);
alter table public.player_blocks enable row level security;
revoke all on public.player_blocks from anon, authenticated;
grant select on public.player_blocks to authenticated;

drop policy if exists "players see the blocks they placed" on public.player_blocks;
create policy "players see the blocks they placed"
  on public.player_blocks for select
  to authenticated
  using (blocker = (select auth.uid()));

-- The old blocks move over.
insert into public.player_blocks (blocker, blocked, created_at)
select requester, addressee, updated_at from public.friendships where status = 'blocked'
on conflict do nothing;
delete from public.friendships where status = 'blocked';

-- True when either player has blocked the other.
create or replace function internal.blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.player_blocks
    where (blocker = a and blocked = b) or (blocker = b and blocked = a)
  );
$$;
revoke all on function internal.blocked_between(uuid, uuid) from public, anon, authenticated;

create or replace function public.block_player(other uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if other is null or other = me or not exists (select 1 from public.profiles where id = other) then
    raise exception 'player_not_found';
  end if;
  delete from public.friendships
  where (requester = me and addressee = other) or (requester = other and addressee = me);
  insert into public.player_blocks (blocker, blocked) values (me, other) on conflict do nothing;
end;
$$;

create or replace function public.unblock_player(other uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  delete from public.player_blocks where blocker = me and blocked = other;
end;
$$;
revoke all on function public.unblock_player(uuid) from public, anon;
grant execute on function public.unblock_player(uuid) to authenticated;

-- As before, plus: no requests between players when either blocked the other.
create or replace function public.send_friend_request(target uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  existing public.friendships;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if target is null or target = me
     or not exists (select 1 from public.profiles where id = target and handle is not null) then
    raise exception 'player_not_found';
  end if;
  if internal.blocked_between(me, target) then
    raise exception 'not_allowed';
  end if;

  select * into existing from public.friendships
  where (requester = me and addressee = target) or (requester = target and addressee = me)
  for update;

  if not found then
    insert into public.friendships (requester, addressee) values (me, target);
    return 'pending';
  end if;

  if existing.status = 'blocked' then
    raise exception 'not_allowed';
  end if;
  if existing.status = 'pending' and existing.addressee = me then
    update public.friendships set status = 'accepted', updated_at = now()
    where requester = existing.requester and addressee = existing.addressee;
    return 'accepted';
  end if;
  return existing.status;
end;
$$;

-- A blocked player cannot take a seat in a room the blocker hosts (friends
-- rooms only: the ranked matcher seats people on its own terms).
create or replace function public._no_blocked_guests()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.rooms r
    join public.player_blocks b on b.blocker = r.host and b.blocked = new.profile_id
    where r.id = new.room_id and not r.ranked and not r.test_match
  ) then
    raise exception 'not_allowed';
  end if;
  return new;
end;
$$;
revoke all on function public._no_blocked_guests() from public, anon, authenticated;
drop trigger if exists no_blocked_guests on public.room_members;
create trigger no_blocked_guests
  before insert on public.room_members
  for each row execute function public._no_blocked_guests();

-- The chat, as before, minus the players the reader has blocked. Realtime
-- applies the same policy.
drop policy if exists "members read the room chat" on public.game_chat;
create policy "members read the room chat"
  on public.game_chat for select
  to authenticated
  using (
    (
      (channel in ('lobby', 'day') and (select public.is_room_member(room_id)))
      or (channel = 'family' and (select public.is_family_reader(room_id, game_id)))
    )
    and not exists (
      select 1 from public.player_blocks b
      where b.blocker = (select auth.uid()) and b.blocked = game_chat.profile_id
    )
  );

-- The ranked matcher, as before, but a lobby where somebody blocked the
-- newcomer (or the newcomer blocked somebody) comes last.
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
  perform public._sweep_rooms();
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
           bool_or(internal.blocked_between(who, m.profile_id)) as blocked,
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
  order by coalesce(s.blocked, false), s.n desc, r.created_at
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

-- ---------------------------------------------------------------------------
-- Reports

create table if not exists internal.reports (
  id bigint generated always as identity primary key,
  -- Kept when the reporter deletes the account, so the report still counts.
  reporter uuid references public.profiles (id) on delete set null,
  target uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (reason in ('language', 'cheating', 'identity', 'spam', 'other')),
  note text check (char_length(note) <= 500),
  game_id uuid,
  room_id uuid,
  message_id bigint,
  -- A copy of the message as it was: the chat itself is deleted after 90 days.
  message_text text,
  message_channel text,
  -- The target's name at the time.
  target_handle text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists reports_by_target on internal.reports (target, created_at);
create index if not exists reports_by_reporter on internal.reports (reporter, created_at);
alter table internal.reports enable row level security;
revoke all on internal.reports from public, anon, authenticated;

-- Report a player. Quietly does nothing when the same player was already
-- reported by the caller in the last day (or for the same message). Once
-- three or more different players have reported someone in 30 days, each
-- further reporter lowers that player's hidden conduct score a little.
create or replace function public.report_player(
  target uuid,
  reason text,
  note text default null,
  game_id uuid default null,
  message_id bigint default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  clean_note text := nullif(btrim(coalesce(report_player.note, '')), '');
  msg record;
  reporters integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select null::text as body, null::text as channel, null::uuid as room_id, null::uuid as game_id into msg;
  if report_player.target is null or report_player.target = me
     or not exists (select 1 from public.profiles p where p.id = report_player.target) then
    raise exception 'player_not_found';
  end if;
  if report_player.reason is null
     or report_player.reason not in ('language', 'cheating', 'identity', 'spam', 'other') then
    raise exception 'invalid_report';
  end if;
  if clean_note is not null and char_length(clean_note) > 500 then
    clean_note := left(clean_note, 500);
  end if;

  if (select count(*) from internal.reports r
      where r.reporter = me and r.created_at > now() - interval '1 hour') >= 10 then
    raise exception 'too_many_reports';
  end if;

  if report_player.message_id is not null then
    if exists (select 1 from internal.reports r
               where r.reporter = me and r.message_id = report_player.message_id) then
      return;
    end if;
  elsif exists (select 1 from internal.reports r
                where r.reporter = me and r.target = report_player.target
                  and r.created_at > now() - interval '1 day') then
    return;
  end if;

  -- The message, only if the caller sat in its room and it is the target's.
  if report_player.message_id is not null then
    select c.body, c.channel, c.room_id, c.game_id into msg
    from public.game_chat c
    where c.id = report_player.message_id and c.profile_id = report_player.target
      and exists (select 1 from public.room_members m where m.room_id = c.room_id and m.profile_id = me);
  end if;

  insert into internal.reports (
    reporter, target, reason, note, game_id, room_id, message_id, message_text, message_channel, target_handle
  )
  values (
    me,
    report_player.target,
    report_player.reason,
    clean_note,
    coalesce(report_player.game_id, msg.game_id),
    msg.room_id,
    case when msg.body is null then null else report_player.message_id end,
    msg.body,
    msg.channel,
    (select p.handle from public.profiles p where p.id = report_player.target)
  );

  if exists (select 1 from internal.reports r
             where r.reporter = me and r.target = report_player.target
               and r.created_at > now() - interval '30 days'
             offset 1) then
    return;  -- this reporter already counted
  end if;
  select count(distinct r.reporter) into reporters
  from internal.reports r
  where r.target = report_player.target and r.reporter is not null
    and r.created_at > now() - interval '30 days';
  if reporters >= 3 then
    perform internal.conduct_of(report_player.target);
    update internal.conduct
    set score = greatest(40, score - 5)
    where profile_id = report_player.target and score > 40;
  end if;
end;
$$;
revoke all on function public.report_player(uuid, text, text, uuid, bigint) from public, anon;
grant execute on function public.report_player(uuid, text, text, uuid, bigint) to authenticated;
