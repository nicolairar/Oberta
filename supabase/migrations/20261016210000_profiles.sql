-- Profiles: one per account, created by a trigger the moment someone signs
-- up (anonymous sign-ins included). The handle and display name stay empty
-- until the player picks them on the profile setup screen.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  -- Lowercase, so "Marco" and "marco" can never both exist.
  handle text unique check (handle ~ '^[a-z0-9_]{3,20}$'),
  display_name text check (
    display_name = btrim(display_name) and char_length(display_name) between 1 and 24
  ),
  language text not null default 'it' check (language in ('it', 'en')),
  -- The equipped look, by catalog id: {"base": ..., "hat": ..., "glasses": ...}.
  -- Clients cannot write it: equipping will go through a function that
  -- checks what the player owns.
  avatar jsonb not null default '{}'::jsonb check (jsonb_typeof(avatar) = 'object'),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Handles, names and looks are public to signed-in players: that is how
-- friends find each other and how a lobby shows who is sitting there.
grant select on public.profiles to authenticated;
grant update (handle, display_name, language) on public.profiles to authenticated;

drop policy if exists "profiles are visible to signed-in players" on public.profiles;
create policy "profiles are visible to signed-in players"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "players edit their own profile" on public.profiles;
create policy "players edit their own profile"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, language)
  values (
    new.id,
    case when new.raw_user_meta_data ->> 'language' = 'en' then 'en' else 'it' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Accounts created before this migration get their profile too.
insert into public.profiles (id)
select id from auth.users
on conflict (id) do nothing;
