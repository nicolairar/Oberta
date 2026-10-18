-- Stramberie / Oddities: the circus and the carnival, drawn by the app.
--
--   circo      the big top: clown, strongman, magician, mime
--   carnevale  costumes and novelties: pirate, chef, rooster, banana, wings
--
-- A new optional `collection` column tags these pieces for their own shelf.
-- The clown set joins the featured window alongside the Vaugirard
-- collection. Re-running is harmless.

alter table public.shop_items add column if not exists collection text;
alter table public.shop_items drop constraint if exists shop_items_collection_check;
alter table public.shop_items add constraint shop_items_collection_check
  check (collection is null or collection in ('circo', 'carnevale'));

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand, collection) values
  ('hat.clownWig', 'hat', 'clownWig', 'leggendario', 1800, 'Parrucca arcobaleno', 'Rainbow clown wig', '2026-10-18', 140, null, 'circo'),
  ('hat.magicianHat', 'hat', 'magicianHat', 'leggendario', 1800, 'Cilindro del prestigiatore', 'Magician''s top hat', '2026-10-18', 141, null, 'circo'),
  ('hat.chefToque', 'hat', 'chefToque', 'raro', 700, 'Toque da cuoco', 'Chef''s toque', '2026-10-18', 142, null, 'carnevale'),
  ('hat.sombrero', 'hat', 'sombrero', 'raro', 700, 'Sombrero con i pompon', 'Pompom sombrero', '2026-10-18', 143, null, 'carnevale'),
  ('hat.tricorn', 'hat', 'tricorn', 'epico', 1100, 'Tricorno del pirata', 'Pirate tricorn', '2026-10-18', 144, null, 'carnevale'),
  ('hat.operaHelmet', 'hat', 'operaHelmet', 'epico', 1100, 'Elmo della prima donna', 'Opera horned helmet', '2026-10-18', 145, null, 'carnevale'),
  ('hat.beekeeper', 'hat', 'beekeeper', 'raro', 700, 'Cappello dell''apicoltore', 'Beekeeper''s veil hat', '2026-10-18', 146, null, 'carnevale'),
  ('hat.roosterHead', 'hat', 'roosterHead', 'leggendario', 1800, 'Testa da gallo', 'Rooster costume head', '2026-10-18', 147, null, 'carnevale'),
  ('hat.propellerBeanie', 'hat', 'propellerBeanie', 'comune', 350, 'Zucchetto con l''elica', 'Propeller beanie', '2026-10-18', 148, null, 'carnevale'),
  ('hat.angelHalo', 'hat', 'angelHalo', 'epico', 1100, 'Aureola d''angelo', 'Angel halo', '2026-10-18', 149, null, 'carnevale'),
  ('hat.devilHorns', 'hat', 'devilHorns', 'epico', 1100, 'Cornetti del diavolo', 'Devil horns', '2026-10-18', 150, null, 'carnevale'),
  ('face.curledMoustache', 'face', 'curledMoustache', 'raro', 700, 'Baffi a ricciolo', 'Curled moustache', '2026-10-18', 220, null, 'circo'),
  ('face.giantMoustache', 'face', 'giantMoustache', 'comune', 350, 'Baffone finto', 'Giant fake moustache', '2026-10-18', 221, null, 'carnevale'),
  ('face.mimeFace', 'face', 'mimeFace', 'raro', 700, 'Trucco da mimo', 'Mime face paint', '2026-10-18', 222, null, 'circo'),
  ('glasses.noseDisguise', 'glasses', 'noseDisguise', 'comune', 350, 'Naso e baffi finti', 'Nose-and-moustache disguise', '2026-10-18', 340, null, 'carnevale'),
  ('glasses.heartGlasses', 'glasses', 'heartGlasses', 'comune', 350, 'Occhiali a cuore', 'Heart glasses', '2026-10-18', 341, null, 'carnevale'),
  ('glasses.hypnoGlasses', 'glasses', 'hypnoGlasses', 'raro', 700, 'Occhiali dell''ipnotista', 'Hypnotist glasses', '2026-10-18', 342, null, 'circo'),
  ('glasses.eyePatch', 'glasses', 'eyePatch', 'comune', 350, 'Benda da pirata', 'Pirate eye patch', '2026-10-18', 343, null, 'carnevale'),
  ('glasses.giantGlasses', 'glasses', 'giantGlasses', 'epico', 1100, 'Occhialoni', 'Giant novelty glasses', '2026-10-18', 344, null, 'carnevale'),
  ('glasses.giantShades', 'glasses', 'giantShades', 'leggendario', 1800, 'Occhialoni da sole', 'Giant sunglasses', '2026-10-18', 345, null, 'carnevale'),
  ('outfit.clown_suit', 'outfit', 'clown_suit', 'leggendario', 1800, 'Costume da clown a pois', 'Polka-dot clown suit', '2026-10-18', 470, null, 'circo'),
  ('outfit.strongman_leotard', 'outfit', 'strongman_leotard', 'epico', 1100, 'Canottiera del forzuto', 'Strongman''s leotard', '2026-10-18', 471, null, 'circo'),
  ('outfit.mime_stripes', 'outfit', 'mime_stripes', 'raro', 700, 'Maglia a righe del mimo', 'Mime''s striped shirt', '2026-10-18', 472, null, 'circo'),
  ('outfit.magician_cape', 'outfit', 'magician_cape', 'epico', 1100, 'Mantello del prestigiatore', 'Magician''s cape', '2026-10-18', 473, null, 'circo'),
  ('outfit.chef_whites', 'outfit', 'chef_whites', 'raro', 700, 'Giacca da cuoco', 'Chef''s whites', '2026-10-18', 474, null, 'carnevale'),
  ('outfit.banana_suit', 'outfit', 'banana_suit', 'leggendario', 1800, 'Costume da banana', 'Banana costume', '2026-10-18', 475, null, 'carnevale'),
  ('accessory.clownNose', 'accessory', 'clownNose', 'leggendario', 1800, 'Naso da clown', 'Clown nose', '2026-10-18', 540, null, 'circo'),
  ('accessory.parrot', 'accessory', 'parrot', 'leggendario', 1800, 'Pappagallo sulla spalla', 'Shoulder parrot', '2026-10-18', 541, null, 'carnevale'),
  ('accessory.rubberDuck', 'accessory', 'rubberDuck', 'comune', 350, 'Paperella nel taschino', 'Pocket rubber duck', '2026-10-18', 542, null, 'carnevale'),
  ('accessory.accordion', 'accessory', 'accordion', 'epico', 1100, 'Fisarmonica', 'Accordion', '2026-10-18', 543, null, 'carnevale'),
  ('accessory.baguetteCigar', 'accessory', 'baguetteCigar', 'raro', 700, 'Sigaro a filone', 'Baguette-size cigar', '2026-10-18', 544, null, 'carnevale'),
  ('accessory.angelWings', 'accessory', 'angelWings', 'leggendario', 1800, 'Ali d''angelo', 'Angel wings', '2026-10-18', 545, null, 'carnevale'),
  ('accessory.batWings', 'accessory', 'batWings', 'leggendario', 1800, 'Ali da diavoletto', 'Devil bat wings', '2026-10-18', 546, null, 'carnevale'),
  ('accessory.butterflyWings', 'accessory', 'butterflyWings', 'leggendario', 1800, 'Ali di farfalla', 'Butterfly wings', '2026-10-18', 547, null, 'carnevale')
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en,
  collection = excluded.collection;

insert into public.shop_rotations (item_id, starts_at, ends_at, sort)
select item_id, '2026-10-18 20:00+00', '2026-11-15 00:00+00', sort
from (values
  ('outfit.clown_suit', 3),
  ('hat.clownWig', 4),
  ('accessory.clownNose', 5)
) as featured (item_id, sort)
where not exists (select 1 from public.shop_rotations where item_id = 'outfit.clown_suit');
