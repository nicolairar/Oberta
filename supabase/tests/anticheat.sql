-- Anti-cheat: a player who calls the API directly (PostgREST, RPC) must not
-- learn anything hidden. Runs on the real database and changes nothing:
--
--   begin; <this file>; rollback;    (the file ends with its own rollback)
--
-- through the SQL editor or the Management API (see docs/sicurezza.md).
-- It returns one row per check; every `ok` must be true.
--
-- The table: Anna (s1, family), Bruno (s2, Detective), Dario (s4, family,
-- dead), a bot (s3). Carla sits in no room. The engine state, the seat
-- views, the family chat and the events are written as the Edge Function
-- writes them (as postgres, through internal.game_commit).
begin;

create temp table _r (n serial, check_name text, ok boolean, detail text);
grant all on _r to authenticated, anon;
grant all on sequence _r_n_seq to authenticated, anon;

-- How many rows [q] returns for the current role; a permission error
-- counts as none.
create function pg_temp.rows(q text) returns integer language plpgsql as $f$
declare c integer;
begin
  execute 'select count(*) from (' || q || ') x' into c;
  return c;
exception when insufficient_privilege then
  return -1;
end;
$f$;

-- [q] must fail (any error): a write or a call that is not allowed.
create function pg_temp.fails(q text) returns text language plpgsql as $f$
begin
  execute q;
  return null;
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$f$;

-- What the current role can read, one fingerprint per relation of the
-- public schema: every row it sees, with its physical place (an update
-- moves a row even when now() is frozen in this transaction).
create function pg_temp.seen() returns table (rel text, fp text) language plpgsql as $f$
declare t record; part text;
begin
  for t in
    select c.relname, c.relkind from pg_class c join pg_namespace s on s.oid = c.relnamespace
    where s.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
      and has_any_column_privilege(c.oid, 'SELECT')
    order by c.relname
  loop
    begin
      if t.relkind in ('r', 'p') then
        execute format('select coalesce(md5(string_agg(x.ctid::text || to_jsonb(x)::text, ''|'' order by x.ctid)), '''') from public.%I x', t.relname) into part;
      else
        execute format('select coalesce(md5(string_agg(to_jsonb(x)::text, ''|'' order by to_jsonb(x)::text)), '''') from public.%I x', t.relname) into part;
      end if;
    exception when others then
      begin
        execute format('select count(*)::text from public.%I', t.relname) into part;
      exception when others then
        part := 'unreadable';
      end;
    end;
    rel := t.relname; fp := part;
    return next;
  end loop;
end;
$f$;
create temp table _snap (k text, rel text, fp text);
grant all on _snap to authenticated, anon;
create temp table _ids (id uuid);
grant all on _ids to authenticated, anon;

insert into auth.users (id) values
  ('a0000000-0000-4000-8000-00000000000a'),
  ('b0000000-0000-4000-8000-00000000000b'),
  ('c0000000-0000-4000-8000-00000000000c'),
  ('d0000000-0000-4000-8000-00000000000d');
insert into public.profiles (id) values
  ('a0000000-0000-4000-8000-00000000000a'),
  ('b0000000-0000-4000-8000-00000000000b'),
  ('c0000000-0000-4000-8000-00000000000c'),
  ('d0000000-0000-4000-8000-00000000000d')
on conflict (id) do nothing;

insert into public.rooms (id, code, host, language, status, max_players)
values ('e0000000-0000-4000-8000-00000000000e', 'ZZZZ22', 'a0000000-0000-4000-8000-00000000000a', 'it', 'playing', 12);
insert into public.room_members (room_id, profile_id, seat) values
  ('e0000000-0000-4000-8000-00000000000e', 'a0000000-0000-4000-8000-00000000000a', 1),
  ('e0000000-0000-4000-8000-00000000000e', 'b0000000-0000-4000-8000-00000000000b', 2),
  ('e0000000-0000-4000-8000-00000000000e', 'd0000000-0000-4000-8000-00000000000d', 4);
insert into public.game_public (room_id, host, version, view, game_id, chat_mode)
values ('e0000000-0000-4000-8000-00000000000e', 'a0000000-0000-4000-8000-00000000000a', 0, null,
        'f0000000-0000-4000-8000-00000000000f', 'night');
insert into public.game_seats (room_id, seat, profile_id, name, alive, family) values
  ('e0000000-0000-4000-8000-00000000000e', 's1', 'a0000000-0000-4000-8000-00000000000a', 'anna', true, true),
  ('e0000000-0000-4000-8000-00000000000e', 's2', 'b0000000-0000-4000-8000-00000000000b', 'bruno', true, false),
  ('e0000000-0000-4000-8000-00000000000e', 's3', null, 'bot.alfa', true, false),
  ('e0000000-0000-4000-8000-00000000000e', 's4', 'd0000000-0000-4000-8000-00000000000d', 'dario', true, true);
insert into internal.game_state (room_id, state) values
  ('e0000000-0000-4000-8000-00000000000e', '{"secret": "SNAPSHOT_ROLES"}');

-- One step of the server: board, seat views, chat rights, events.
select internal.game_commit('e0000000-0000-4000-8000-00000000000e', $j${
  "changed": true, "version": 1, "finished": false, "state": {"secret": "SNAPSHOT_ROLES"},
  "board": {"board": {"round": 1, "finalRoles": []}, "offline": [], "departed": []},
  "seatViews": {
    "s1": {"view": {"seat": "s1", "role": "padrino", "secret": "VIEW_ANNA"}},
    "s2": {"view": {"seat": "s2", "role": "detective", "secret": "VIEW_BRUNO"}},
    "s4": {"view": {"seat": "s4", "role": "mafioso", "secret": "VIEW_DARIO"}}
  },
  "chat": {"mode": "night", "seats": {
    "s1": {"alive": true, "family": true},
    "s2": {"alive": true, "family": false},
    "s4": {"alive": false, "family": true}
  }},
  "events": [
    {"to": null, "kind": "night", "data": {"round": 1}},
    {"to": "s1", "kind": "familyTarget", "data": {"name": "bruno"}},
    {"to": "s2", "kind": "found", "data": {"name": "anna", "team": "mafia"}},
    {"to": "s3", "kind": "found", "data": {"name": "bot"}}
  ]
}$j$::jsonb);

insert into public.game_chat (room_id, game_id, channel, profile_id, seat, name, body) values
  ('e0000000-0000-4000-8000-00000000000e', 'f0000000-0000-4000-8000-00000000000f', 'family',
   'a0000000-0000-4000-8000-00000000000a', 's1', 'anna', 'stanotte tocca a bruno'),
  ('e0000000-0000-4000-8000-00000000000e', 'f0000000-0000-4000-8000-00000000000f', 'day',
   'b0000000-0000-4000-8000-00000000000b', 's2', 'bruno', 'buongiorno');

insert into _r (check_name, ok, detail)
select 'setup: the bot gets no private event', count(*) = 3, count(*)::text
from public.game_events where room_id = 'e0000000-0000-4000-8000-00000000000e';

-- ---- Bruno, a player outside the family.
set local role authenticated;
set local request.jwt.claims to '{"sub": "b0000000-0000-4000-8000-00000000000b", "role": "authenticated"}';

insert into _r (check_name, ok, detail) select 'bruno reads his own seat view',
  pg_temp.rows($q$select 1 from public.game_seat_views where profile_id = 'b0000000-0000-4000-8000-00000000000b'$q$) = 1, null;
insert into _r (check_name, ok, detail) select 'bruno reads no other seat view',
  pg_temp.rows($q$select 1 from public.game_seat_views where profile_id <> 'b0000000-0000-4000-8000-00000000000b' or seat <> 's2'$q$) = 0, null;
insert into _r (check_name, ok, detail) select 'no other role anywhere bruno can read',
  pg_temp.rows($q$select 1 from public.game_seat_views where view::text like '%VIEW_ANNA%' or view::text like '%padrino%'$q$) = 0
  and pg_temp.rows($q$select 1 from public.game_public where view::text like '%padrino%' or view::text like '%SNAPSHOT%'$q$) = 0, null;
insert into _r (check_name, ok, detail) select 'bruno sees the board',
  pg_temp.rows($q$select 1 from public.game_public where room_id = 'e0000000-0000-4000-8000-00000000000e'$q$) = 1, null;
insert into _r (check_name, ok, detail) select 'bruno does not read the family chat',
  pg_temp.rows($q$select 1 from public.game_chat where channel = 'family'$q$) = 0, null;
insert into _r (check_name, ok, detail) select 'bruno reads the town chat',
  pg_temp.rows($q$select 1 from public.game_chat where channel = 'day' and room_id = 'e0000000-0000-4000-8000-00000000000e'$q$) = 1, null;
insert into _r (check_name, ok, detail) select 'is_family_reader says no to bruno',
  not public.is_family_reader('e0000000-0000-4000-8000-00000000000e', 'f0000000-0000-4000-8000-00000000000f'), null;
insert into _r (check_name, ok, detail) select 'bruno cannot write in the family chat',
  pg_temp.fails($q$select public.send_chat('e0000000-0000-4000-8000-00000000000e', 'family', 'ciao')$q$) like '%chat_closed%', null;
insert into _r (check_name, ok, detail) select 'internal.game_state is out of reach',
  pg_temp.rows('select 1 from internal.game_state') = -1, null;
insert into _r (check_name, ok, detail) select 'internal.config is out of reach',
  pg_temp.rows('select 1 from internal.config') = -1, null;
insert into _r (check_name, ok, detail) select 'game_seats (rights, family flags) is out of reach',
  pg_temp.rows('select 1 from public.game_seats') = -1, null;
insert into _r (check_name, ok, detail) select 'game_intents (moves) is out of reach',
  pg_temp.rows('select 1 from public.game_intents') <= 0, null;
insert into _r (check_name, ok, detail) select 'bruno reads the public event and his own secret only',
  pg_temp.rows($q$select 1 from public.game_events where recipient is null$q$) = 1
  and pg_temp.rows($q$select 1 from public.game_events where recipient = 'b0000000-0000-4000-8000-00000000000b'$q$) = 1
  and pg_temp.rows($q$select 1 from public.game_events where recipient <> 'b0000000-0000-4000-8000-00000000000b'$q$) = 0, null;
insert into _r (check_name, ok, detail) select 'the order numbers do not count the others'' secrets',
  pg_temp.rows($q$select 1 from public.game_events where n <> 1$q$) = 0, null;
insert into _r (check_name, ok, detail) select 'bruno cannot save a step', pg_temp.fails(
  $q$select internal.game_commit('e0000000-0000-4000-8000-00000000000e', '{}'::jsonb)$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot write seat views', pg_temp.fails(
  $q$update public.game_seat_views set profile_id = 'b0000000-0000-4000-8000-00000000000b'$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot write the board', pg_temp.fails(
  $q$update public.game_public set version = 99$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot write events', pg_temp.fails(
  $q$insert into public.game_events (room_id, game_id, kind) values ('e0000000-0000-4000-8000-00000000000e', 'f0000000-0000-4000-8000-00000000000f', 'end')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot delete events', pg_temp.fails(
  $q$delete from public.game_events$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot wake the engine by hand', pg_temp.fails(
  $q$select internal.wake_game('e0000000-0000-4000-8000-00000000000e')$q$) is not null, null;
insert into _r (check_name, ok, detail) select 'bruno cannot act for anna', pg_temp.fails(
  $q$select public.submit_intent('e0000000-0000-4000-8000-00000000000e', '{"type":"pass","seat":"s1"}')$q$) like '%not_your_seat%', null;

-- ---- Anna, family: the family chat and her own secret, never Bruno's.
set local request.jwt.claims to '{"sub": "a0000000-0000-4000-8000-00000000000a", "role": "authenticated"}';
insert into _r (check_name, ok, detail) select 'anna (family) reads the family chat',
  pg_temp.rows($q$select 1 from public.game_chat where channel = 'family'$q$) = 1, null;
insert into _r (check_name, ok, detail) select 'anna reads her secret, not the detective''s finding',
  pg_temp.rows($q$select 1 from public.game_events where kind = 'familyTarget'$q$) = 1
  and pg_temp.rows($q$select 1 from public.game_events where kind = 'found'$q$) = 0, null;
insert into _r (check_name, ok, detail) select 'anna reads no other seat view',
  pg_temp.rows($q$select 1 from public.game_seat_views where view::text like '%VIEW_BRUNO%'$q$) = 0, null;

-- ---- Dario, family but dead: the family chat closes for him.
set local request.jwt.claims to '{"sub": "d0000000-0000-4000-8000-00000000000d", "role": "authenticated"}';
insert into _r (check_name, ok, detail) select 'a dead mafioso no longer reads the family chat',
  pg_temp.rows($q$select 1 from public.game_chat where channel = 'family'$q$) = 0, null;

-- ---- Carla, in no room: nothing at all.
set local request.jwt.claims to '{"sub": "c0000000-0000-4000-8000-00000000000c", "role": "authenticated"}';
insert into _r (check_name, ok, detail) select 'an outsider reads nothing of the game',
  pg_temp.rows($q$select 1 from public.game_public where room_id = 'e0000000-0000-4000-8000-00000000000e'$q$) = 0
  and pg_temp.rows($q$select 1 from public.game_seat_views where room_id = 'e0000000-0000-4000-8000-00000000000e'$q$) = 0
  and pg_temp.rows($q$select 1 from public.game_chat where room_id = 'e0000000-0000-4000-8000-00000000000e'$q$) = 0
  and pg_temp.rows($q$select 1 from public.game_events where room_id = 'e0000000-0000-4000-8000-00000000000e'$q$) = 0, null;

-- ---- The family talks: nothing Bruno can read moves, not even a number.
reset role;
insert into _r (check_name, ok, detail)
select 'game_chat has no shared counter (random uuid ids)',
  (select data_type from information_schema.columns
   where table_schema = 'public' and table_name = 'game_chat' and column_name = 'id') = 'uuid'
  and not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name in ('game_chat', 'game_events')
                    and (is_identity = 'YES' or column_default like 'nextval%')),
  null;
set local role authenticated;
set local request.jwt.claims to '{"sub": "b0000000-0000-4000-8000-00000000000b", "role": "authenticated"}';
insert into _snap select 'before', * from pg_temp.seen();
insert into _r (check_name, ok, detail) select 'the square counts only the square',
  (select array_agg(n order by n) from public.game_chat where channel = 'day') = '{1}', null;

set local request.jwt.claims to '{"sub": "a0000000-0000-4000-8000-00000000000a", "role": "authenticated"}';
insert into _ids select public.send_chat('e0000000-0000-4000-8000-00000000000e', 'family', 'bruno è il detective');
insert into _r (check_name, ok, detail) select 'send_chat returns the new random id',
  (select count(*) from _ids i join public.game_chat c on c.id = i.id and c.channel = 'family') = 1, null;
insert into _r (check_name, ok, detail) select 'the family counts only the family',
  (select array_agg(n order by n) from public.game_chat where channel = 'family') = '{1,2}', null;

set local request.jwt.claims to '{"sub": "b0000000-0000-4000-8000-00000000000b", "role": "authenticated"}';
insert into _snap select 'after', * from pg_temp.seen();
insert into _r (check_name, ok, detail)
select 'a family message changes nothing bruno can read (any table, view, Realtime row, board version)',
  count(*) = 0, string_agg(coalesce(b.rel, a.rel), ',')
from (select * from _snap where k = 'before') b
full join (select * from _snap where k = 'after') a on a.rel = b.rel
where a.fp is distinct from b.fp;
insert into _r (check_name, ok, detail) select 'bruno read a fingerprint of the room',
  (select count(*) from _snap where k = 'before' and rel in ('game_chat', 'game_public', 'game_events') and fp <> '') = 3, null;
select public.report_player('a0000000-0000-4000-8000-00000000000a', 'language', null, null, (select id from _ids));

reset role;
insert into _r (check_name, ok, detail) select 'report_player takes the message''s uuid',
  exists (select 1 from internal.reports where reporter = 'b0000000-0000-4000-8000-00000000000b'
          and message_id = (select id from _ids)), null;
update public.game_public set chat_mode = 'day' where room_id = 'e0000000-0000-4000-8000-00000000000e';
set local role authenticated;
set local request.jwt.claims to '{"sub": "b0000000-0000-4000-8000-00000000000b", "role": "authenticated"}';
select public.send_chat('e0000000-0000-4000-8000-00000000000e', 'day', 'chi ha parlato stanotte?');
insert into _r (check_name, ok, detail) select 'by day the square goes on from 1 to 2, whatever the family wrote',
  (select array_agg(n order by n) from public.game_chat where channel = 'day') = '{1,2}', null;

-- ---- Bruno leaves the room: his own view closes too.
reset role;
update public.room_members set left_at = now()
where room_id = 'e0000000-0000-4000-8000-00000000000e' and profile_id = 'b0000000-0000-4000-8000-00000000000b';
set local role authenticated;
set local request.jwt.claims to '{"sub": "b0000000-0000-4000-8000-00000000000b", "role": "authenticated"}';
insert into _r (check_name, ok, detail) select 'who left reads nothing more',
  pg_temp.rows($q$select 1 from public.game_seat_views$q$) = 0
  and pg_temp.rows($q$select 1 from public.game_events$q$) = 0, null;

-- ---- Anonymous: nothing.
set local role anon;
insert into _r (check_name, ok, detail) select 'anon reads nothing',
  pg_temp.rows('select 1 from public.game_public') <= 0
  and pg_temp.rows('select 1 from public.game_seat_views') <= 0
  and pg_temp.rows('select 1 from public.game_chat') <= 0
  and pg_temp.rows('select 1 from public.game_events') <= 0, null;

reset role;
-- ---- Realtime: only published tables, all behind the same policies.
insert into _r (check_name, ok, detail)
select 'every game table Realtime publishes has row level security', bool_and(c.relrowsecurity), string_agg(t.tablename, ',')
from pg_publication_tables t join pg_class c on c.relname = t.tablename
join pg_namespace n on n.oid = c.relnamespace and n.nspname = t.schemaname
where t.pubname = 'supabase_realtime' and t.schemaname = 'public';
insert into _r (check_name, ok, detail)
select 'the secret tables are not published to Realtime', count(*) = 0, string_agg(tablename, ',')
from pg_publication_tables where pubname = 'supabase_realtime'
  and (schemaname = 'internal' or tablename in ('game_seats', 'game_intents'));

select n, check_name, ok, detail from _r order by n;
rollback;
