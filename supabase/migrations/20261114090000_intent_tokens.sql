-- The moves no longer count the whole server's moves.
--
-- submit_intent returned game_intents.id, from one identity sequence shared
-- by every room, and the engine wrote that id back in the seat's receipt:
-- between two of one's own moves a player could see how many moves had been
-- sent meanwhile (night actions included). Now:
--
-- - each intent gets a random `token`; submit_intent returns it and the
--   engine puts it (never the id) in the receipt of the seat's view;
-- - `id` stays as the arrival order, read only by the Edge Function (as
--   postgres) and internal.game_commit; clients have no privilege on the
--   table and it is not published to Realtime.

alter table public.game_intents add column if not exists token uuid not null default gen_random_uuid();

revoke all on public.game_intents from public, anon, authenticated;
drop policy if exists "only the host reads intents" on public.game_intents;

do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_intents'
  ) then
    alter publication supabase_realtime drop table public.game_intents;
  end if;
end;
$$;

-- submit_intent, as before, returning the token.
drop function if exists public.submit_intent(uuid, jsonb);
create function public.submit_intent(room uuid, intent jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  my_seat text;
  pending integer;
  new_token uuid;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room)
     or not exists (select 1 from public.rooms where id = room and status = 'playing') then
    raise exception 'not_allowed';
  end if;
  select seat into my_seat from public.game_seats where room_id = room and profile_id = me;
  if my_seat is null then
    raise exception 'not_allowed';
  end if;
  if intent is null or jsonb_typeof(intent) <> 'object' or intent ->> 'seat' is distinct from my_seat then
    raise exception 'not_your_seat';
  end if;
  if octet_length(intent::text) > 512 then
    raise exception 'invalid_intent';
  end if;
  select count(*) into pending from public.game_intents where room_id = room and profile_id = me;
  if pending >= 20 then
    raise exception 'too_many_intents';
  end if;
  insert into public.game_intents (room_id, seat, profile_id, intent)
  values (room, my_seat, me, intent)
  returning token into new_token;
  update public.game_seats set last_seen = now() where room_id = room and seat = my_seat;
  perform internal.wake_game(room);
  return new_token;
end;
$$;
revoke all on function public.submit_intent(uuid, jsonb) from public, anon;
grant execute on function public.submit_intent(uuid, jsonb) to authenticated;

-- The receipts already published, and those the engine keeps in its state
-- to publish again, carry the old ids: drop them.
update public.game_seat_views set view = view - 'receipt' where view ? 'receipt';
update internal.game_state set state = state - 'receipts'
where jsonb_typeof(state) = 'object' and state ? 'receipts';

notify pgrst, 'reload schema';
