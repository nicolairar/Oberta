-- Sweep stale rooms before picking a lobby: otherwise the matcher can pick
-- a lobby older than six hours that the member-insert sweep then deletes.
create or replace function internal.ranked_place(who uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  q internal.ranked_queue;
  size integer := internal.config_int('ranked_size', 12);
  test boolean := internal.config_int('ranked_test_humans', 0) > 0;
  mine double precision;
  low boolean;
  target uuid;
  new_code text;
begin
  perform public._sweep_rooms();
  select * into q from internal.ranked_queue where profile_id = who for update;
  if not found or q.room_id is not null then
    return q.room_id;
  end if;
  mine := internal.ordinal(who, q.language);
  low := coalesce((select score from internal.conduct where profile_id = who), 100) < 70;

  select r.id into target
  from public.rooms r
  cross join lateral (
    select count(*) as n,
           avg(internal.ordinal(m.profile_id, q.language)) as rating,
           bool_and(coalesce(c.score, 100) < 70) as all_low,
           bool_or(coalesce(c.score, 100) < 70) as any_low,
           max(extract(epoch from now() - coalesce(rq.joined_at, m.joined_at))) as waited
    from public.room_members m
    left join internal.conduct c on c.profile_id = m.profile_id
    left join internal.ranked_queue rq on rq.profile_id = m.profile_id
    where m.room_id = r.id and m.left_at is null
  ) s
  where r.status = 'lobby' and r.language = q.language
    and (r.ranked or r.test_match) and r.test_match = test
    and s.n between 1 and size - 1
    and (case when low then s.all_low else not s.any_low end)
    and abs(s.rating - mine) <= internal.ranked_band(greatest(s.waited, extract(epoch from now() - q.joined_at)))
  order by s.n desc, r.created_at
  limit 1
  for update of r skip locked;

  if target is null then
    loop
      select string_agg(substr(alphabet, get_byte(uuid_send(gen_random_uuid()), 0) % length(alphabet) + 1, 1), '')
        into new_code
        from generate_series(1, 6);
      begin
        insert into public.rooms (code, host, language, max_players, ranked, test_match, bots)
        values (new_code, who, q.language, size, not test, test, 0)
        returning id into target;
        exit;
      exception when unique_violation then
      end;
    end loop;
  end if;
  perform internal.ranked_seat(target, who);
  perform internal.ranked_countdown(target);
  return target;
end;
$$;
revoke all on function internal.ranked_place(uuid) from public, anon, authenticated;
