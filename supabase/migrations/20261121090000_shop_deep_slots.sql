-- The dearest shelf: eight new slots around and on the portrait, the top
-- tier of the shop.
--
--   aura        a whole scene behind the player (legendary, 3000: a full
--               picture, dearer than any legendary before)
--   back        what sits on the shoulders; the four pairs of wings move
--               here from `accessory`
--   headFx      an effect over the head, or a glow round its outline
--   faceExtras  marks on the face, up to two at once: avatar.faceExtras is
--               `blush+tear`, equip_item toggles one in or out
--   eyeShine    a shine over the pupils
--   hairDye     a two-tone dye over the free hair
--   held        something in a hand: one catalogue item, worn under
--               avatar.heldL or avatar.heldR (equip_item's new p_hand); the
--               cat and the teddy take both hands
--   frontFx     an effect in front of everything
--
-- Each slot has a free `none` piece, owned by everyone. Prices: rarity
-- still fixes comune and raro; epico now spans 1100-1799 and leggendario
-- 1800-5000, so the deep pieces sit above the old ones of their class.
--
-- The wings: accessory.<wing> rows stay (disabled, the coin ledger points at
-- them); back.<wing> replaces them in the catalogue, every inventory, the
-- window, the Heaven and Hell bundle and every saved avatar.
--
-- equip_item and unequip_slot learn the new slots, and the look the app
-- sends underneath the saved one (p_current) now keeps only pieces the
-- player owns: nothing unpaid is ever saved. Purchases still go through
-- buy_item and buy_bundle only; tables keep their RLS and grants. The CLI
-- applies the file in one transaction; re-running is harmless.

alter table public.shop_items drop constraint if exists shop_items_slot_check;
alter table public.shop_items add constraint shop_items_slot_check
  check (slot in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo', 'border', 'nameStyle', 'gesture',
                  'aura', 'back', 'headFx', 'faceExtras', 'eyeShine', 'hairDye', 'held', 'frontFx'));

-- The price rule: replace the fixed price per rarity (an unnamed check from
-- the first shop migration) with one that lets the deep pieces cost more.
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.shop_items'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%price_coins%'
  loop
    execute format('alter table public.shop_items drop constraint %I', c.conname);
  end loop;
end;
$$;
alter table public.shop_items add constraint shop_items_price_check check (case rarity
  when 'base' then price_coins = 0
  when 'comune' then price_coins = 350
  when 'raro' then price_coins = 700
  when 'epico' then price_coins between 1100 and 1799
  when 'leggendario' then price_coins between 1800 and 5000
end);

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand, collection) values
  ('aura.none', 'aura', 'none', 'base', 0, 'Nessuna scena', 'No scene', '2026-11-20', 1000, null, null),
  ('aura.inferno', 'aura', 'inferno', 'leggendario', 3000, 'Fiamme dell''inferno', 'Hellfire', '2026-11-20', 1001, null, null),
  ('aura.harbourMoon', 'aura', 'harbourMoon', 'leggendario', 3000, 'Luna sul porto', 'Moon over the harbour', '2026-11-20', 1002, null, null),
  ('aura.sunburst', 'aura', 'sunburst', 'leggendario', 3000, 'Raggiera déco', 'Deco sunburst', '2026-11-20', 1003, null, null),
  ('aura.neonAlley', 'aura', 'neonAlley', 'leggendario', 3000, 'Vicolo al neon', 'Neon alley', '2026-11-20', 1004, null, null),
  ('aura.cardRoomSmoke', 'aura', 'cardRoomSmoke', 'leggendario', 3000, 'Fumo della bisca', 'Card-room smoke', '2026-11-20', 1005, null, null),
  ('aura.varietyCurtain', 'aura', 'varietyCurtain', 'leggendario', 3000, 'Sipario del varietà', 'Variety curtain', '2026-11-20', 1006, null, null),
  ('aura.vault', 'aura', 'vault', 'leggendario', 3000, 'Il caveau', 'The vault', '2026-11-20', 1007, null, null),
  ('aura.vesuvio', 'aura', 'vesuvio', 'leggendario', 3000, 'Vesuvio al tramonto', 'Vesuvius at sunset', '2026-11-20', 1008, null, null),
  ('aura.spaghettiStorm', 'aura', 'spaghettiStorm', 'leggendario', 3000, 'Tempesta di spaghetti', 'Spaghetti storm', '2026-11-20', 1009, null, null),
  ('back.none', 'back', 'none', 'base', 0, 'Spalle libere', 'Nothing on the back', '2026-11-20', 1100, null, null),
  ('back.violinCase', 'back', 'violinCase', 'leggendario', 2400, 'Custodia da violino', 'Violin case', '2026-11-20', 1101, null, null),
  ('back.gildedWings', 'back', 'gildedWings', 'leggendario', 2400, 'Ali dorate déco', 'Gilded deco wings', '2026-11-20', 1102, null, null),
  ('back.skeleton', 'back', 'skeleton', 'leggendario', 2400, 'Scheletro nell''armadio', 'Skeleton in the closet', '2026-11-20', 1103, null, null),
  ('back.parasol', 'back', 'parasol', 'leggendario', 2400, 'Parasole di pizzo', 'Lace parasol', '2026-11-20', 1104, null, null),
  ('back.saxophone', 'back', 'saxophone', 'leggendario', 2400, 'Sassofono del night', 'Nightclub saxophone', '2026-11-20', 1105, null, null),
  ('headFx.none', 'headFx', 'none', 'base', 0, 'Niente in testa', 'Nothing overhead', '2026-11-20', 1200, null, null),
  ('headFx.halo', 'headFx', 'halo', 'leggendario', 2200, 'Aureola del santo', 'Saint''s halo', '2026-11-20', 1201, null, null),
  ('headFx.starOrbit', 'headFx', 'starOrbit', 'leggendario', 2200, 'Giro di stelle', 'Ring of stars', '2026-11-20', 1202, null, null),
  ('headFx.sparks', 'headFx', 'sparks', 'leggendario', 2200, 'Scintille', 'Sparks', '2026-11-20', 1203, null, null),
  ('headFx.hearts', 'headFx', 'hearts', 'leggendario', 2200, 'Cuori in testa', 'Head over heels', '2026-11-20', 1204, null, null),
  ('headFx.coins', 'headFx', 'coins', 'leggendario', 2200, 'Giro di monete', 'Orbiting coins', '2026-11-20', 1205, null, null),
  ('headFx.rainCloud', 'headFx', 'rainCloud', 'leggendario', 2200, 'Nuvoletta della sfiga', 'Bad-luck cloud', '2026-11-20', 1206, null, null),
  ('headFx.dizzyBirds', 'headFx', 'dizzyBirds', 'leggendario', 2200, 'Uccellini del cazzotto', 'Knockout birdies', '2026-11-20', 1207, null, null),
  ('headFx.ghostGlow', 'headFx', 'ghostGlow', 'leggendario', 2200, 'Alone del fantasma', 'Ghostly glow', '2026-11-20', 1208, null, null),
  ('headFx.emberGlow', 'headFx', 'emberGlow', 'leggendario', 2200, 'Alone di brace', 'Ember glow', '2026-11-20', 1209, null, null),
  ('faceExtras.none', 'faceExtras', 'none', 'base', 0, 'Faccia pulita', 'Clean face', '2026-11-20', 1300, null, null),
  ('faceExtras.blush', 'faceExtras', 'blush', 'epico', 1200, 'Guance rosse', 'Rosy cheeks', '2026-11-20', 1301, null, null),
  ('faceExtras.tear', 'faceExtras', 'tear', 'epico', 1200, 'Lacrima di coccodrillo', 'Crocodile tear', '2026-11-20', 1302, null, null),
  ('faceExtras.stitchScar', 'faceExtras', 'stitchScar', 'epico', 1200, 'Cicatrice cucita', 'Stitched scar', '2026-11-20', 1303, null, null),
  ('faceExtras.skullPaint', 'faceExtras', 'skullPaint', 'epico', 1200, 'Trucco da teschio', 'Skull paint', '2026-11-20', 1304, null, null),
  ('faceExtras.beautyStar', 'faceExtras', 'beautyStar', 'epico', 1200, 'Neo a stella', 'Star beauty mark', '2026-11-20', 1305, null, null),
  ('faceExtras.goldTooth', 'faceExtras', 'goldTooth', 'epico', 1200, 'Dente d''oro', 'Gold tooth', '2026-11-20', 1306, null, null),
  ('faceExtras.blackEye', 'faceExtras', 'blackEye', 'epico', 1200, 'Occhio nero', 'Black eye', '2026-11-20', 1307, null, null),
  ('faceExtras.lipstickKiss', 'faceExtras', 'lipstickKiss', 'epico', 1200, 'Bacio col rossetto', 'Lipstick kiss', '2026-11-20', 1308, null, null),
  ('faceExtras.plaster', 'faceExtras', 'plaster', 'epico', 1200, 'Cerotto a croce', 'Cross plaster', '2026-11-20', 1309, null, null),
  ('eyeShine.none', 'eyeShine', 'none', 'base', 0, 'Occhi normali', 'Plain eyes', '2026-11-20', 1400, null, null),
  ('eyeShine.glint', 'eyeShine', 'glint', 'epico', 1300, 'Luccichio', 'Glint', '2026-11-20', 1401, null, null),
  ('eyeShine.star', 'eyeShine', 'star', 'epico', 1300, 'Occhi da diva', 'Star-struck', '2026-11-20', 1402, null, null),
  ('eyeShine.heart', 'eyeShine', 'heart', 'epico', 1300, 'Occhi innamorati', 'Love-struck', '2026-11-20', 1403, null, null),
  ('eyeShine.spiral', 'eyeShine', 'spiral', 'epico', 1300, 'Ipnosi', 'Hypnotised', '2026-11-20', 1404, null, null),
  ('eyeShine.lira', 'eyeShine', 'lira', 'epico', 1300, 'Occhi a lire', 'Lira eyes', '2026-11-20', 1405, null, null),
  ('eyeShine.flame', 'eyeShine', 'flame', 'epico', 1300, 'Occhi di fuoco', 'Eyes of fire', '2026-11-20', 1406, null, null),
  ('eyeShine.diamond', 'eyeShine', 'diamond', 'epico', 1300, 'Occhi di brillante', 'Diamond eyes', '2026-11-20', 1407, null, null),
  ('eyeShine.crosshair', 'eyeShine', 'crosshair', 'epico', 1300, 'Occhio da sicario', 'Hitman''s eye', '2026-11-20', 1408, null, null),
  ('hairDye.none', 'hairDye', 'none', 'base', 0, 'Nessuna tinta', 'No dye', '2026-11-20', 1500, null, null),
  ('hairDye.midnight', 'hairDye', 'midnight', 'epico', 1400, 'Tinta mezzanotte', 'Midnight dye', '2026-11-20', 1501, null, null),
  ('hairDye.neonPop', 'hairDye', 'neonPop', 'epico', 1400, 'Tinta neon', 'Neon dye', '2026-11-20', 1502, null, null),
  ('hairDye.sunset', 'hairDye', 'sunset', 'epico', 1400, 'Tinta tramonto', 'Sunset dye', '2026-11-20', 1503, null, null),
  ('hairDye.cherry', 'hairDye', 'cherry', 'epico', 1400, 'Tinta ciliegia', 'Cherry dye', '2026-11-20', 1504, null, null),
  ('hairDye.frost', 'hairDye', 'frost', 'epico', 1400, 'Tinta brina', 'Frost dye', '2026-11-20', 1505, null, null),
  ('hairDye.tricolore', 'hairDye', 'tricolore', 'leggendario', 2000, 'Tinta tricolore', 'Tricolore dye', '2026-11-20', 1506, null, null),
  ('hairDye.goldLeaf', 'hairDye', 'goldLeaf', 'leggendario', 2000, 'Capelli d''oro', 'Golden locks', '2026-11-20', 1507, null, null),
  ('held.none', 'held', 'none', 'base', 0, 'Mani libere', 'Empty hands', '2026-11-20', 1600, null, null),
  ('held.grappa', 'held', 'grappa', 'epico', 1500, 'Bottiglia di grappa', 'Bottle of grappa', '2026-11-20', 1601, null, null),
  ('held.rose', 'held', 'rose', 'epico', 1500, 'Rosa rossa', 'Red rose', '2026-11-20', 1602, null, null),
  ('held.revolver', 'held', 'revolver', 'epico', 1500, 'Rivoltella', 'Revolver', '2026-11-20', 1603, null, null),
  ('held.cards', 'held', 'cards', 'epico', 1500, 'Mano di poker', 'Poker hand', '2026-11-20', 1604, null, null),
  ('held.coupe', 'held', 'coupe', 'epico', 1500, 'Coppa di spumante', 'Glass of bubbly', '2026-11-20', 1605, null, null),
  ('held.candle', 'held', 'candle', 'epico', 1500, 'Candela', 'Candle', '2026-11-20', 1606, null, null),
  ('held.cannolo', 'held', 'cannolo', 'epico', 1500, 'Cannolo gigante', 'Giant cannolo', '2026-11-20', 1607, null, null),
  ('held.moka', 'held', 'moka', 'epico', 1500, 'Moka del caffè', 'Coffee moka', '2026-11-20', 1608, null, null),
  ('held.fish', 'held', 'fish', 'epico', 1500, 'Pesce nel giornale', 'Fish in a newspaper', '2026-11-20', 1609, null, null),
  ('held.cat', 'held', 'cat', 'leggendario', 2400, 'Il gatto del padrino', 'The godfather''s cat', '2026-11-20', 1610, null, null),
  ('held.teddy', 'held', 'teddy', 'leggendario', 2400, 'Orsetto del boss', 'The boss''s teddy', '2026-11-20', 1611, null, null),
  ('frontFx.none', 'frontFx', 'none', 'base', 0, 'Niente davanti', 'Nothing in front', '2026-11-20', 1700, null, null),
  ('frontFx.smokeRings', 'frontFx', 'smokeRings', 'leggendario', 2200, 'Anelli di fumo', 'Smoke rings', '2026-11-20', 1701, null, null),
  ('frontFx.petals', 'frontFx', 'petals', 'leggendario', 2200, 'Petali di rosa', 'Rose petals', '2026-11-20', 1702, null, null),
  ('frontFx.sparkles', 'frontFx', 'sparkles', 'leggendario', 2200, 'Scintillio', 'Twinkles', '2026-11-20', 1703, null, null),
  ('frontFx.bats', 'frontFx', 'bats', 'leggendario', 2200, 'Pipistrelli', 'Bats', '2026-11-20', 1704, null, null),
  ('frontFx.yarn', 'frontFx', 'yarn', 'leggendario', 2200, 'Gomitolo', 'Ball of yarn', '2026-11-20', 1705, null, null),
  ('frontFx.banknotes', 'frontFx', 'banknotes', 'leggendario', 2200, 'Pioggia di lire', 'Raining lire', '2026-11-20', 1706, null, null),
  ('frontFx.musicNotes', 'frontFx', 'musicNotes', 'leggendario', 2200, 'Serenata', 'Serenade', '2026-11-20', 1707, null, null),
  ('frontFx.fireflies', 'frontFx', 'fireflies', 'leggendario', 2200, 'Lucciole', 'Fireflies', '2026-11-20', 1708, null, null),
  ('back.angelWings', 'back', 'angelWings', 'leggendario', 1800, 'Ali d''angelo', 'Angel wings', '2026-10-18', 545, null, 'carnevale'),
  ('back.batWings', 'back', 'batWings', 'leggendario', 1800, 'Ali da diavoletto', 'Devil bat wings', '2026-10-18', 546, null, 'carnevale'),
  ('back.butterflyWings', 'back', 'butterflyWings', 'leggendario', 1800, 'Ali di farfalla', 'Butterfly wings', '2026-10-18', 547, null, 'carnevale'),
  ('back.dragonWings', 'back', 'dragonWings', 'leggendario', 1800, 'Ali di drago', 'Dragon wings', '2026-10-18', 550, null, 'assurdo')
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en,
  price_coins = excluded.price_coins,
  rarity = excluded.rarity,
  enabled = true;

-- The wings move to the shoulders: inventories, the window, the bundle, the
-- saved looks; the old rows are switched off.
create temporary table _wings (old_id text primary key, new_id text not null, look text not null) on commit drop;
insert into _wings values
  ('accessory.angelWings', 'back.angelWings', 'angelWings'),
  ('accessory.batWings', 'back.batWings', 'batWings'),
  ('accessory.butterflyWings', 'back.butterflyWings', 'butterflyWings'),
  ('accessory.dragonWings', 'back.dragonWings', 'dragonWings');

insert into public.shop_inventory (profile_id, item_id, source, acquired_at)
select i.profile_id, w.new_id, i.source, i.acquired_at
from public.shop_inventory i join _wings w on w.old_id = i.item_id
on conflict do nothing;
delete from public.shop_inventory where item_id in (select old_id from _wings);

update public.shop_rotations r set item_id = w.new_id from _wings w where r.item_id = w.old_id;

insert into public.shop_bundle_items (bundle_id, item_id)
select b.bundle_id, w.new_id from public.shop_bundle_items b join _wings w on w.old_id = b.item_id
on conflict do nothing;
delete from public.shop_bundle_items where item_id in (select old_id from _wings);

update public.shop_items set enabled = false where id in (select old_id from _wings);

update public.profiles
set avatar = (avatar - 'accessory') || jsonb_build_object('back', avatar ->> 'accessory')
where avatar ->> 'accessory' in (select look from _wings);

-- Whether a player owns a catalogue piece (free ones belong to everyone).
create or replace function public._owns(p_profile uuid, p_item text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.shop_items where id = p_item and rarity = 'base')
      or exists (select 1 from public.shop_inventory where profile_id = p_profile and item_id = p_item);
$$;

-- The look the app sends, with only the pieces the player owns: the
-- barber's free features pass, every shop slot needs its piece.
create or replace function public._owned_look(p_profile uuid, p_look jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb)
  from jsonb_each(case when jsonb_typeof(p_look) = 'object' then p_look else '{}'::jsonb end) e
  where jsonb_typeof(e.value) = 'string'
    and case
      when e.key in ('heldL', 'heldR') then public._owns(p_profile, 'held.' || (e.value #>> '{}'))
      when e.key = 'faceExtras' then not exists (
        select 1 from unnest(string_to_array(e.value #>> '{}', '+')) t where not public._owns(p_profile, 'faceExtras.' || t))
      when e.key = 'base' then public._owns(p_profile, 'face.' || substr(e.value #>> '{}', position('_' in (e.value #>> '{}')) + 1))
      when e.key in (select distinct slot from public.shop_items) then public._owns(p_profile, e.key || '.' || (e.value #>> '{}'))
      else true
    end;
$$;

drop function if exists public.equip_item(text, text, jsonb);

create or replace function public.equip_item(p_item text, p_tone text default null, p_current jsonb default null, p_hand text default null)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  item public.shop_items;
  current jsonb;
  tone text;
  hand text;
  other text;
  marks text[];
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into item from public.shop_items where id = p_item;
  if not found or (item.rarity = 'base' and not item.enabled) or item.slot = 'gesture' then
    raise exception 'item_not_found';
  end if;
  if item.rarity <> 'base'
     and not exists (select 1 from public.shop_inventory where profile_id = me and item_id = item.id) then
    raise exception 'not_owned';
  end if;
  select avatar into current from public.profiles where id = me for update;
  current := public._owned_look(me, p_current) || coalesce(current, '{}'::jsonb);
  if item.slot = 'face' then
    tone := public.avatar_tone(current, p_tone);
    if tone is null then
      raise exception 'tone_required';
    end if;
    current := current || jsonb_build_object('base', tone || '_' || item.look_id);
  elsif item.slot = 'held' then
    if item.look_id = 'none' then
      current := current || jsonb_build_object('heldL', 'none', 'heldR', 'none');
    elsif item.look_id in ('cat', 'teddy') then
      -- Held with both hands: on the left, the right hand empty.
      current := current || jsonb_build_object('heldL', item.look_id, 'heldR', 'none');
    else
      hand := case when p_hand = 'left' then 'heldL' else 'heldR' end;
      other := case when hand = 'heldL' then 'heldR' else 'heldL' end;
      if coalesce(current ->> other, 'none') in ('cat', 'teddy') then
        current := current || jsonb_build_object(other, 'none');
      end if;
      current := current || jsonb_build_object(hand, item.look_id);
    end if;
  elsif item.slot = 'faceExtras' then
    -- Up to two marks: a worn one comes off, a new one pushes out the oldest.
    if item.look_id = 'none' then
      marks := array[]::text[];
    else
      marks := array_remove(array_remove(string_to_array(coalesce(current ->> 'faceExtras', 'none'), '+'), 'none'), '');
      if item.look_id = any (marks) then
        marks := array_remove(marks, item.look_id);
      else
        marks := marks || item.look_id;
        if cardinality(marks) > 2 then
          marks := marks[cardinality(marks) - 1:cardinality(marks)];
        end if;
      end if;
    end if;
    current := current || jsonb_build_object('faceExtras', case when cardinality(marks) = 0 then 'none' else array_to_string(marks, '+') end);
  else
    current := current || jsonb_build_object(item.slot, item.look_id);
  end if;
  update public.profiles set avatar = current where id = me;
  return query select * from public.profiles where id = me;
end;
$$;

revoke all on function public.equip_item(text, text, jsonb, text) from public, anon;
grant execute on function public.equip_item(text, text, jsonb, text) to authenticated;

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
  if p_slot not in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo', 'border', 'nameStyle',
                    'aura', 'back', 'headFx', 'faceExtras', 'eyeShine', 'hairDye', 'held', 'heldL', 'heldR', 'frontFx') then
    raise exception 'bad_slot';
  end if;
  select avatar into current from public.profiles where id = me for update;
  current := public._owned_look(me, p_current) || coalesce(current, '{}'::jsonb);
  if p_slot = 'face' then
    tone := public.avatar_tone(current, p_tone);
    if tone is not null then
      update public.profiles set avatar = current || jsonb_build_object('base', tone || '_clean') where id = me;
    end if;
  elsif p_slot = 'held' then
    update public.profiles set avatar = current - 'heldL' - 'heldR' where id = me;
  else
    update public.profiles set avatar = current - p_slot where id = me;
  end if;
  return query select * from public.profiles where id = me;
end;
$$;

revoke all on function public.unequip_slot(text, text, jsonb) from public, anon;
grant execute on function public.unequip_slot(text, text, jsonb) to authenticated;
revoke all on function public._owns(uuid, text) from public, anon, authenticated;
revoke all on function public._owned_look(uuid, jsonb) from public, anon, authenticated;
