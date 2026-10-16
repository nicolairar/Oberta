-- Handles become letters only: 3 to 16 of a-z, stored lowercase, so
-- uniqueness is case-insensitive ("Marco" and "marco" are the same name).
-- Profiles also get level, experience and coins: only server-side functions
-- will write them, and only the owner reads them (through my_profile()).

-- Drop the old handle check, whatever name it was given.
do $$
declare
  old record;
begin
  for old in
    select conname from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%handle%'
  loop
    execute format('alter table public.profiles drop constraint %I', old.conname);
  end loop;
end;
$$;

-- Handles that no longer fit go back to empty: the app sees an incomplete
-- profile and makes those players pick a new one at their next sign-in.
update public.profiles
set handle = null
where handle is not null and handle !~ '^[a-z]{3,16}$';

alter table public.profiles
  add constraint profiles_handle_check check (handle ~ '^[a-z]{3,16}$');

-- Already implied by the lowercase check plus the unique handle, but it
-- keeps names case-insensitive even if the check is ever relaxed.
create unique index if not exists profiles_handle_lower_key on public.profiles (lower(handle));

alter table public.profiles
  add column if not exists level integer not null default 1 check (level >= 1),
  add column if not exists xp integer not null default 0 check (xp >= 0),
  add column if not exists coins integer not null default 0 check (coins >= 0);

-- Other players see only the public columns. Column grants replace the
-- table-wide one, so new columns stay private unless granted here.
revoke select on public.profiles from authenticated;
grant select (id, handle, display_name, language, avatar, created_at) on public.profiles to authenticated;

-- Clients still update only these three; level, xp and coins are not
-- writable (no insert or update grant on them).
revoke update on public.profiles from authenticated;
grant update (handle, display_name, language) on public.profiles to authenticated;

-- The signed-in player's own profile, with level, xp and coins.
create or replace function public.my_profile()
returns setof public.profiles
language sql
stable
security definer
set search_path = ''
as $$
  select * from public.profiles where id = (select auth.uid());
$$;

revoke all on function public.my_profile() from public, anon, authenticated;
grant execute on function public.my_profile() to authenticated;
