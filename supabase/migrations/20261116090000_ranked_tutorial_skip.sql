-- "I already know the game": a player can skip the three practice hands
-- and go straight to ranked. The skip is one more row in
-- tutorial_completions (faction 'skip'), so ranked_status already reports
-- it in 'tutorials' and the client unlocks ranked when it sees it.

alter table public.tutorial_completions
  drop constraint if exists tutorial_completions_faction_check;
alter table public.tutorial_completions
  add constraint tutorial_completions_faction_check
  check (faction in ('family', 'town', 'solo', 'skip'));

-- Ranked is open with all three hands done, or with the skip.
create or replace function internal.tutorials_cleared(who uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
      select 1 from public.tutorial_completions t where t.profile_id = who and t.faction = 'skip'
    )
    or (
      select count(*) from public.tutorial_completions t
      where t.profile_id = who and t.faction in ('family', 'town', 'solo')
    ) >= 3;
$$;
revoke all on function internal.tutorials_cleared(uuid) from public, anon, authenticated;

-- Records the skip. Calling it twice is fine. Returns what tutorial_complete
-- returns: the rows recorded, 'skip' among them.
create or replace function public.tutorial_skip()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public._ready_player();
begin
  insert into public.tutorial_completions (profile_id, faction)
  values (me, 'skip')
  on conflict on constraint tutorial_completions_pkey do nothing;
  return internal.tutorials_of(me);
end;
$$;
revoke all on function public.tutorial_skip() from public, anon;
grant execute on function public.tutorial_skip() to authenticated;

-- Same as before: the three practice hands, or the skip.
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
  if not internal.tutorials_cleared(me) then
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

revoke all on function public.enqueue_ranked(text) from public, anon;
grant execute on function public.enqueue_ranked(text) to authenticated;

notify pgrst, 'reload schema';
