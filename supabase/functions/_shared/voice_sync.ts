// The server's side of voice: what the database says about a room, and the
// push to LiveKit when that changes. A token only decides how a phone joins;
// a phone already in a room keeps whatever it joined with, so every change
// that takes a right away (the day ends, the night ends, a death, the
// Tailor) is pushed here with RoomService: participants who may no longer be
// in a room are removed, the others get their new permissions.
//
// internal.voice_sessions (migration 20261115090000_voice_chat.sql) keeps,
// per room, the LiveKit rooms tokens were minted for and the signature
// (voice_rules.ts) last pushed: a step that changes nothing about voice
// costs one small query, and rooms where nobody uses voice cost nothing.
import type { RoomService } from './livekit.ts';
import {
  defaultVoiceConfig,
  memberOf,
  type VoiceConfig,
  voiceGrant,
  type VoiceRoom,
  type VoiceSchedule,
  voiceSignature,
} from './voice_rules.ts';

export interface Query {
  query<T = Record<string, unknown>>(text: string, params?: unknown[]): Promise<T[]>;
}

export interface VoiceSession {
  signature: string | null;
  rooms: string[];
}

export interface VoiceStore {
  room(roomId: string): Promise<VoiceRoom | null>;
  config(): Promise<VoiceConfig>;
  session(roomId: string): Promise<VoiceSession | null>;
  /** A token was minted for [name]: it must be watched from now on. */
  remember(roomId: string, name: string): Promise<void>;
  /** The push for [signature] is done; [forget] are empty and over. */
  settle(roomId: string, signature: string, forget: string[]): Promise<void>;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && uuid.test(value);
}

function schedule(value: unknown): VoiceSchedule | null {
  if (!value || typeof value !== 'object') return null;
  const s = value as Record<string, unknown>;
  if (typeof s.stage !== 'string') return null;
  return { stage: s.stage, round: Number(s.round ?? 0), startsAt: Number(s.startsAt ?? 0) };
}

export function sqlVoiceStore(db: Query): VoiceStore {
  return {
    async room(roomId) {
      if (!isUuid(roomId)) return null;
      const [room] = await db.query<{ status: string; ranked: boolean; game_id: string | null; schedule: unknown }>(
        `select r.status, r.ranked, g.game_id::text as game_id, g.view -> 'schedule' as schedule
         from public.rooms r left join public.game_public g on g.room_id = r.id
         where r.id = $1::uuid`,
        [roomId],
      );
      if (!room) return null;
      const members = await db.query<{
        profile: string;
        member_seat: number;
        game_seat: string | null;
        alive: boolean | null;
        family: boolean | null;
        silenced: boolean | null;
      }>(
        `select m.profile_id::text as profile, m.seat::int as member_seat, s.seat as game_seat,
                s.alive, s.family, s.silenced
         from public.room_members m
         left join public.game_seats s on s.room_id = m.room_id and s.profile_id = m.profile_id
         where m.room_id = $1::uuid and m.left_at is null`,
        [roomId],
      );
      return {
        id: roomId,
        status: room.status,
        ranked: Boolean(room.ranked),
        gameId: room.game_id,
        schedule: schedule(typeof room.schedule === 'string' ? JSON.parse(room.schedule) : room.schedule),
        members: members.map((m) => ({
          profile: m.profile,
          memberSeat: Number(m.member_seat),
          gameSeat: m.game_seat,
          alive: m.alive ?? true,
          family: m.family ?? false,
          silenced: m.silenced ?? false,
        })),
      };
    },
    async config() {
      const rows = await db.query<{ key: string; value: string }>(
        `select key, value from internal.config where key in ('voice_friends', 'voice_ranked', 'voice_ghosts', 'voice_settle_ms')`,
      );
      const value = (key: string) => rows.find((r) => r.key === key)?.value;
      const flag = (key: string, fallback: boolean) => (value(key) === undefined ? fallback : value(key) === '1');
      const settle = Number(value('voice_settle_ms'));
      return {
        friends: flag('voice_friends', defaultVoiceConfig.friends),
        ranked: flag('voice_ranked', defaultVoiceConfig.ranked),
        ghosts: flag('voice_ghosts', defaultVoiceConfig.ghosts),
        settleMs: Number.isFinite(settle) && settle >= 0 ? settle : defaultVoiceConfig.settleMs,
      };
    },
    async session(roomId) {
      const [row] = await db.query<{ signature: string | null; rooms: string[] }>(
        `select signature, rooms from internal.voice_sessions where room_id = $1::uuid`,
        [roomId],
      );
      return row ? { signature: row.signature, rooms: row.rooms ?? [] } : null;
    },
    async remember(roomId, name) {
      await db.query(
        `insert into internal.voice_sessions (room_id, rooms) values ($1::uuid, array[$2::text])
         on conflict (room_id) do update
           set rooms = array(select distinct r from unnest(internal.voice_sessions.rooms || array[$2::text]) r),
               updated_at = now()`,
        [roomId, name],
      );
    },
    async settle(roomId, signature, forget) {
      await db.query(
        `update internal.voice_sessions
         set signature = $2, rooms = array(select r from unnest(rooms) r where r <> all($3::text[])), updated_at = now()
         where room_id = $1::uuid`,
        [roomId, signature, forget],
      );
    },
  };
}

export interface SyncResult {
  pushed: boolean;
  removed: number;
  updated: number;
}

/**
 * Brings every LiveKit room of [roomId] in line with the rules, if anything
 * changed since the last push. Safe to run twice, and from anywhere.
 */
export async function syncVoice(store: VoiceStore, service: RoomService, roomId: string, now: number): Promise<SyncResult> {
  const result: SyncResult = { pushed: false, removed: 0, updated: 0 };
  const session = await store.session(roomId);
  if (!session) return result;
  const room = await store.room(roomId);
  if (!room) return result;
  const signature = voiceSignature(room);
  if (signature === session.signature) return result;
  const config = await store.config();

  // The rooms someone belongs in during this stage (opening or open).
  const current = new Set<string>();
  for (const member of room.members) {
    const decision = voiceGrant(room, member.profile, config, Number.MAX_SAFE_INTEGER);
    if (decision.ok && decision.room) current.add(decision.room);
  }
  const forget: string[] = [];
  for (const name of session.rooms) {
    const participants = await service.list(name);
    let left = participants.length;
    for (const participant of participants) {
      const member = memberOf(room, participant.identity);
      const decision = member ? voiceGrant(room, member.profile, config, now) : null;
      if (!decision?.ok || decision.room !== name || decision.identity !== participant.identity) {
        await service.remove(name, participant.identity);
        result.removed++;
        left--;
      } else if (decision.canPublish !== participant.canPublish || decision.canSubscribe !== participant.canSubscribe) {
        await service.update(name, participant.identity, { canPublish: decision.canPublish, canSubscribe: decision.canSubscribe });
        result.updated++;
      }
    }
    if (left === 0 && !current.has(name)) forget.push(name);
  }
  await store.settle(roomId, signature, forget);
  result.pushed = true;
  return result;
}
