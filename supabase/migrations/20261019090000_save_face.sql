-- The barber's mirror: free face features (skin, head shape, eyes, brows,
-- nose, mouth, hair, details, age) saved into profiles.avatar as flat keys
-- next to the shop slots. Four more skin tones join the six of the shop.

create or replace function public.avatar_tone(p_avatar jsonb, p_tone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_avatar ->> 'base', '_', 1) in
      ('porcelain', 'rose', 'olive', 'tan', 'umber', 'ebony', 'ivory', 'honey', 'sienna', 'espresso')
      then split_part(p_avatar ->> 'base', '_', 1)
    when p_tone in ('porcelain', 'rose', 'olive', 'tan', 'umber', 'ebony', 'ivory', 'honey', 'sienna', 'espresso')
      then p_tone
  end;
$$;

revoke all on function public.avatar_tone(jsonb, text) from public, anon, authenticated;

-- Saves the face. Only the free feature keys and the skin tone move: hats,
-- glasses, outfits, accessories and paid moustaches stay as saved. p_mark is
-- the free moustache/mark the app shows for players who never saved a face;
-- a saved mark always wins, and an unsaved one must be a free base item.
create or replace function public.save_face(p_face jsonb, p_tone text, p_mark text default null)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  allowed constant jsonb := jsonb_build_object(
    'shape', jsonb_build_array('oval', 'round', 'square', 'long', 'heart'),
    'eyes', jsonb_build_array('almond', 'round', 'hooded', 'narrow', 'upturned', 'downturned'),
    'eyeColor', jsonb_build_array('dark', 'brown', 'hazel', 'green', 'blue', 'grey'),
    'brows', jsonb_build_array('straight', 'arched', 'thick', 'thin', 'angled'),
    'nose', jsonb_build_array('straight', 'button', 'roman', 'broad', 'pointed'),
    'mouth', jsonb_build_array('neutral', 'smile', 'smirk', 'full', 'thin', 'stern'),
    'hair', jsonb_build_array('bald', 'slicked', 'sidePart', 'crewCut', 'curly', 'wavy', 'afro', 'bun', 'bob', 'long'),
    'hairColor', jsonb_build_array('black', 'darkBrown', 'brown', 'blonde', 'red', 'auburn', 'grey', 'white'),
    'detail', jsonb_build_array('none', 'freckles', 'beautyMark', 'scar'),
    'age', jsonb_build_array('none', 'lines', 'deep')
  );
  entry record;
  current jsonb;
  mark text;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if p_face is null or jsonb_typeof(p_face) <> 'object' then
    raise exception 'bad_face';
  end if;
  for entry in select key, value from jsonb_each(p_face) loop
    if not (allowed ? entry.key)
       or jsonb_typeof(entry.value) <> 'string'
       or not ((allowed -> entry.key) @> jsonb_build_array(entry.value)) then
      raise exception 'bad_face';
    end if;
  end loop;
  if p_tone is null
     or p_tone not in ('porcelain', 'rose', 'olive', 'tan', 'umber', 'ebony', 'ivory', 'honey', 'sienna', 'espresso') then
    raise exception 'bad_face';
  end if;

  select coalesce(avatar, '{}'::jsonb) into current from public.profiles where id = me for update;
  if current ? 'base' and position('_' in current ->> 'base') > 0 then
    mark := substr(current ->> 'base', position('_' in current ->> 'base') + 1);
  elsif p_mark is not null
     and exists (select 1 from public.shop_items where slot = 'face' and look_id = p_mark and rarity = 'base') then
    mark := p_mark;
  else
    mark := 'clean';
  end if;

  update public.profiles
     set avatar = current || p_face || jsonb_build_object('base', p_tone || '_' || mark)
   where id = me;
  return query select * from public.profiles where id = me;
end;
$$;

revoke all on function public.save_face(jsonb, text, text) from public, anon;
grant execute on function public.save_face(jsonb, text, text) to authenticated;
