-- Stand-ins for what Supabase provides, so the migrations run in PGlite
-- (supabase/functions/tests/game_test.ts): roles, auth.uid(), the realtime
-- publication, and stubs for pg_net (calls are recorded in net.calls) and
-- pg_cron.
create role anon nologin; create role authenticated nologin; create role service_role nologin;
create schema auth;
create table auth.users (id uuid primary key, raw_user_meta_data jsonb default '{}', email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(coalesce(current_setting('request.jwt.claim.sub', true),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb) ->> 'sub'), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
grant usage on schema public to anon, authenticated;
create publication supabase_realtime;
-- pg_net and pg_cron stubs (Supabase has the real ones).
create schema net;
create table net.calls (id bigserial primary key, url text, body jsonb, headers jsonb);
create function net.http_post(url text, body jsonb default '{}', params jsonb default '{}', headers jsonb default '{}', timeout_milliseconds int default 5000)
returns bigint language sql as $$ insert into net.calls (url, body, headers) values (url, body, headers) returning id $$;
create schema cron;
create table cron.jobs (name text primary key, schedule text, command text);
create table cron.job_run_details (end_time timestamptz);
create function cron.schedule(name text, schedule text, command text) returns bigint language sql as $$
  insert into cron.jobs values (name, schedule, command) on conflict (name) do update set schedule = excluded.schedule, command = excluded.command returning 1::bigint $$;
