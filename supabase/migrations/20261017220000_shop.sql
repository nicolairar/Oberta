-- The shop: a catalog of cosmetic items, what each player owns, the
-- featured rotation, and the functions that buy and equip. Cosmetics only,
-- never a gameplay advantage; one currency, coins.
--
--   shop_items      the catalog. Readable by signed-in players (enabled
--                   items only). The drawings live in the app: an item id
--                   is `slot.look_id`, and look_id is what profiles.avatar
--                   stores for that slot (for the face slot it is the mark,
--                   and avatar.base becomes `tone_mark`).
--   shop_inventory  what each player owns. Each player reads their own rows.
--   shop_rotations  featured items with a window; readable while live.
--   coin_ledger     every change to a balance, for support and audits.
--
-- Nobody but these functions writes any of it, nor coins or avatar:
-- buy_item, equip_item, unequip_slot (players) and grant_coins (service role
-- only: level-up rewards, and verified App Store purchases later).
--
-- Rarity fixes the price: comune 350, raro 700, epico 1100, leggendario
-- 1800. Items of rarity `base` cost nothing and everyone owns them: the free
-- default set (the looks the app already hands out from a player's name).

create table if not exists public.shop_items (
  id text primary key,
  slot text not null check (slot in ('hat', 'face', 'glasses', 'outfit', 'accessory')),
  look_id text not null check (look_id ~ '^[A-Za-z_]{1,40}$'),
  rarity text not null check (rarity in ('base', 'comune', 'raro', 'epico', 'leggendario')),
  price_coins integer not null,
  name_it text not null check (char_length(name_it) between 1 and 60),
  name_en text not null check (char_length(name_en) between 1 and 60),
  released_on date not null default current_date,
  enabled boolean not null default true,
  sort integer not null default 0,
  unique (slot, look_id),
  check (id = slot || '.' || look_id),
  check (price_coins = case rarity
    when 'base' then 0
    when 'comune' then 350
    when 'raro' then 700
    when 'epico' then 1100
    when 'leggendario' then 1800
  end)
);

create table if not exists public.shop_inventory (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  item_id text not null references public.shop_items (id),
  source text not null default 'coins' check (source in ('coins', 'purchase', 'gift')),
  acquired_at timestamptz not null default now(),
  primary key (profile_id, item_id)
);

create table if not exists public.shop_rotations (
  id bigserial primary key,
  item_id text not null references public.shop_items (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  sort integer not null default 0,
  check (ends_at > starts_at)
);

create index if not exists shop_rotations_window on public.shop_rotations (starts_at, ends_at);

create table if not exists public.coin_ledger (
  id bigserial primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  delta integer not null check (delta <> 0),
  reason text not null check (reason in ('buy', 'level_up', 'purchase', 'gift', 'refund')),
  item_id text references public.shop_items (id),
  reference text,
  created_at timestamptz not null default now()
);

create index if not exists coin_ledger_profile on public.coin_ledger (profile_id, created_at);
-- One credit per App Store transaction, so a retried verification never pays twice.
create unique index if not exists coin_ledger_reference on public.coin_ledger (reason, reference) where reference is not null;

alter table public.shop_items enable row level security;
alter table public.shop_inventory enable row level security;
alter table public.shop_rotations enable row level security;
alter table public.coin_ledger enable row level security;

-- Read-only for players; no insert, update or delete grants anywhere.
grant select on public.shop_items, public.shop_inventory, public.shop_rotations, public.coin_ledger to authenticated;

drop policy if exists "the catalog is visible to signed-in players" on public.shop_items;
create policy "the catalog is visible to signed-in players"
  on public.shop_items for select to authenticated
  using (enabled);

drop policy if exists "players see what they own" on public.shop_inventory;
create policy "players see what they own"
  on public.shop_inventory for select to authenticated
  using (profile_id = (select auth.uid()));

drop policy if exists "live rotations are visible" on public.shop_rotations;
create policy "live rotations are visible"
  on public.shop_rotations for select to authenticated
  using (starts_at <= now() and ends_at > now());

drop policy if exists "players see their own ledger" on public.coin_ledger;
create policy "players see their own ledger"
  on public.coin_ledger for select to authenticated
  using (profile_id = (select auth.uid()));

-- Buys an item with coins: enabled, not free, not owned, enough coins. The
-- balance update locks the profile row, so two buys at once queue up, and
-- the inventory key stops a second copy; any failure rolls everything back.
create or replace function public.buy_item(p_item text)
returns setof public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  item public.shop_items;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into item from public.shop_items where id = p_item and enabled;
  if not found then
    raise exception 'item_not_found';
  end if;
  if item.rarity = 'base'
     or exists (select 1 from public.shop_inventory where profile_id = me and item_id = item.id) then
    raise exception 'already_owned';
  end if;
  update public.profiles set coins = coins - item.price_coins
  where id = me and coins >= item.price_coins;
  if not found then
    raise exception 'not_enough_coins';
  end if;
  insert into public.shop_inventory (profile_id, item_id, source) values (me, item.id, 'coins');
  insert into public.coin_ledger (profile_id, delta, reason, item_id) values (me, -item.price_coins, 'buy', item.id);
  return query select * from public.profiles where id = me;
end;
$$;

-- The skin tone of a look: the part of avatar.base before the mark, or,
-- for a look never saved, the tone the app shows.
create or replace function public.avatar_tone(p_avatar jsonb, p_tone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_avatar ->> 'base', '_', 1) in ('porcelain', 'rose', 'olive', 'tan', 'umber', 'ebony')
      then split_part(p_avatar ->> 'base', '_', 1)
    when p_tone in ('porcelain', 'rose', 'olive', 'tan', 'umber', 'ebony') then p_tone
  end;
$$;

-- Wears an owned (or free) item. For the face the tone is kept from the
-- saved look, or taken from p_tone (the app passes the tone it shows, for
-- players who never saved a look).
create or replace function public.equip_item(p_item text, p_tone text default null)
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
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  select * into item from public.shop_items where id = p_item;
  if not found or (item.rarity = 'base' and not item.enabled) then
    raise exception 'item_not_found';
  end if;
  if item.rarity <> 'base'
     and not exists (select 1 from public.shop_inventory where profile_id = me and item_id = item.id) then
    raise exception 'not_owned';
  end if;
  select avatar into current from public.profiles where id = me for update;
  if item.slot = 'face' then
    tone := public.avatar_tone(current, p_tone);
    if tone is null then
      raise exception 'tone_required';
    end if;
    update public.profiles set avatar = current || jsonb_build_object('base', tone || '_' || item.look_id) where id = me;
  else
    update public.profiles set avatar = current || jsonb_build_object(item.slot, item.look_id) where id = me;
  end if;
  return query select * from public.profiles where id = me;
end;
$$;

-- Takes off what is worn in a slot: the app then shows the free piece that
-- comes from the player's name. The face goes back to clean shaven.
create or replace function public.unequip_slot(p_slot text, p_tone text default null)
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
  if p_slot not in ('hat', 'face', 'glasses', 'outfit', 'accessory') then
    raise exception 'bad_slot';
  end if;
  select avatar into current from public.profiles where id = me for update;
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

-- Credits (or, for refunds, debits) coins. Service role only: the level-up
-- reward and the App Store verification will call it. p_reference is the
-- App Store transaction id, so the same purchase is never credited twice.
create or replace function public.grant_coins(p_profile uuid, p_amount integer, p_reason text, p_reference text default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  balance integer;
begin
  insert into public.coin_ledger (profile_id, delta, reason, reference) values (p_profile, p_amount, p_reason, p_reference);
  update public.profiles set coins = coins + p_amount where id = p_profile returning coins into balance;
  if not found then
    raise exception 'player_not_found';
  end if;
  return balance;
end;
$$;

revoke all on function public.buy_item(text) from public, anon, authenticated;
revoke all on function public.avatar_tone(jsonb, text) from public, anon, authenticated;
revoke all on function public.equip_item(text, text) from public, anon, authenticated;
revoke all on function public.unequip_slot(text, text) from public, anon, authenticated;
revoke all on function public.grant_coins(uuid, integer, text, text) from public, anon, authenticated;
grant execute on function public.buy_item(text) to authenticated;
grant execute on function public.equip_item(text, text) to authenticated;
grant execute on function public.unequip_slot(text, text) to authenticated;
grant execute on function public.grant_coins(uuid, integer, text, text) to service_role;

-- The first catalog. Base items: the free set everyone already wears.
insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort) values
  ('hat.fedora', 'hat', 'fedora', 'base', 0, 'Fedora', 'Fedora', '2026-10-17', 100),
  ('hat.bowler', 'hat', 'bowler', 'base', 0, 'Bombetta', 'Bowler', '2026-10-17', 101),
  ('hat.coppola', 'hat', 'coppola', 'base', 0, 'Coppola', 'Flat cap', '2026-10-17', 102),
  ('hat.slicked', 'hat', 'slicked', 'base', 0, 'Brillantina', 'Slicked back', '2026-10-17', 103),
  ('hat.bob', 'hat', 'bob', 'base', 0, 'Caschetto', 'Bob', '2026-10-17', 104),
  ('hat.bun', 'hat', 'bun', 'base', 0, 'Chignon', 'Chignon', '2026-10-17', 105),
  ('hat.wideBrim', 'hat', 'wideBrim', 'base', 0, 'Tesa larga', 'Wide brim', '2026-10-17', 106),
  ('face.clean', 'face', 'clean', 'base', 0, 'Sbarbato', 'Clean shaven', '2026-10-17', 200),
  ('face.mustache', 'face', 'mustache', 'base', 0, 'Baffi', 'Moustache', '2026-10-17', 201),
  ('face.lips', 'face', 'lips', 'base', 0, 'Rossetto', 'Red lips', '2026-10-17', 202),
  ('face.scar', 'face', 'scar', 'base', 0, 'Cicatrice', 'Scar', '2026-10-17', 203),
  ('face.stubble', 'face', 'stubble', 'base', 0, 'Barba di tre giorni', 'Stubble', '2026-10-17', 204),
  ('face.goatee', 'face', 'goatee', 'base', 0, 'Pizzetto', 'Goatee', '2026-10-17', 205),
  ('face.mole', 'face', 'mole', 'base', 0, 'Neo', 'Beauty mark', '2026-10-17', 206),
  ('glasses.none', 'glasses', 'none', 'base', 0, 'Niente occhiali', 'No glasses', '2026-10-17', 300),
  ('glasses.round', 'glasses', 'round', 'base', 0, 'Occhiali tondi', 'Round glasses', '2026-10-17', 301),
  ('glasses.monocle', 'glasses', 'monocle', 'base', 0, 'Monocolo', 'Monocle', '2026-10-17', 302),
  ('glasses.shades', 'glasses', 'shades', 'base', 0, 'Occhiali scuri', 'Dark glasses', '2026-10-17', 303),
  ('outfit.charcoal_pinstripe', 'outfit', 'charcoal_pinstripe', 'base', 0, 'Gessato antracite', 'Charcoal pinstripe', '2026-10-17', 400),
  ('outfit.navy_double', 'outfit', 'navy_double', 'base', 0, 'Doppiopetto blu', 'Navy double-breasted', '2026-10-17', 401),
  ('outfit.bottle_green', 'outfit', 'bottle_green', 'base', 0, 'Verde bottiglia', 'Bottle green', '2026-10-17', 402),
  ('outfit.camel_check', 'outfit', 'camel_check', 'base', 0, 'Quadretti cammello', 'Camel check', '2026-10-17', 403),
  ('outfit.plum_velvet', 'outfit', 'plum_velvet', 'base', 0, 'Velluto prugna', 'Plum velvet', '2026-10-17', 404),
  ('outfit.cream_dinner', 'outfit', 'cream_dinner', 'base', 0, 'Giacca da sera crema', 'Cream dinner jacket', '2026-10-17', 405),
  ('outfit.slate_check', 'outfit', 'slate_check', 'base', 0, 'Quadretti ardesia', 'Slate check', '2026-10-17', 406),
  ('outfit.wine_silk', 'outfit', 'wine_silk', 'base', 0, 'Seta vinaccia', 'Wine silk', '2026-10-17', 407),
  ('outfit.rust_tweed', 'outfit', 'rust_tweed', 'base', 0, 'Tweed ruggine', 'Rust tweed', '2026-10-17', 408),
  ('outfit.olive_pinstripe', 'outfit', 'olive_pinstripe', 'base', 0, 'Gessato oliva', 'Olive pinstripe', '2026-10-17', 409),
  ('outfit.black_tuxedo', 'outfit', 'black_tuxedo', 'base', 0, 'Smoking nero', 'Black tuxedo', '2026-10-17', 410),
  ('accessory.none', 'accessory', 'none', 'base', 0, 'Collo aperto', 'Open collar', '2026-10-17', 500),
  ('accessory.tie', 'accessory', 'tie', 'base', 0, 'Cravatta', 'Tie', '2026-10-17', 501),
  ('accessory.bowTie', 'accessory', 'bowTie', 'base', 0, 'Papillon', 'Bow tie', '2026-10-17', 502),
  ('accessory.pearls', 'accessory', 'pearls', 'base', 0, 'Perle', 'Pearls', '2026-10-17', 503),
  ('accessory.scarf', 'accessory', 'scarf', 'base', 0, 'Sciarpa', 'Scarf', '2026-10-17', 504),
  ('accessory.carnation', 'accessory', 'carnation', 'base', 0, 'Garofano', 'Carnation', '2026-10-17', 505),
  ('accessory.cigar', 'accessory', 'cigar', 'base', 0, 'Sigaro', 'Cigar', '2026-10-17', 506),
  ('accessory.cigarette', 'accessory', 'cigarette', 'base', 0, 'Sigaretta', 'Cigarette', '2026-10-17', 507),
  ('accessory.toothpick', 'accessory', 'toothpick', 'base', 0, 'Stuzzicadenti', 'Toothpick', '2026-10-17', 508),
  -- For sale.
  ('face.pencil', 'face', 'pencil', 'comune', 350, 'Baffetto a matita', 'Pencil moustache', '2026-10-17', 210),
  ('face.handlebar', 'face', 'handlebar', 'comune', 350, 'Baffi a manubrio', 'Handlebar moustache', '2026-10-17', 211),
  ('face.walrus', 'face', 'walrus', 'comune', 350, 'Baffoni a tricheco', 'Walrus moustache', '2026-10-17', 212),
  ('face.imperial', 'face', 'imperial', 'comune', 350, 'Baffi all''imperiale', 'Imperial', '2026-10-17', 213),
  ('accessory.polkaTie', 'accessory', 'polkaTie', 'comune', 350, 'Cravatta a pois', 'Polka-dot tie', '2026-10-17', 510),
  ('accessory.cravat', 'accessory', 'cravat', 'comune', 350, 'Foulard di seta', 'Silk cravat', '2026-10-17', 511),
  ('accessory.pocketSquare', 'accessory', 'pocketSquare', 'comune', 350, 'Fazzoletto da taschino', 'Pocket square', '2026-10-17', 512),
  ('accessory.pipe', 'accessory', 'pipe', 'comune', 350, 'Pipa', 'Pipe', '2026-10-17', 513),
  ('accessory.pocketWatch', 'accessory', 'pocketWatch', 'comune', 350, 'Catena d''orologio', 'Watch chain', '2026-10-17', 514),
  ('hat.borsalino', 'hat', 'borsalino', 'raro', 700, 'Borsalino', 'Borsalino', '2026-10-17', 110),
  ('hat.panama', 'hat', 'panama', 'raro', 700, 'Panama', 'Panama', '2026-10-17', 111),
  ('hat.trilby', 'hat', 'trilby', 'raro', 700, 'Trilby', 'Trilby', '2026-10-17', 112),
  ('hat.homburg', 'hat', 'homburg', 'raro', 700, 'Homburg', 'Homburg', '2026-10-17', 113),
  ('hat.boater', 'hat', 'boater', 'raro', 700, 'Paglietta', 'Boater', '2026-10-17', 114),
  ('hat.topHat', 'hat', 'topHat', 'raro', 700, 'Cilindro', 'Top hat', '2026-10-17', 115),
  ('glasses.pinceNez', 'glasses', 'pinceNez', 'raro', 700, 'Pince-nez', 'Pince-nez', '2026-10-17', 310),
  ('glasses.tortoise', 'glasses', 'tortoise', 'raro', 700, 'Occhiali di tartaruga', 'Tortoiseshell glasses', '2026-10-17', 311),
  ('glasses.aviator', 'glasses', 'aviator', 'raro', 700, 'Occhiali da aviatore', 'Aviators', '2026-10-17', 312),
  ('outfit.navy_chalkstripe', 'outfit', 'navy_chalkstripe', 'epico', 1100, 'Gessato blu', 'Navy chalk stripe', '2026-10-17', 420),
  ('outfit.grey_flannel', 'outfit', 'grey_flannel', 'epico', 1100, 'Flanella grigia', 'Grey flannel', '2026-10-17', 421),
  ('outfit.brown_pinstripe', 'outfit', 'brown_pinstripe', 'epico', 1100, 'Gessato marrone', 'Brown pinstripe', '2026-10-17', 422),
  ('outfit.cream_linen', 'outfit', 'cream_linen', 'epico', 1100, 'Lino crema', 'Cream linen', '2026-10-17', 423),
  ('outfit.midnight_double', 'outfit', 'midnight_double', 'epico', 1100, 'Doppiopetto notte', 'Midnight double-breasted', '2026-10-17', 424),
  ('outfit.white_dinner', 'outfit', 'white_dinner', 'epico', 1100, 'Smoking bianco', 'White dinner jacket', '2026-10-17', 425),
  ('outfit.trench_coat', 'outfit', 'trench_coat', 'leggendario', 1800, 'Impermeabile del detective', 'Detective''s trench coat', '2026-10-17', 430),
  ('outfit.gold_brocade', 'outfit', 'gold_brocade', 'leggendario', 1800, 'Smoking di broccato d''oro', 'Gold brocade tuxedo', '2026-10-17', 431)
on conflict (id) do nothing;

-- The first featured window: two weeks from the release.
insert into public.shop_rotations (item_id, starts_at, ends_at, sort)
select item_id, '2026-10-17 00:00+00', '2026-11-01 00:00+00', sort
from (values ('outfit.trench_coat', 0), ('hat.borsalino', 1), ('face.handlebar', 2), ('glasses.aviator', 3)) as featured (item_id, sort)
where not exists (select 1 from public.shop_rotations);
