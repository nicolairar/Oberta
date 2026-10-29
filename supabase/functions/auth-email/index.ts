// Supabase Auth's Send Email Hook (see handler.ts): the sign-in emails, code
// and magic link, through Brevo. Deployed without JWT verification: Auth
// signs every call with SEND_EMAIL_HOOK_SECRET (standard-webhooks), and the
// images are public GETs.
import { handleAuthEmail } from './handler.ts';

Deno.serve((req) =>
  handleAuthEmail(req, {
    env: (name) => Deno.env.get(name),
    fetch,
    log: console.log,
  })
);
