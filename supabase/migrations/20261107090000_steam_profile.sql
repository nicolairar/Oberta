-- Steam players: persona name, Steam avatar as an opt-in profile picture,
-- and public platform marks (a small Steam / Apple logo next to a name).
--
--   profiles.steam_persona  the Steam persona name, as Steam shows it
--                           (control characters stripped, at most 64
--                           characters). Owner only (my_profile): shown
--                           under the handle in the player's own profile.
--   profiles.steam_avatar   the Steam avatar URL: https and a *.steamstatic.com
--                           host only (the allow-list below). Owner only.
--   profiles.picture        'game' (the drawn avatar, default) or 'steam'
--                           (the Steam image). Chosen by the player.
--   profiles.picture_url    generated: the Steam avatar only when the player
--                           chose 'steam'. The only picture others can read.
--   profiles.on_steam       a Steam identity is tied to the profile.
--   profiles.on_apple       an Apple identity is tied to the profile.
--                           Booleans only: nobody else learns the SteamID or
--                           the Apple address.
--
-- The steam-auth Edge Function fills persona and avatar on every Steam
-- sign-in, and again when the app asks (action "refresh", at most every six
-- hours: internal.steam_identities.refreshed_at). It reads the public
-- profile (steamcommunity.com/profiles/<id>/?xml=1) or, once a Web API key
-- exists, GetPlayerSummaries.
--
-- Deleting the account removes all of it: the columns live on the profile
-- row, internal.steam_identities cascades from it. export_my_data() carries
-- the profile row (with these columns) and now the SteamID too.

alter table public.profiles
  add column if not exists steam_persona text
    check (steam_persona is null or char_length(steam_persona) between 1 and 64),
  add column if not exists steam_avatar text
    check (steam_avatar is null or steam_avatar ~ '^https://([a-z0-9-]+\.)*steamstatic\.com/[A-Za-z0-9/_.-]{1,200}$'),
  add column if not exists picture text not null default 'game' check (picture in ('game', 'steam')),
  add column if not exists on_steam boolean not null default false,
  add column if not exists on_apple boolean not null default false;

alter table public.profiles
  add column if not exists picture_url text
    generated always as (case when picture = 'steam' then steam_avatar end) stored;

alter table internal.steam_identities add column if not exists refreshed_at timestamptz;

-- What others may read, what the owner may change.
revoke select on public.profiles from authenticated;
grant select (id, handle, language, avatar, created_at, on_steam, on_apple, picture_url) on public.profiles to authenticated;
revoke update on public.profiles from authenticated;
grant update (handle, language, picture) on public.profiles to authenticated;

-- on_steam follows internal.steam_identities. When linking moves a Steam
-- identity to the older profile, the persona, the avatar and the picture
-- choice move with it.
create or replace function internal.steam_identity_marks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    if tg_op = 'UPDATE' and new.profile_id is distinct from old.profile_id then
      update public.profiles p
         set steam_persona = coalesce(p.steam_persona, o.steam_persona),
             steam_avatar = coalesce(p.steam_avatar, o.steam_avatar),
             picture = case when p.picture = 'game' then o.picture else p.picture end
        from public.profiles o
       where p.id = new.profile_id and o.id = old.profile_id;
    end if;
    if tg_op = 'DELETE' or new.profile_id is distinct from old.profile_id then
      update public.profiles
         set on_steam = false, steam_persona = null, steam_avatar = null, picture = 'game'
       where id = old.profile_id;
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    update public.profiles set on_steam = true where id = new.profile_id and not on_steam;
  end if;
  return null;
end;
$$;
revoke all on function internal.steam_identity_marks() from public, anon, authenticated;

drop trigger if exists steam_identity_marks on internal.steam_identities;
create trigger steam_identity_marks
after insert or update or delete on internal.steam_identities
for each row execute function internal.steam_identity_marks();

-- on_apple follows auth.identities (sign-in, linking, deletion).
create or replace function internal.apple_identity_marks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  touched uuid[] := '{}';
begin
  if tg_op in ('UPDATE', 'DELETE') and old.provider = 'apple' then
    touched := touched || old.user_id;
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.provider = 'apple' then
    touched := touched || new.user_id;
  end if;
  if cardinality(touched) > 0 then
    update public.profiles p
       set on_apple = exists (select 1 from auth.identities i where i.user_id = p.id and i.provider = 'apple')
     where p.id = any (touched);
  end if;
  return null;
end;
$$;
revoke all on function internal.apple_identity_marks() from public, anon, authenticated;

drop trigger if exists oberta_apple_identity_marks on auth.identities;
create trigger oberta_apple_identity_marks
after insert or update or delete on auth.identities
for each row execute function internal.apple_identity_marks();

-- The marks of the players already here.
update public.profiles p
   set on_steam = exists (select 1 from internal.steam_identities s where s.profile_id = p.id),
       on_apple = exists (select 1 from auth.identities i where i.user_id = p.id and i.provider = 'apple');

-- The Steam id of a profile when its persona and avatar are due a refresh
-- (never fetched, or more than six hours ago), else null. Service role only.
create or replace function public.steam_refresh_target(p_profile_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select steam_id from internal.steam_identities
   where profile_id = p_profile_id
     and (refreshed_at is null or refreshed_at < now() - interval '6 hours');
$$;

-- Stores what the Steam profile says. Persona: control characters out,
-- trimmed, at most 64 characters. Avatar: only an https *.steamstatic.com
-- URL, anything else is dropped. A missing value keeps the old one.
create or replace function public.steam_profile_store(p_steam_id text, p_persona text, p_avatar text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner uuid;
  persona text := nullif(left(btrim(regexp_replace(coalesce(p_persona, ''), '[[:cntrl:]]', '', 'g')), 64), '');
  image text := case
    when p_avatar ~ '^https://([a-z0-9-]+\.)*steamstatic\.com/[A-Za-z0-9/_.-]{1,200}$' then p_avatar
  end;
begin
  update internal.steam_identities set refreshed_at = now() where steam_id = p_steam_id
  returning profile_id into owner;
  if owner is null then
    return;
  end if;
  update public.profiles
     set steam_persona = coalesce(persona, steam_persona),
         steam_avatar = coalesce(image, steam_avatar)
   where id = owner;
end;
$$;

revoke all on function public.steam_refresh_target(uuid) from public, anon, authenticated;
revoke all on function public.steam_profile_store(text, text, text) from public, anon, authenticated;
grant execute on function public.steam_refresh_target(uuid) to service_role;
grant execute on function public.steam_profile_store(text, text, text) to service_role;

-- The data export now names the Steam account too.
create or replace function public.export_my_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  return internal.export_my_data_base() || jsonb_build_object(
    'missions', coalesce((select jsonb_agg(to_jsonb(m) - 'profile_id') from internal.player_missions m
                          where m.profile_id = me), '[]'::jsonb),
    'stats', coalesce((select jsonb_object_agg(metric, value) from internal.player_stats
                       where profile_id = me), '{}'::jsonb),
    'achievements', coalesce((select jsonb_agg(to_jsonb(a) - 'profile_id') from internal.player_achievements a
                              where a.profile_id = me), '[]'::jsonb),
    'steam', (select jsonb_build_object('steam_id', s.steam_id, 'linked_at', s.created_at, 'refreshed_at', s.refreshed_at)
                from internal.steam_identities s where s.profile_id = me)
  );
end;
$$;
revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- The leaderboard rows carry the platform marks.
create or replace function public.leaderboard(board_language text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  cached internal.leaderboard_cache;
  top jsonb;
  mine public.ratings;
  place bigint;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if board_language not in ('it', 'en') then
    raise exception 'bad_language';
  end if;
  select * into cached from internal.leaderboard_cache where language = board_language;
  if found and cached.computed_at > now() - interval '60 seconds' then
    top := cached.rows;
  elsif not pg_try_advisory_xact_lock(hashtext('oberta.leaderboard.' || board_language)) then
    top := coalesce(cached.rows, '[]'::jsonb);
  else
    select coalesce(jsonb_agg(jsonb_build_object('rank', n, 'handle', handle, 'tier', tier,
                                                 'steam', on_steam, 'apple', on_apple) order by n), '[]'::jsonb)
      into top
    from (
      select row_number() over (order by rt.mu - 3 * rt.sigma desc, rt.games desc, p.handle) as n,
             p.handle, p.on_steam, p.on_apple, internal.rank_tier(rt.mu - 3 * rt.sigma) as tier
      from public.ratings rt
      join public.profiles p on p.id = rt.profile_id
      where rt.language = board_language and rt.games > 0 and p.handle is not null
      order by rt.mu - 3 * rt.sigma desc, rt.games desc, p.handle
      limit 100
    ) board;
    insert into internal.leaderboard_cache (language, rows, computed_at) values (board_language, top, now())
    on conflict (language) do update set rows = excluded.rows, computed_at = excluded.computed_at;
  end if;
  select * into mine from public.ratings where profile_id = me and language = board_language and games > 0;
  if found then
    select 1 + count(*) into place
    from public.ratings rt
    join public.profiles p on p.id = rt.profile_id
    where rt.language = board_language and rt.games > 0 and p.handle is not null
      and rt.mu - 3 * rt.sigma > mine.mu - 3 * mine.sigma;
  end if;
  return jsonb_build_object(
    'top', top,
    'me', case when place is null then null
               else jsonb_build_object('rank', place, 'tier', internal.rank_tier(mine.mu - 3 * mine.sigma)) end
  );
end;
$$;
revoke all on function public.leaderboard(text) from public, anon;
grant execute on function public.leaderboard(text) to authenticated;

-- Old cached boards have no marks: compute them again.
delete from internal.leaderboard_cache;
