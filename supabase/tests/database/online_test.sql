-- Profiles, friendships and rooms, seen from the players' side.
-- Run with: supabase test db
begin;
select plan(35);

-- Three players sign up. Carla has not picked a handle yet.
insert into auth.users (id, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', '{}'),
  ('22222222-2222-2222-2222-222222222222', '{"language": "en"}'),
  ('33333333-3333-3333-3333-333333333333', '{}');

select is((select count(*)::int from public.profiles), 3, 'every sign-up gets a profile');
select is(
  (select language from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  'en', 'the language picked at sign-up is kept'
);

update public.profiles set handle = 'bruno'
where id = '22222222-2222-2222-2222-222222222222';

-- Nobody signed out can read anything.
set local role anon;
select throws_ok('select * from public.profiles', '42501', null, 'anon cannot read profiles');
select throws_ok('select * from public.rooms', '42501', null, 'anon cannot read rooms');
select throws_ok('select * from public.friendships', '42501', null, 'anon cannot read friendships');
select throws_ok($$ select public.join_room('ABCDEF') $$, '42501', null, 'anon cannot join rooms');
reset role;

-- Anna sets up her profile.
set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok(
  $$ update public.profiles set handle = 'anna' where id = auth.uid() $$,
  'a player picks her handle'
);
select throws_ok(
  $$ update public.profiles set handle = 'Anna!' where id = auth.uid() $$,
  '23514', null, 'handles are lowercase letters, digits and underscores'
);
update public.profiles set handle = 'hacked' where id = '22222222-2222-2222-2222-222222222222';
select is(
  (select handle from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  'bruno', 'nobody edits someone else''s profile'
);
select throws_ok(
  $$ select display_name from public.profiles $$,
  '42703', null, 'there is no display name any more: the handle is the only name'
);
select throws_ok(
  $$ update public.profiles set avatar = '{"hat": "gold"}' where id = auth.uid() $$,
  '42501', null, 'the avatar is not written by the client'
);

-- Rooms.
create temp table the_room as select * from public.create_room('it');
select matches((select code from the_room), '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$', 'six unambiguous characters');
select is((select host from the_room), '11111111-1111-1111-1111-111111111111'::uuid, 'the creator hosts');
select is((select seat from public.room_members where room_id = (select id from the_room)), 1::smallint, 'the host sits first');
select throws_ok($$ select public.create_room('fr') $$, 'P0001', 'invalid_language', 'only it or en');

set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok(
  $$ select public.join_room((select code from the_room)) $$,
  'P0001', 'profile_incomplete', 'no handle, no table'
);
select is((select count(*)::int from public.rooms), 0, 'outsiders do not see the room');
select is((select count(*)::int from public.room_members), 0, 'outsiders do not see who is in it');

set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok($$ select public.join_room('ZZZZZZ') $$, 'P0001', 'room_not_found', 'a wrong code finds nothing');
select is(
  (select id from public.join_room(lower((select code from the_room)))),
  (select id from the_room), 'the code works typed in lowercase too'
);
select is((select count(*)::int from public.room_members), 2, 'members see each other');
select is(
  (select seat from public.room_members where profile_id = auth.uid()), 2::smallint, 'the next free seat'
);
select throws_ok(
  $$ insert into public.room_members (room_id, profile_id, seat) select id, auth.uid(), 9 from the_room $$,
  '42501', null, 'members are not written by hand'
);

-- A full table turns people away.
reset role;
update public.profiles set handle = 'carla'
where id = '33333333-3333-3333-3333-333333333333';
update public.rooms set max_players = 2 where id = (select id from the_room);
set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok($$ select public.join_room((select code from the_room)) $$, 'P0001', 'room_full', 'no seat left');

-- Friendships.
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select is(public.send_friend_request('22222222-2222-2222-2222-222222222222'), 'pending', 'Anna asks Bruno');
select throws_ok(
  $$ select public.send_friend_request(auth.uid()) $$, 'P0001', 'player_not_found', 'not yourself'
);
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select is((select count(*)::int from public.friendships), 0, 'other people''s friendships stay hidden');
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok(
  $$ select public.respond_friend_request('33333333-3333-3333-3333-333333333333', true) $$,
  'P0001', 'request_not_found', 'only real requests can be answered'
);
select is(
  public.respond_friend_request('11111111-1111-1111-1111-111111111111', true), 'accepted', 'Bruno accepts'
);

-- Leaving: the host hands over, the last one out closes the room.
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok(
  'select public.leave_room((select id from the_room))', 'P0001', 'host_must_choose', 'the host must pick an heir'
);
select lives_ok(
  $$ select public.leave_room((select id from the_room), '22222222-2222-2222-2222-222222222222') $$,
  'the host leaves, handing the room to Bruno'
);
select is((select count(*)::int from public.rooms), 0, 'who leaves no longer sees the room');
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select is((select host from public.rooms), '22222222-2222-2222-2222-222222222222'::uuid, 'the host hands over');
select lives_ok('select public.leave_room((select id from the_room))', 'the last player leaves');
reset role;
select is((select count(*)::int from public.rooms where id = (select id from the_room)), 0, 'an empty room is deleted');

select * from finish();
rollback;
