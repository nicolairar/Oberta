-- Item look ids may contain digits (e.g. glasses3d).
alter table public.shop_items drop constraint if exists shop_items_look_id_check;
alter table public.shop_items add constraint shop_items_look_id_check check (look_id ~ '^[A-Za-z0-9_]{1,40}$');

-- Stramberie / Oddities, part two: l'assurdo. The loudest pieces in the
-- shop: fish heads, dinosaur hoods, jetpacks, a cat on the head.
--
-- Widens the `collection` check with 'assurdo', lets look ids carry digits
-- (glasses3d), and adds the pieces.
-- The CLI applies the file in one transaction; re-running is harmless.

alter table public.shop_items drop constraint if exists shop_items_collection_check;
alter table public.shop_items add constraint shop_items_collection_check
  check (collection is null or collection in ('circo', 'carnevale', 'assurdo'));

alter table public.shop_items drop constraint if exists shop_items_look_id_check;
alter table public.shop_items add constraint shop_items_look_id_check
  check (look_id ~ '^[A-Za-z][A-Za-z0-9_]{0,39}$');

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand, collection) values
  ('hat.fishHead', 'hat', 'fishHead', 'leggendario', 1800, 'Testa di pesce', 'Fish head mask', '2026-10-18', 151, null, 'assurdo'),
  ('hat.dinoHood', 'hat', 'dinoHood', 'leggendario', 1800, 'Cappuccio da dinosauro', 'Dinosaur hood', '2026-10-18', 152, null, 'assurdo'),
  ('hat.astronautHelmet', 'hat', 'astronautHelmet', 'leggendario', 1800, 'Casco da astronauta', 'Astronaut bubble helmet', '2026-10-18', 153, null, 'assurdo'),
  ('hat.unicornHorn', 'hat', 'unicornHorn', 'epico', 1100, 'Corno da unicorno', 'Unicorn horn headband', '2026-10-18', 154, null, 'assurdo'),
  ('hat.spaghettiHat', 'hat', 'spaghettiHat', 'epico', 1100, 'Piatto di spaghetti', 'Spaghetti plate hat', '2026-10-18', 155, null, 'assurdo'),
  ('hat.octopusHat', 'hat', 'octopusHat', 'leggendario', 1800, 'Polpo in testa', 'Octopus hat', '2026-10-18', 156, null, 'assurdo'),
  ('hat.ufoHat', 'hat', 'ufoHat', 'leggendario', 1800, 'Disco volante', 'UFO hat with alien', '2026-10-18', 157, null, 'assurdo'),
  ('hat.birthdayCake', 'hat', 'birthdayCake', 'epico', 1100, 'Torta di compleanno', 'Birthday cake hat', '2026-10-18', 158, null, 'assurdo'),
  ('hat.rainbowAfro', 'hat', 'rainbowAfro', 'leggendario', 1800, 'Afro arcobaleno', 'Rainbow afro', '2026-10-18', 159, null, 'assurdo'),
  ('hat.flamingHair', 'hat', 'flamingHair', 'leggendario', 1800, 'Capelli in fiamme', 'Flaming hair', '2026-10-18', 160, null, 'assurdo'),
  ('hat.starHalo', 'hat', 'starHalo', 'epico', 1100, 'Giro di stelle', 'Halo of stars', '2026-10-18', 161, null, 'assurdo'),
  ('hat.catOnHead', 'hat', 'catOnHead', 'leggendario', 1800, 'Gatto in testa', 'Cat on the head', '2026-10-18', 162, null, 'assurdo'),
  ('face.vikingBeard', 'face', 'vikingBeard', 'leggendario', 1800, 'Barba del vichingo', 'Braided viking beard', '2026-10-18', 223, null, 'assurdo'),
  ('glasses.googlyEyes', 'glasses', 'googlyEyes', 'raro', 700, 'Occhi mobili', 'Googly-eye glasses', '2026-10-18', 346, null, 'assurdo'),
  ('glasses.glasses3d', 'glasses', 'glasses3d', 'raro', 700, 'Occhialini 3D', '3D glasses', '2026-10-18', 347, null, 'assurdo'),
  ('glasses.bulbMonocle', 'glasses', 'bulbMonocle', 'epico', 1100, 'Monocolo dell''idea', 'Lightbulb monocle', '2026-10-18', 348, null, 'assurdo'),
  ('outfit.pizza_suit', 'outfit', 'pizza_suit', 'leggendario', 1800, 'Costume da pizza', 'Pizza slice costume', '2026-10-18', 476, null, 'assurdo'),
  ('outfit.cactus_suit', 'outfit', 'cactus_suit', 'leggendario', 1800, 'Costume da cactus', 'Cactus costume', '2026-10-18', 477, null, 'assurdo'),
  ('outfit.ghost_sheet', 'outfit', 'ghost_sheet', 'epico', 1100, 'Lenzuolo da fantasma', 'Ghost sheet', '2026-10-18', 478, null, 'assurdo'),
  ('outfit.mummy_wraps', 'outfit', 'mummy_wraps', 'epico', 1100, 'Bende da mummia', 'Mummy wraps', '2026-10-18', 479, null, 'assurdo'),
  ('accessory.snailShell', 'accessory', 'snailShell', 'epico', 1100, 'Guscio di lumaca', 'Snail shell backpack', '2026-10-18', 548, null, 'assurdo'),
  ('accessory.jetpack', 'accessory', 'jetpack', 'leggendario', 1800, 'Zaino a razzo', 'Jetpack', '2026-10-18', 549, null, 'assurdo'),
  ('accessory.dragonWings', 'accessory', 'dragonWings', 'leggendario', 1800, 'Ali di drago', 'Dragon wings', '2026-10-18', 550, null, 'assurdo'),
  ('accessory.balloons', 'accessory', 'balloons', 'leggendario', 1800, 'Mazzo di palloncini', 'Balloon bunch', '2026-10-18', 551, null, 'assurdo'),
  ('accessory.giantBowTie', 'accessory', 'giantBowTie', 'raro', 700, 'Papillon gigante', 'Giant bow tie', '2026-10-18', 552, null, 'assurdo'),
  ('accessory.pigeon', 'accessory', 'pigeon', 'raro', 700, 'Piccione sulla spalla', 'Shoulder pigeon', '2026-10-18', 553, null, 'assurdo'),
  ('accessory.plungerSword', 'accessory', 'plungerSword', 'epico', 1100, 'Spada sturalavandini', 'Plunger sword', '2026-10-18', 554, null, 'assurdo')
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en,
  collection = excluded.collection;

