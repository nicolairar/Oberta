// LiveKit, without its SDK: access tokens are HS256 JWTs signed with the API
// secret (https://docs.livekit.io/home/get-started/authentication/), and
// RoomService is Twirp over HTTPS with JSON bodies. The secrets come only
// from Deno.env (LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET) and are
// never logged or returned, except the public server URL the phones dial.
//
// Live audio only: no grant here ever allows recording, egress, ingress,
// data messages, metadata or admin powers to a phone. The admin token below
// is minted per call for RoomService and never leaves the function.
import { SignJWT } from 'npm:jose@5.9.6';

export interface LiveKitEnv {
  /** wss://… as the phones dial it. */
  url: string;
  key: string;
  secret: string;
}

export function liveKitEnv(env: (name: string) => string | undefined): LiveKitEnv | null {
  const url = env('LIVEKIT_URL');
  const key = env('LIVEKIT_API_KEY');
  const secret = env('LIVEKIT_API_SECRET');
  if (!url || !key || !secret) return null;
  return { url, key, secret };
}

/** The HTTPS origin of the RoomService API, from the wss:// URL. */
export function apiOrigin(url: string): string {
  return url.replace(/^ws(s?):\/\//, 'http$1://').replace(/\/+$/, '');
}

/** A phone's grant: one room, the microphone at most. */
export interface ParticipantGrant {
  room: string;
  canPublish: boolean;
  canSubscribe: boolean;
}

export async function participantToken(
  lk: LiveKitEnv,
  identity: string,
  grant: ParticipantGrant,
  ttlSeconds: number,
  nowMs: number,
): Promise<string> {
  const now = Math.floor(nowMs / 1000);
  return await new SignJWT({
    video: {
      room: grant.room,
      roomJoin: true,
      canPublish: grant.canPublish,
      canSubscribe: grant.canSubscribe,
      canPublishData: false,
      canPublishSources: grant.canPublish ? ['microphone'] : [],
      canUpdateOwnMetadata: false,
    },
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuer(lk.key)
    .setSubject(identity)
    .setJti(crypto.randomUUID())
    .setNotBefore(now - 5)
    .setIssuedAt(now)
    .setExpirationTime(now + ttlSeconds)
    .sign(new TextEncoder().encode(lk.secret));
}

export interface LiveParticipant {
  identity: string;
  canPublish: boolean;
  canSubscribe: boolean;
}

/** The permissions a participant is given (ParticipantPermission). */
export interface Permission {
  canPublish: boolean;
  canSubscribe: boolean;
}

/** What voice_sync needs from RoomService. */
export interface RoomService {
  list(room: string): Promise<LiveParticipant[]>;
  update(room: string, identity: string, permission: Permission): Promise<void>;
  remove(room: string, identity: string): Promise<void>;
}

type Fetch = typeof fetch;

export function roomService(lk: LiveKitEnv, fetcher: Fetch = fetch, clock: () => number = Date.now): RoomService {
  const origin = apiOrigin(lk.url);
  async function call(method: string, room: string, body: Record<string, unknown>): Promise<Response> {
    const now = Math.floor(clock() / 1000);
    const admin = await new SignJWT({ video: { room, roomAdmin: true } })
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuer(lk.key)
      .setNotBefore(now - 5)
      .setExpirationTime(now + 60)
      .sign(new TextEncoder().encode(lk.secret));
    return await fetcher(`${origin}/twirp/livekit.RoomService/${method}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${admin}` },
      body: JSON.stringify(body),
    });
  }
  // Twirp answers "not_found" for a room nobody is in: nothing to do there.
  async function ok(response: Response, method: string): Promise<void> {
    if (response.ok || response.status === 404) {
      await response.body?.cancel();
      return;
    }
    const detail = await response.text().catch(() => '');
    throw new Error(`livekit ${method} ${response.status} ${detail.slice(0, 120)}`);
  }
  return {
    async list(room) {
      const response = await call('ListParticipants', room, { room });
      if (!response.ok) {
        await ok(response, 'ListParticipants');
        return [];
      }
      const json = await response.json();
      // deno-lint-ignore no-explicit-any
      return ((json?.participants ?? []) as any[]).map((p) => ({
        identity: String(p.identity ?? ''),
        canPublish: Boolean(p.permission?.canPublish ?? p.permission?.can_publish ?? false),
        canSubscribe: Boolean(p.permission?.canSubscribe ?? p.permission?.can_subscribe ?? false),
      }));
    },
    async update(room, identity, permission) {
      await ok(
        await call('UpdateParticipant', room, {
          room,
          identity,
          permission: {
            canSubscribe: permission.canSubscribe,
            canPublish: permission.canPublish,
            canPublishData: false,
            canPublishSources: permission.canPublish ? ['MICROPHONE'] : [],
            canUpdateMetadata: false,
          },
        }),
        'UpdateParticipant',
      );
    },
    async remove(room, identity) {
      await ok(await call('RemoveParticipant', room, { room, identity }), 'RemoveParticipant');
    },
  };
}
