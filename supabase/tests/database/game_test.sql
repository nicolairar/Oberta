-- Online games: who may read and write what.
-- Run with: supabase test db
begin;
select plan(35);

-- Anna hosts, Bruno and Carla play, Dario is in another room.
insert into auth.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333'),
  ('44444444-4444-4444-4444-444444444444');
update public.profiles set handle = 'anna' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set handle = 'bruno' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set handle = 'carla' where id = '33333333-3333-3333-3333-333333333333';
update public.profiles set handle = 'dario' where id = '44444444-4444-4444-4444-444444444444';

set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
create temp table r as select * from public.create_room('it');
grant select on r to authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select public.join_room((select code from r));
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select public.join_room((select code from r));
set local request.jwt.claims to '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
select public.create_room('en');

-- Bots in the lobby.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok($$ select public.set_room_bots((select id from r), 2) $$, 'P0001', 'not_allowed', 'only the host adds bots');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok($$ select public.set_room_bots((select id from r), 14) $$, 'P0001', 'room_full', 'bots and people fit the table');
select lives_ok($$ select public.set_room_bots((select id from r), 2) $$, 'the host adds two bots');
select is((select bots from public.rooms where id = (select id from r)), 2::smallint, 'everyone in the room sees the bots');

-- Starting.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.start_game((select id from r), '[]'::jsonb) $$, 'P0001', 'not_allowed', 'only the host starts'
);
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok(
  $$ select public.start_game((select id from r), '[
    {"seat": "s1", "profile_id": "11111111-1111-1111-1111-111111111111"},
    {"seat": "s2", "profile_id": "22222222-2222-2222-2222-222222222222"},
    {"seat": "s3", "profile_id": null, "name": "bot.alfa"},
    {"seat": "s4", "profile_id": null, "name": "bot.bravo"}]'::jsonb) $$,
  'P0001', 'invalid_seats', 'every player in the room needs a seat'
);
select throws_ok(
  $$ select public.start_game((select id from r), '[
    {"seat": "s1", "profile_id": "11111111-1111-1111-1111-111111111111"},
    {"seat": "s2", "profile_id": "22222222-2222-2222-2222-222222222222"},
    {"seat": "s3", "profile_id": "33333333-3333-3333-3333-333333333333"},
    {"seat": "s4", "profile_id": "44444444-4444-4444-4444-444444444444"}]'::jsonb) $$,
  'P0001', 'invalid_seats', 'nobody from outside the room'
);
select throws_ok(
  $$ select public.start_game((select id from r), '[
    {"seat": "s1", "profile_id": "11111111-1111-1111-1111-111111111111"},
    {"seat": "s2", "profile_id": "22222222-2222-2222-2222-222222222222"},
    {"seat": "s3", "profile_id": "33333333-3333-3333-3333-333333333333"},
    {"seat": "s4", "profile_id": null, "name": "Anna"}]'::jsonb) $$,
  'P0001', 'invalid_seats', 'a bot cannot pose as a player'
);
select lives_ok(
  $$ select public.start_game((select id from r), '[
    {"seat": "s1", "profile_id": "11111111-1111-1111-1111-111111111111", "name": "whatever"},
    {"seat": "s2", "profile_id": "22222222-2222-2222-2222-222222222222"},
    {"seat": "s3", "profile_id": "33333333-3333-3333-3333-333333333333"},
    {"seat": "s4", "profile_id": null, "name": "bot.alfa"},
    {"seat": "s5", "profile_id": null, "name": "bot.bravo"}]'::jsonb) $$,
  'the host starts with three players and two bots'
);
select is((select status from public.rooms where id = (select id from r)), 'playing', 'the room is playing');
select throws_ok('select * from public.game_seats', '42501', null, 'seats are read by functions only');
reset role;
select is(
  (select name from public.game_seats where room_id = (select id from r) and seat = 's1'), 'anna',
  'players sit under their handle, whatever the host sends'
);
set local role authenticated;

-- Publishing.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.publish_game((select id from r), 1, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb) $$,
  'P0001', 'not_allowed', 'only the host publishes'
);
select throws_ok('insert into public.game_public (room_id, host) select id, auth.uid() from r', '42501', null,
  'nobody writes the board by hand');
select throws_ok($$ update public.game_seat_views set view = '{}' $$, '42501', null, 'nobody writes seat views by hand');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.publish_game((select id from r), 1, '{"phase": "night"}'::jsonb,
       '{"s1": {"role": "padrino"}, "s2": {"role": "medico"}, "s3": {"role": "cittadino"}, "s4": {"role": "mafioso"}}'::jsonb,
       '{"snapshot": "secret"}'::jsonb) $$,
  'the host publishes version 1'
);
select throws_ok(
  $$ select public.publish_game((select id from r), 1, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb) $$,
  'P0001', 'stale_version', 'versions only go forward'
);
select is((select count(*)::int from public.game_seat_views), 1, 'the host reads only its own seat');
select is((select view ->> 'role' from public.game_seat_views), 'padrino', 'its own role');
select is((select state ->> 'snapshot' from public.game_host_state), 'secret', 'the host reads its saved game');

set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select is((select view ->> 'phase' from public.game_public), 'night', 'players read the board');
select is((select count(*)::int from public.game_seat_views), 1, 'Bruno reads one seat view');
select is((select view ->> 'role' from public.game_seat_views), 'medico', 'and it is his');
select is((select count(*)::int from public.game_host_state), 0, 'players never read the host''s saved game');

-- Intents.
select throws_ok(
  $$ select public.submit_intent((select id from r), '{"type": "pass", "seat": "s3"}'::jsonb) $$,
  'P0001', 'not_your_seat', 'nobody acts for another seat'
);
select ok(
  public.submit_intent((select id from r), '{"type": "pass", "seat": "s2"}'::jsonb) > 0,
  'Bruno sends an intent for his own seat'
);
select throws_ok('insert into public.game_intents (room_id, seat, profile_id, intent) select id, ''s2'', auth.uid(), ''{}'' from r',
  '42501', null, 'intents go through submit_intent only');
select is((select count(*)::int from public.game_intents), 0, 'players cannot read intents, not even their own');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select is((select seat from public.game_intents), 's2', 'the host reads the intent');

-- Outsiders.
set local request.jwt.claims to '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
select is((select count(*)::int from public.game_public), 0, 'outsiders do not see the board');
select is((select count(*)::int from public.game_seat_views), 0, 'outsiders see no seat');
select throws_ok(
  $$ select public.submit_intent((select id from r), '{"type": "pass", "seat": "s1"}'::jsonb) $$,
  'P0001', 'not_allowed', 'outsiders cannot act'
);

-- Handled intents go; the end reopens the lobby.
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ select public.publish_game((select id from r), 2, '{"phase": "ended"}'::jsonb, '{}'::jsonb, '{}'::jsonb,
       (select max(id) from public.game_intents), true) $$,
  'the host publishes the end'
);
select is((select count(*)::int from public.game_intents), 0, 'handled intents are deleted');
select is((select status from public.rooms where id = (select id from r)), 'lobby', 'the lobby opens again');

select * from finish();
rollback;
