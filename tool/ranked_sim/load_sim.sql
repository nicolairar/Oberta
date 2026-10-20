-- Ranked load simulation against the REAL database, always rolled back.
--
-- 60 throwaway players (40 it, 20 en; 11 of them low conduct; ratings
-- spread wide so the rating band splits them), no bots (ranked_test_humans
-- = 0 inside the transaction only), everybody calls enqueue_ranked as
-- themselves, then time is moved forward 15 s at a time and the matcher
-- runs. Every step checks: nobody in two rooms, no table over 12, no lobby
-- with a foreign language, every started game exactly 12 humans and ranked.
-- One player leaves during a countdown. The block ends by raising an
-- exception carrying the results, so nothing is ever committed.
--
-- Run (tool/ranked_sim.py prepends the newest migration when asked):
--   python3 tool/ranked_sim/run.py [--with supabase/migrations/<file>.sql]

do $sim$
#variable_conflict use_variable
declare
  ids uuid[] := '{}';
  id uuid;
  lang text;
  i integer;
  step integer;
  bad text;
  quitter uuid;
  countdown_room uuid;
  log jsonb := '[]'::jsonb;
  result jsonb;
begin
  -- Hold the matcher lock so the live cron tick cannot run it under us.
  perform pg_advisory_xact_lock(hashtext('oberta.ranked_match'));
  update internal.config set value = '0' where key = 'ranked_test_humans';

  perform setseed(0.42);
  for i in 1 .. 60 loop
    id := gen_random_uuid();
    ids := ids || id;
    insert into auth.users (id, aud, role, email)
    values (id, 'authenticated', 'authenticated', 'zsim' || i || '@sim.invalid');
    update public.profiles set handle = 'zsim' || lpad(i::text, 3, '0') where profiles.id = id;
    lang := case when i <= 40 then 'it' else 'en' end;
    insert into public.ratings (profile_id, language, mu, sigma)
    values (id, lang, 15 + random() * 25, 3)
    on conflict (profile_id, language) do update set mu = excluded.mu, sigma = excluded.sigma;
    insert into internal.conduct (profile_id, score)
    values (id, case when i % 5 = 0 and (i <= 40 or i % 10 = 0) then 50 else 100 end)
    on conflict (profile_id) do update set score = excluded.score;
  end loop;

  -- Everybody queues, in random order, as themselves.
  for id in select x from unnest(ids) x order by random() loop
    perform set_config('request.jwt.claims', json_build_object('sub', id, 'role', 'authenticated')::text, true);
    perform public.enqueue_ranked(
      (select language from public.ratings where profile_id = id limit 1));
  end loop;
  perform set_config('request.jwt.claims', '', true);

  -- Anonymous waiting room: under RLS a lobby member reads only their own
  -- row, the lobby has no host, and lobby chat is refused.
  select m.profile_id, m.room_id into quitter, countdown_room
  from public.room_members m join public.rooms r on r.id = m.room_id
  where r.status = 'lobby' and r.seated between 2 and 11 and m.left_at is null and m.profile_id = any (ids)
  limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', quitter, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  if (select count(*) from public.room_members where room_id = countdown_room) <> 1 then
    raise exception 'SIM_FAIL a lobby member can see the other members';
  end if;
  if (select host from public.rooms where rooms.id = countdown_room) is not null
     or (select seated from public.rooms where rooms.id = countdown_room) < 2 then
    raise exception 'SIM_FAIL lobby row exposes a host or misses the count';
  end if;
  execute 'reset role';
  begin
    insert into public.game_chat (room_id, profile_id, channel, body) values (countdown_room, quitter, 'lobby', 'ciao');
    raise exception 'SIM_FAIL lobby chat accepted in a ranked lobby';
  exception when others then
    if sqlerrm like 'SIM_FAIL%' then raise; end if;
  end;
  perform set_config('request.jwt.claims', '', true);
  log := log || jsonb_build_object('event', 'anonymous lobby: member sees only own row, no host, no lobby chat');
  quitter := null;
  countdown_room := null;

  for step in 0 .. 24 loop
    -- Invariants.
    select string_agg(p::text, ',') into bad from (
      select m.profile_id p from public.room_members m join public.rooms r on r.id = m.room_id
      where m.left_at is null and r.status in ('lobby', 'playing') and m.profile_id = any (ids)
      group by m.profile_id having count(*) > 1) d;
    if bad is not null then raise exception 'SIM_FAIL step % two rooms: %', step, bad; end if;
    select string_agg(r.id::text, ',') into bad from public.rooms r
    where (select count(*) from public.room_members m where m.room_id = r.id and m.left_at is null) > 12;
    if bad is not null then raise exception 'SIM_FAIL step % over 12: %', step, bad; end if;
    select string_agg(r.id::text, ',') into bad from public.rooms r
    join public.room_members m on m.room_id = r.id and m.left_at is null
    join public.ratings g on g.profile_id = m.profile_id
    where m.profile_id = any (ids) and g.language <> r.language;
    if bad is not null then raise exception 'SIM_FAIL step % mixed language: %', step, bad; end if;
    select string_agg(r.id::text, ',') into bad from public.rooms r
    where r.status = 'playing' and exists (select 1 from public.room_members m where m.room_id = r.id and m.profile_id = any (ids))
      and (not r.ranked or r.bots <> 0
           or (select count(*) from public.room_members m where m.room_id = r.id and m.left_at is null) <> 12);
    if bad is not null then raise exception 'SIM_FAIL step % bad start: %', step, bad; end if;

    log := log || jsonb_build_object(
      't', step * 15,
      'lobbies', (select coalesce(jsonb_agg(x order by x), '[]') from (
          select r.language || ':' || (select count(*) from public.room_members m where m.room_id = r.id and m.left_at is null)
                 || case when r.starts_at is not null then '*' else '' end
                 || ':low' || (select count(*) from public.room_members m join internal.conduct c on c.profile_id = m.profile_id
                               where m.room_id = r.id and m.left_at is null and c.score < 70) x
          from public.rooms r
          where r.status = 'lobby' and exists (select 1 from public.room_members m where m.room_id = r.id and m.profile_id = any (ids))) l),
      'playing', (select count(*) from public.rooms r where r.status = 'playing'
                  and exists (select 1 from public.room_members m where m.room_id = r.id and m.profile_id = any (ids))));

    -- One player walks out during the first countdown, then comes back.
    if countdown_room is null then
      select r.id into countdown_room from public.rooms r
      where r.status = 'lobby' and r.starts_at is not null
        and exists (select 1 from public.room_members m where m.room_id = r.id and m.profile_id = any (ids))
      limit 1;
      if countdown_room is not null then
        select profile_id into quitter from public.room_members where room_id = countdown_room and left_at is null limit 1;
        perform set_config('request.jwt.claims', json_build_object('sub', quitter, 'role', 'authenticated')::text, true);
        perform public.leave_ranked_queue();
        if (select starts_at from public.rooms where rooms.id = countdown_room) is not null then
          raise exception 'SIM_FAIL countdown did not stop when a player left';
        end if;
        perform public.enqueue_ranked((select language from public.ratings where profile_id = quitter limit 1));
        perform set_config('request.jwt.claims', '', true);
        log := log || jsonb_build_object('event', 'left during countdown, countdown stopped, came back');
      end if;
    end if;

    -- 15 seconds pass: phones keep polling (seen_at fresh), the matcher runs.
    update internal.ranked_queue set joined_at = joined_at - interval '15 seconds', seen_at = now()
    where profile_id = any (ids);
    update public.room_members set joined_at = joined_at - interval '15 seconds'
    where profile_id = any (ids);
    update public.rooms r set created_at = created_at - interval '15 seconds',
                              starts_at = starts_at - interval '15 seconds'
    where r.status = 'lobby' and exists (select 1 from public.room_members m where m.room_id = r.id and m.profile_id = any (ids));
    perform internal.ranked_match();
  end loop;

  select jsonb_build_object(
    'games', (select jsonb_agg(jsonb_build_object(
                'lang', r.language, 'humans', (select count(*) from public.room_members m where m.room_id = r.id and m.left_at is null),
                'low', (select count(*) from public.room_members m join internal.conduct c on c.profile_id = m.profile_id
                        where m.room_id = r.id and m.left_at is null and c.score < 70),
                'ranked', r.ranked, 'bots', r.bots))
              from public.rooms r where r.status = 'playing'
                and exists (select 1 from public.room_members m where m.room_id = r.id and m.profile_id = any (ids))),
    'still_waiting', (select jsonb_agg(jsonb_build_object('lang', q.language, 'wait_s', extract(epoch from now() - q.joined_at)::int,
                'low', coalesce(c.score, 100) < 70))
              from internal.ranked_queue q left join internal.conduct c on c.profile_id = q.profile_id
              where q.profile_id = any (ids)),
    'online_counts', public.online_counts(),
    'log', log) into result;
  raise exception 'SIM_RESULT %', result;
end
$sim$;
