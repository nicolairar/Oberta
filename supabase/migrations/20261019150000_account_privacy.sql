-- Privacy: a player can download their own data (GDPR art. 15/20) and delete
-- their account from inside the app (GDPR art. 17, App Store guideline
-- 5.1.1(v)).
--
-- Export: public.export_my_data() returns everything tied to the caller as
-- one JSON document. The app shares it with the iOS share sheet.
--
-- Deletion: the Edge Function `account` (supabase/functions/account) checks
-- the caller's JWT, calls public.forget_account() with the service role, then
-- deletes the auth user. Every personal table cascades from profiles, which
-- cascades from auth.users: profile, friendships, inventory, coin ledger,
-- room memberships, seats, intents, chat messages and abandons all go.
--
-- What is kept, and why: coin purchases made with real money ('purchase')
-- and their refunds are copied, without any link to the person, into
-- internal.deleted_purchases. Tax and consumer law (and App Store refund
-- disputes) require keeping a record of paid transactions for years; the
-- copy holds only the App Store transaction reference, the amount, the date
-- and a random id, so it is no longer personal data on our side.

create table if not exists internal.deleted_purchases (
  id bigint generated always as identity primary key,
  -- Random per deleted account: groups one person's rows, names nobody.
  deletion_id uuid not null,
  delta integer not null,
  reason text not null,
  item_id text,
  reference text,
  created_at timestamptz not null,
  deleted_at timestamptz not null default now()
);

revoke all on internal.deleted_purchases from public, anon, authenticated;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_signed_in';
  end if;
  return jsonb_build_object(
    'exported_at', now(),
    'account_id', me,
    'profile', (select to_jsonb(p) from public.profiles p where p.id = me),
    'friendships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'requester', f.requester,
        'addressee', f.addressee,
        'other_handle', o.handle,
        'status', to_jsonb(f) -> 'status',
        'created_at', to_jsonb(f) -> 'created_at'))
      from public.friendships f
      left join public.profiles o
        on o.id = case when f.requester = me then f.addressee else f.requester end
      where me in (f.requester, f.addressee)), '[]'::jsonb),
    'inventory', coalesce((
      select jsonb_agg(to_jsonb(i)) from public.shop_inventory i where i.profile_id = me), '[]'::jsonb),
    'coin_ledger', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.created_at) from public.coin_ledger l where l.profile_id = me), '[]'::jsonb),
    'room_memberships', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.joined_at) from public.room_members m where m.profile_id = me), '[]'::jsonb),
    'chat_messages', coalesce((
      select jsonb_agg(to_jsonb(c)) from public.game_chat c where c.profile_id = me), '[]'::jsonb),
    'abandons', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.abandoned_at) from internal.game_abandons a where a.profile_id = me), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- Called only by the `account` Edge Function, with the service role, after
-- it has verified the caller's JWT. Leaves open rooms the polite way (the
-- host passes to the next player instead of the room vanishing), keeps the
-- anonymous purchase records, then deletes the profile and everything that
-- cascades from it. The function deletes the auth user right after.
create or replace function public.forget_account(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership record;
  deletion uuid := gen_random_uuid();
begin
  for membership in
    select room_id from public.room_members where profile_id = target and left_at is null
  loop
    perform public._leave_room(membership.room_id, target);
  end loop;

  insert into internal.deleted_purchases (deletion_id, delta, reason, item_id, reference, created_at)
  select deletion, l.delta, l.reason, l.item_id, l.reference, l.created_at
  from public.coin_ledger l
  where l.profile_id = target and l.reason in ('purchase', 'refund');

  delete from public.profiles where id = target;
end;
$$;

revoke all on function public.forget_account(uuid) from public, anon, authenticated;
grant execute on function public.forget_account(uuid) to service_role;

-- Retention promised in the privacy policy: chat messages live 90 days.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule(
      'oberta-trim-chat',
      '41 4 * * *',
      $job$delete from public.game_chat where created_at < now() - interval '90 days'$job$
    );
  end if;
end;
$$;
