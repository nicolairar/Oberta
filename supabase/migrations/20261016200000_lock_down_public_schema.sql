-- New tables in the public schema are NOT exposed to the app by default.
-- Every table gets its own explicit grants and Row Level Security policies
-- in the migration that creates it: secret roles and ranked data must never
-- leak because someone forgot to lock a table.

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;

-- Applied by the Supabase GitHub integration on every push to main.
