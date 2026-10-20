-- Leaving a game for good: the seat counts as away since long ago, so the
-- next step records the abandon at once (no rewards, even if the side wins
-- afterwards), instead of waiting for the reconnect grace to expire.
create or replace function public.game_leave(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
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
