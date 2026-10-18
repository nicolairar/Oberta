-- The barber's mirror asks first how one presents (man, woman, other): a free
-- face key `presentation` that save_face now accepts. Five free women's
-- outfits (dresses and blouses). Two new paid slots: `hairdo` (extravagant
-- hairstyles that cover the free hair while worn) and `tattoo` (sailor-style
-- tattoos where the skin shows). Each has a free `none` piece, like glasses.

alter table public.shop_items drop constraint if exists shop_items_slot_check;
alter table public.shop_items add constraint shop_items_slot_check
  check (slot in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo'));

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort) values
  ('outfit.rose_dress', 'outfit', 'rose_dress', 'base', 0, 'Abito rosa antico', 'Dusty rose dress', '2026-10-19', 411),
  ('outfit.black_dress', 'outfit', 'black_dress', 'base', 0, 'Tubino nero', 'Little black dress', '2026-10-19', 412),
  ('outfit.emerald_dress', 'outfit', 'emerald_dress', 'base', 0, 'Abito smeraldo', 'Emerald dress', '2026-10-19', 413),
  ('outfit.ivory_blouse', 'outfit', 'ivory_blouse', 'base', 0, 'Camicetta avorio', 'Ivory blouse', '2026-10-19', 414),
  ('outfit.powder_blouse', 'outfit', 'powder_blouse', 'base', 0, 'Camicetta celeste', 'Powder blue blouse', '2026-10-19', 415),
  ('hairdo.none', 'hairdo', 'none', 'base', 0, 'I tuoi capelli', 'Your own hair', '2026-10-19', 600),
  ('hairdo.beehive', 'hairdo', 'beehive', 'epico', 1100, 'Alveare gigante', 'Giant beehive', '2026-10-19', 601),
  ('hairdo.punkSpikes', 'hairdo', 'punkSpikes', 'epico', 1100, 'Creste punk al neon', 'Neon-pink punk spikes', '2026-10-19', 602),
  ('hairdo.spaceBuns', 'hairdo', 'spaceBuns', 'raro', 700, 'Due chignon spaziali', 'Double space buns', '2026-10-19', 603),
  ('hairdo.toweringPompadour', 'hairdo', 'toweringPompadour', 'epico', 1100, 'Ciuffo a torre col ricciolo', 'Towering pompadour with a curl', '2026-10-19', 604),
  ('hairdo.flowerCrown', 'hairdo', 'flowerCrown', 'raro', 700, 'Corona di trecce e fiori', 'Braided crown with flowers', '2026-10-19', 605),
  ('hairdo.mermaidWaves', 'hairdo', 'mermaidWaves', 'epico', 1100, 'Onde da sirena ghiaccio', 'Ice-blue mermaid waves', '2026-10-19', 606),
  ('hairdo.flameBouffant', 'hairdo', 'flameBouffant', 'epico', 1100, 'Cotonatura rosso fiamma', 'Flame-red bouffant', '2026-10-19', 607),
  ('hairdo.glitterAfro', 'hairdo', 'glitterAfro', 'leggendario', 1800, 'Afro di brillantini', 'Glitter afro', '2026-10-19', 608),
  ('hairdo.samuraiTopknot', 'hairdo', 'samuraiTopknot', 'raro', 700, 'Codino da samurai', 'Samurai topknot', '2026-10-19', 609),
  ('hairdo.stripedUndercut', 'hairdo', 'stripedUndercut', 'raro', 700, 'Rasato a strisce', 'Striped undercut', '2026-10-19', 610),
  ('hairdo.rainbowPonytail', 'hairdo', 'rainbowPonytail', 'leggendario', 1800, 'Coda arcobaleno lunghissima', 'Extra-long rainbow ponytail', '2026-10-19', 611),
  ('hairdo.birdNestMane', 'hairdo', 'birdNestMane', 'leggendario', 1800, 'Criniera con uccellino', 'Curly mane with a hidden bird', '2026-10-19', 612),
  ('tattoo.none', 'tattoo', 'none', 'base', 0, 'Pelle pulita', 'No tattoo', '2026-10-19', 700),
  ('tattoo.anchor', 'tattoo', 'anchor', 'comune', 350, 'Ancora', 'Anchor', '2026-10-19', 701),
  ('tattoo.swallow', 'tattoo', 'swallow', 'comune', 350, 'Rondine', 'Swallow', '2026-10-19', 702),
  ('tattoo.roseDagger', 'tattoo', 'roseDagger', 'raro', 700, 'Rosa e pugnale', 'Rose and dagger', '2026-10-19', 703),
  ('tattoo.mammaHeart', 'tattoo', 'mammaHeart', 'raro', 700, 'Cuore MAMMA', 'MAMMA heart banner', '2026-10-19', 704),
  ('tattoo.spiderWeb', 'tattoo', 'spiderWeb', 'epico', 1100, 'Ragnatela sul collo', 'Spider web on the neck', '2026-10-19', 705),
  ('tattoo.teardrop', 'tattoo', 'teardrop', 'comune', 350, 'Lacrima', 'Teardrop', '2026-10-19', 706),
  ('tattoo.cheekStar', 'tattoo', 'cheekStar', 'comune', 350, 'Stellina sulla guancia', 'Star on the cheek', '2026-10-19', 707),
  ('tattoo.koi', 'tattoo', 'koi', 'epico', 1100, 'Carpa koi sul collo', 'Koi on the neck', '2026-10-19', 708),
  ('tattoo.playingCards', 'tattoo', 'playingCards', 'raro', 700, 'Carte da gioco', 'Playing cards', '2026-10-19', 709),
  ('tattoo.skullTopHat', 'tattoo', 'skullTopHat', 'raro', 700, 'Teschio col cilindro', 'Skull in a top hat', '2026-10-19', 710),
  ('tattoo.familyCrest', 'tattoo', 'familyCrest', 'epico', 1100, 'Stemma di famiglia', 'Family crest', '2026-10-19', 711)
on conflict (id) do nothing;

create or replace function public.unequip_slot(p_slot text, p_tone text default null, p_current jsonb default null)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  current jsonb;
  tone text;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if p_slot not in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo') then
    raise exception 'bad_slot';
  end if;
  select avatar into current from public.profiles where id = me for update;
  current := coalesce(p_current, '{}'::jsonb) || coalesce(current, '{}'::jsonb);
  if p_slot = 'face' then
    tone := public.avatar_tone(current, p_tone);
    if tone is not null then
      update public.profiles set avatar = current || jsonb_build_object('base', tone || '_clean') where id = me;
    end if;
  else
    update public.profiles set avatar = current - p_slot where id = me;
  end if;
  return query select * from public.profiles where id = me;
end;
$$;

revoke all on function public.unequip_slot(text, text, jsonb) from public, anon;
grant execute on function public.unequip_slot(text, text, jsonb) to authenticated;

-- save_face: the same checks as face_options, plus the free `presentation`.
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
    'shadow', jsonb_build_array('none', 'liner', 'smoky', 'bronze', 'rose', 'teal', 'plum'),
    'presentation', jsonb_build_array('other', 'man', 'woman')
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
