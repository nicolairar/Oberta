-- One name per player: the handle. The separate display name goes, so
-- nobody can sit at a table looking like someone else.
--
-- Handles become Instagram-style: lowercase letters, digits, "_" and ".",
-- 3 to 12 characters, unique whatever the case. They start with a letter or
-- a digit, never end with a dot, never have two dots in a row and never more
-- than three symbols in a row. Names that offend (hate, slurs, racism,
-- homophobia, sex, bullying, Nazi references) or pose as staff are refused,
-- after undoing leetspeak and separators. The word list lives in
-- reserved_words; the app keeps a mirror for instant feedback
-- (lib/online/reserved_words.dart), and a test keeps the two equal.
-- Names that look like bots ("bot.alfa", "bot_1", "b0t...") belong to bots.

alter table public.profiles drop column if exists display_name;

-- Drop the old handle check, whatever name it was given.
do $$
declare
  old record;
begin
  for old in
    select conname from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%handle%'
  loop
    execute format('alter table public.profiles drop constraint %I', old.conname);
  end loop;
end;
$$;

create table if not exists public.reserved_words (
  word text primary key check (word ~ '^[a-z]+$'),
  lang text not null check (lang in ('it', 'en', 'any')),
  -- 'contains': refused anywhere in the name; 'exact': only as the whole name.
  match text not null check (match in ('contains', 'exact'))
);

-- Nobody reads the list from the app: only the functions below do.
alter table public.reserved_words enable row level security;
revoke all on public.reserved_words from anon, authenticated;

-- Keep in sync with lib/online/reserved_words.dart (test/online/handle_rules_test.dart checks).
insert into public.reserved_words (word, lang, match) values
  ('admin', 'any', 'exact'),
  ('administrator', 'en', 'contains'),
  ('amministratore', 'it', 'contains'),
  ('moderator', 'en', 'contains'),
  ('moderatore', 'it', 'contains'),
  ('mod', 'any', 'exact'),
  ('oberta', 'any', 'exact'),
  ('omerta', 'any', 'exact'),
  ('support', 'en', 'contains'),
  ('supporto', 'it', 'contains'),
  ('assistenza', 'it', 'contains'),
  ('staff', 'any', 'contains'),
  ('official', 'en', 'contains'),
  ('ufficiale', 'it', 'contains'),
  ('narrator', 'en', 'contains'),
  ('narratore', 'it', 'contains'),
  ('system', 'en', 'exact'),
  ('sistema', 'it', 'exact'),
  ('root', 'any', 'exact'),
  ('bot', 'any', 'exact'),
  ('anthropic', 'any', 'contains'),
  ('hitler', 'any', 'contains'),
  ('nazi', 'any', 'exact'),
  ('neonazi', 'any', 'contains'),
  ('naziskin', 'any', 'contains'),
  ('heil', 'any', 'exact'),
  ('siegheil', 'any', 'contains'),
  ('heilhitler', 'any', 'contains'),
  ('gestapo', 'any', 'contains'),
  ('auschwitz', 'any', 'contains'),
  ('holocaust', 'en', 'contains'),
  ('olocausto', 'it', 'contains'),
  ('whitepower', 'en', 'contains'),
  ('kkk', 'any', 'exact'),
  ('kukluxklan', 'any', 'contains'),
  ('mussolini', 'it', 'contains'),
  ('duce', 'it', 'exact'),
  ('fascio', 'it', 'exact'),
  ('fascista', 'it', 'contains'),
  ('nigger', 'en', 'contains'),
  ('nigga', 'en', 'contains'),
  ('negro', 'any', 'exact'),
  ('negri', 'it', 'exact'),
  ('negra', 'it', 'exact'),
  ('kike', 'en', 'exact'),
  ('chink', 'en', 'contains'),
  ('spic', 'en', 'exact'),
  ('wetback', 'en', 'contains'),
  ('coon', 'en', 'exact'),
  ('paki', 'en', 'exact'),
  ('zingaro', 'it', 'contains'),
  ('zingari', 'it', 'contains'),
  ('terrone', 'it', 'contains'),
  ('terroni', 'it', 'contains'),
  ('polentone', 'it', 'contains'),
  ('muslimdog', 'en', 'contains'),
  ('faggot', 'en', 'contains'),
  ('fag', 'en', 'exact'),
  ('dyke', 'en', 'exact'),
  ('tranny', 'en', 'contains'),
  ('frocio', 'it', 'contains'),
  ('froci', 'it', 'contains'),
  ('frocia', 'it', 'contains'),
  ('ricchione', 'it', 'contains'),
  ('recchione', 'it', 'contains'),
  ('culattone', 'it', 'contains'),
  ('finocchio', 'it', 'exact'),
  ('checca', 'it', 'exact'),
  ('retard', 'en', 'contains'),
  ('ritardato', 'it', 'contains'),
  ('mongoloide', 'it', 'contains'),
  ('handicappato', 'it', 'contains'),
  ('spastic', 'en', 'contains'),
  ('killyourself', 'en', 'contains'),
  ('kys', 'en', 'exact'),
  ('killthe', 'en', 'contains'),
  ('killall', 'en', 'contains'),
  ('killjews', 'en', 'contains'),
  ('killgays', 'en', 'contains'),
  ('killblacks', 'en', 'contains'),
  ('killmuslims', 'en', 'contains'),
  ('killwomen', 'en', 'contains'),
  ('deathto', 'en', 'contains'),
  ('uccidi', 'it', 'contains'),
  ('ucciditi', 'it', 'contains'),
  ('ammazza', 'it', 'contains'),
  ('suicidati', 'it', 'contains'),
  ('morteai', 'it', 'contains'),
  ('morteagli', 'it', 'contains'),
  ('rapist', 'en', 'exact'),
  ('rape', 'en', 'exact'),
  ('stupro', 'it', 'contains'),
  ('stupratore', 'it', 'contains'),
  ('pedophile', 'en', 'contains'),
  ('paedophile', 'en', 'contains'),
  ('pedo', 'any', 'exact'),
  ('pedofilo', 'it', 'contains'),
  ('molester', 'en', 'contains'),
  ('ciccione', 'it', 'contains'),
  ('fatass', 'en', 'contains'),
  ('fuck', 'en', 'contains'),
  ('shit', 'en', 'contains'),
  ('bitch', 'en', 'contains'),
  ('cunt', 'en', 'contains'),
  ('whore', 'en', 'contains'),
  ('slut', 'en', 'contains'),
  ('asshole', 'en', 'contains'),
  ('bastard', 'en', 'contains'),
  ('motherfucker', 'en', 'contains'),
  ('dick', 'en', 'exact'),
  ('cock', 'en', 'exact'),
  ('pussy', 'en', 'contains'),
  ('penis', 'en', 'exact'),
  ('vagina', 'any', 'contains'),
  ('porn', 'any', 'contains'),
  ('hentai', 'any', 'contains'),
  ('milf', 'any', 'contains'),
  ('dildo', 'any', 'contains'),
  ('blowjob', 'en', 'contains'),
  ('sex', 'any', 'exact'),
  ('cazzo', 'it', 'contains'),
  ('minchia', 'it', 'contains'),
  ('coglione', 'it', 'contains'),
  ('stronzo', 'it', 'contains'),
  ('stronza', 'it', 'contains'),
  ('puttana', 'it', 'contains'),
  ('troia', 'it', 'exact'),
  ('zoccola', 'it', 'contains'),
  ('mignotta', 'it', 'contains'),
  ('vaffanculo', 'it', 'contains'),
  ('fanculo', 'it', 'contains'),
  ('merda', 'it', 'contains'),
  ('pompino', 'it', 'contains'),
  ('figa', 'it', 'exact'),
  ('fica', 'it', 'exact'),
  ('pene', 'it', 'exact'),
  ('tette', 'it', 'exact'),
  ('scopare', 'it', 'contains'),
  ('porcodio', 'it', 'contains'),
  ('diocane', 'it', 'contains'),
  ('dioporco', 'it', 'contains'),
  ('porcamadonna', 'it', 'contains'),
  ('madonnaputtana', 'it', 'contains')
on conflict (word) do update set lang = excluded.lang, match = excluded.match;

-- The forms a handle is checked in: lowercase, leetspeak undone (0>o, 1>i
-- or l, 3>e, 4>a, 5>s, 7>t, @>a, $>s), anything but letters removed; each
-- as is ("plain") and with repeated letters collapsed ("collapsed").
create or replace function public._handle_forms(h text)
returns table (plain text, collapsed text)
language sql
immutable
set search_path = ''
as $$
  select distinct s.p, regexp_replace(s.p, '(.)\1+', '\1', 'g')
  from (
    select regexp_replace(translate(lower(h), v.f, v.t), '[^a-z]', '', 'g') as p
    from (values ('013457@$', 'oieastas'), ('013457@$', 'oleastas')) as v (f, t)
  ) as s;
$$;

revoke all on function public._handle_forms(text) from public, anon, authenticated;

-- True when a handle is reserved: bot-like, or containing a reserved word.
-- 'exact' words compare with the whole name as typed (so "mood" is not
-- "mod"); 'contains' words anywhere, with repeated letters collapsed.
create or replace function public._handle_blocked(h text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select h ~ '^b[o0]t([._0-9]|$)'
    or exists (
      select 1
      from public.reserved_words as w, public._handle_forms(h) as f
      where (w.match = 'exact' and f.plain = w.word)
         or (w.match = 'contains'
             and position(regexp_replace(w.word, '(.)\1+', '\1', 'g') in f.collapsed) > 0)
    );
$$;

revoke all on function public._handle_blocked(text) from public, anon, authenticated;

-- Handles that no longer fit go back to empty: those players pick a new one
-- at their next sign-in.
update public.profiles
set handle = null
where handle is not null
  and (handle !~ '^[a-z0-9][a-z0-9._]{2,11}$'
       or handle ~ '\.$'
       or handle ~ '\.\.'
       or handle ~ '[._]{4}'
       or public._handle_blocked(handle));

alter table public.profiles
  add constraint profiles_handle_check check (
    handle ~ '^[a-z0-9][a-z0-9._]{2,11}$'
    and handle !~ '\.$'
    and handle !~ '\.\.'
    and handle !~ '[._]{4}'
  );

create or replace function public._check_handle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.handle is not null
     and (tg_op = 'INSERT' or new.handle is distinct from old.handle)
     and public._handle_blocked(new.handle) then
    raise exception 'handle_not_allowed';
  end if;
  return new;
end;
$$;

revoke all on function public._check_handle() from public, anon, authenticated;

drop trigger if exists profiles_handle_allowed on public.profiles;
create trigger profiles_handle_allowed
  before insert or update of handle on public.profiles
  for each row execute function public._check_handle();

-- The public columns, without the display name; clients still write only
-- handle and language.
revoke select on public.profiles from authenticated;
grant select (id, handle, language, avatar, created_at) on public.profiles to authenticated;
revoke update on public.profiles from authenticated;
grant update (handle, language) on public.profiles to authenticated;
