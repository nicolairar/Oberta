-- Gesti: table reactions. A player throws a gesture at another seat (a lit
-- cigar, a whiskey toast, a hat tip, a finger on the lips, ...) and every
-- phone in the room plays it flying from seat to seat.
--
--   shop_items, slot 'gesture'   six free gestures (rarity base, owned by
--                                everyone) and seven for sale, plus the
--                                bundle 'repertorio'. They are bought through
--                                buy_item / buy_bundle like any piece, but
--                                never worn: equip_item refuses them.
--   profiles.table_reactions     the owner's switch in Settings (default
--                                on): off, nobody can throw gestures at them.
--   table_reactions              one row per gesture thrown, readable by the
--                                room's members (minus senders the reader
--                                blocked), delivered through Realtime and
--                                pruned after ten minutes. Written only by
--                                send_reaction.
--   send_reaction(room, target_seat, reaction_id)
--                                validates everything: membership, phase
--                                (lobby, or a day phase of the game for a
--                                living sender and a living target; never at
--                                night), an 8-second cooldown, a per-game cap
--                                of 40, ownership of paid gestures, blocks in
--                                either direction and the target's switch.
--                                Blocked or muted targets are skipped
--                                silently (returns 0) so the sender learns
--                                nothing.
--
-- In a lobby target_seat is the room_members seat number ('3'); in a game
-- it is the game seat ('s3'). The CLI applies the file in one transaction;
-- re-running is harmless.

alter table public.shop_items drop constraint if exists shop_items_slot_check;
alter table public.shop_items add constraint shop_items_slot_check
  check (slot in ('hat', 'face', 'glasses', 'outfit', 'accessory', 'hairdo', 'tattoo', 'border', 'nameStyle', 'gesture'));

insert into public.shop_items (id, slot, look_id, rarity, price_coins, name_it, name_en, released_on, sort) values
  ('gesture.cigar', 'gesture', 'cigar', 'base', 0, 'Sigaro acceso', 'Lit cigar', '2026-11-09', 1000),
  ('gesture.toast', 'gesture', 'toast', 'base', 0, 'Brindisi', 'Whiskey toast', '2026-11-09', 1001),
  ('gesture.hatTip', 'gesture', 'hatTip', 'base', 0, 'Giù il cappello', 'Hat tip', '2026-11-09', 1002),
  ('gesture.omerta', 'gesture', 'omerta', 'base', 0, 'Acqua in bocca', 'Not a word', '2026-11-09', 1003),
  ('gesture.eye', 'gesture', 'eye', 'base', 0, 'Ti tengo d''occhio', 'I''m watching you', '2026-11-09', 1004),
  ('gesture.coin', 'gesture', 'coin', 'base', 0, 'Testa o croce', 'Coin flip', '2026-11-09', 1005),
  ('gesture.fish', 'gesture', 'fish', 'comune', 350, 'Dorme con i pesci', 'Sleeps with the fishes', '2026-11-09', 1010),
  ('gesture.gun', 'gesture', 'gun', 'raro', 700, 'Pistola fumante', 'Smoking gun', '2026-11-09', 1011),
  ('gesture.cash', 'gesture', 'cash', 'raro', 700, 'Valigetta di contanti', 'Briefcase of cash', '2026-11-09', 1012),
  ('gesture.rose', 'gesture', 'rose', 'epico', 1100, 'Rosa sulla bara', 'Rose on the coffin', '2026-11-09', 1013),
  ('gesture.kiss', 'gesture', 'kiss', 'epico', 1100, 'Il baciamano', 'Kiss the ring', '2026-11-09', 1014),
  ('gesture.horse', 'gesture', 'horse', 'leggendario', 1800, 'Un''offerta che non puoi rifiutare', 'An offer you can''t refuse', '2026-11-09', 1015),
  ('gesture.tommy', 'gesture', 'tommy', 'leggendario', 1800, 'Raffica di mitra', 'Tommy gun burst', '2026-11-09', 1016)
on conflict (id) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en;

insert into public.shop_bundles (id, tier, discount_pct, name_it, name_en, tagline_it, tagline_en, sort) values
  ('repertorio', 'premium', 40, 'Il Repertorio', 'The Repertoire', 'Tutti i gesti della famiglia: al tavolo si parla anche senza parlare.', 'Every gesture of the family: at the table you talk without a word.', 600)
on conflict (id) do nothing;

insert into public.shop_bundle_items (bundle_id, item_id) values
  ('repertorio', 'gesture.fish'), ('repertorio', 'gesture.gun'), ('repertorio', 'gesture.cash'), ('repertorio', 'gesture.rose'),
  ('repertorio', 'gesture.kiss'), ('repertorio', 'gesture.horse'), ('repertorio', 'gesture.tommy')
on conflict do nothing;

-- Gestures are thrown, not worn.
create or replace function public.equip_item(p_item text, p_tone text default null, p_current jsonb default null)
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
  if not found or (item.rarity = 'base' and not item.enabled) or item.slot = 'gesture' then
    raise exception 'item_not_found';
  end if;
  if item.rarity <> 'base'
     and not exists (select 1 from public.shop_inventory where profile_id = me and item_id = item.id) then
    raise exception 'not_owned';
  end if;
  select avatar into current from public.profiles where id = me for update;
  current := coalesce(p_current, '{}'::jsonb) || coalesce(current, '{}'::jsonb);
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
revoke all on function public.equip_item(text, text, jsonb) from public, anon;
grant execute on function public.equip_item(text, text, jsonb) to authenticated;

alter table public.profiles add column if not exists table_reactions boolean not null default true;
grant update (handle, language, picture, public_profile, table_reactions) on public.profiles to authenticated;

create table if not exists public.table_reactions (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms (id) on delete cascade,
  -- Null in the lobby.
  game_id uuid,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  from_seat text not null,
  to_seat text not null,
  reaction text not null check (reaction ~ '^[a-zA-Z]{1,24}$'),
  created_at timestamptz not null default now()
);
create index if not exists table_reactions_by_room on public.table_reactions (room_id, id);
create index if not exists table_reactions_by_sender on public.table_reactions (profile_id, created_at);
create index if not exists table_reactions_by_age on public.table_reactions (created_at);
alter table public.table_reactions enable row level security;
revoke all on public.table_reactions from anon, authenticated;
grant select on public.table_reactions to authenticated;

drop policy if exists "members see the room's gestures" on public.table_reactions;
create policy "members see the room's gestures"
  on public.table_reactions for select
  to authenticated
  using (
    (select public.is_room_member(room_id))
    and not exists (
      select 1 from public.player_blocks b
      where b.blocker = (select auth.uid()) and b.blocked = table_reactions.profile_id
    )
  );

create or replace function public.send_reaction(room uuid, target_seat text, reaction_id text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  r public.rooms;
  g public.game_public;
  s public.game_seats;
  t public.game_seats;
  item public.shop_items;
  from_ text;
  target uuid;
  last_at timestamptz;
  sent integer;
  new_id bigint;
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_room_member(room) then
    raise exception 'not_allowed';
  end if;
  select * into item from public.shop_items
  where id = 'gesture.' || coalesce(reaction_id, '') and slot = 'gesture';
  if not found or not item.enabled then
    raise exception 'item_not_found';
  end if;
  if item.rarity <> 'base'
     and not exists (select 1 from public.shop_inventory where profile_id = me and item_id = item.id) then
    raise exception 'not_owned';
  end if;

  select * into r from public.rooms where id = room;
  if r.status = 'lobby' then
    select m.seat::text into from_ from public.room_members m
    where m.room_id = room and m.profile_id = me and m.left_at is null;
    select m.profile_id into target from public.room_members m
    where m.room_id = room and m.seat::text = target_seat and m.left_at is null;
    if target is null or target = me then
      raise exception 'reaction_closed';
    end if;
  elsif r.status = 'playing' then
    select * into g from public.game_public where room_id = room;
    select * into s from public.game_seats where room_id = room and profile_id = me;
    select * into t from public.game_seats where room_id = room and seat = target_seat;
    -- Day phases only (discussion and vote), between the living.
    if g.room_id is null or g.chat_mode <> 'day' or s.seat is null or not s.alive
       or t.seat is null or not t.alive or t.seat = s.seat then
      raise exception 'reaction_closed';
    end if;
    from_ := s.seat;
    target := t.profile_id;
  else
    raise exception 'reaction_closed';
  end if;

  select max(created_at) into last_at from public.table_reactions where profile_id = me;
  if last_at is not null and last_at > now() - interval '8 seconds' then
    raise exception 'reaction_cooldown';
  end if;
  if g.room_id is not null then
    select count(*) into sent from public.table_reactions
    where room_id = room and profile_id = me and game_id = g.game_id;
  else
    select count(*) into sent from public.table_reactions
    where room_id = room and profile_id = me and game_id is null and created_at > now() - interval '1 hour';
  end if;
  if sent >= 40 then
    raise exception 'reaction_cap';
  end if;

  -- A bot (null profile) takes everything; a person can say no.
  if target is not null and (
    exists (
      select 1 from public.player_blocks b
      where (b.blocker = target and b.blocked = me) or (b.blocker = me and b.blocked = target)
    )
    or not coalesce((select p.table_reactions from public.profiles p where p.id = target), true)
  ) then
    return 0;
  end if;

  delete from public.table_reactions where created_at < now() - interval '10 minutes';
  insert into public.table_reactions (room_id, game_id, profile_id, from_seat, to_seat, reaction)
  values (room, g.game_id, me, from_, target_seat, item.look_id)
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.send_reaction(uuid, text, text) from public, anon;
grant execute on function public.send_reaction(uuid, text, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'table_reactions'
     ) then
    alter publication supabase_realtime add table public.table_reactions;
  end if;
end;
$$;
