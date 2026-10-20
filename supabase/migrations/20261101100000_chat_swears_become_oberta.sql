-- Swear words in chat are no longer refused: each offending word (or the two
-- or three words that spell one together, "porca madonna") becomes "obertà".
-- "che cazzo dici" -> "che obertà dici". Same word lists as before.
create or replace function public._chat_word_bad(token text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.reserved_words as w, public._handle_forms(token) as f
    where w.in_chat and (
      (w.match = 'contains' and position(regexp_replace(w.word, '(.)\1+', '\1', 'g') in f.collapsed) > 0)
      or (w.match = 'exact' and f.plain = w.word))
  );
$$;
revoke all on function public._chat_word_bad(text) from public, anon, authenticated;

create or replace function public._chat_span_bad(joined text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.reserved_words as w, public._handle_forms(joined) as f
    where w.in_chat and w.match = 'contains'
      and f.collapsed = regexp_replace(w.word, '(.)\1+', '\1', 'g')
  );
$$;
revoke all on function public._chat_span_bad(text) from public, anon, authenticated;

create or replace function public._chat_clean(body text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  words text[] := regexp_split_to_array(btrim(body), '\s+');
  n integer := coalesce(array_length(words, 1), 0);
  out text[] := '{}';
  i integer := 1;
begin
  while i <= n loop
    if i + 2 <= n and public._chat_span_bad(words[i] || words[i + 1] || words[i + 2]) then
      out := out || 'obertà'::text; i := i + 3;
    elsif i + 1 <= n and public._chat_span_bad(words[i] || words[i + 1]) then
      out := out || 'obertà'::text; i := i + 2;
    elsif public._chat_word_bad(words[i]) then
      out := out || 'obertà'::text; i := i + 1;
    else
      out := out || words[i]; i := i + 1;
    end if;
  end loop;
  return array_to_string(out, ' ');
end;
$$;
revoke all on function public._chat_clean(text) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_chat(room uuid, channel text, body text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  me uuid := auth.uid();
  r public.rooms;
  g public.game_public;
  s public.game_seats;
  text_ text := btrim(coalesce(body, ''));
  recent integer;
  sender text;
  new_id bigint;
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
$function$
;
