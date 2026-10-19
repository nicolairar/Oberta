-- Idle rooms go sooner: a lobby with nobody seated, or where nobody has sat
-- down for 30 minutes, is deleted (members cascade). The sweep also runs
-- every minute, not only when someone joins a room.
create or replace function public._sweep_rooms()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.rooms r
  where r.status = 'ended'
     or (r.status = 'lobby' and r.created_at < now() - interval '30 minutes' and not exists (
           select 1 from public.room_members m
           where m.room_id = r.id and m.left_at is null and m.joined_at > now() - interval '30 minutes'))
     or (r.status = 'lobby' and r.created_at < now() - interval '2 minutes' and not exists (
           select 1 from public.room_members m where m.room_id = r.id and m.left_at is null));
$$;
revoke all on function public._sweep_rooms() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('oberta-sweep-rooms', '* * * * *', 'select public._sweep_rooms()');
  end if;
end;
$$;

select public._sweep_rooms();
