-- The chat no longer counts the whole server's messages.
--
-- game_chat.id came from one identity sequence shared by every room and
-- channel: a town player could compare the ids of two messages in the
-- square and see that, during the night, messages had been written
-- somewhere else (the family, alive and at least two of them). Now:
--
-- - `id` is a random uuid, the only key a phone ever sees or sends back
--   (send_chat returns it, report_player takes it);
-- - `n` numbers the messages of one channel of one room (and one game),
--   1, 2, 3...: it counts only what the readers of that channel read, so a
--   gap never tells anything about the other channels;
-- - the phones sort by created_at, then n.
--
-- The old bigint ids are gone (column and sequence dropped), the reports
-- that pointed to a message keep pointing to it by its new id, and the
-- engine's chat cursor (state.lastChat, for the AFK rule) moves to the
-- square's `n`. The AFK rule now hears only the square: a family message
-- must not change anything that the others can see, not even who gets
-- sent home for being idle.

-- ---------------------------------------------------------------------------
-- The new columns, filled for the messages already there.

alter table public.game_chat add column if not exists uid uuid not null default gen_random_uuid();
alter table public.game_chat add column if not exists n integer;

update public.game_chat c
set n = o.n
from (
  select id, row_number() over (partition by room_id, game_id, channel order by id) as n
  from public.game_chat
) o
where o.id = c.id;

-- ---------------------------------------------------------------------------
-- The reports follow the messages to their new ids.

alter table internal.reports add column if not exists message_uid uuid;
update internal.reports r set message_uid = c.uid from public.game_chat c where c.id = r.message_id;
alter table internal.reports drop column message_id;
alter table internal.reports rename column message_uid to message_id;

-- ---------------------------------------------------------------------------
-- The uuid becomes the key; the shared sequence goes with the old column.

drop index if exists public.game_chat_by_room;
alter table public.game_chat drop constraint game_chat_pkey;
alter table public.game_chat drop column id;
alter table public.game_chat rename column uid to id;
alter table public.game_chat add primary key (id);
alter table public.game_chat alter column n set not null;
create index if not exists game_chat_by_room on public.game_chat (room_id, created_at);
create unique index if not exists game_chat_order
  on public.game_chat (room_id, channel, coalesce(game_id, '00000000-0000-0000-0000-000000000000'::uuid), n);

-- The number of a new message: the next one in its channel, whatever the
-- writer passed. One writer at a time per channel.
create or replace function public._game_chat_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(
    hashtextextended('game_chat:' || new.room_id::text || ':' || new.channel || ':' || coalesce(new.game_id::text, ''), 0)
  );
  select coalesce(max(c.n), 0) + 1 into new.n
  from public.game_chat c
  where c.room_id = new.room_id and c.channel = new.channel and c.game_id is not distinct from new.game_id;
  return new;
end;
$$;
revoke all on function public._game_chat_order() from public, anon, authenticated;
drop trigger if exists game_chat_order on public.game_chat;
create trigger game_chat_order
  before insert on public.game_chat
  for each row execute function public._game_chat_order();

-- ---------------------------------------------------------------------------
-- send_chat, as before, returning the new uuid.

drop function if exists public.send_chat(uuid, text, text);
create function public.send_chat(room uuid, channel text, body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  g public.game_public;
  s public.game_seats;
  text_ text := btrim(coalesce(body, ''));
  recent integer;
  sender text;
  new_id uuid;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  if char_length(text_) = 0 or char_length(text_) > 300 then
    raise exception 'invalid_message';
  end if;
  select count(*) into recent from public.game_chat
  where profile_id = me and created_at > now() - interval '3 seconds';
  if recent >= 3 then
    raise exception 'too_many_messages';
  end if;
  text_ := public._chat_clean(text_);
  select * into r from public.rooms where id = room;

  if channel = 'lobby' then
    if r.status <> 'lobby' then
      raise exception 'chat_closed';
    end if;
    select handle into sender from public.profiles where id = me;
    insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body)
    values (room, null, 'lobby', me, null, coalesce(sender, '?'), text_)
    returning id into new_id;
    return new_id;
  end if;

  select * into g from public.game_public where room_id = room;
  select * into s from public.game_seats where room_id = room and profile_id = me;
  if g.room_id is null or s.seat is null or r.status <> 'playing' or not s.alive then
    raise exception 'chat_closed';
  end if;
  if channel = 'day' then
    if g.chat_mode <> 'day' then
      raise exception 'chat_closed';
    end if;
    if s.silenced then
      raise exception 'silenced';
    end if;
  elsif channel = 'family' then
    if not s.family
       or not (g.chat_mode = 'night' or (g.chat_mode = 'day' and s.family_day)) then
      raise exception 'chat_closed';
    end if;
  else
    raise exception 'chat_closed';
  end if;
  insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body)
  values (room, g.game_id, channel, me, s.seat, s.name, text_)
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.send_chat(uuid, text, text) from public, anon;
grant execute on function public.send_chat(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- report_player, as before, with the message's uuid.

drop function if exists public.report_player(uuid, text, text, uuid, bigint);
create function public.report_player(
  target uuid,
  reason text,
  note text default null,
  game_id uuid default null,
  message_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  clean_note text := nullif(btrim(coalesce(report_player.note, '')), '');
  msg record;
  reporters integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select null::text as body, null::text as channel, null::uuid as room_id, null::uuid as game_id into msg;
  if report_player.target is null or report_player.target = me
     or not exists (select 1 from public.profiles p where p.id = report_player.target) then
    raise exception 'player_not_found';
  end if;
  if report_player.reason is null
     or report_player.reason not in ('language', 'cheating', 'identity', 'spam', 'other') then
    raise exception 'invalid_report';
  end if;
  if clean_note is not null and char_length(clean_note) > 500 then
    clean_note := left(clean_note, 500);
  end if;

  if (select count(*) from internal.reports r
      where r.reporter = me and r.created_at > now() - interval '1 hour') >= 10 then
    raise exception 'too_many_reports';
  end if;

  if report_player.message_id is not null then
    if exists (select 1 from internal.reports r
               where r.reporter = me and r.message_id = report_player.message_id) then
      return;
    end if;
  elsif exists (select 1 from internal.reports r
                where r.reporter = me and r.target = report_player.target
                  and r.created_at > now() - interval '1 day') then
    return;
  end if;

  -- The message, only if the caller sat in its room and it is the target's.
  if report_player.message_id is not null then
    select c.body, c.channel, c.room_id, c.game_id into msg
    from public.game_chat c
    where c.id = report_player.message_id and c.profile_id = report_player.target
      and exists (select 1 from public.room_members m where m.room_id = c.room_id and m.profile_id = me);
  end if;

  insert into internal.reports (
    reporter, target, reason, note, game_id, room_id, message_id, message_text, message_channel, target_handle
  )
  values (
    me,
    report_player.target,
    report_player.reason,
    clean_note,
    coalesce(report_player.game_id, msg.game_id),
    msg.room_id,
    case when msg.body is null then null else report_player.message_id end,
    msg.body,
    msg.channel,
    (select p.handle from public.profiles p where p.id = report_player.target)
  );

  if exists (select 1 from internal.reports r
             where r.reporter = me and r.target = report_player.target
               and r.created_at > now() - interval '30 days'
             offset 1) then
    return;  -- this reporter already counted
  end if;
  select count(distinct r.reporter) into reporters
  from internal.reports r
  where r.target = report_player.target and r.reporter is not null
    and r.created_at > now() - interval '30 days';
  if reporters >= 3 then
    perform internal.conduct_of(report_player.target);
    update internal.conduct
    set score = greatest(40, score - 5)
    where profile_id = report_player.target and score > 40;
  end if;
end;
$$;
revoke all on function public.report_player(uuid, text, text, uuid, uuid) from public, anon;
grant execute on function public.report_player(uuid, text, text, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The engine's chat cursor, for the games being played: the last square
-- message already heard (the Edge Function now reads only the square, by n).

update internal.game_state s
set state = jsonb_set(s.state, '{lastChat}', to_jsonb(coalesce((
  select max(c.n)
  from public.game_chat c
  join public.game_public g on g.room_id = c.room_id and g.game_id = c.game_id
  where c.room_id = s.room_id and c.channel = 'day'
), 0)))
where jsonb_typeof(s.state) = 'object' and s.state ? 'lastChat';

notify pgrst, 'reload schema';
