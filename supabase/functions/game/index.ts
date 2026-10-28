// The Edge Function that runs online games. It holds no state: every call
// steps the games that have something due, straight in the database (see
// runner.ts), with the Dart engine compiled to JavaScript (engine.ts).
//
// Only the database calls it, through pg_net (supabase/migrations/
// 20261017180000_server_authority.sql): when a game starts, when a player
// sends a move, and every 2 seconds from pg_cron when a game has something
// due. The call carries a secret the function reads back from
// internal.config, so nobody else can make it run. It connects with the
// built-in SUPABASE_DB_URL; no key lives in the app or the repo.
//
// After the steps, the voice chat (supabase/functions/voice-token): the
// rooms whose voice rights just changed (a stage ended, someone died, the
// Tailor sewed) are pushed to LiveKit at once, so a phone that joined with
// yesterday's rights cannot keep them (see _shared/voice_sync.ts).
import postgres from 'npm:postgres@3.4.5';
import { step } from './engine.ts';
import { type Db, runDue } from './runner.ts';
import { liveKitEnv, roomSeal, roomService } from '../_shared/livekit.ts';
import { sqlVoiceStore, syncVoice } from '../_shared/voice_sync.ts';

const sql = postgres(Deno.env.get('SUPABASE_DB_URL')!, { prepare: false, max: 3, idle_timeout: 20 });

// deno-lint-ignore no-explicit-any
type Sql = any;

function wrap(s: Sql): Db {
  return {
    query: (text, params = []) => s.unsafe(text, params as never[]),
    transaction: (work) => sql.begin((tx: Sql) => work(wrap(tx))) as never,
  };
}

const db = wrap(sql);
let secret: string | null = null;
const lk = liveKitEnv((name) => Deno.env.get(name));
const voice = lk ? { store: sqlVoiceStore(db), service: roomService(lk), seal: roomSeal(lk.secret) } : null;

async function pushVoice(rooms: Set<string>) {
  if (!voice) return;
  for (const room of rooms) {
    try {
      await syncVoice(voice.store, voice.service, room, Date.now(), voice.seal);
    } catch (error) {
      console.error(`voice ${room}:`, error instanceof Error ? error.message : 'failed');
    }
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });
  if (secret === null) {
    const [row] = await sql`select value from internal.config where key = 'wake_secret'`;
    secret = row?.value ?? null;
  }
  if (secret === null || req.headers.get('x-oberta-wake') !== secret) {
    return new Response('forbidden', { status: 403 });
  }
  const body = await req.json().catch(() => ({}));
  const room = typeof body?.room === 'string' ? body.room : null;
  const touched = new Set<string>();
  const stepped = await runDue(db, step, { room, onStep: (r) => touched.add(r) });
  await pushVoice(touched);
  return Response.json({ stepped });
});
