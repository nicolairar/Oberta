// The voice chat's door (see handler.ts): the player's JWT says who asks
// (verify_jwt = true in config.toml, and checked again with Auth here), the
// database says what the game allows, LiveKit gets a token for exactly that.
// It connects with the built-in SUPABASE_DB_URL like the game function; the
// LiveKit secrets are Edge Function secrets, read from Deno.env only.
import postgres from 'npm:postgres@3.4.5';
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { liveKitEnv, roomService } from '../_shared/livekit.ts';
import { sqlVoiceStore } from '../_shared/voice_sync.ts';
import { handleVoiceToken } from './handler.ts';

const sql = postgres(Deno.env.get('SUPABASE_DB_URL')!, { prepare: false, max: 2, idle_timeout: 20 });
const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const store = sqlVoiceStore({ query: (text, params = []) => sql.unsafe(text, params as never[]) as never });
const env = (name: string) => Deno.env.get(name);
const lk = liveKitEnv(env);

Deno.serve((req) =>
  handleVoiceToken(req, {
    env,
    userFor: async (jwt) => {
      const { data, error } = await admin.auth.getUser(jwt);
      return error ? null : data?.user?.id ?? null;
    },
    store,
    service: lk ? roomService(lk) : null,
    now: Date.now,
  })
);
