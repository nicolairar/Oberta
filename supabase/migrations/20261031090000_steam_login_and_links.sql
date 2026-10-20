-- Steam login (OpenID 2.0, Phase 1 of docs/steam.md) and account linking.
--
--   internal.steam_identities   one row per SteamID64: the profile it signs
--                               into. Written only by the steam-auth Edge
--                               Function (service role) and by linking.
--   internal.steam_nonces       every openid.response_nonce accepted once,
--                               so a captured Steam assertion cannot be
--                               replayed.
--   internal.steam_login_codes  the one-time code the function hands to the
--                               desktop app's loopback listener (stored as a
--                               sha256, bound to the app's random state,
--                               valid two minutes). The app trades it, with
--                               the same state, for a magic-link token.
--   internal.link_codes         "Collega account": a 6-character code made
--                               by a signed-in player, valid ten minutes,
--                               redeemed on another platform while signed in
--                               with the other identity.
--   internal.link_attempts      wrong codes per profile (five per ten
--                               minutes, then 'too_many_attempts').
--   internal.merged_profiles    which profile was folded into which.
--
-- Link rules (see docs/steam.md, 1.4):
--   * the OLDER profile (profiles.created_at) stays: handle, look, coins,
--     XP, cosmetics, ratings, history, receipts. The younger profile's
--     progress is not carried over;
--   * the younger profile's sign-in identities move to the older one: its
--     Steam identity (internal.steam_identities) and its Apple / Google
--     identities (auth.identities). Email identities (test accounts, the
--     synthetic address of a Steam user) are not moved;
--   * refused when both have a Steam identity or both have the same
--     provider ('link_conflict'), when either is in a running game or in
--     the ranked queue ('already_in_game'), or when the code is the
--     caller's own ('link_same_account');
--   * the younger auth user is then signed out everywhere, banned and its
--     handle freed; it can no longer be entered with any identity. If the
--     caller was the younger one, the app signs in again (the same Steam or
--     Apple / Google login now lands on the older profile).

create table if not exists internal.steam_identities (
  steam_id text primary key check (steam_id ~ '^[0-9]{17}$'),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
revoke all on table internal.steam_identities from public, anon, authenticated;
grant all on table internal.steam_identities to service_role;

create table if not exists internal.steam_nonces (
  nonce text primary key check (length(nonce) <= 255),
  seen_at timestamptz not null default now()
);
revoke all on table internal.steam_nonces from public, anon, authenticated;

create table if not exists internal.steam_login_codes (
  code_hash text primary key,
  state text not null check (length(state) between 16 and 128),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null
);
revoke all on table internal.steam_login_codes from public, anon, authenticated;

create table if not exists internal.link_codes (
  code text primary key check (code ~ '^[A-Z2-9]{6}$'),
  profile_id uuid not null unique references public.profiles (id) on delete cascade,
  expires_at timestamptz not null
);
revoke all on table internal.link_codes from public, anon, authenticated;

create table if not exists internal.link_attempts (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists link_attempts_by_profile on internal.link_attempts (profile_id, at);
revoke all on table internal.link_attempts from public, anon, authenticated;

create table if not exists internal.merged_profiles (
  merged_id uuid primary key,
  into_id uuid not null references public.profiles (id) on delete cascade,
  merged_at timestamptz not null default now()
);
revoke all on table internal.merged_profiles from public, anon, authenticated;

-- The profile a Steam account signs into, or null (service role only).
create or replace function public.steam_identity_profile(p_steam_id text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select profile_id from internal.steam_identities where steam_id = p_steam_id;
$$;

-- The SteamID64 tied to a profile, or null (service role only).
create or replace function public.steam_identity_of_profile(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select steam_id from internal.steam_identities where profile_id = p_profile_id;
$$;

-- Ties a new Steam account to the profile just created for it. Returns the
-- profile that owns the Steam id afterwards (another one if a parallel
-- login won the race).
create or replace function public.steam_identity_attach(p_steam_id text, p_profile_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner uuid;
begin
  insert into internal.steam_identities (steam_id, profile_id)
  values (p_steam_id, p_profile_id)
  on conflict (steam_id) do nothing;
  select profile_id into owner from internal.steam_identities where steam_id = p_steam_id;
  return owner;
end;
$$;

-- Accepts a verified Steam assertion once (by its nonce) and issues the
-- one-time login code for the app. Returns the code in clear, once.
create or replace function public.steam_login_code_issue(p_profile_id uuid, p_state text, p_nonce text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  code text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  delete from internal.steam_nonces where seen_at < now() - interval '1 day';
  delete from internal.steam_login_codes where expires_at < now();
  begin
    insert into internal.steam_nonces (nonce) values (p_nonce);
  exception when unique_violation then
    raise exception 'steam_replay';
  end;
  insert into internal.steam_login_codes (code_hash, state, profile_id, expires_at)
  values (encode(sha256(convert_to(code, 'UTF8')), 'hex'), p_state, p_profile_id, now() + interval '2 minutes');
  return code;
end;
$$;

-- Trades the code (with the state it was bound to) for the profile id, once.
create or replace function public.steam_login_code_consume(p_code text, p_state text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  who uuid;
begin
  delete from internal.steam_login_codes
   where code_hash = encode(sha256(convert_to(p_code, 'UTF8')), 'hex')
     and state = p_state
     and expires_at > now()
  returning profile_id into who;
  if who is null then
    raise exception 'steam_code_invalid';
  end if;
  return who;
end;
$$;

revoke all on function public.steam_identity_profile(text) from public, anon, authenticated;
revoke all on function public.steam_identity_attach(text, uuid) from public, anon, authenticated;
revoke all on function public.steam_identity_of_profile(uuid) from public, anon, authenticated;
grant execute on function public.steam_identity_of_profile(uuid) to service_role;
revoke all on function public.steam_login_code_issue(uuid, text, text) from public, anon, authenticated;
revoke all on function public.steam_login_code_consume(text, text) from public, anon, authenticated;
grant execute on function public.steam_identity_profile(text) to service_role;
grant execute on function public.steam_identity_attach(text, uuid) to service_role;
grant execute on function public.steam_login_code_issue(uuid, text, text) to service_role;
grant execute on function public.steam_login_code_consume(text, text) to service_role;

-- "Collega account": a fresh 6-character code for the caller, valid ten
-- minutes. Asking again replaces the old one.
create or replace function public.link_code_create()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  new_code text;
  until timestamptz := now() + interval '10 minutes';
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  delete from internal.link_codes where profile_id = me or expires_at < now();
  loop
    select string_agg(substr(alphabet, get_byte(uuid_send(gen_random_uuid()), 0) % length(alphabet) + 1, 1), '')
      into new_code
      from generate_series(1, 6);
    begin
      insert into internal.link_codes (code, profile_id, expires_at) values (new_code, me, until);
      exit;
    exception when unique_violation then
      -- another player holds this code right now: draw again.
    end;
  end loop;
  return json_build_object('code', new_code, 'expires_at', until);
end;
$$;

create or replace function public._busy_playing(who uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1 from public.room_members m join public.rooms r on r.id = m.room_id
            where m.profile_id = who and m.left_at is null and r.status = 'playing'
         )
      or exists (select 1 from internal.ranked_queue q where q.profile_id = who);
$$;
revoke all on function public._busy_playing(uuid) from public, anon, authenticated;

-- Redeems a code made on the other platform: the two accounts become one
-- (rules at the top of this file). Returns which profile stayed and whether
-- the caller must sign in again.
create or replace function public.link_code_redeem(p_code text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  other uuid;
  older uuid;
  younger uuid;
  clean text := upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if (select count(*) from internal.link_attempts
       where profile_id = me and at > now() - interval '10 minutes') >= 5 then
    raise exception 'too_many_attempts';
  end if;
  select profile_id into other from internal.link_codes where code = clean and expires_at > now();
  if other is null then
    insert into internal.link_attempts (profile_id) values (me);
    raise exception 'link_code_invalid';
  end if;
  if other = me then
    raise exception 'link_same_account';
  end if;
  if public._busy_playing(me) or public._busy_playing(other) then
    raise exception 'already_in_game';
  end if;

  select p.id into older from public.profiles p
   where p.id in (me, other) order by p.created_at, p.id limit 1;
  younger := case when older = me then other else me end;

  if (select count(*) from internal.steam_identities where profile_id in (me, other)) > 1 then
    raise exception 'link_conflict';
  end if;
  if exists (
    select 1 from auth.identities y join auth.identities o on o.provider = y.provider
     where y.user_id = younger and o.user_id = older and y.provider <> 'email'
  ) then
    raise exception 'link_conflict';
  end if;

  update internal.steam_identities set profile_id = older where profile_id = younger;
  update auth.identities set user_id = older, updated_at = now()
   where user_id = younger and provider <> 'email';

  delete from internal.link_codes where profile_id in (me, other);
  delete from internal.link_attempts where profile_id = younger;
  delete from internal.active_sessions where profile_id = younger;
  delete from auth.refresh_tokens where user_id = younger::text;
  delete from auth.sessions where user_id = younger;
  update auth.users set banned_until = 'infinity' where id = younger;
  update public.profiles set handle = null where id = younger;
  insert into internal.merged_profiles (merged_id, into_id) values (younger, older)
  on conflict (merged_id) do update set into_id = excluded.into_id, merged_at = now();

  return json_build_object('kept', older, 'merged', younger, 'sign_in_again', younger = me);
end;
$$;

revoke all on function public.link_code_create() from public, anon;
revoke all on function public.link_code_redeem(text) from public, anon;
grant execute on function public.link_code_create() to authenticated;
grant execute on function public.link_code_redeem(text) to authenticated;
