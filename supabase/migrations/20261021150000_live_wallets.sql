-- Live wallets: level, XP and coins pushed to the phone over Realtime.
--
--   public.wallets   one row per profile, a read-only mirror of
--                    profiles.level/xp/coins kept by a trigger. The source of
--                    truth stays in profiles (written only by server
--                    functions); clients may only SELECT their own row and
--                    have no insert/update/delete grants. In the
--                    supabase_realtime publication, so the app subscribes to
--                    its own row (filter profile_id=eq.<uid>).

create table if not exists public.wallets (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  level integer not null default 1,
  xp integer not null default 0,
  coins integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.wallets enable row level security;
alter table public.wallets replica identity full;

revoke all on table public.wallets from public, anon, authenticated;
grant select on table public.wallets to authenticated;
grant all on table public.wallets to service_role;

drop policy if exists "players read their own wallet" on public.wallets;
create policy "players read their own wallet"
  on public.wallets for select to authenticated
  using (profile_id = (select auth.uid()));

create or replace function public.sync_wallet()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.wallets (profile_id, level, xp, coins, updated_at)
  values (new.id, new.level, new.xp, new.coins, now())
  on conflict (profile_id) do update
    set level = excluded.level, xp = excluded.xp, coins = excluded.coins, updated_at = now()
    where (public.wallets.level, public.wallets.xp, public.wallets.coins)
      is distinct from (excluded.level, excluded.xp, excluded.coins);
  return new;
end;
$$;

revoke all on function public.sync_wallet() from public, anon, authenticated;

drop trigger if exists profiles_sync_wallet on public.profiles;
create trigger profiles_sync_wallet
  after insert or update of level, xp, coins on public.profiles
  for each row execute function public.sync_wallet();

insert into public.wallets (profile_id, level, xp, coins)
select id, level, xp, coins from public.profiles
on conflict (profile_id) do update
  set level = excluded.level, xp = excluded.xp, coins = excluded.coins, updated_at = now();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'wallets'
    ) then
    alter publication supabase_realtime add table public.wallets;
  end if;
end;
$$;
