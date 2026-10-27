-- Account linking without codes. The 6-character link codes of
-- 20261031090000_steam_login_and_links.sql are gone: a player proves the
-- other identity by signing in with it, and the steam-auth Edge Function
-- (service role) joins the two profiles.
--
--   Desktop (signed in with Steam) -> "Collega Apple / Google": the app runs
--     the Apple or Google OAuth sign-in in the system browser (PKCE, a
--     loopback redirect to 127.0.0.1 like the Steam login) on a throwaway
--     auth client, then sends that session's access token. The function
--     checks both tokens and calls link_profiles().
--   Mobile (signed in with Apple / Google) -> "Collega Steam": Steam OpenID
--     in the browser; steam-auth checks the assertion and sends the app back
--     to oberta://steam-link with a one-time code bound to the app's state
--     (internal.steam_link_codes, two minutes). The app trades it, with its
--     own JWT, and the function calls steam_link().
--
-- Merge rules are the old ones: the OLDER profile stays (handle, look,
-- coins, XP, cosmetics, ratings, history); the younger one's Steam / Apple /
-- Google identities move to it; the younger auth user is signed out, banned
-- and its handle freed. Refused when both have Steam or the same provider
-- ('link_conflict'), when either is in a game or in the ranked queue
-- ('already_in_game'), or when it is the same account ('link_same_account').

drop function if exists public.link_code_create();
drop function if exists public.link_code_redeem(text);
drop table if exists internal.link_codes;
drop table if exists internal.link_attempts;

create table if not exists internal.steam_link_codes (
  code_hash text primary key,
  state text not null check (length(state) between 16 and 128),
  steam_id text not null check (steam_id ~ '^[0-9]{17}$'),
  expires_at timestamptz not null
);
revoke all on table internal.steam_link_codes from public, anon, authenticated;

-- Joins two profiles (rules above). Service role only: the caller of the
-- Edge Function has proved both identities. Returns the profile that stays.
create or replace function public.link_profiles(p_caller uuid, p_other uuid)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  older uuid;
  younger uuid;
begin
  if p_caller is null or p_other is null then
    raise exception 'not_signed_in';
  end if;
  if p_caller = p_other then
    raise exception 'link_same_account';
  end if;
  if (select count(*) from public.profiles where id in (p_caller, p_other)) < 2 then
    raise exception 'not_signed_in';
  end if;
  if public._busy_playing(p_caller) or public._busy_playing(p_other) then
    raise exception 'already_in_game';
  end if;

  select p.id into older from public.profiles p
   where p.id in (p_caller, p_other) order by p.created_at, p.id limit 1;
  younger := case when older = p_caller then p_other else p_caller end;

  if (select count(*) from internal.steam_identities where profile_id in (p_caller, p_other)) > 1 then
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

  delete from internal.active_sessions where profile_id = younger;
  delete from auth.refresh_tokens where user_id = younger::text;
  delete from auth.sessions where user_id = younger;
  update auth.users set banned_until = 'infinity' where id = younger;
  update public.profiles set handle = null where id = younger;
  insert into internal.merged_profiles (merged_id, into_id) values (younger, older)
  on conflict (merged_id) do update set into_id = excluded.into_id, merged_at = now();

  return json_build_object('kept', older, 'merged', younger);
end;
$$;

-- "Collega Steam": ties a verified SteamID to the caller. A SteamID nobody
-- has yet simply joins the caller's profile; one that already signs into a
-- profile merges the two (link_profiles).
create or replace function public.steam_link(p_profile_id uuid, p_steam_id text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner uuid;
begin
  select profile_id into owner from internal.steam_identities where steam_id = p_steam_id;
  if owner = p_profile_id then
    raise exception 'link_same_account';
  end if;
  if owner is not null then
    return public.link_profiles(p_profile_id, owner);
  end if;
  if exists (select 1 from internal.steam_identities where profile_id = p_profile_id) then
    raise exception 'link_conflict';
  end if;
  insert into internal.steam_identities (steam_id, profile_id) values (p_steam_id, p_profile_id);
  return json_build_object('kept', p_profile_id, 'merged', null);
end;
$$;

-- The Steam OpenID leg of "Collega Steam": the verified assertion once (by
-- its nonce), then a one-time code for the app, bound to its state.
create or replace function public.steam_link_code_issue(p_steam_id text, p_state text, p_nonce text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  code text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  delete from internal.steam_nonces where seen_at < now() - interval '1 day';
  delete from internal.steam_link_codes where expires_at < now();
  begin
    insert into internal.steam_nonces (nonce) values (p_nonce);
  exception when unique_violation then
    raise exception 'steam_replay';
  end;
  insert into internal.steam_link_codes (code_hash, state, steam_id, expires_at)
  values (encode(sha256(convert_to(code, 'UTF8')), 'hex'), p_state, p_steam_id, now() + interval '2 minutes');
  return code;
end;
$$;

create or replace function public.steam_link_code_consume(p_code text, p_state text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  found text;
begin
  delete from internal.steam_link_codes
   where code_hash = encode(sha256(convert_to(p_code, 'UTF8')), 'hex')
     and state = p_state
     and expires_at > now()
  returning steam_id into found;
  if found is null then
    raise exception 'steam_code_invalid';
  end if;
  return found;
end;
$$;

revoke all on function public.link_profiles(uuid, uuid) from public, anon, authenticated;
revoke all on function public.steam_link(uuid, text) from public, anon, authenticated;
revoke all on function public.steam_link_code_issue(text, text, text) from public, anon, authenticated;
revoke all on function public.steam_link_code_consume(text, text) from public, anon, authenticated;
grant execute on function public.link_profiles(uuid, uuid) to service_role;
grant execute on function public.steam_link(uuid, text) to service_role;
grant execute on function public.steam_link_code_issue(text, text, text) to service_role;
grant execute on function public.steam_link_code_consume(text, text) to service_role;
