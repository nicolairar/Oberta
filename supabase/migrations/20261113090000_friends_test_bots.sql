-- Bots are no longer chosen by the client: there is no "add a bot" button.
--
-- TEST PERIOD ONLY: with internal.config 'friends_test_bots' > 0, a friends
-- room with at least two people may start, and the server fills every empty
-- seat with a bot when the host deals. With the flag at 0 (at launch) bots
-- never sit in a friends game and four people are needed. 'friends_test_size'
-- (default: the room's size) caps how many seats the bots fill up to.
--
--   update internal.config set value = '0' where key = 'friends_test_bots';
--
-- Reverse: restore public.start_game and the grant on public.set_room_bots
-- from 20261020120000_ranked.sql, and delete the config row.

insert into internal.config (key, value) values ('friends_test_bots', '1')
on conflict (key) do nothing;

create or replace function public.start_game(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  people integer;
  fill integer := 0;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into r from public.rooms where id = room for update;
  if not found or r.host <> me or r.ranked or r.test_match then
    raise exception 'not_allowed';
  end if;
  if r.status <> 'lobby' then
    raise exception 'room_closed';
  end if;
  select count(*) into people from public.room_members where room_id = room and left_at is null;
  if internal.config_int('friends_test_bots', 0) > 0 then
    if people < 2 then
      raise exception 'invalid_seats';
    end if;
    fill := greatest(0, least(r.max_players, internal.config_int('friends_test_size', r.max_players)) - people);
  elsif people < 4 then
    raise exception 'invalid_seats';
  end if;
  if people + fill > r.max_players then
    raise exception 'invalid_seats';
  end if;
  update public.rooms set bots = fill where id = room;
  perform internal.begin_game(room, me);
end;
$$;
revoke all on function public.start_game(uuid) from public, anon;
grant execute on function public.start_game(uuid) to authenticated;

-- Nobody sets bots by hand any more; leftover counts are cleared.
revoke all on function public.set_room_bots(uuid, integer) from public, anon, authenticated;
update public.rooms set bots = 0 where status = 'lobby' and not ranked and not test_match and bots <> 0;
