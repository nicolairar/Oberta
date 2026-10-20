-- Fair play at settle time.
--
-- AFK: the engine marks a seat `afk` when it sat through most of its turns
-- without sending anything (see Attendance in lib/online/game/game_server.dart).
-- It gets nothing, is rated as a loss and, in ranked, takes a soft conduct
-- hit (smaller than quitting, no strike, no cooldown). Only the player sees it,
-- in their own history row.
--
-- Short games: a game that ended before day 2 because someone left pays
-- nobody (`short`, from the engine).
--
-- Leaving after death: no penalty, but no rewards either if the side wins.

alter table public.match_history add column if not exists afk boolean not null default false;

-- Who asked to leave a game, server side only.
create table if not exists internal.game_leaves (
  game_id uuid not null,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  seat text not null,
  left_at timestamptz not null default now(),
  primary key (game_id, profile_id)
);
alter table internal.game_leaves enable row level security;
revoke all on internal.game_leaves from public, anon, authenticated;

create or replace function public.game_leave(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  gid uuid;
  my_seat text;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  select game_id into gid from public.game_public where room_id = room;
  select seat into my_seat from public.game_seats where room_id = room and profile_id = me;
  if gid is not null and my_seat is not null then
    insert into internal.game_leaves (game_id, profile_id, seat)
    values (gid, me, my_seat)
    on conflict (game_id, profile_id) do nothing;
  end if;
  -- Alive, the next step records the abandon at once; dead, the engine
  -- ignores it and settle reads game_leaves instead.
  update public.game_seats set last_seen = now() - interval '1 day'
  where room_id = room and profile_id = me;
  update internal.game_state
  set next_due_at = least(coalesce(next_due_at, now()), now())
  where room_id = room;
  perform internal.wake_game(room);
end;
$$;
revoke all on function public.game_leave(uuid) from public, anon;
grant execute on function public.game_leave(uuid) to authenticated;

create or replace function internal.settle_input(room uuid, result jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_public;
  r public.rooms;
  today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  seats jsonb;
begin
  select * into g from public.game_public where room_id = room;
  select * into r from public.rooms where id = room;
  if g.room_id is null or r.id is null or result is null or result -> 'seats' is null then
    return null;
  end if;
  if exists (select 1 from public.match_history where game_id = g.game_id) then
    return null;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'profile', s.profile_id,
           'seat', s.seat,
           'team', result -> 'seats' -> s.seat ->> 'team',
           'role', result -> 'seats' -> s.seat ->> 'role',
           'won', coalesce((result -> 'seats' -> s.seat ->> 'won')::boolean, false),
           'survived', coalesce((result -> 'seats' -> s.seat ->> 'survived')::boolean, false),
           'abandoned', coalesce((result -> 'seats' -> s.seat ->> 'abandoned')::boolean, false),
           'afk', coalesce((result -> 'seats' -> s.seat ->> 'afk')::boolean, false),
           'short', coalesce((result -> 'seats' -> s.seat ->> 'short')::boolean, false),
           'leftDead', not coalesce((result -> 'seats' -> s.seat ->> 'abandoned')::boolean, false)
             and exists (select 1 from internal.game_leaves l
                         where l.game_id = g.game_id and l.profile_id = s.profile_id),
           'level', p.level,
           'xp', p.xp,
           'mu', coalesce(rt.mu, 25),
           'sigma', coalesce(rt.sigma, 25.0 / 3),
           'wonToday', exists (
             select 1 from public.match_history h
             where h.profile_id = s.profile_id and h.won and h.played_at >= today),
           'friendsGamesToday', (
             select count(*) from public.match_history h
             where h.profile_id = s.profile_id and not h.ranked and h.played_at >= today)
         ) order by s.seat), '[]'::jsonb)
    into seats
  from public.game_seats s
  join public.profiles p on p.id = s.profile_id
  left join public.ratings rt on rt.profile_id = s.profile_id and rt.language = r.language
  where s.room_id = room and s.profile_id is not null and result -> 'seats' ? s.seat;
  return jsonb_build_object(
    'ranked', r.ranked,
    'humans', (select count(*) from public.game_seats where room_id = room and profile_id is not null),
    'seats', seats
  );
end;
$$;
revoke all on function internal.settle_input(uuid, jsonb) from public, anon, authenticated;

create or replace function internal.record_match(room uuid, winner text, settlement jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_public;
  r public.rooms;
  p jsonb;
  who uuid;
  saved integer := 0;
begin
  select * into g from public.game_public where room_id = room;
  select * into r from public.rooms where id = room;
  if g.room_id is null or r.id is null then
    return 0;
  end if;
  if exists (select 1 from public.match_history where game_id = g.game_id) then
    return 0;
  end if;
  for p in select * from jsonb_array_elements(coalesce(settlement -> 'players', '[]'::jsonb)) loop
    who := (p ->> 'profile')::uuid;
    update public.profiles
    set level = (p ->> 'level')::integer, xp = (p ->> 'xp')::integer
    where id = who;
    if (p ->> 'coins')::integer > 0 then
      perform public.grant_coins(who, (p ->> 'coins')::integer, 'level_up', g.game_id::text || ':' || who::text);
    end if;
    if r.ranked then
      insert into public.ratings as rt (profile_id, language, mu, sigma, games, wins, updated_at)
      values (who, r.language, (p ->> 'mu')::double precision, (p ->> 'sigma')::double precision, 1,
              case when (p ->> 'won')::boolean and not coalesce((p ->> 'afk')::boolean, false)
                        and not coalesce((p ->> 'leftDead')::boolean, false) then 1 else 0 end, now())
      on conflict (profile_id, language) do update
        set mu = excluded.mu, sigma = excluded.sigma, games = rt.games + 1,
            wins = rt.wins + excluded.wins, updated_at = now();
      if (p ->> 'abandoned')::boolean then
        null; -- the abandon trigger already took its strike
      elsif coalesce((p ->> 'afk')::boolean, false) then
        -- A soft abandon: a smaller hit, no strike, no cooldown.
        perform internal.conduct_of(who);
        update internal.conduct set score = greatest(0, score - 7) where profile_id = who;
      elsif coalesce((p ->> 'leftDead')::boolean, false) then
        null; -- left after dying: no penalty, no credit
      else
        perform internal.conduct_of(who);
        update internal.conduct
        set strikes = greatest(0, strikes - 1), score = least(100, score + 5)
        where profile_id = who;
      end if;
    end if;
    insert into public.match_history (
      game_id, room_id, profile_id, language, ranked, test_match, players, seat, role, team, winner,
      won, survived, abandoned, afk, xp_gained, level_before, level_after, coins_gained, rating_delta, ordinal_after)
    values (
      g.game_id, room, who, r.language, r.ranked, r.test_match,
      (select count(*) from public.game_seats where room_id = room),
      p ->> 'seat', coalesce(p ->> 'role', '?'), coalesce(p ->> 'team', '?'), coalesce(winner, '?'),
      (p ->> 'won')::boolean, (p ->> 'survived')::boolean, (p ->> 'abandoned')::boolean,
      coalesce((p ->> 'afk')::boolean, false),
      (p ->> 'xpGained')::integer, (p ->> 'levelBefore')::integer, (p ->> 'level')::integer,
      (p ->> 'coins')::integer,
      case when r.ranked then (p ->> 'ratingDelta')::double precision end,
      case when r.ranked then (p ->> 'mu')::double precision - 3 * (p ->> 'sigma')::double precision end);
    saved := saved + 1;
  end loop;
  return saved;
end;
$$;
revoke all on function internal.record_match(uuid, text, jsonb) from public, anon, authenticated;
