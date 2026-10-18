-- Equipping saved only the changed slot, and the app re-derived every other
-- slot from the player's name: in some places that differed from what the
-- player saw, so wearing a hat could change the suit. Now the app sends the
-- whole look it shows (p_current), saved underneath the stored one.

drop function if exists public.equip_item(text, text);
drop function if exists public.unequip_slot(text, text);

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
  if not found or (item.rarity = 'base' and not item.enabled) then
    raise exception 'item_not_found';
  end if;
  if item.rarity <> 'base'
     and not exists (select 1 from public.shop_inventory where profile_id = me and item_id = item.id) then
    raise exception 'not_owned';
  end if;
  select avatar into current from public.profiles where id = me for update;
  -- The whole look the app shows, then what is already saved on top: only
  -- the slot being changed moves, nothing else is re-derived from the name.
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

-- Takes off what is worn in a slot: the app then shows the free piece that
-- comes from the player's name. The face goes back to clean shaven.
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
  if p_slot not in ('hat', 'face', 'glasses', 'outfit', 'accessory') then
    raise exception 'bad_slot';
  end if;
  select avatar into current from public.profiles where id = me for update;
  -- The whole look the app shows, then what is already saved on top: only
  -- the slot being changed moves, nothing else is re-derived from the name.
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


revoke all on function public.equip_item(text, text, jsonb) from public, anon;
grant execute on function public.equip_item(text, text, jsonb) to authenticated;
revoke all on function public.unequip_slot(text, text, jsonb) from public, anon;
grant execute on function public.unequip_slot(text, text, jsonb) to authenticated;
