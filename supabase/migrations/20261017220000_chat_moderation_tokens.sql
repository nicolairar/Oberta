-- Chat moderation per word: 'contains' words are matched inside each
-- whitespace-separated token, not across the whole message with the spaces
-- stripped ("qualcun tra voi" is not "cunt"). A word spelled over two or
-- three whole tokens still counts ("porca madonna"). Words that are normal game
-- talk stay reserved for handles but are allowed in chat.

update public.reserved_words set in_chat = false
where word in ('uccidi', 'ucciditi', 'ammazza', 'killthe', 'killall', 'deathto', 'morteai', 'morteagli');

create or replace function public._chat_blocked(body text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.reserved_words as w,
         regexp_split_to_table(body, '\s+') as token,
         public._handle_forms(token) as f
    where w.in_chat and w.match = 'contains'
      and position(regexp_replace(w.word, '(.)\1+', '\1', 'g') in f.collapsed) > 0
  ) or exists (
    with tokens as (
      select t.token, t.n
      from regexp_split_to_table(body, '\s+') with ordinality as t (token, n)
    ), spans as (
      select a.token || b.token as joined
      from tokens a join tokens b on b.n = a.n + 1
      union all
      select a.token || b.token || c.token
      from tokens a join tokens b on b.n = a.n + 1 join tokens c on c.n = a.n + 2
    )
    select 1
    from public.reserved_words as w, spans as s, public._handle_forms(s.joined) as f
    where w.in_chat and w.match = 'contains'
      and f.collapsed = regexp_replace(w.word, '(.)\1+', '\1', 'g')
  ) or exists (
    select 1
    from public.reserved_words as w,
         regexp_split_to_table(body, '\s+') as token,
         public._handle_forms(token) as f
    where w.in_chat and w.match = 'exact' and f.plain = w.word
  );
$$;
revoke all on function public._chat_blocked(text) from public, anon, authenticated;
