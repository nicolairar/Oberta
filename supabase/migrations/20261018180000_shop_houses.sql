-- The fashion houses, recast: seven invented labels, each with its own mark
-- drawn by the app.
--
--   vaugirard    Vaugirard & Fils     trunks and luggage, tan canvas and brass
--   arminio      Arminio Milano       soft Milanese tailoring, greige and navy
--   cuccioli     Cuccioli Firenze     Florentine leather, green-amber band
--   versalli     Versalli             baroque black and gold
--   chanterelle  Maison Chanterelle   Paris couture, black, white and pearls
--   nikea        Nikea Sport          period athletics, black and orange
--   adelphi      Adelphi Atletica     period athletics, blue and white
--
-- The old house values are renamed in place, so every item id (and every
-- profile that owns or wears one) keeps working; their names follow the new
-- houses. Nine new pieces join, and the featured window moves to the
-- Vaugirard & Fils collection. Re-running is harmless.

alter table public.shop_items drop constraint if exists shop_items_brand_check;

update public.shop_items set brand = case brand
  when 'vanetti' then 'arminio'
  when 'moretti' then 'cuccioli'
  when 'delacroix' then 'chanterelle'
  when 'fulmine' then 'nikea'
  when 'ricci' then 'versalli'
  else brand
end
where brand in ('vanetti', 'moretti', 'delacroix', 'fulmine', 'ricci');

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand) values
  ('hat.morettiFedora', 'hat', 'morettiFedora', 'epico', 1100, 'Fedora a fascia Cuccioli', 'Cuccioli banded fedora', '2026-10-18', 130, 'cuccioli'),
  ('hat.morettiPanama', 'hat', 'morettiPanama', 'epico', 1100, 'Panama Cuccioli', 'Cuccioli panama', '2026-10-18', 131, 'cuccioli'),
  ('hat.morettiHomburg', 'hat', 'morettiHomburg', 'leggendario', 1800, 'Homburg con staffa Cuccioli', 'Cuccioli stirrup homburg', '2026-10-18', 132, 'cuccioli'),
  ('hat.fulmineCap', 'hat', 'fulmineCap', 'epico', 1100, 'Berretto da corsa Nikea', 'Nikea running cap', '2026-10-18', 133, 'nikea'),
  ('hat.vaugirardCap', 'hat', 'vaugirardCap', 'epico', 1100, 'Coppola da viaggio Vaugirard', 'Vaugirard travel cap', '2026-10-18', 134, 'vaugirard'),
  ('hat.adelphiCap', 'hat', 'adelphiCap', 'epico', 1100, 'Berretto da tennis Adelphi', 'Adelphi tennis cap', '2026-10-18', 135, 'adelphi'),
  ('glasses.delacroixShades', 'glasses', 'delacroixShades', 'epico', 1100, 'Occhiali bianchi Chanterelle', 'Chanterelle white-rim glasses', '2026-10-18', 330, 'chanterelle'),
  ('glasses.ricciMonocle', 'glasses', 'ricciMonocle', 'epico', 1100, 'Monocolo barocco Versalli', 'Versalli baroque monocle', '2026-10-18', 331, 'versalli'),
  ('outfit.vanetti_pinstripe', 'outfit', 'vanetti_pinstripe', 'epico', 1100, 'Completo morbido Arminio', 'Arminio soft suit', '2026-10-18', 450, 'arminio'),
  ('outfit.vanetti_tuxedo', 'outfit', 'vanetti_tuxedo', 'leggendario', 1800, 'Smoking blu notte Arminio', 'Arminio midnight tuxedo', '2026-10-18', 451, 'arminio'),
  ('outfit.vanetti_ivory', 'outfit', 'vanetti_ivory', 'leggendario', 1800, 'Giacca greige Arminio', 'Arminio greige jacket', '2026-10-18', 452, 'arminio'),
  ('outfit.delacroix_velvet', 'outfit', 'delacroix_velvet', 'epico', 1100, 'Giacca bordata Chanterelle', 'Chanterelle braided jacket', '2026-10-18', 453, 'chanterelle'),
  ('outfit.delacroix_cape', 'outfit', 'delacroix_cape', 'leggendario', 1800, 'Mantello bianco e nero Chanterelle', 'Chanterelle black-and-white cape', '2026-10-18', 454, 'chanterelle'),
  ('outfit.fulmine_track', 'outfit', 'fulmine_track', 'epico', 1100, 'Giacca da pista Nikea', 'Nikea track top', '2026-10-18', 455, 'nikea'),
  ('outfit.fulmine_cardigan', 'outfit', 'fulmine_cardigan', 'epico', 1100, 'Cardigan atletico Nikea', 'Nikea athletic cardigan', '2026-10-18', 456, 'nikea'),
  ('outfit.vaugirard_travel', 'outfit', 'vaugirard_travel', 'leggendario', 1800, 'Spolverino da viaggio Vaugirard', 'Vaugirard travel coat', '2026-10-18', 457, 'vaugirard'),
  ('outfit.cuccioli_blazer', 'outfit', 'cuccioli_blazer', 'epico', 1100, 'Blazer a fascia Cuccioli', 'Cuccioli banded blazer', '2026-10-18', 458, 'cuccioli'),
  ('outfit.versalli_baroque', 'outfit', 'versalli_baroque', 'leggendario', 1800, 'Giacca barocca Versalli', 'Versalli baroque jacket', '2026-10-18', 459, 'versalli'),
  ('outfit.adelphi_track', 'outfit', 'adelphi_track', 'epico', 1100, 'Giacca da pista Adelphi', 'Adelphi track top', '2026-10-18', 460, 'adelphi'),
  ('outfit.adelphi_cardigan', 'outfit', 'adelphi_cardigan', 'epico', 1100, 'Maglia da squadra Adelphi', 'Adelphi team cardigan', '2026-10-18', 461, 'adelphi'),
  ('accessory.ricciChain', 'accessory', 'ricciChain', 'epico', 1100, 'Catena barocca Versalli', 'Versalli baroque chain', '2026-10-18', 530, 'versalli'),
  ('accessory.ricciTiePin', 'accessory', 'ricciTiePin', 'epico', 1100, 'Fermacravatta Versalli', 'Versalli tie pin', '2026-10-18', 531, 'versalli'),
  ('accessory.ricciWatch', 'accessory', 'ricciWatch', 'leggendario', 1800, 'Cipolla d''oro Versalli', 'Versalli gold pocket watch', '2026-10-18', 532, 'versalli'),
  ('accessory.delacroixScarf', 'accessory', 'delacroixScarf', 'epico', 1100, 'Sciarpa da sera Chanterelle', 'Chanterelle evening scarf', '2026-10-18', 533, 'chanterelle'),
  ('accessory.delacroixAscot', 'accessory', 'delacroixAscot', 'epico', 1100, 'Foulard a fiocchi Chanterelle', 'Chanterelle bow ascot', '2026-10-18', 534, 'chanterelle'),
  ('accessory.vaugirardStrap', 'accessory', 'vaugirardStrap', 'epico', 1100, 'Tracolla Vaugirard', 'Vaugirard satchel strap', '2026-10-18', 535, 'vaugirard'),
  ('accessory.chanterellePearls', 'accessory', 'chanterellePearls', 'leggendario', 1800, 'Perle lunghe Chanterelle', 'Chanterelle long pearls', '2026-10-18', 536, 'chanterelle')
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en,
  brand = excluded.brand;

alter table public.shop_items add constraint shop_items_brand_check
  check (brand is null or brand in ('vaugirard', 'arminio', 'cuccioli', 'versalli', 'chanterelle', 'nikea', 'adelphi'));

-- The Arminio window closes as the Vaugirard collection takes the glass.
update public.shop_rotations set ends_at = '2026-10-18 18:00+00'
where starts_at = '2026-10-18 12:00+00' and ends_at = '2026-11-08 00:00+00';

insert into public.shop_rotations (item_id, starts_at, ends_at, sort)
select item_id, '2026-10-18 18:00+00', '2026-11-15 00:00+00', sort
from (values
  ('outfit.vaugirard_travel', 0),
  ('hat.vaugirardCap', 1),
  ('accessory.vaugirardStrap', 2)
) as featured (item_id, sort)
where not exists (select 1 from public.shop_rotations where item_id = 'outfit.vaugirard_travel');
