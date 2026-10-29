// The launch waitlist (see handler.ts). It connects with the built-in
// SUPABASE_DB_URL like the game function, so it can reach
// internal.waitlist_join, which alone hands back the tokens for the
// welcome email. The Brevo secrets are Edge Function secrets, read from
// Deno.env only (docs/release.md); without them the mail is skipped.
import postgres from 'npm:postgres@3.4.5';
import { handleWaitlist, type JoinResult } from './handler.ts';

const sql = postgres(Deno.env.get('SUPABASE_DB_URL')!, { prepare: false, max: 2, idle_timeout: 20 });

Deno.serve((req) =>
  handleWaitlist(req, {
    env: (name) => Deno.env.get(name),
    join: async (email, lang, consent, ip) => {
      const [row] = await sql`select internal.waitlist_join(${email}, ${lang}, ${consent}, ${ip}) as r`;
      return row.r as JoinResult;
    },
    unsubscribe: async (token) => {
      await sql`select public.unsubscribe_waitlist(${token})`;
    },
    noteMail: async (token, error) => {
      await (error === null
        ? sql`update internal.waitlist set confirm_sent_at = now(), confirm_error = null where confirm_token = ${token}::uuid`
        : sql`update internal.waitlist set confirm_error = ${error} where confirm_token = ${token}::uuid`);
    },
    fetch,
    log: console.log,
  })
);
