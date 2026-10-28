// POST {room} with the player's JWT -> the LiveKit token for the voice room
// that player belongs in right now, with only the rights the game gives
// (voice_rules.ts), or {room: null} when there is none (with retryIn when a
// stage is about to open: the phone asks again then, the server decides).
//
//   200 {room, kind, identity, url, token, canPublish, canSubscribe, expiresIn}
//   200 {room: null, retryIn?}
//   401 not_signed_in · 400 bad_request · 403 not_member | voice_off | room_closed
//   501 not_configured (no LiveKit secrets)
//
// The token lives a few minutes: enough to join, useless to come back with
// after the stage changed (the rooms are named per stage, and voice_sync.ts
// pushes the new permissions to whoever is still connected).
import { liveKitEnv, participantToken, type RoomService } from '../_shared/livekit.ts';
import { isUuid, syncVoice, type VoiceStore } from '../_shared/voice_sync.ts';
import { voiceGrant } from '../_shared/voice_rules.ts';

export const tokenTtlSeconds = 180;

export interface VoiceTokenDeps {
  env: (name: string) => string | undefined;
  /** The profile id behind a JWT, or null if it is not a signed-in user. */
  userFor: (jwt: string) => Promise<string | null>;
  store: VoiceStore;
  /** RoomService for the push; null skips it (tests, or no secrets). */
  service: RoomService | null;
  now: () => number;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

export async function handleVoiceToken(req: Request, deps: VoiceTokenDeps): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const jwt = req.headers.get('authorization')?.replace(/^Bearer /i, '');
  if (!jwt) return json({ error: 'not_signed_in' }, 401);
  const profile = await deps.userFor(jwt).catch(() => null);
  if (!profile) return json({ error: 'not_signed_in' }, 401);
  const body = await req.json().catch(() => null);
  const roomId = body?.room;
  if (!isUuid(roomId)) return json({ error: 'bad_request' }, 400);
  const lk = liveKitEnv(deps.env);
  if (!lk) return json({ error: 'not_configured' }, 501);

  const room = await deps.store.room(roomId);
  if (!room) return json({ error: 'not_member' }, 403);
  const config = await deps.store.config();
  const now = deps.now();
  const decision = voiceGrant(room, profile, config, now);
  if (!decision.ok) return json({ error: decision.error }, 403);

  // Whoever asks also makes sure nobody kept a right the game took away
  // (someone who left the room, a stage that changed): cheap when nothing did.
  if (deps.service) {
    try {
      await syncVoice(deps.store, deps.service, roomId, now);
    } catch (error) {
      console.error('voice sync', roomId, error instanceof Error ? error.message : 'failed');
    }
  }

  if (!decision.room || !decision.identity) {
    const retryIn = decision.retryAt === null ? null : Math.max(0, decision.retryAt - now);
    return json({ room: null, retryIn });
  }
  await deps.store.remember(roomId, decision.room);
  const token = await participantToken(
    lk,
    decision.identity,
    { room: decision.room, canPublish: decision.canPublish, canSubscribe: decision.canSubscribe },
    tokenTtlSeconds,
    now,
  );
  return json({
    room: decision.room,
    kind: decision.kind,
    identity: decision.identity,
    url: lk.url,
    token,
    canPublish: decision.canPublish,
    canSubscribe: decision.canSubscribe,
    expiresIn: tokenTtlSeconds,
  });
}
