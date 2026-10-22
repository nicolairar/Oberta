-- Mandatory update: a minimum build per platform.
--
--   internal.config  min_build_<platform>   the lowest build number (the +N of
--                                           pubspec "version: x.y.z+N") that
--                                           may still talk to the server;
--                    store_url_<platform>   where to get the new build.
--   platforms: ios, android, macos, windows, linux. All minimums start at 0:
--   nobody is blocked until someone raises one with
--   tool/release/set_min_build.sh <platform> <build>.
--
-- public.app_requirements(platform) -> {min_build, store_url}
--   readable by anyone (also before signing in), so the app can tell on
--   launch and on resume whether it is too old.
--
-- Enforcement: the PostgREST pre-request hook (public.check_device_session,
-- 20261029090000_one_active_device.sql) now also reads the x-app-build and
-- x-app-platform headers the app sends on every request and raises
-- 'update_required' when the build is below the platform's minimum.
-- app_requirements itself is never blocked.
--
-- Builds older than this one send no such header: they are let through, so
-- raising a minimum never blocks them. It only reaches builds that know how
-- to show the update screen. Edge Functions, Auth and Realtime are not
-- behind this hook; every write the game cares about is an RPC that is.
--
-- The app also compares its version with the stores (App Store lookup on
-- iOS, the latest GitHub release on desktop); this server minimum is the
-- safety net for online play.

insert into internal.config (key, value) values
  ('min_build_ios', '0'),
  ('min_build_android', '0'),
  ('min_build_macos', '0'),
  ('min_build_windows', '0'),
  ('min_build_linux', '0'),
  ('store_url_ios', 'https://apps.apple.com/app/id6822433258'),
  ('store_url_android', 'https://play.google.com/store/apps/details?id=com.obertagame.oberta'),
  ('store_url_macos', 'https://github.com/nicolairar/Oberta/releases/latest'),
  ('store_url_windows', 'https://github.com/nicolairar/Oberta/releases/latest'),
  ('store_url_linux', 'https://github.com/nicolairar/Oberta/releases/latest')
on conflict (key) do nothing;

create or replace function public.app_requirements(platform text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when platform in ('ios', 'android', 'macos', 'windows', 'linux') then
      jsonb_build_object(
        'min_build', internal.config_int('min_build_' || platform, 0),
        'store_url', (select value from internal.config where key = 'store_url_' || platform))
    else jsonb_build_object('min_build', 0, 'store_url', null)
  end;
$$;

revoke all on function public.app_requirements(text) from public;
grant execute on function public.app_requirements(text) to anon, authenticated, service_role;

-- Same hook as before, with the build check in front.
create or replace function public.check_device_session()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  path text := current_setting('request.path', true);
  headers json;
  build text;
  platform text;
  me uuid;
  header text;
  active text;
begin
  headers := nullif(current_setting('request.headers', true), '')::json;
  build := headers ->> 'x-app-build';
  platform := headers ->> 'x-app-platform';
  if build ~ '^[0-9]{1,9}$'
    and platform in ('ios', 'android', 'macos', 'windows', 'linux')
    and path is distinct from '/rpc/app_requirements'
    and build::integer < internal.config_int('min_build_' || platform, 0) then
    raise exception 'update_required';
  end if;

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
  header := headers ->> 'x-device-session';
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

notify pgrst, 'reload config';
