-- Which app build each player runs, so the server never deals a role their
-- phone cannot read.
--
-- Build 65 does not know the Prostitute, the Jailer or the Pacifist: dealt
-- one of them (or seeing one in the deck) it could not parse the table and
-- stayed on "connecting" forever, while the game went on without it.
--
-- internal.client_builds  profile -> the last build (x-app-build header)
--                         seen when they created, joined or queued for a
--                         room. Server side only.
-- The Edge Function reads the lowest build at the table when it deals and
-- passes it to the engine (lib/online/game/role_builds.dart), which leaves
-- out the roles that build does not know. A player with no build recorded
-- counts as the oldest.
--
-- Reverse: drop the triggers and internal.note_client_build(), then the table.

create table if not exists internal.client_builds (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  build integer not null,
  platform text,
  seen_at timestamptz not null default now()
);
revoke all on internal.client_builds from public, anon, authenticated;

-- Records the caller's build from the request headers. Never fails the
-- statement that called it: no header, no user, or anything odd is ignored.
create or replace function internal.note_client_build()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  headers json;
  build text;
begin
  if me is null then
    return null;
  end if;
  begin
    headers := nullif(current_setting('request.headers', true), '')::json;
    build := headers ->> 'x-app-build';
    if build ~ '^[0-9]{1,9}$' then
      insert into internal.client_builds as c (profile_id, build, platform, seen_at)
      values (me, build::integer, left(headers ->> 'x-app-platform', 16), now())
      on conflict (profile_id) do update
        set build = excluded.build, platform = excluded.platform, seen_at = excluded.seen_at
        where c.build is distinct from excluded.build or c.platform is distinct from excluded.platform;
    end if;
  exception when others then
    null;
  end;
  return null;
end;
$$;
revoke all on function internal.note_client_build() from public, anon, authenticated;

drop trigger if exists note_client_build on public.room_members;
create trigger note_client_build
  after insert or update on public.room_members
  for each statement execute function internal.note_client_build();

drop trigger if exists note_client_build on internal.ranked_queue;
create trigger note_client_build
  after insert or update on internal.ranked_queue
  for each statement execute function internal.note_client_build();
