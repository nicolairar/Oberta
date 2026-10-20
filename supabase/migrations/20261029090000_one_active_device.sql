-- One active device per account.
--
-- Every app instance makes up a device session id when it starts (and again
-- after each sign-in) and claims it with claim_session(). Only the claimed
-- session may write: play, chat, queue for ranked, shop, change the look.
--
--   internal.active_sessions   one row per profile: the session that may
--                              play now, its label ("iPhone", "Mac", later
--                              "Steam"), when it claimed and when it was last
--                              seen, plus the latest device that asked to
--                              play (the contender) while this one was active.
--   public.session_signals     a read-only mirror of the row (labels and ids,
--                              no secrets) in the supabase_realtime
--                              publication: both devices subscribe to their
--                              own profile and show the "one device at a
--                              time" dialog the moment something changes.
--
-- claim_session(session_id, device_label, force)
--   * no row, the same session, force = true, or an active session not seen
--     for 90 seconds (closed app, dead phone) -> this session becomes active;
--   * otherwise the caller becomes the contender and gets {active: false}.
--     Both devices then show the dialog; whoever taps "GIOCO QUA" calls again
--     with force = true and wins, the other is pushed out.
-- session_status(session_id)
--   heartbeat (every ~30 s while the app is open) and the answer the app
--   needs: am I active, who is the other device, is someone asking.
--
-- Enforcement: PostgREST calls public.check_device_session() before every
-- request (pgrst.db_pre_request). For the write RPCs listed there it reads
-- the x-device-session header that the app sends on every call and raises
-- 'other_device' if it is not the active session of the caller.
--
-- Transition period: builds older than this one send no header. A request
-- without the header is let through, so those builds keep working exactly
-- as before (and they never claim, so they never push anyone out). When no
-- such build is left in the stores, a later migration flips
-- internal.require_device_session() to true and headerless writes fail too.
--
-- Switching device during a running game: claiming does not touch the seat.
-- The old device can no longer ping (game_ping is guarded), so its seat goes
-- quiet; the new device, signed in as the same profile, opens the game, its
-- game_ping refreshes the same seat and it simply carries on. Rule: if the
-- new device reconnects within the usual reconnect grace, nothing happened
-- (no penalty); if nobody comes back in time, the seat is handled exactly
-- like leaving (20261027090000_game_leave / 20261028090000_afk_and_dead_leave):
-- abandon penalty if alive, none if already dead.

create table if not exists internal.active_sessions (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  session_id text not null check (length(session_id) between 8 and 64),
  device_label text not null default '' check (length(device_label) <= 32),
  claimed_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  contender_session text check (length(contender_session) between 8 and 64),
  contender_label text check (length(contender_label) <= 32),
  contended_at timestamptz
);

revoke all on table internal.active_sessions from public, anon, authenticated;
grant all on table internal.active_sessions to service_role;

create table if not exists public.session_signals (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  active_session text not null,
  active_label text not null default '',
  contender_session text,
  contender_label text,
  updated_at timestamptz not null default now()
);

alter table public.session_signals enable row level security;
alter table public.session_signals replica identity full;

revoke all on table public.session_signals from public, anon, authenticated;
grant select on table public.session_signals to authenticated;
grant all on table public.session_signals to service_role;

drop policy if exists "players read their own session signal" on public.session_signals;
create policy "players read their own session signal"
  on public.session_signals for select to authenticated
  using (profile_id = (select auth.uid()));

-- Mirror only what the devices react to; the heartbeat (last_seen) stays quiet.
create or replace function internal.sync_session_signal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.session_signals
    (profile_id, active_session, active_label, contender_session, contender_label, updated_at)
  values (new.profile_id, new.session_id, new.device_label, new.contender_session, new.contender_label, now())
  on conflict (profile_id) do update
    set active_session = excluded.active_session,
        active_label = excluded.active_label,
        contender_session = excluded.contender_session,
        contender_label = excluded.contender_label,
        updated_at = now()
    where (public.session_signals.active_session, public.session_signals.active_label,
           public.session_signals.contender_session, public.session_signals.contender_label)
      is distinct from
          (excluded.active_session, excluded.active_label, excluded.contender_session, excluded.contender_label);
  return new;
end;
$$;

revoke all on function internal.sync_session_signal() from public, anon, authenticated;

drop trigger if exists active_sessions_sync_signal on internal.active_sessions;
create trigger active_sessions_sync_signal
  after insert or update on internal.active_sessions
  for each row execute function internal.sync_session_signal();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'session_signals'
    ) then
    alter publication supabase_realtime add table public.session_signals;
  end if;
end;
$$;

-- False during the transition: requests without the header pass.
create or replace function internal.require_device_session()
returns boolean
language sql
immutable
set search_path = ''
as $$ select false $$;

create or replace function internal.session_answer(s internal.active_sessions, session text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'active', s.session_id = session,
    'active_label', s.device_label,
    'waiting', s.session_id <> session and s.contender_session is not distinct from session,
    'contender_label',
      case when s.session_id = session
             and s.contender_session is not null
             and s.contender_session <> session
             and s.contended_at > now() - interval '5 minutes'
           then s.contender_label end
  );
$$;

revoke all on function internal.session_answer(internal.active_sessions, text) from public, anon, authenticated;

create or replace function public.claim_session(session_id text, device_label text, force boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  label text := left(coalesce(nullif(trim(device_label), ''), '?'), 32);
  current internal.active_sessions;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if session_id is null or length(session_id) not between 8 and 64 then
    raise exception 'not_allowed';
  end if;
  if not exists (select 1 from public.profiles where id = me) then
    raise exception 'profile_incomplete';
  end if;

  select * into current from internal.active_sessions where profile_id = me for update;

  if not found then
    insert into internal.active_sessions (profile_id, session_id, device_label)
    values (me, claim_session.session_id, label)
    returning * into current;
  elsif current.session_id = claim_session.session_id then
    update internal.active_sessions
    set device_label = label, last_seen = now(),
        contender_session = case when force then null else contender_session end,
        contender_label = case when force then null else contender_label end,
        contended_at = case when force then null else contended_at end
    where profile_id = me
    returning * into current;
  elsif force or current.last_seen < now() - interval '90 seconds' then
    update internal.active_sessions
    set session_id = claim_session.session_id, device_label = label,
        claimed_at = now(), last_seen = now(),
        contender_session = null, contender_label = null, contended_at = null
    where profile_id = me
    returning * into current;
  else
    update internal.active_sessions
    set contender_session = claim_session.session_id, contender_label = label, contended_at = now()
    where profile_id = me
    returning * into current;
  end if;

  return internal.session_answer(current, claim_session.session_id);
end;
$$;

revoke all on function public.claim_session(text, text, boolean) from public, anon;
grant execute on function public.claim_session(text, text, boolean) to authenticated;

create or replace function public.session_status(session_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  current internal.active_sessions;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  update internal.active_sessions set last_seen = now()
  where profile_id = me and active_sessions.session_id = session_status.session_id
  returning * into current;
  if not found then
    select * into current from internal.active_sessions where profile_id = me;
    if not found then
      return jsonb_build_object('active', false, 'active_label', null, 'waiting', false, 'contender_label', null);
    end if;
  end if;
  return internal.session_answer(current, session_status.session_id);
end;
$$;

revoke all on function public.session_status(text) from public, anon;
grant execute on function public.session_status(text) to authenticated;

-- Runs before every PostgREST request. Cheap for everything that is not a
-- guarded write: one string comparison and out.
create or replace function public.check_device_session()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  path text := current_setting('request.path', true);
  me uuid;
  header text;
  active text;
begin
  if path is null or path not in (
    '/rpc/submit_intent', '/rpc/send_chat', '/rpc/game_ping',
    '/rpc/enqueue_ranked', '/rpc/create_room', '/rpc/join_room', '/rpc/start_game', '/rpc/set_room_bots',
    '/rpc/buy_item', '/rpc/buy_bundle', '/rpc/equip_item', '/rpc/unequip_slot', '/rpc/save_face'
  ) then
    return;
  end if;
  me := auth.uid();
  if me is null then
    return;
  end if;
  header := nullif(current_setting('request.headers', true), '')::json ->> 'x-device-session';
  if header is null then
    if internal.require_device_session() then
      raise exception 'other_device';
    end if;
    return;
  end if;
  select session_id into active from internal.active_sessions where profile_id = me;
  if active is not null and active <> header then
    raise exception 'other_device';
  end if;
end;
$$;

revoke all on function public.check_device_session() from public, anon;
grant execute on function public.check_device_session() to authenticated, anon, service_role;

alter role authenticator set pgrst.db_pre_request = 'public.check_device_session';
notify pgrst, 'reload config';
