-- Calcio / Football: the terraces of the twenties. Ten teams, known only by
-- nicknames and city colours (no real club names, crests or kits), each with
-- four legendary pieces: a laced-collar wool jersey, a bobble hat, a bar
-- scarf and a showpiece (smoke flare, tin megaphone, trophy or flag) that
-- brings a team-coloured glow behind the portrait.
--
-- Adds 'calcio' to the collection check, the forty items, one bundle per
-- team and the whole stand. Purchases still go through buy_item and
-- buy_bundle only; tables keep their RLS and grants.
-- The CLI applies the file in one transaction; re-running is harmless.

alter table public.shop_items drop constraint if exists shop_items_collection_check;
alter table public.shop_items add constraint shop_items_collection_check
  check (collection is null or collection in ('circo', 'carnevale', 'assurdo', 'calcio'));

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort, brand, collection) values
  ('outfit.blaugrana_kit', 'outfit', 'blaugrana_kit', 'leggendario', 1800, 'Maglia Blaugrana', 'Blaugrana jersey', '2026-10-23', 480, null, 'calcio'),
  ('hat.blaugranaCap', 'hat', 'blaugranaCap', 'leggendario', 1800, 'Berretto Blaugrana', 'Blaugrana bobble hat', '2026-10-23', 170, null, 'calcio'),
  ('accessory.blaugranaScarf', 'accessory', 'blaugranaScarf', 'leggendario', 1800, 'Sciarpa Blaugrana', 'Blaugrana scarf', '2026-10-23', 560, null, 'calcio'),
  ('accessory.blaugranaFlare', 'accessory', 'blaugranaFlare', 'leggendario', 1800, 'Fumogeno Blaugrana', 'Blaugrana smoke flare', '2026-10-23', 561, null, 'calcio'),
  ('outfit.merengues_kit', 'outfit', 'merengues_kit', 'leggendario', 1800, 'Maglia Merengues', 'Merengues jersey', '2026-10-23', 481, null, 'calcio'),
  ('hat.merenguesCap', 'hat', 'merenguesCap', 'leggendario', 1800, 'Berretto Merengues', 'Merengues bobble hat', '2026-10-23', 171, null, 'calcio'),
  ('accessory.merenguesScarf', 'accessory', 'merenguesScarf', 'leggendario', 1800, 'Sciarpa Merengues', 'Merengues scarf', '2026-10-23', 562, null, 'calcio'),
  ('accessory.merenguesTrophy', 'accessory', 'merenguesTrophy', 'leggendario', 1800, 'Coppa Merengues', 'Merengues trophy', '2026-10-23', 563, null, 'calcio'),
  ('outfit.celesti_kit', 'outfit', 'celesti_kit', 'leggendario', 1800, 'Maglia Celesti', 'Celesti jersey', '2026-10-23', 482, null, 'calcio'),
  ('hat.celestiCap', 'hat', 'celestiCap', 'leggendario', 1800, 'Berretto Celesti', 'Celesti bobble hat', '2026-10-23', 172, null, 'calcio'),
  ('accessory.celestiScarf', 'accessory', 'celestiScarf', 'leggendario', 1800, 'Sciarpa Celesti', 'Celesti scarf', '2026-10-23', 564, null, 'calcio'),
  ('accessory.celestiMegaphone', 'accessory', 'celestiMegaphone', 'leggendario', 1800, 'Megafono Celesti', 'Celesti megaphone', '2026-10-23', 565, null, 'calcio'),
  ('outfit.diavoli_kit', 'outfit', 'diavoli_kit', 'leggendario', 1800, 'Maglia Diavoli Rossi', 'Diavoli Rossi jersey', '2026-10-23', 483, null, 'calcio'),
  ('hat.diavoliCap', 'hat', 'diavoliCap', 'leggendario', 1800, 'Berretto Diavoli Rossi', 'Diavoli Rossi bobble hat', '2026-10-23', 173, null, 'calcio'),
  ('accessory.diavoliScarf', 'accessory', 'diavoliScarf', 'leggendario', 1800, 'Sciarpa Diavoli Rossi', 'Diavoli Rossi scarf', '2026-10-23', 566, null, 'calcio'),
  ('accessory.diavoliFlare', 'accessory', 'diavoliFlare', 'leggendario', 1800, 'Fumogeno Diavoli Rossi', 'Diavoli Rossi smoke flare', '2026-10-23', 567, null, 'calcio'),
  ('outfit.reds_kit', 'outfit', 'reds_kit', 'leggendario', 1800, 'Maglia Reds del Porto', 'Reds del Porto jersey', '2026-10-23', 484, null, 'calcio'),
  ('hat.redsCap', 'hat', 'redsCap', 'leggendario', 1800, 'Berretto Reds del Porto', 'Reds del Porto bobble hat', '2026-10-23', 174, null, 'calcio'),
  ('accessory.redsScarf', 'accessory', 'redsScarf', 'leggendario', 1800, 'Sciarpa Reds del Porto', 'Reds del Porto scarf', '2026-10-23', 568, null, 'calcio'),
  ('accessory.redsMegaphone', 'accessory', 'redsMegaphone', 'leggendario', 1800, 'Megafono Reds del Porto', 'Reds del Porto megaphone', '2026-10-23', 569, null, 'calcio'),
  ('outfit.rossoneri_kit', 'outfit', 'rossoneri_kit', 'leggendario', 1800, 'Maglia Rossoneri', 'Rossoneri jersey', '2026-10-23', 485, null, 'calcio'),
  ('hat.rossoneriCap', 'hat', 'rossoneriCap', 'leggendario', 1800, 'Berretto Rossoneri', 'Rossoneri bobble hat', '2026-10-23', 175, null, 'calcio'),
  ('accessory.rossoneriScarf', 'accessory', 'rossoneriScarf', 'leggendario', 1800, 'Sciarpa Rossoneri', 'Rossoneri scarf', '2026-10-23', 570, null, 'calcio'),
  ('accessory.rossoneriFlare', 'accessory', 'rossoneriFlare', 'leggendario', 1800, 'Fumogeno Rossoneri', 'Rossoneri smoke flare', '2026-10-23', 571, null, 'calcio'),
  ('outfit.nerazzurri_kit', 'outfit', 'nerazzurri_kit', 'leggendario', 1800, 'Maglia Nerazzurri', 'Nerazzurri jersey', '2026-10-23', 486, null, 'calcio'),
  ('hat.nerazzurriCap', 'hat', 'nerazzurriCap', 'leggendario', 1800, 'Berretto Nerazzurri', 'Nerazzurri bobble hat', '2026-10-23', 176, null, 'calcio'),
  ('accessory.nerazzurriScarf', 'accessory', 'nerazzurriScarf', 'leggendario', 1800, 'Sciarpa Nerazzurri', 'Nerazzurri scarf', '2026-10-23', 572, null, 'calcio'),
  ('accessory.nerazzurriFlag', 'accessory', 'nerazzurriFlag', 'leggendario', 1800, 'Bandiera Nerazzurri', 'Nerazzurri flag', '2026-10-23', 573, null, 'calcio'),
  ('outfit.bianconeri_kit', 'outfit', 'bianconeri_kit', 'leggendario', 1800, 'Maglia Bianconeri', 'Bianconeri jersey', '2026-10-23', 487, null, 'calcio'),
  ('hat.bianconeriCap', 'hat', 'bianconeriCap', 'leggendario', 1800, 'Berretto Bianconeri', 'Bianconeri bobble hat', '2026-10-23', 177, null, 'calcio'),
  ('accessory.bianconeriScarf', 'accessory', 'bianconeriScarf', 'leggendario', 1800, 'Sciarpa Bianconeri', 'Bianconeri scarf', '2026-10-23', 574, null, 'calcio'),
  ('accessory.bianconeriTrophy', 'accessory', 'bianconeriTrophy', 'leggendario', 1800, 'Coppa Bianconeri', 'Bianconeri trophy', '2026-10-23', 575, null, 'calcio'),
  ('outfit.giallorossi_kit', 'outfit', 'giallorossi_kit', 'leggendario', 1800, 'Maglia Giallorossi', 'Giallorossi jersey', '2026-10-23', 488, null, 'calcio'),
  ('hat.giallorossiCap', 'hat', 'giallorossiCap', 'leggendario', 1800, 'Berretto Giallorossi', 'Giallorossi bobble hat', '2026-10-23', 178, null, 'calcio'),
  ('accessory.giallorossiScarf', 'accessory', 'giallorossiScarf', 'leggendario', 1800, 'Sciarpa Giallorossi', 'Giallorossi scarf', '2026-10-23', 576, null, 'calcio'),
  ('accessory.giallorossiFlare', 'accessory', 'giallorossiFlare', 'leggendario', 1800, 'Fumogeno Giallorossi', 'Giallorossi smoke flare', '2026-10-23', 577, null, 'calcio'),
  ('outfit.azzurri_kit', 'outfit', 'azzurri_kit', 'leggendario', 1800, 'Maglia Azzurri del Golfo', 'Azzurri del Golfo jersey', '2026-10-23', 489, null, 'calcio'),
  ('hat.azzurriCap', 'hat', 'azzurriCap', 'leggendario', 1800, 'Berretto Azzurri del Golfo', 'Azzurri del Golfo bobble hat', '2026-10-23', 179, null, 'calcio'),
  ('accessory.azzurriScarf', 'accessory', 'azzurriScarf', 'leggendario', 1800, 'Sciarpa Azzurri del Golfo', 'Azzurri del Golfo scarf', '2026-10-23', 578, null, 'calcio'),
  ('accessory.azzurriFlag', 'accessory', 'azzurriFlag', 'leggendario', 1800, 'Bandiera Azzurri del Golfo', 'Azzurri del Golfo flag', '2026-10-23', 579, null, 'calcio')
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en,
  collection = excluded.collection;

insert into public.shop_bundles (id, tier, discount_pct, name_it, name_en, tagline_it, tagline_en, sort) values
  ('curva_blaugrana', 'premium', 40, 'Curva Blaugrana', 'Blaugrana End', 'Blu e granata, a righe.', 'Blue and garnet stripes.', 200),
  ('curva_merengues', 'premium', 40, 'Curva Merengues', 'Merengues End', 'Bianco candido e oro.', 'Spotless white and gold.', 210),
  ('curva_celesti', 'premium', 40, 'Curva Celesti', 'Celesti End', 'Il celeste del cielo sopra le fabbriche.', 'Sky blue over the factory chimneys.', 220),
  ('curva_diavoli', 'premium', 40, 'Curva Diavoli Rossi', 'Diavoli Rossi End', 'Rosso fuoco, collo nero.', 'Fire red, black collar.', 230),
  ('curva_reds', 'premium', 40, 'Curva Reds del Porto', 'Reds del Porto End', 'Rosso dal porto, e cantano sempre.', 'Harbour red, and always singing.', 240),
  ('curva_rossoneri', 'premium', 40, 'Curva Rossoneri', 'Rossoneri End', 'Righe rosse e nere.', 'Red and black stripes.', 250),
  ('curva_nerazzurri', 'premium', 40, 'Curva Nerazzurri', 'Nerazzurri End', 'Righe nere e azzurre.', 'Black and blue stripes.', 260),
  ('curva_bianconeri', 'premium', 40, 'Curva Bianconeri', 'Bianconeri End', 'Bianco e nero, nient''altro.', 'Black and white, nothing else.', 270),
  ('curva_giallorossi', 'premium', 40, 'Curva Giallorossi', 'Giallorossi End', 'Porpora e oro, a metà.', 'Maroon and gold, halved.', 280),
  ('curva_azzurri', 'premium', 40, 'Curva Azzurri del Golfo', 'Azzurri del Golfo End', 'L''azzurro del golfo e del vulcano.', 'The blue of the bay and the volcano.', 290),
  ('curva', 'premium', 45, 'La Curva', 'The Whole Stand', 'Tutte e dieci le squadre: quaranta pezzi leggendari.', 'All ten teams: forty legendary pieces.', 400)
on conflict (id) do nothing;

insert into public.shop_bundle_items (bundle_id, item_id) values
  ('curva_blaugrana', 'outfit.blaugrana_kit'), ('curva_blaugrana', 'hat.blaugranaCap'), ('curva_blaugrana', 'accessory.blaugranaScarf'), ('curva_blaugrana', 'accessory.blaugranaFlare'),
  ('curva_merengues', 'outfit.merengues_kit'), ('curva_merengues', 'hat.merenguesCap'), ('curva_merengues', 'accessory.merenguesScarf'), ('curva_merengues', 'accessory.merenguesTrophy'),
  ('curva_celesti', 'outfit.celesti_kit'), ('curva_celesti', 'hat.celestiCap'), ('curva_celesti', 'accessory.celestiScarf'), ('curva_celesti', 'accessory.celestiMegaphone'),
  ('curva_diavoli', 'outfit.diavoli_kit'), ('curva_diavoli', 'hat.diavoliCap'), ('curva_diavoli', 'accessory.diavoliScarf'), ('curva_diavoli', 'accessory.diavoliFlare'),
  ('curva_reds', 'outfit.reds_kit'), ('curva_reds', 'hat.redsCap'), ('curva_reds', 'accessory.redsScarf'), ('curva_reds', 'accessory.redsMegaphone'),
  ('curva_rossoneri', 'outfit.rossoneri_kit'), ('curva_rossoneri', 'hat.rossoneriCap'), ('curva_rossoneri', 'accessory.rossoneriScarf'), ('curva_rossoneri', 'accessory.rossoneriFlare'),
  ('curva_nerazzurri', 'outfit.nerazzurri_kit'), ('curva_nerazzurri', 'hat.nerazzurriCap'), ('curva_nerazzurri', 'accessory.nerazzurriScarf'), ('curva_nerazzurri', 'accessory.nerazzurriFlag'),
  ('curva_bianconeri', 'outfit.bianconeri_kit'), ('curva_bianconeri', 'hat.bianconeriCap'), ('curva_bianconeri', 'accessory.bianconeriScarf'), ('curva_bianconeri', 'accessory.bianconeriTrophy'),
  ('curva_giallorossi', 'outfit.giallorossi_kit'), ('curva_giallorossi', 'hat.giallorossiCap'), ('curva_giallorossi', 'accessory.giallorossiScarf'), ('curva_giallorossi', 'accessory.giallorossiFlare'),
  ('curva_azzurri', 'outfit.azzurri_kit'), ('curva_azzurri', 'hat.azzurriCap'), ('curva_azzurri', 'accessory.azzurriScarf'), ('curva_azzurri', 'accessory.azzurriFlag'),
  ('curva', 'outfit.blaugrana_kit'), ('curva', 'hat.blaugranaCap'), ('curva', 'accessory.blaugranaScarf'), ('curva', 'accessory.blaugranaFlare'),
  ('curva', 'outfit.merengues_kit'), ('curva', 'hat.merenguesCap'), ('curva', 'accessory.merenguesScarf'), ('curva', 'accessory.merenguesTrophy'),
  ('curva', 'outfit.celesti_kit'), ('curva', 'hat.celestiCap'), ('curva', 'accessory.celestiScarf'), ('curva', 'accessory.celestiMegaphone'),
  ('curva', 'outfit.diavoli_kit'), ('curva', 'hat.diavoliCap'), ('curva', 'accessory.diavoliScarf'), ('curva', 'accessory.diavoliFlare'),
  ('curva', 'outfit.reds_kit'), ('curva', 'hat.redsCap'), ('curva', 'accessory.redsScarf'), ('curva', 'accessory.redsMegaphone'),
  ('curva', 'outfit.rossoneri_kit'), ('curva', 'hat.rossoneriCap'), ('curva', 'accessory.rossoneriScarf'), ('curva', 'accessory.rossoneriFlare'),
  ('curva', 'outfit.nerazzurri_kit'), ('curva', 'hat.nerazzurriCap'), ('curva', 'accessory.nerazzurriScarf'), ('curva', 'accessory.nerazzurriFlag'),
  ('curva', 'outfit.bianconeri_kit'), ('curva', 'hat.bianconeriCap'), ('curva', 'accessory.bianconeriScarf'), ('curva', 'accessory.bianconeriTrophy'),
  ('curva', 'outfit.giallorossi_kit'), ('curva', 'hat.giallorossiCap'), ('curva', 'accessory.giallorossiScarf'), ('curva', 'accessory.giallorossiFlare'),
  ('curva', 'outfit.azzurri_kit'), ('curva', 'hat.azzurriCap'), ('curva', 'accessory.azzurriScarf'), ('curva', 'accessory.azzurriFlag')
on conflict do nothing;
