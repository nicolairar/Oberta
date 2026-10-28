-- Public profiles: another player's dossier, opened from a seat, a chat
-- message, the friends list or the leaderboard.
--
-- * profiles.public_profile: the owner's switch in Settings (default on).
--   Off, others only see the handle, the level and the portrait.
-- * public_stats(target): a handle or a profile id. Account-level numbers
--   only, from real games (never test matches): games, wins, longest win
--   streak, time at the table, top five roles, best rank tier, title and
--   the three rarest achievements. Never abandons, AFK, conduct, coins or
--   the Steam name, and nothing about a game still running (match_history
--   is written when a game is settled). Players who blocked each other
--   cannot see each other's profile.

alter table public.profiles add column if not exists public_profile boolean not null default true;
grant update (handle, language, picture, public_profile) on public.profiles to authenticated;

create or replace function public.public_stats(target text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  p public.profiles;
  s jsonb;
  best public.ratings;
  base jsonb;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if target ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select * into p from public.profiles where id = target::uuid;
  else
    select * into p from public.profiles where handle = lower(ltrim(trim(target), '@'));
  end if;
  if p.id is null or p.handle is null then
    raise exception 'profile_not_found';
  end if;
  if p.id <> me and internal.blocked_between(me, p.id) then
    raise exception 'profile_blocked';
  end if;
  base := jsonb_build_object(
    'id', p.id, 'handle', p.handle, 'level', p.level, 'avatar', p.avatar,
    'picture_url', p.picture_url, 'public', p.public_profile);
  if not p.public_profile and p.id <> me then
    return base;
  end if;
  s := internal.stats_slice(p.id, false);
  select * into best from public.ratings
  where profile_id = p.id and games > 0
  order by mu - 3 * sigma desc
  limit 1;
  return base || jsonb_build_object(
    'on_steam', p.on_steam,
    'on_apple', p.on_apple,
    'tier', case when best.profile_id is not null then internal.rank_tier(best.mu - 3 * best.sigma) end,
    'title', (select title from internal.player_achievements
              where profile_id = p.id and title is not null
              order by unlocked_at desc limit 1),
    'featured', coalesce((
      select jsonb_agg(achievement_id order by holders, unlocked_at desc)
      from (
        select a.achievement_id, a.unlocked_at,
               (select count(*) from internal.player_achievements b
                where b.achievement_id = a.achievement_id) as holders
        from internal.player_achievements a
        where a.profile_id = p.id
        order by holders, a.unlocked_at desc
        limit 3
      ) f), '[]'::jsonb),
    'games', s -> 'games',
    'wins', s -> 'wins',
    'longest_streak', s -> 'longest_streak',
    'seconds', s -> 'seconds',
    'timed', s -> 'timed',
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object('role', key, 'games', g, 'wins', w) order by g desc, w desc, key)
      from (
        select key, (value ->> 'games')::integer as g, (value ->> 'wins')::integer as w
        from jsonb_each(s -> 'roles')
        where key <> '?'
        order by g desc, w desc, key
        limit 5
      ) r), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.public_stats(text) from public, anon;
grant execute on function public.public_stats(text) to authenticated;
