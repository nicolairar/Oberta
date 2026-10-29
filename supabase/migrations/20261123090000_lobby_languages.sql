-- Lobby languages: a room, a ranked queue, a rating and a leaderboard can be
-- in any language, not only Italian and English. A Japanese phone plays the
-- interface in English (until it is translated) but still finds the Japanese
-- tables; everyone also sees the Italian and English ones (client side).
--
-- The code is ISO 639-1, lower case, checked against the full list (the same
-- list as lib/l10n/lobby_language.dart). Idempotent: the checks are replaced
-- by name, and the functions are patched only where they still say 'it'/'en'.
--
-- RLS is unchanged: the same tables, the same grants, the same policies;
-- only the value check widens.

create or replace function internal.lobby_languages()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select '{
    aa,ab,ae,af,ak,am,an,ar,as,av,ay,az,ba,be,bg,bi,bm,bn,bo,br,
    bs,ca,ce,ch,co,cr,cs,cu,cv,cy,da,de,dv,dz,ee,el,en,eo,es,et,
    eu,fa,ff,fi,fj,fo,fr,fy,ga,gd,gl,gn,gu,gv,ha,he,hi,ho,hr,ht,
    hu,hy,hz,ia,id,ie,ig,ii,ik,io,is,it,iu,ja,jv,ka,kg,ki,kj,kk,
    kl,km,kn,ko,kr,ks,ku,kv,kw,ky,la,lb,lg,li,ln,lo,lt,lu,lv,mg,
    mh,mi,mk,ml,mn,mr,ms,mt,my,na,nb,nd,ne,ng,nl,nn,no,nr,nv,ny,
    oc,oj,om,or,os,pa,pi,pl,ps,pt,qu,rm,rn,ro,ru,rw,sa,sc,sd,se,
    sg,si,sk,sl,sm,sn,so,sq,sr,ss,st,su,sv,sw,ta,te,tg,th,ti,tk,
    tl,tn,to,tr,ts,tt,tw,ty,ug,uk,ur,uz,ve,vi,vo,wa,wo,xh,yi,yo,
    za,zh,zu
  }'::text[]
$$;

create or replace function internal.is_lobby_language(code text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select code is not null and code = any (internal.lobby_languages())
$$;
revoke all on function internal.lobby_languages() from public, anon, authenticated;
revoke all on function internal.is_lobby_language(text) from public, anon, authenticated;

-- The column checks. Constraints evaluate as the writing role, so they carry
-- the list inline instead of calling into the internal schema.
do $migration$
declare
  target record;
  old record;
begin
  for target in
    select * from (values
      ('public', 'profiles'),
      ('public', 'rooms'),
      ('public', 'ratings'),
      ('internal', 'ranked_queue'),
      ('internal', 'leaderboard_cache')
    ) as t(schema_name, table_name)
  loop
    for old in
      select c.conname
      from pg_constraint c
      join pg_class r on r.oid = c.conrelid
      join pg_namespace n on n.oid = r.relnamespace
      where n.nspname = target.schema_name and r.relname = target.table_name and c.contype = 'c'
        and pg_get_constraintdef(c.oid) like '%language%'
        and c.conname <> target.table_name || '_language_iso639_1'
    loop
      execute format('alter table %I.%I drop constraint %I', target.schema_name, target.table_name, old.conname);
    end loop;
    execute format('alter table %I.%I drop constraint if exists %I', target.schema_name, target.table_name,
      target.table_name || '_language_iso639_1');
    execute format('alter table %I.%I add constraint %I check (language = any (%L::text[]))',
      target.schema_name, target.table_name, target.table_name || '_language_iso639_1',
      internal.lobby_languages()::text);
  end loop;
end
$migration$;

-- The functions that accepted only 'it' and 'en'. Each is patched in place
-- (pg_get_functiondef), so a newer body written by another migration keeps
-- everything else; grants survive create or replace.
do $migration$
declare
  patch record;
  def text;
begin
  for patch in
    select * from (values
      ('public.create_room(text)', 'room_language not in (''it'', ''en'')', 'not internal.is_lobby_language(room_language)'),
      ('public.enqueue_ranked(text)', 'queue_language not in (''it'', ''en'')', 'not internal.is_lobby_language(queue_language)'),
      ('public.leaderboard(text)', 'board_language not in (''it'', ''en'')', 'not internal.is_lobby_language(board_language)')
    ) as p(fn, old_text, new_text)
  loop
    def := pg_get_functiondef(patch.fn::regprocedure);
    if position(patch.old_text in def) > 0 then
      execute replace(def, patch.old_text, patch.new_text);
    elsif position(patch.new_text in def) = 0 then
      raise exception 'lobby languages: % has neither the old nor the new language check', patch.fn;
    end if;
  end loop;
end
$migration$;

-- Players queued per language, for every language with somebody in it.
create or replace function public.online_counts()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  cached internal.online_counts_cache;
  fresh jsonb;
begin
  select * into cached from internal.online_counts_cache where id;
  if found and cached.computed_at > now() - interval '30 seconds' then
    return cached.counts;
  end if;
  -- Only one caller recomputes; the others get the last numbers.
  if not pg_try_advisory_xact_lock(hashtext('oberta.online_counts')) then
    return coalesce(cached.counts, '{"online": 0, "queued": {}}'::jsonb);
  end if;
  select jsonb_build_object(
    'online', (
      select count(distinct p) from (
        select profile_id as p from internal.ranked_queue
        union all
        select m.profile_id from public.room_members m join public.rooms r on r.id = m.room_id
        where m.left_at is null and r.status = 'lobby' and m.joined_at > now() - interval '30 minutes'
        union all
        select profile_id from public.game_seats
        where profile_id is not null and last_seen > now() - interval '2 minutes'
      ) people
    ),
    'queued', coalesce(
      (select jsonb_object_agg(q.language, q.n)
       from (select language, count(*) as n from internal.ranked_queue group by language) q),
      '{}'::jsonb
    )
  ) into fresh;
  insert into internal.online_counts_cache (id, counts, computed_at) values (true, fresh, now())
  on conflict (id) do update set counts = excluded.counts, computed_at = excluded.computed_at;
  return fresh;
end;
$$;
revoke all on function public.online_counts() from public, anon;
grant execute on function public.online_counts() to authenticated;
