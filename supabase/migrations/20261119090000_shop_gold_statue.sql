-- The gold statue and its crown, from the cartoon-noir avatars: a face
-- piece that turns skin and hair to gold leaf with a moving shine, and a
-- jewelled crown that rests on top of any hairstyle. Both legendary, in
-- the 'assurdo' collection, priced like every other legendary.
-- The CLI applies the file in one transaction; re-running is harmless.

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand, collection) values
  ('face.goldStatue', 'face', 'goldStatue', 'leggendario', 1800, 'Statua d''oro', 'Gold statue', '2026-10-28', 224, null, 'assurdo'),
  ('hat.crown', 'hat', 'crown', 'leggendario', 1800, 'Corona del re', 'King''s crown', '2026-10-28', 163, null, 'assurdo')
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en;
