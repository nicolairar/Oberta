-- More choices in the barber's mirror: eight head shapes, twelve eye cuts,
-- eight iris colours, ten brows, ten noses, twelve mouths (two painted),
-- twenty-four hairstyles, twelve hair colours, more skin details, and two new
-- optional make-up keys: lips (lipstick) and shadow (eyeshadow or liner).
-- Every id of the first version is still valid, so saved faces read the same.

create or replace function public.save_face(p_face jsonb, p_tone text, p_mark text default null)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  allowed constant jsonb := jsonb_build_object(
    'shape', jsonb_build_array('oval', 'round', 'square', 'long', 'heart', 'diamond', 'pear', 'chiselled'),
    'eyes', jsonb_build_array('almond', 'round', 'hooded', 'narrow', 'upturned', 'downturned', 'monolid', 'sleepy', 'wide', 'catEye', 'deepSet', 'doe'),
    'eyeColor', jsonb_build_array('dark', 'brown', 'hazel', 'amber', 'green', 'teal', 'blue', 'grey'),
    'brows', jsonb_build_array('straight', 'arched', 'thick', 'thin', 'angled', 'rounded', 'bushy', 'pencil', 'sloped', 'furrowed'),
    'nose', jsonb_build_array('straight', 'button', 'roman', 'broad', 'pointed', 'snub', 'wide', 'crooked', 'small', 'long'),
    'mouth', jsonb_build_array('neutral', 'smile', 'smirk', 'full', 'thin', 'stern', 'grin', 'pout', 'cupid', 'wide', 'lipstick', 'lipstickSmile'),
    'hair', jsonb_build_array('bald', 'slicked', 'sidePart', 'crewCut', 'curly', 'wavy', 'afro', 'bun', 'bob', 'long', 'pompadour', 'quiff', 'ducktail', 'flatTop', 'middlePart', 'receding', 'coils', 'fingerWaves', 'victoryRolls', 'pinCurls', 'pageboy', 'ponytail', 'braids', 'updo'),
    'hairColor', jsonb_build_array('black', 'darkBrown', 'brown', 'chestnut', 'blonde', 'platinum', 'strawberry', 'red', 'auburn', 'saltPepper', 'grey', 'white'),
    'detail', jsonb_build_array('none', 'freckles', 'beautyMark', 'scar', 'dimples', 'rosyCheeks', 'cheekScar', 'mole'),
    'age', jsonb_build_array('none', 'lines', 'deep'),
    'lips', jsonb_build_array('none', 'red', 'crimson', 'coral', 'rose', 'plum', 'wine'),
    'shadow', jsonb_build_array('none', 'liner', 'smoky', 'bronze', 'rose', 'teal', 'plum')
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
