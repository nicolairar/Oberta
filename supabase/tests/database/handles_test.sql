-- Handles: Instagram-style form, moderation, names reserved for bots.
-- Run with: supabase test db
begin;
select plan(30);

insert into auth.users (id, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', '{}'),
  ('22222222-2222-2222-2222-222222222222', '{}');

set local role authenticated;
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

-- Good names.
select lives_ok($$ update public.profiles set handle = 'anna' where id = auth.uid() $$, 'letters');
select lives_ok($$ update public.profiles set handle = 'anna.rossi' where id = auth.uid() $$, 'a dot between names');
select lives_ok($$ update public.profiles set handle = 'anna_r_92' where id = auth.uid() $$, 'underscores and digits');
select lives_ok($$ update public.profiles set handle = '9anna' where id = auth.uid() $$, 'a digit first');
select lives_ok($$ update public.profiles set handle = 'a___b' where id = auth.uid() $$, 'three symbols in a row');
select lives_ok($$ update public.profiles set handle = 'abcdefghijkl' where id = auth.uid() $$, 'twelve characters');
select lives_ok($$ update public.profiles set handle = 'roberta' where id = auth.uid() $$, 'a name hiding a staff word stays');
select lives_ok($$ update public.profiles set handle = 'mood' where id = auth.uid() $$, 'double letters are not collapsed for exact words');
select lives_ok($$ update public.profiles set handle = 'bottega' where id = auth.uid() $$, 'words starting with bot are fine');
select lives_ok($$ update public.profiles set handle = 'pedone' where id = auth.uid() $$, 'short words only match whole names');

-- Bad form.
select throws_ok($$ update public.profiles set handle = 'ab' where id = auth.uid() $$, '23514', null, 'too short');
select throws_ok($$ update public.profiles set handle = 'abcdefghijklm' where id = auth.uid() $$, '23514', null, 'too long');
select throws_ok($$ update public.profiles set handle = 'Anna' where id = auth.uid() $$, '23514', null, 'uppercase');
select throws_ok($$ update public.profiles set handle = 'an-na' where id = auth.uid() $$, '23514', null, 'a dash');
select throws_ok($$ update public.profiles set handle = '.anna' where id = auth.uid() $$, '23514', null, 'starts with a dot');
select throws_ok($$ update public.profiles set handle = '_anna' where id = auth.uid() $$, '23514', null, 'starts with an underscore');
select throws_ok($$ update public.profiles set handle = 'anna.' where id = auth.uid() $$, '23514', null, 'ends with a dot');
select throws_ok($$ update public.profiles set handle = 'an..na' where id = auth.uid() $$, '23514', null, 'two dots in a row');
select throws_ok($$ update public.profiles set handle = 'a_._.b' where id = auth.uid() $$, '23514', null, 'four symbols in a row');

-- Moderation, after leetspeak and separators.
select throws_ok($$ update public.profiles set handle = 'fuck' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'an insult');
select throws_ok($$ update public.profiles set handle = 'f.u.c.k' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'dots in between');
select throws_ok($$ update public.profiles set handle = 'fuuuck' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'repeated letters');
select throws_ok($$ update public.profiles set handle = 'h1tl3r' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'leetspeak');
select throws_ok($$ update public.profiles set handle = 'str0nz0_92' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'Italian insult with digits');
select throws_ok($$ update public.profiles set handle = 'uccidi.ebrei' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'kill pattern');
select throws_ok($$ update public.profiles set handle = 'admin' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'staff name');
select throws_ok($$ update public.profiles set handle = 'bot.alfa' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'bot names are for bots');
select throws_ok($$ update public.profiles set handle = 'b0t_7' where id = auth.uid() $$, 'P0001', 'handle_not_allowed', 'bot names in disguise');

-- The list itself stays hidden.
select throws_ok('select * from public.reserved_words', '42501', null, 'players cannot read the word list');
reset role;

-- Unique whatever the case: lowercase is all there is.
update public.profiles set handle = 'carla' where id = '11111111-1111-1111-1111-111111111111';
select throws_ok(
  $$ update public.profiles set handle = 'carla' where id = '22222222-2222-2222-2222-222222222222' $$,
  '23505', null, 'two players cannot share a handle'
);

select * from finish();
rollback;
