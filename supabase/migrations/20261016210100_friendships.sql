-- Friendships: one row per pair of players, whoever asked first.
-- Clients only read their own rows; every change goes through the
-- functions below, which check who is allowed to do what.
--
--   pending   requester asked, addressee has not answered
--   accepted  friends
--   blocked   requester blocked addressee (only the blocker sees the row)

create table if not exists public.friendships (
  requester uuid not null references public.profiles (id) on delete cascade,
  addressee uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- A asking B and B asking A is the same friendship.
create unique index if not exists friendships_one_row_per_pair
  on public.friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee on public.friendships (addressee);

alter table public.friendships enable row level security;

grant select on public.friendships to authenticated;

drop policy if exists "players see their own friendships" on public.friendships;
create policy "players see their own friendships"
  on public.friendships for select
  to authenticated
  using (
    requester = (select auth.uid())
    or (addressee = (select auth.uid()) and status <> 'blocked')
  );

-- Ask someone to be friends. If they had already asked you, this accepts.
-- Returns the resulting status.
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

-- Answer a request someone sent you: accept, or decline (the row goes away,
-- so they may ask again later).
create or replace function public.respond_friend_request(requester_id uuid, accept boolean)
returns text
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
  if accept then
    update public.friendships set status = 'accepted', updated_at = now()
    where requester = requester_id and addressee = me and status = 'pending';
  else
    delete from public.friendships
    where requester = requester_id and addressee = me and status = 'pending';
  end if;
  if not found then
    raise exception 'request_not_found';
  end if;
  return case when accept then 'accepted' else 'declined' end;
end;
$$;

-- Unfriend, cancel a request you sent, or lift a block you placed.
-- A block placed by the other player stays where it is.
create or replace function public.remove_friend(other uuid)
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
  delete from public.friendships
  where (requester = me and addressee = other)
     or (requester = other and addressee = me and status <> 'blocked');
end;
$$;

-- Block a player: whatever was between you is replaced by your block.
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
  insert into public.friendships (requester, addressee, status) values (me, other, 'blocked');
end;
$$;

revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.block_player(uuid) from public, anon;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.block_player(uuid) to authenticated;
