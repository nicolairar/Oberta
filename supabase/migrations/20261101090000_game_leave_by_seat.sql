-- game_leave checked room membership, but the app may leave the room in the
-- same moment it leaves the game: the call was refused and the leave never
-- recorded (a dead player who left still got the loss XP). Now owning a seat
-- in the game is enough.
create or replace function public.game_leave(room uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  gid uuid;
  my_seat text;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select seat into my_seat from public.game_seats where room_id = room and profile_id = me;
  if my_seat is null then
    raise exception 'not_allowed';
  end if;
  select game_id into gid from public.game_public where room_id = room;
  if gid is not null then
    insert into internal.game_leaves (game_id, profile_id, seat)
    values (gid, me, my_seat)
    on conflict (game_id, profile_id) do nothing;
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
