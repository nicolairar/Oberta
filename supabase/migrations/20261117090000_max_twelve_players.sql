-- At most twelve at a table, everywhere: friends rooms hold 4–12 players
-- (ranked was already 12). New rooms default to 12 seats, existing rooms
-- are clamped, and the check refuses anything bigger. The friends test
-- auto-fill (start_game) caps at max_players, so it fills up to 12 too.
--
-- Seats of past games (room_members.seat up to 16) are left as they are.
--
-- Reverse: set the default back to 16, the max_players check to "between 2
-- and 16" and the bots check to "between 0 and 15".

update public.rooms set max_players = 12 where max_players > 12;

alter table public.rooms alter column max_players set default 12;
alter table public.rooms drop constraint if exists rooms_max_players_check;
alter table public.rooms
  add constraint rooms_max_players_check check (max_players between 2 and 12);

-- Bots fill empty seats, so with at least one person there are at most 11.
update public.rooms set bots = 11 where bots > 11;
alter table public.rooms drop constraint if exists rooms_bots_check;
alter table public.rooms add constraint rooms_bots_check check (bots between 0 and 11);

-- A test size above twelve would mean nothing now.
update internal.config set value = '12'
where key = 'friends_test_size' and value ~ '^\d+$' and value::int > 12;
