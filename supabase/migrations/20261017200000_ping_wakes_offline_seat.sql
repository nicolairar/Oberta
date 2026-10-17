-- A seat that comes back must be seen back at once. game_ping used to wake
-- the function, but the function only steps games that are due (a deadline
-- passed, or intents waiting): a returning seat was neither, so the game was
-- not stepped and the seat stayed "offline" for everyone until the next
-- deadline, or for good once the game had ended. Now game_ping also makes
-- the game due right away; if the wake is lost, the 2-second tick catches it.
create or replace function public.game_ping(room uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  was_offline boolean;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  update public.game_seats set last_seen = now()
  where room_id = room and profile_id = me
  returning offline into was_offline;
  if was_offline then
    update internal.game_state
    set next_due_at = least(coalesce(next_due_at, now()), now())
    where room_id = room;
    perform internal.wake_game(room);
  end if;
  return (extract(epoch from clock_timestamp()) * 1000)::bigint;
end;
$$;
revoke all on function public.game_ping(uuid) from public, anon;
grant execute on function public.game_ping(uuid) to authenticated;
