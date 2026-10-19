-- Bundles: a set of existing catalog items sold together at a discount.
-- Every item in a bundle is still sold on its own, at its rarity price; the
-- bundle is the better deal.
--
--   shop_bundles       the bundle: names, tier (set or premium) and its
--                      discount, a whole percentage off the sum of singles.
--   shop_bundle_items  which items a bundle holds.
--
-- The price is never stored and never sent by the app: buy_bundle sums the
-- items the player does not own yet, takes the discount off and rounds down
-- to ten coins (bundle_price). Owning part of a bundle makes it cheaper; owning
-- all of it makes it unbuyable.

create table if not exists public.shop_bundles (
  id text primary key check (id ~ '^[a-z_]{1,40}$'),
  tier text not null check (tier in ('set', 'premium')),
  discount_pct integer not null check (discount_pct between 20 and 50),
  name_it text not null check (char_length(name_it) between 1 and 60),
  name_en text not null check (char_length(name_en) between 1 and 60),
  tagline_it text not null check (char_length(tagline_it) between 1 and 120),
  tagline_en text not null check (char_length(tagline_en) between 1 and 120),
  enabled boolean not null default true,
  sort integer not null default 0
);

create table if not exists public.shop_bundle_items (
  bundle_id text not null references public.shop_bundles (id) on delete cascade,
  item_id text not null references public.shop_items (id),
  primary key (bundle_id, item_id)
);

alter table public.coin_ledger add column if not exists bundle_id text references public.shop_bundles (id);

alter table public.shop_bundles enable row level security;
alter table public.shop_bundle_items enable row level security;

revoke all on table public.shop_bundles, public.shop_bundle_items from public, anon, authenticated;
grant select on table public.shop_bundles, public.shop_bundle_items to authenticated;

drop policy if exists "bundles are visible to signed-in players" on public.shop_bundles;
create policy "bundles are visible to signed-in players"
  on public.shop_bundles for select to authenticated
  using (enabled);

drop policy if exists "bundle contents are visible to signed-in players" on public.shop_bundle_items;
create policy "bundle contents are visible to signed-in players"
  on public.shop_bundle_items for select to authenticated
  using (exists (select 1 from public.shop_bundles b where b.id = bundle_id and b.enabled));

-- What a bundle costs a player: the missing items, discounted, rounded down
-- to ten. The app shows the same formula; this one is the one that charges.
create or replace function public.bundle_price(p_bundle text, p_profile uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select (coalesce(sum(i.price_coins), 0) * (100 - b.discount_pct) / 100 / 10 * 10)::integer
  from public.shop_bundles b
  join public.shop_bundle_items bi on bi.bundle_id = b.id
  join public.shop_items i on i.id = bi.item_id
  where b.id = p_bundle
    and i.rarity <> 'base'
    and not exists (select 1 from public.shop_inventory s where s.profile_id = p_profile and s.item_id = i.id)
  group by b.discount_pct;
$$;

-- Buys every missing item of a bundle at the bundle price. The balance
-- update locks the profile row, so concurrent buys queue up; any failure
-- rolls everything back.
create or replace function public.buy_bundle(p_bundle text)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  price integer;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not exists (select 1 from public.shop_bundles where id = p_bundle and enabled)
     or exists (
       select 1 from public.shop_bundle_items bi join public.shop_items i on i.id = bi.item_id
       where bi.bundle_id = p_bundle and not i.enabled) then
    raise exception 'item_not_found';
  end if;
  -- Lock first, so the price is computed against a stable inventory.
  perform 1 from public.profiles where id = me for update;
  price := public.bundle_price(p_bundle, me);
  if price is null then
    raise exception 'already_owned';
  end if;
  update public.profiles set coins = coins - price where id = me and coins >= price;
  if not found then
    raise exception 'not_enough_coins';
  end if;
  insert into public.shop_inventory (profile_id, item_id, source)
  select me, bi.item_id, 'coins'
  from public.shop_bundle_items bi join public.shop_items i on i.id = bi.item_id
  where bi.bundle_id = p_bundle and i.rarity <> 'base'
  on conflict do nothing;
  if price > 0 then
    insert into public.coin_ledger (profile_id, delta, reason, bundle_id) values (me, -price, 'buy', p_bundle);
  end if;
  return query select * from public.profiles where id = me;
end;
$$;

revoke all on function public.bundle_price(text, uuid) from public, anon, authenticated;
revoke all on function public.buy_bundle(text) from public, anon, authenticated;
grant execute on function public.buy_bundle(text) to authenticated;

insert into public.shop_bundles (id, tier, discount_pct, name_it, name_en, tagline_it, tagline_en, sort) values
  ('ragioniere', 'set', 30, 'Il Ragioniere', 'The Bookkeeper', 'Conti in ordine, baffo in ordine.', 'Neat books, neat moustache.', 10),
  ('detective', 'set', 35, 'Il Detective', 'The Private Eye', 'Impermeabile, trilby e una pipa che pensa.', 'Trench coat, trilby and a thinking pipe.', 20),
  ('padrino', 'set', 35, 'Il Padrino', 'The Godfather', 'Un''offerta che non potrai rifiutare.', 'An offer you can''t refuse.', 30),
  ('pirata', 'set', 38, 'Il Pirata', 'The Pirate', 'Tricorno, benda, barba e pappagallo.', 'Tricorn, patch, beard and parrot.', 40),
  ('nikea', 'set', 35, 'Squadra Nikea', 'Team Nikea', 'Tutto il guardaroba da pista.', 'The whole track wardrobe.', 50),
  ('adelphi', 'set', 35, 'Squadra Adelphi', 'Team Adelphi', 'Il campo dei due fratelli.', 'The two brothers'' squad.', 60),
  ('vaugirard', 'set', 35, 'Il Viaggiatore', 'The Traveller', 'La collezione Vaugirard al completo.', 'The full Vaugirard collection.', 70),
  ('versalli', 'premium', 40, 'Casa Versalli', 'House of Versalli', 'Tutto l''oro del barocco, in un colpo.', 'All the baroque gold, in one go.', 100),
  ('chanterelle', 'premium', 40, 'Maison Chanterelle', 'Maison Chanterelle', 'L''alta moda intera, perle comprese.', 'The whole couture line, pearls included.', 110),
  ('ali', 'premium', 40, 'Paradiso e Inferno', 'Heaven and Hell', 'Aureola, cornetti e quattro paia d''ali.', 'Halo, horns and four pairs of wings.', 120),
  ('tendone', 'premium', 45, 'Il Grande Tendone', 'The Big Top', 'Il circo intero: clown, mimo, forzuto e mago.', 'The whole circus: clown, mime, strongman and magician.', 130),
  ('leggende', 'premium', 40, 'Le Leggende', 'The Legends', 'Dieci pezzi leggendari: il guardaroba di un boss.', 'Ten legendary pieces: a boss''s wardrobe.', 140)
on conflict (id) do nothing;

insert into public.shop_bundle_items (bundle_id, item_id) values
  ('ragioniere', 'glasses.browline'), ('ragioniere', 'face.pencil'), ('ragioniere', 'accessory.knitTie'), ('ragioniere', 'hat.porkPie'),
  ('detective', 'outfit.trench_coat'), ('detective', 'hat.trilby'), ('detective', 'face.pencil'), ('detective', 'accessory.pipe'),
  ('padrino', 'hat.borsalino'), ('padrino', 'outfit.midnight_double'), ('padrino', 'face.walrus'), ('padrino', 'accessory.pocketWatch'), ('padrino', 'accessory.whiteCarnation'),
  ('pirata', 'hat.tricorn'), ('pirata', 'glasses.eyePatch'), ('pirata', 'face.fullBeard'), ('pirata', 'accessory.parrot'),
  ('nikea', 'hat.fulmineCap'), ('nikea', 'outfit.fulmine_track'), ('nikea', 'outfit.fulmine_cardigan'),
  ('adelphi', 'hat.adelphiCap'), ('adelphi', 'outfit.adelphi_track'), ('adelphi', 'outfit.adelphi_cardigan'),
  ('vaugirard', 'outfit.vaugirard_travel'), ('vaugirard', 'hat.vaugirardCap'), ('vaugirard', 'accessory.vaugirardStrap'),
  ('versalli', 'outfit.versalli_baroque'), ('versalli', 'glasses.ricciMonocle'), ('versalli', 'accessory.ricciChain'), ('versalli', 'accessory.ricciTiePin'), ('versalli', 'accessory.ricciWatch'),
  ('chanterelle', 'outfit.delacroix_cape'), ('chanterelle', 'outfit.delacroix_velvet'), ('chanterelle', 'glasses.delacroixShades'), ('chanterelle', 'accessory.delacroixScarf'), ('chanterelle', 'accessory.delacroixAscot'), ('chanterelle', 'accessory.chanterellePearls'),
  ('ali', 'hat.angelHalo'), ('ali', 'hat.devilHorns'), ('ali', 'accessory.angelWings'), ('ali', 'accessory.batWings'), ('ali', 'accessory.butterflyWings'), ('ali', 'accessory.dragonWings'),
  ('tendone', 'hat.clownWig'), ('tendone', 'hat.magicianHat'), ('tendone', 'face.curledMoustache'), ('tendone', 'face.mimeFace'), ('tendone', 'glasses.hypnoGlasses'), ('tendone', 'outfit.clown_suit'), ('tendone', 'outfit.strongman_leotard'), ('tendone', 'outfit.mime_stripes'), ('tendone', 'outfit.magician_cape'), ('tendone', 'accessory.clownNose'),
  ('leggende', 'outfit.trench_coat'), ('leggende', 'outfit.gold_brocade'), ('leggende', 'hat.morettiHomburg'), ('leggende', 'outfit.vanetti_tuxedo'), ('leggende', 'outfit.vanetti_ivory'), ('leggende', 'outfit.delacroix_cape'), ('leggende', 'accessory.ricciWatch'), ('leggende', 'outfit.vaugirard_travel'), ('leggende', 'outfit.versalli_baroque'), ('leggende', 'accessory.chanterellePearls')
on conflict do nothing;
