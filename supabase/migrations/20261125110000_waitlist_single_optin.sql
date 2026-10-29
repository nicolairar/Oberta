-- Single opt-in (owner decision): ticking the consent box and sending the
-- form subscribes; the proof stays the consent text version and time. The
-- email that follows is a welcome with the unsubscribe link, no confirm step.
--
-- * Every row is confirmed at sign-up (confirmed_at = sign-up time).
-- * waitlist_join hands the Edge Function `mail_token` (the row's
--   confirm_token, now only a private key to note how the welcome mail went:
--   confirm_sent_at / confirm_error) and the unsubscribe token, only when new.
-- * public.confirm_waitlist goes away: there is nothing to confirm.
-- Idempotent.

alter table internal.waitlist alter column confirmed set default true;
update internal.waitlist set confirmed = true, confirmed_at = coalesce(confirmed_at, consent_at) where not confirmed;

comment on column internal.waitlist.confirm_token is 'Private row key for the welcome mail outcome (single opt-in: nothing to confirm).';
comment on column internal.waitlist.confirm_sent_at is 'When the welcome email went out.';
comment on column internal.waitlist.confirm_error is 'Why the welcome email did not go out.';

drop function if exists public.confirm_waitlist(text);

create or replace function internal.waitlist_join(email text, lang text, consent_version text, ip text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  addr text := lower(btrim(coalesce(waitlist_join.email, '')));
  code text := lower(btrim(coalesce(waitlist_join.lang, '')));
  consent text := btrim(coalesce(waitlist_join.consent_version, ''));
  client text;
  now_minute timestamptz := date_trunc('minute', now());
  client_hits integer;
  client_hour integer;
  all_hits integer;
  added internal.waitlist;
begin
  -- No ticked box (or an unknown wording), no sign-up.
  if not exists (select 1 from internal.waitlist_consents c where c.version = consent) then
    return jsonb_build_object('ok', false, 'error', 'consent_required');
  end if;
  -- Shape: one @, a plain local part, a dotted domain with a 2+ letter end.
  if length(addr) > 254
    or addr !~ '^[a-z0-9._%+''-]{1,64}@[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]{2,63}$'
    or addr ~ '\.\.' or addr ~ '^\.' or addr ~ '\.@' then
    return jsonb_build_object('ok', false, 'error', 'invalid_email');
  end if;
  if not internal.is_lobby_language(code) then
    code := 'it';
  end if;

  -- Who is asking: the client address, hashed with the secret salt.
  client := md5(coalesce((select c.value from internal.config c where c.key = 'waitlist_salt'), '')
    || ':' || coalesce(nullif(btrim(split_part(coalesce(waitlist_join.ip, ''), ',', 1)), ''), 'unknown'));

  delete from internal.waitlist_hits where minute < now() - interval '1 hour';

  select coalesce(sum(h.hits) filter (where h.minute = now_minute), 0),
         coalesce(sum(h.hits), 0)
    into client_hits, client_hour
    from internal.waitlist_hits h where h.bucket = client;
  select coalesce(sum(h.hits), 0) into all_hits
    from internal.waitlist_hits h where h.minute = now_minute;
  -- 5 a minute and 20 an hour from one client, 120 a minute overall.
  if client_hits >= 5 or client_hour >= 20 or all_hits >= 120 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  insert into internal.waitlist_hits as h (bucket, minute, hits)
  values (client, now_minute, 1)
  on conflict (bucket, minute) do update set hits = h.hits + 1;

  -- Already there: nothing changes (the first consent stays the proof).
  insert into internal.waitlist (email, lang, source, consent_at, consent_version, confirmed, confirmed_at)
  values (addr, code, 'site', now(), consent, true, now())
  on conflict do nothing
  returning * into added;

  if added.id is null then
    return jsonb_build_object('ok', true, 'new', false);
  end if;
  return jsonb_build_object('ok', true, 'new', true, 'lang', added.lang,
    'mail_token', added.confirm_token, 'unsubscribe_token', added.unsubscribe_token);
end;
$$;
revoke all on function internal.waitlist_join(text, text, text, text) from public, anon, authenticated;
