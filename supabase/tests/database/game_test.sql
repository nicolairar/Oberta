-- Online games run on the server: who may read and write what.
-- Run with: supabase test db
begin;
select plan(69);

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
grant select on r to authenticated, anon;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select public.join_room((select code from r));
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select public.join_room((select code from r));
set local request.jwt.claims to '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
select public.create_room('en');

-- Lobby chat.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select ok(public.send_chat((select id from r), 'lobby', 'ciao a tutti') is not null, 'the lobby chats');
set local request.jwt.claims to '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
select throws_ok($$ select public.send_chat((select id from r), 'lobby', 'ciao') $$, 'P0001', 'not_allowed',
  'outsiders do not write in the room');
select is((select count(*)::int from public.game_chat), 0, 'nor read it');

-- Bots in the lobby: nobody adds them by hand; in the test period the server
-- fills the table up to friends_test_size when the host deals.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok($$ select public.set_room_bots((select id from r), 2) $$, '42501', null, 'a guest cannot add bots');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok($$ select public.set_room_bots((select id from r), 2) $$, '42501', null, 'nor can the host');
select is((select bots from public.rooms where id = (select id from r)), 0::smallint, 'no bots before the deal');
reset role;
insert into internal.config (key, value) values ('friends_test_bots', '1'), ('friends_test_size', '5')
on conflict (key) do update set value = excluded.value;
select ok(true, 'the test period is on');
set local role authenticated;

-- Starting.
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok($$ select public.start_game((select id from r)) $$, 'P0001', 'not_allowed', 'only the host starts');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select lives_ok($$ select public.start_game((select id from r)) $$, 'the host starts with three players; the server adds two bots');
select is((select status from public.rooms where id = (select id from r)), 'playing', 'the room is playing');
select throws_ok('select * from public.game_seats', '42501', null, 'seats are read by functions only');
select throws_ok($$ select public.start_game((select id from r)) $$, 'P0001', 'room_closed', 'one game at a time');

-- The secret state: no client reads or writes it, not even the host.
select throws_ok('select * from internal.game_state', '42501', null, 'the host cannot read the engine state');
select throws_ok('select * from internal.config', '42501', null, 'nor the wake secret');
select throws_ok($$ select internal.game_commit((select id from r), '{}'::jsonb) $$, '42501', null, 'nor save a step');
select throws_ok($$ select internal.wake_game(null) $$, '42501', null, 'nor wake the function by hand');
select throws_ok($$ select public.publish_game((select id from r), 1, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb) $$,
  '42883', null, 'the old host publishing is gone');
set local role anon;
select throws_ok('select * from internal.game_state', '42501', null, 'anon cannot read the engine state');
select throws_ok('select * from public.game_public', '42501', null, 'nor the board');
set local role authenticated;

reset role;
select is(
  (select string_agg(seat || '=' || coalesce(profile_id::text, name), ',' order by seat) from public.game_seats
   where room_id = (select id from r)),
  's1=11111111-1111-1111-1111-111111111111,s2=22222222-2222-2222-2222-222222222222,'
  || 's3=33333333-3333-3333-3333-333333333333,s4=bot.alfa,s5=bot.bravo',
  'the server seats people in room order, then the bots'
);
select is((select state from internal.game_state where room_id = (select id from r)), null::jsonb,
  'the cards are still to deal');
select ok((select next_due_at <= now() from internal.game_state where room_id = (select id from r)),
  'and the game is due at once');
select is((select count(*)::int from public.game_chat where room_id = (select id from r)), 1,
  'the lobby chat stays');

-- The function saves a step (as postgres, like the Edge Function).
select lives_ok($$ select internal.game_commit((select id from r), '{
  "changed": true, "version": 1, "finished": false, "nextDue": 1893456000000, "lastIntent": null,
  "state": {"snapshot": "secret"},
  "board": {"schedule": {"stage": "night"}, "offline": ["s3"]},
  "seatViews": {"s1": {"view": {"role": "padrino"}}, "s2": {"view": {"role": "medico"}},
                "s3": {"view": {"role": "cittadino"}}, "s4": {"view": {"role": "mafioso"}}},
  "chat": {"mode": "night", "seats": {"s1": {"alive": true, "family": true, "silenced": false},
           "s2": {"alive": true, "family": false, "silenced": false},
           "s3": {"alive": false, "family": false, "silenced": false}}},
  "departed": []}'::jsonb) $$, 'the function saves version 1');
select is((select count(*)::int from public.game_seat_views where room_id = (select id from r)), 3,
  'one view per human seat, none for bots');
select throws_ok($$ select internal.game_commit((select id from r), '{"changed": true, "version": 1}'::jsonb) $$,
  'P0001', 'stale_version', 'versions only go forward');
select is((select offline from public.game_seats where room_id = (select id from r) and seat = 's3'), true,
  'presence is saved');
set local role authenticated;

set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select is((select view -> 'schedule' ->> 'stage' from public.game_public), 'night', 'players read the board');
select is((select count(*)::int from public.game_seat_views), 1, 'Bruno reads one seat view');
select is((select view -> 'view' ->> 'role' from public.game_seat_views), 'medico', 'and it is his');
select throws_ok($$ update public.game_seat_views set view = '{}' $$, '42501', null, 'nobody writes seat views by hand');
select throws_ok('insert into public.game_public (room_id, host) select id, auth.uid() from r', '42501', null,
  'nobody writes the board by hand');

-- Intents and acknowledgements.
select throws_ok(
  $$ select public.submit_intent((select id from r), '{"type": "pass", "seat": "s3"}'::jsonb) $$,
  'P0001', 'not_your_seat', 'nobody acts for another seat'
);
select ok(
  public.submit_intent((select id from r), '{"type": "pass", "seat": "s2"}'::jsonb) is not null,
  'Bruno sends an intent for his own seat'
);
select ok(
  public.submit_intent((select id from r), '{"type": "ack", "seat": "s2", "stage": "night-1"}'::jsonb) is not null,
  'and an acknowledgement'
);
select throws_ok('insert into public.game_intents (room_id, seat, profile_id, intent) select id, ''s2'', auth.uid(), ''{}'' from r',
  '42501', null, 'intents go through submit_intent only');
select throws_ok('select * from public.game_intents', '42501', null, 'no phone reads intents, not even its own');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok('select * from public.game_intents', '42501', null, 'not even the host');
select ok(public.game_ping((select id from r)) > 0, 'a phone says it is there, and gets the server clock');
select ok(public.server_now() > 0, 'the server clock');

-- Night chat: the family only.
select throws_ok($$ select public.send_chat((select id from r), 'day', 'ciao') $$, 'P0001', 'chat_closed',
  'no town chat at night');
select ok(public.send_chat((select id from r), 'family', 'stanotte il medico') is not null, 'the family talks at night');
select throws_ok($$ select public.send_chat((select id from r), 'lobby', 'ciao') $$, 'P0001', 'chat_closed',
  'the lobby chat closes while playing');
select throws_ok($$ select public.send_chat((select id from r), 'family', 'porca madonna') $$, 'P0001',
  'message_blocked', 'the same word list as the handles');
select throws_ok($$ select public.send_chat((select id from r), 'family', repeat('a', 301)) $$, 'P0001',
  'invalid_message', 'messages are short');
select is((select count(*)::int from public.game_chat where channel = 'family'), 1, 'the family reads its chat');
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select throws_ok($$ select public.send_chat((select id from r), 'family', 'ciao') $$, 'P0001', 'chat_closed',
  'a citizen cannot write to the family');
select is((select count(*)::int from public.game_chat where channel = 'family'), 0, 'nor read it');
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select throws_ok($$ select public.send_chat((select id from r), 'day', 'ciao') $$, 'P0001', 'chat_closed',
  'the dead do not write');

-- Day: the town talks, the silenced one does not.
reset role;
select lives_ok($$ select internal.game_commit((select id from r), '{
  "changed": true, "version": 2, "finished": false, "nextDue": 1893456000000,
  "state": {"snapshot": "secret"}, "board": {"schedule": {"stage": "discussion"}, "offline": []}, "seatViews": {},
  "chat": {"mode": "day", "seats": {"s1": {"alive": true, "family": true, "silenced": true},
           "s2": {"alive": true, "family": false, "silenced": false}}},
  "departed": ["s3"]}'::jsonb) $$, 'the function opens the day, and records an abandon');
set local role authenticated;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select ok(public.send_chat((select id from r), 'day', 'chi è stato?') is not null, 'the living talk by day');
select ok(public.send_chat((select id from r), 'day', 'io no') is not null, 'twice');
select throws_ok($$ select public.send_chat((select id from r), 'day', 'basta') $$, 'P0001', 'too_many_messages',
  'but not too fast');
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok($$ select public.send_chat((select id from r), 'day', 'ciao') $$, 'P0001', 'silenced',
  'the Tailor''s victim reads but does not write');
select throws_ok($$ select public.send_chat((select id from r), 'family', 'ciao') $$, 'P0001', 'chat_closed',
  'and the family chat is for the night');
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select is((select count(*)::int from public.game_chat where channel = 'day'), 2, 'the dead read the town chat');
select throws_ok('select * from internal.game_abandons', '42501', null, 'abandons are not readable by any phone');
select throws_ok($$ insert into internal.game_abandons (profile_id, game_id, seat) values (auth.uid(), gen_random_uuid(), 's3') $$,
  '42501', null, 'nor writable');
reset role;
select is((select count(*)::int from internal.game_abandons where seat = 's3'), 1, 'the server recorded Carla''s abandon');
set local role authenticated;
set local request.jwt.claims to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

-- Outsiders.
set local request.jwt.claims to '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}';
select is((select count(*)::int from public.game_public), 0, 'outsiders do not see the board');
select is((select count(*)::int from public.game_seat_views), 0, 'outsiders see no seat');
select throws_ok(
  $$ select public.submit_intent((select id from r), '{"type": "pass", "seat": "s1"}'::jsonb) $$,
  'P0001', 'not_allowed', 'outsiders cannot act'
);

-- Handled intents go; the end reopens the lobby.
reset role;
select lives_ok($$ select internal.game_commit((select id from r), jsonb_build_object(
  'changed', true, 'version', 3, 'finished', true, 'nextDue', null, 'state', '{}'::jsonb, 'board', '{}'::jsonb,
  'seatViews', '{}'::jsonb, 'chat', '{"mode": "closed", "seats": {}}'::jsonb,
  'lastIntent', (select max(id) from public.game_intents))) $$, 'the function saves the end');
select is((select count(*)::int from public.game_intents), 0, 'handled intents are deleted');
select is((select status from public.rooms where id = (select id from r)), 'lobby', 'the lobby opens again');
select is((select next_due_at from internal.game_state where room_id = (select id from r)), null::timestamptz,
  'and the server stops looking at the game');

select ok(not public._chat_blocked('qualcun tra voi mente'), 'words across tokens are not blocked');
select ok(not public._chat_blocked('uccidi il medico'), 'game talk is allowed in chat');
select ok(public._chat_blocked('porca madonna'), 'blasphemy is still blocked');

select * from finish();
rollback;
