-- Ranked asks for the three practice hands first (red Family, gold Town,
-- green Solo). Friends rooms stay open to everyone. Accounts made before
-- this start with none done: no backfill.

create table if not exists public.tutorial_completions (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  faction text not null check (faction in ('family', 'town', 'solo')),
  completed_at timestamptz not null default now(),
  primary key (profile_id, faction)
);
alter table public.tutorial_completions enable row level security;
revoke all on public.tutorial_completions from public, anon, authenticated;
grant select on public.tutorial_completions to authenticated;

drop policy if exists tutorial_completions_own on public.tutorial_completions;
create policy tutorial_completions_own on public.tutorial_completions
  for select to authenticated using (profile_id = auth.uid());

create or replace function internal.tutorials_of(who uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(t.faction order by t.faction), '[]'::jsonb)
  from public.tutorial_completions t where t.profile_id = who;
$$;
revoke all on function internal.tutorials_of(uuid) from public, anon, authenticated;

-- Records a finished practice hand. Calling it twice is fine.
create or replace function public.tutorial_complete(faction text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
begin
  if faction is null or faction not in ('family', 'town', 'solo') then
    raise exception 'invalid_faction';
  end if;
  insert into public.tutorial_completions (profile_id, faction)
  values (me, tutorial_complete.faction)
  on conflict on constraint tutorial_completions_pkey do nothing;
  return internal.tutorials_of(me);
end;
$$;
revoke all on function public.tutorial_complete(text) from public, anon;
grant execute on function public.tutorial_complete(text) to authenticated;

-- Same as before, with the practice hands checked first.
create or replace function public.enqueue_ranked(queue_language text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
  c internal.conduct;
  q internal.ranked_queue;
  other uuid;
begin
  if queue_language is null or queue_language not in ('it', 'en') then
    raise exception 'invalid_language';
  end if;
  if (select count(*) from public.tutorial_completions t where t.profile_id = me) < 3 then
    raise exception 'tutorials_required';
  end if;
  c := internal.conduct_of(me);
  if c.cooldown_until > now() then
    raise exception 'ranked_cooldown';
  end if;
  if exists (
    select 1 from public.room_members m join public.rooms r on r.id = m.room_id
    where m.profile_id = me and m.left_at is null and r.status = 'playing'
  ) then
    raise exception 'already_in_game';
  end if;
  select * into q from internal.ranked_queue where profile_id = me;
  if q.room_id is not null and q.language = queue_language then
    update internal.ranked_queue set seen_at = now() where profile_id = me;
    return public.ranked_status();
  end if;
  for other in
    select room_id from public.room_members where profile_id = me and left_at is null
  loop
    perform public._leave_room(other, me);
  end loop;
  insert into internal.ranked_queue as rq (profile_id, language)
  values (me, queue_language)
  on conflict (profile_id) do update
    set language = excluded.language,
        joined_at = case when rq.language = excluded.language then rq.joined_at else now() end,
        seen_at = now(),
        room_id = null;
  perform internal.ranked_place(me);
  return public.ranked_status();
end;
$$;

-- Same as before, plus the practice hands done ('tutorials').
create or replace function public.ranked_status()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  q internal.ranked_queue;
  c internal.conduct;
  waiting integer := 0;
  estimate double precision;
  matched uuid;
  is_test boolean;
  seated integer;
  size integer := internal.config_int('ranked_size', 12);
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  update internal.ranked_queue set seen_at = now() where profile_id = me returning * into q;
  c := internal.conduct_of(me);
  if q.profile_id is not null then
    select count(*) into waiting from internal.ranked_queue where language = q.language;
    select avg(wait_seconds) into estimate
    from (
      select wait_seconds from internal.ranked_matches
      where language = q.language and not test and formed_at > now() - interval '1 day'
      order by formed_at desc limit 10
    ) recent;
    estimate := coalesce(estimate, 30 + greatest(0, size - waiting) * 15);
  end if;
  select r.id, r.test_match, r.seated into matched, is_test, seated
  from public.rooms r join public.room_members m on m.room_id = r.id
  where m.profile_id = me and m.left_at is null and (r.ranked or r.test_match) and r.status in ('lobby', 'playing')
  order by r.created_at desc
  limit 1;
  return jsonb_build_object(
    'queued', q.profile_id is not null,
    'language', q.language,
    'since', case when q.profile_id is null then null else (extract(epoch from q.joined_at) * 1000)::bigint end,
    'waiting', waiting,
    'estimate', case when estimate is null then null else round(estimate)::integer end,
    'room', matched,
    'seated', seated,
    'test', coalesce(is_test, false),
    'cooldown_until', case when c.cooldown_until > now()
                           then (extract(epoch from c.cooldown_until) * 1000)::bigint end,
    'warning', c.strikes between 1 and 2 and c.last_abandon_at > now() - interval '24 hours',
    'tutorials', internal.tutorials_of(me)
  );
end;
$$;

revoke all on function public.enqueue_ranked(text) from public, anon;
grant execute on function public.enqueue_ranked(text) to authenticated;
revoke all on function public.ranked_status() from public, anon;
grant execute on function public.ranked_status() to authenticated;

notify pgrst, 'reload schema';
