-- Ranked is always exactly 12 players (owner rule). The small-table path of
-- 20261030090000 (a lobby starting with 'ranked_small_min' after
-- 'ranked_small_after' seconds) was only neutralised by a config value;
-- here it goes away for good: a ranked lobby needs 12, whatever the wait and
-- whatever the config says. The TEST ONLY flag ('ranked_test_humans') is
-- unchanged: those rooms are test_match, never ranked, and fill with bots.
-- Idempotent.

update internal.config set value = '12' where key = 'ranked_size';
insert into internal.config (key, value) values ('ranked_size', '12')
on conflict (key) do nothing;
delete from internal.config where key in ('ranked_small_after', 'ranked_small_min');

-- How many people make a lobby ready: 12 for ranked, the test number for a
-- test match.
create or replace function internal.ranked_need(test boolean)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when test then least(12, greatest(1, internal.config_int('ranked_test_humans', 1)))
              else 12 end;
$$;
revoke all on function internal.ranked_need(boolean) from public, anon, authenticated;

-- Kept for its callers (ranked_countdown, ranked_start): no waiting-time
-- discount any more.
create or replace function internal.ranked_need_room(room uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select internal.ranked_need(coalesce((select r.test_match from public.rooms r where r.id = room), false));
$$;
revoke all on function internal.ranked_need_room(uuid) from public, anon, authenticated;

-- The tick no longer re-checks lobbies for the small-table threshold.
create or replace function internal.game_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform internal.ranked_match();
  if exists (
    select 1 from internal.game_state g
    where g.next_due_at <= now()
       or exists (select 1 from public.game_intents i where i.room_id = g.room_id)
  ) then
    perform internal.wake_game(null);
  end if;
end;
$$;
revoke all on function internal.game_tick() from public, anon, authenticated;

drop function if exists internal.ranked_small_tick();
