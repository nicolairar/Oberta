-- The second drop: fashion houses and more variety.
--
-- Every brand here is invented for the game (Casa Vanetti, Fratelli Moretti,
-- Maison Delacroix, Atletica Fulmine, Gioielleria Ricci), with its own mark
-- drawn by the app; none imitates a real label. shop_items.brand names the
-- house (null for the shop's own pieces), and the brand pieces sit at the
-- top of the price list. The featured window moves to the Casa Vanetti
-- collection. Re-running is harmless.

alter table public.shop_items add column if not exists brand text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'shop_items_brand_check') then
    alter table public.shop_items add constraint shop_items_brand_check
      check (brand is null or brand in ('vanetti', 'moretti', 'delacroix', 'fulmine', 'ricci'));
  end if;
end;
$$;

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand) values
  ('hat.porkPie', 'hat', 'porkPie', 'comune', 350, 'Pork pie', 'Pork pie', '2026-10-18', 120, null),
  ('hat.beret', 'hat', 'beret', 'comune', 350, 'Basco', 'Beret', '2026-10-18', 121, null),
  ('hat.pearlFedora', 'hat', 'pearlFedora', 'comune', 350, 'Fedora grigio perla', 'Pearl grey fedora', '2026-10-18', 122, null),
  ('hat.cloche', 'hat', 'cloche', 'raro', 700, 'Cloche', 'Cloche', '2026-10-18', 123, null),
  ('hat.morettiFedora', 'hat', 'morettiFedora', 'epico', 1100, 'Fedora Moretti', 'Moretti fedora', '2026-10-18', 130, 'moretti'),
  ('hat.morettiPanama', 'hat', 'morettiPanama', 'epico', 1100, 'Panama Moretti', 'Moretti panama', '2026-10-18', 131, 'moretti'),
  ('hat.morettiHomburg', 'hat', 'morettiHomburg', 'leggendario', 1800, 'Homburg da sera Moretti', 'Moretti evening homburg', '2026-10-18', 132, 'moretti'),
  ('hat.fulmineCap', 'hat', 'fulmineCap', 'epico', 1100, 'Berretto da ciclista Fulmine', 'Fulmine cycling cap', '2026-10-18', 133, 'fulmine'),
  ('face.chevron', 'face', 'chevron', 'comune', 350, 'Baffi a spazzola', 'Chevron moustache', '2026-10-18', 220, null),
  ('face.horseshoe', 'face', 'horseshoe', 'comune', 350, 'Baffi a ferro di cavallo', 'Horseshoe moustache', '2026-10-18', 221, null),
  ('face.vandyke', 'face', 'vandyke', 'comune', 350, 'Pizzo alla moschettiera', 'Musketeer goatee', '2026-10-18', 222, null),
  ('face.muttonChops', 'face', 'muttonChops', 'raro', 700, 'Basettoni', 'Mutton chops', '2026-10-18', 223, null),
  ('face.fullBeard', 'face', 'fullBeard', 'raro', 700, 'Barba da capitano', 'Captain''s beard', '2026-10-18', 224, null),
  ('glasses.goldRims', 'glasses', 'goldRims', 'comune', 350, 'Montatura dorata', 'Gold rims', '2026-10-18', 320, null),
  ('glasses.browline', 'glasses', 'browline', 'comune', 350, 'Occhiali da ragioniere', 'Accountant''s glasses', '2026-10-18', 321, null),
  ('glasses.catEye', 'glasses', 'catEye', 'raro', 700, 'Occhiali a gatto', 'Cat-eye glasses', '2026-10-18', 322, null),
  ('glasses.delacroixShades', 'glasses', 'delacroixShades', 'epico', 1100, 'Occhiali fumé Delacroix', 'Delacroix smoked glasses', '2026-10-18', 330, 'delacroix'),
  ('glasses.ricciMonocle', 'glasses', 'ricciMonocle', 'epico', 1100, 'Monocolo con brillante Ricci', 'Ricci diamond monocle', '2026-10-18', 331, 'ricci'),
  ('outfit.charcoal_windowpane', 'outfit', 'charcoal_windowpane', 'raro', 700, 'Finestrato antracite', 'Charcoal windowpane', '2026-10-18', 440, null),
  ('outfit.tan_herringbone', 'outfit', 'tan_herringbone', 'raro', 700, 'Spina di pesce tabacco', 'Tan herringbone', '2026-10-18', 441, null),
  ('outfit.steel_sharkskin', 'outfit', 'steel_sharkskin', 'raro', 700, 'Fresco di lana acciaio', 'Steel sharkskin', '2026-10-18', 442, null),
  ('outfit.oxblood_double', 'outfit', 'oxblood_double', 'raro', 700, 'Doppiopetto sangue di bue', 'Oxblood double-breasted', '2026-10-18', 443, null),
  ('outfit.vanetti_pinstripe', 'outfit', 'vanetti_pinstripe', 'epico', 1100, 'Gessato Vanetti', 'Vanetti pinstripe', '2026-10-18', 450, 'vanetti'),
  ('outfit.vanetti_tuxedo', 'outfit', 'vanetti_tuxedo', 'leggendario', 1800, 'Smoking di raso Vanetti', 'Vanetti satin tuxedo', '2026-10-18', 451, 'vanetti'),
  ('outfit.vanetti_ivory', 'outfit', 'vanetti_ivory', 'leggendario', 1800, 'Smoking avorio Vanetti', 'Vanetti ivory dinner jacket', '2026-10-18', 452, 'vanetti'),
  ('outfit.delacroix_velvet', 'outfit', 'delacroix_velvet', 'epico', 1100, 'Giacca da camera Delacroix', 'Delacroix velvet smoking jacket', '2026-10-18', 453, 'delacroix'),
  ('outfit.delacroix_cape', 'outfit', 'delacroix_cape', 'leggendario', 1800, 'Mantello d''opera Delacroix', 'Delacroix opera cape', '2026-10-18', 454, 'delacroix'),
  ('outfit.fulmine_track', 'outfit', 'fulmine_track', 'epico', 1100, 'Tuta Fulmine', 'Fulmine track jacket', '2026-10-18', 455, 'fulmine'),
  ('outfit.fulmine_cardigan', 'outfit', 'fulmine_cardigan', 'epico', 1100, 'Cardigan da squadra Fulmine', 'Fulmine team cardigan', '2026-10-18', 456, 'fulmine'),
  ('accessory.stripeTie', 'accessory', 'stripeTie', 'comune', 350, 'Cravatta a righe', 'Striped tie', '2026-10-18', 520, null),
  ('accessory.knitTie', 'accessory', 'knitTie', 'comune', 350, 'Cravatta di maglia', 'Knit tie', '2026-10-18', 521, null),
  ('accessory.polkaBowTie', 'accessory', 'polkaBowTie', 'comune', 350, 'Papillon a pois', 'Polka-dot bow tie', '2026-10-18', 522, null),
  ('accessory.whiteCarnation', 'accessory', 'whiteCarnation', 'comune', 350, 'Garofano bianco', 'White carnation', '2026-10-18', 523, null),
  ('accessory.suspenders', 'accessory', 'suspenders', 'raro', 700, 'Bretelle', 'Braces', '2026-10-18', 524, null),
  ('accessory.cigaretteHolder', 'accessory', 'cigaretteHolder', 'raro', 700, 'Bocchino', 'Cigarette holder', '2026-10-18', 525, null),
  ('accessory.ricciChain', 'accessory', 'ricciChain', 'epico', 1100, 'Catena d''oro Ricci', 'Ricci gold chain', '2026-10-18', 530, 'ricci'),
  ('accessory.ricciTiePin', 'accessory', 'ricciTiePin', 'epico', 1100, 'Fermacravatta Ricci', 'Ricci tie pin', '2026-10-18', 531, 'ricci'),
  ('accessory.ricciWatch', 'accessory', 'ricciWatch', 'leggendario', 1800, 'Cipolla d''oro Ricci', 'Ricci gold pocket watch', '2026-10-18', 532, 'ricci'),
  ('accessory.delacroixScarf', 'accessory', 'delacroixScarf', 'epico', 1100, 'Sciarpa da sera Delacroix', 'Delacroix evening scarf', '2026-10-18', 533, 'delacroix'),
  ('accessory.delacroixAscot', 'accessory', 'delacroixAscot', 'epico', 1100, 'Foulard Delacroix', 'Delacroix ascot', '2026-10-18', 534, 'delacroix')
on conflict (id) do nothing;

-- The first window closes as the Vanetti collection takes the glass.
update public.shop_rotations set ends_at = '2026-10-18 12:00+00'
where starts_at = '2026-10-17 00:00+00' and ends_at = '2026-11-01 00:00+00';

insert into public.shop_rotations (item_id, starts_at, ends_at, sort)
select item_id, '2026-10-18 12:00+00', '2026-11-08 00:00+00', sort
from (values
  ('outfit.vanetti_tuxedo', 0),
  ('outfit.vanetti_pinstripe', 1),
  ('outfit.vanetti_ivory', 2),
  ('hat.morettiHomburg', 3),
  ('accessory.ricciWatch', 4)
) as featured (item_id, sort)
where not exists (select 1 from public.shop_rotations where item_id = 'outfit.vanetti_tuxedo');
