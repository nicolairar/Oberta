-- Cornici e nomi: two slots that are not worn on the portrait but around it.
--
--   border     the frame drawn around a player's seat card and portrait
--              (brass filigree, velvet, mosaic, film strip, playing-card
--              suits, art deco, barbed wire, roses, neon, and two animated
--              legendaries: a ring of fire and a pulsing neon tube).
--   nameStyle  the ink of the player's name on the seat plate and in chat
--              (solid colours, gold and silver foil, a sunset gradient, a
--              neon glow, and two animated legendaries).
--
-- Both live in profiles.avatar under their slot name, like every other
-- piece, so they travel wherever looks are already published: the avatar
-- column other players may read on profiles, room members (which embed the
-- profile) and the friends list. Each slot has a free piece (`none`,
-- `plain`) that everyone owns, like glasses.
--
-- equip_item already writes avatar[item.slot] for any catalog slot, so it
-- needs no change; unequip_slot learns the two new slot names. Purchases
-- still go through buy_item and buy_bundle only; tables keep their RLS and
-- grants. The CLI applies the file in one transaction; re-running is harmless.

alter table public.shop_items drop constraint if exists shop_items_slot_check;
alter table public.shop_items add constraint shop_items_slot_check
  check (slot in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo', 'border', 'nameStyle'));

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort) values
  ('border.none', 'border', 'none', 'base', 0, 'Nessuna cornice', 'No frame', '2026-10-24', 800),
  ('border.brass', 'border', 'brass', 'comune', 350, 'Filigrana d''ottone', 'Brass filigree', '2026-10-24', 801),
  ('border.velvet', 'border', 'velvet', 'comune', 350, 'Velluto rosso sangue', 'Blood-red velvet', '2026-10-24', 802),
  ('border.mosaic', 'border', 'mosaic', 'raro', 700, 'Mosaico', 'Mosaic', '2026-10-24', 803),
  ('border.filmStrip', 'border', 'filmStrip', 'raro', 700, 'Pellicola', 'Film strip', '2026-10-24', 804),
  ('border.suits', 'border', 'suits', 'raro', 700, 'Quattro semi', 'Four suits', '2026-10-24', 805),
  ('border.artDeco', 'border', 'artDeco', 'epico', 1100, 'Oro art déco', 'Art deco gold', '2026-10-24', 806),
  ('border.barbedWire', 'border', 'barbedWire', 'epico', 1100, 'Filo spinato', 'Barbed wire', '2026-10-24', 807),
  ('border.roseThorns', 'border', 'roseThorns', 'epico', 1100, 'Rose e spine', 'Roses and thorns', '2026-10-24', 808),
  ('border.neonPink', 'border', 'neonPink', 'epico', 1100, 'Neon rosa', 'Pink neon', '2026-10-24', 809),
  ('border.flame', 'border', 'flame', 'leggendario', 1800, 'Cornice di fuoco', 'Ring of fire', '2026-10-24', 810),
  ('border.neonPulse', 'border', 'neonPulse', 'leggendario', 1800, 'Neon pulsante', 'Pulsing neon', '2026-10-24', 811),
  ('nameStyle.plain', 'nameStyle', 'plain', 'base', 0, 'Inchiostro semplice', 'Plain ink', '2026-10-24', 900),
  ('nameStyle.crimson', 'nameStyle', 'crimson', 'comune', 350, 'Rosso cremisi', 'Crimson', '2026-10-24', 901),
  ('nameStyle.emerald', 'nameStyle', 'emerald', 'comune', 350, 'Verde smeraldo', 'Emerald', '2026-10-24', 902),
  ('nameStyle.sapphire', 'nameStyle', 'sapphire', 'comune', 350, 'Blu zaffiro', 'Sapphire', '2026-10-24', 903),
  ('nameStyle.violet', 'nameStyle', 'violet', 'comune', 350, 'Viola', 'Violet', '2026-10-24', 904),
  ('nameStyle.goldFoil', 'nameStyle', 'goldFoil', 'raro', 700, 'Foglia d''oro', 'Gold foil', '2026-10-24', 905),
  ('nameStyle.silverFoil', 'nameStyle', 'silverFoil', 'raro', 700, 'Foglia d''argento', 'Silver foil', '2026-10-24', 906),
  ('nameStyle.tramonto', 'nameStyle', 'tramonto', 'epico', 1100, 'Tramonto', 'Sunset', '2026-10-24', 907),
  ('nameStyle.neonGlow', 'nameStyle', 'neonGlow', 'epico', 1100, 'Insegna al neon', 'Neon sign', '2026-10-24', 908),
  ('nameStyle.shimmer', 'nameStyle', 'shimmer', 'leggendario', 1800, 'Oro scintillante', 'Shimmering gold', '2026-10-24', 909),
  ('nameStyle.inferno', 'nameStyle', 'inferno', 'leggendario', 1800, 'Inferno', 'Inferno', '2026-10-24', 910)
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en;

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
  if p_slot not in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo', 'border', 'nameStyle') then
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

insert into public.shop_bundles (id, tier, discount_pct, name_it, name_en, tagline_it, tagline_en, sort) values
  ('insegna_neon', 'set', 35, 'Insegna al Neon', 'Neon Sign', 'Rosa neon intorno, rosa neon nel nome.', 'Pink neon round the seat and in the name.', 500),
  ('bisca', 'set', 35, 'La Bisca', 'The Card Den', 'Velluto, quattro semi e un nome d''oro.', 'Velvet, four suits and a golden name.', 510),
  ('giardino', 'set', 30, 'Il Giardino', 'The Rose Garden', 'Rose, spine e un nome al tramonto.', 'Roses, thorns and a sunset name.', 520),
  ('leggenda', 'premium', 40, 'La Leggenda', 'The Legend', 'Fuoco, neon e oro che si muovono: al tavolo ti vedono da lontano.', 'Moving fire, neon and gold: the whole table sees you coming.', 530)
on conflict (id) do nothing;

insert into public.shop_bundle_items (bundle_id, item_id) values
  ('insegna_neon', 'border.neonPink'), ('insegna_neon', 'nameStyle.neonGlow'),
  ('bisca', 'border.suits'), ('bisca', 'border.velvet'), ('bisca', 'nameStyle.goldFoil'),
  ('giardino', 'border.roseThorns'), ('giardino', 'nameStyle.tramonto'), ('giardino', 'nameStyle.crimson'),
  ('leggenda', 'border.flame'), ('leggenda', 'border.neonPulse'), ('leggenda', 'border.artDeco'), ('leggenda', 'nameStyle.shimmer'), ('leggenda', 'nameStyle.inferno')
on conflict do nothing;
