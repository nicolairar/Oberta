-- Why a confirmation email did not go out (Brevo's status and message, or
-- "secrets_missing"), written by the `waitlist` Edge Function next to
-- confirm_sent_at, so a failed send shows up with a query instead of only in
-- the function logs. Never holds a secret. Idempotent.

alter table internal.waitlist add column if not exists confirm_error text;
