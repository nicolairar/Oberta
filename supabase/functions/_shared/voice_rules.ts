// Who may speak and who may listen in a room's voice chat, right now. Pure:
// the same rules decide the token voice-token mints and the permissions the
// game function pushes to LiveKit when a stage changes (voice_sync.ts).
//
// The rules follow the game, never the phone:
//   * lobby (and after the game): every member speaks and listens;
//   * day (discussion, vote): the living speak, unless the Tailor sewed
//     their mouth (silenced) that day; the dead only listen;
//   * night: only the living family speaks and listens, in its own room;
//     the dead may talk among themselves (ghosts); everybody else is out;
//   * every other stage (the card, the films, the dawn, the verdict):
//     nobody is connected, nobody speaks.
//
// A stage opens for voice only once the server says it has started for
// everyone: the night (and the discussion) at its published start plus
// [VoiceConfig.settleMs], so every phone has finished its transition first.
// The vote follows the discussion without a break. A stage that ends closes
// its voice at once: the commit that ends it is the one that pushes the new
// permissions.
//
// LiveKit never learns who anyone is: a participant is a seat ("s3" in the
// game, "m3" in the lobby) in a room named after opaque ids.

export interface VoiceSchedule {
  stage: string;
  round: number;
  /** Milliseconds since the epoch, server time. */
  startsAt: number;
}

export interface VoiceMember {
  profile: string;
  /** The seat in the room (room_members.seat). */
  memberSeat: number;
  /** The seat in the current game (game_seats.seat), null if not seated. */
  gameSeat: string | null;
  alive: boolean;
  family: boolean;
  silenced: boolean;
}

export interface VoiceRoom {
  id: string;
  status: string;
  ranked: boolean;
  /** The current (or last) game in this room. */
  gameId: string | null;
  schedule: VoiceSchedule | null;
  /** Only the members still in the room (left_at is null). */
  members: VoiceMember[];
}

export interface VoiceConfig {
  /** Voice in friends rooms (internal.config voice_friends, default on). */
  friends: boolean;
  /** Voice in ranked rooms (internal.config voice_ranked, default off). */
  ranked: boolean;
  /** The dead talk among themselves at night (voice_ghosts, default on). */
  ghosts: boolean;
  /** After a stage's published start, before its voice opens. */
  settleMs: number;
}

export const defaultVoiceConfig: VoiceConfig = { friends: true, ranked: false, ghosts: true, settleMs: 1000 };

export type VoiceKind = 'lobby' | 'day' | 'family' | 'ghosts';

export type VoiceError = 'not_member' | 'voice_off' | 'room_closed';

export interface VoiceGrant {
  ok: true;
  /** The LiveKit room to be in, or null: be in none. */
  room: string | null;
  kind: VoiceKind | null;
  identity: string | null;
  canPublish: boolean;
  canSubscribe: boolean;
  /** When to ask again (server ms): a closed stage that is about to open. */
  retryAt: number | null;
}

export type VoiceDecision = VoiceGrant | { ok: false; error: VoiceError };

const nobody = (retryAt: number | null = null): VoiceGrant => ({
  ok: true,
  room: null,
  kind: null,
  identity: null,
  canPublish: false,
  canSubscribe: false,
  retryAt,
});

/** When voice opens in this stage (server ms), or null if it never does. */
export function voiceOpensAt(schedule: VoiceSchedule, settleMs: number): number | null {
  switch (schedule.stage) {
    case 'night':
    case 'discussion':
      return schedule.startsAt + settleMs;
    case 'vote':
      // The same day goes on: no break between discussion and vote.
      return 0;
    default:
      return null;
  }
}

function lobbyLike(room: VoiceRoom): boolean {
  return room.status !== 'playing' || room.schedule?.stage === 'ended';
}

/** The decision for [profile] in [room] at [now] (server ms). */
export function voiceGrant(room: VoiceRoom, profile: string, config: VoiceConfig, now: number): VoiceDecision {
  const me = room.members.find((m) => m.profile === profile);
  if (!me) return { ok: false, error: 'not_member' };
  if (room.ranked ? !config.ranked : !config.friends) return { ok: false, error: 'voice_off' };
  if (room.status === 'ended') return { ok: false, error: 'room_closed' };
  const prefix = `ob-${room.id}`;
  const grant = (kind: VoiceKind, name: string, identity: string, canPublish: boolean): VoiceGrant => ({
    ok: true,
    room: `${prefix}-${name}`,
    kind,
    identity,
    canPublish,
    canSubscribe: true,
    retryAt: null,
  });

  if (lobbyLike(room)) return grant('lobby', `lobby-${room.gameId ?? 'new'}`, `m${me.memberSeat}`, true);

  const schedule = room.schedule;
  const game = room.gameId;
  const seat = me.gameSeat;
  if (!schedule || !game || !seat) return nobody();
  const opensAt = voiceOpensAt(schedule, config.settleMs);
  if (opensAt === null) return nobody();
  if (now < opensAt) return nobody(opensAt);

  if (schedule.stage === 'night') {
    if (me.alive && me.family) return grant('family', `family-${game}-${schedule.round}`, seat, true);
    if (!me.alive && config.ghosts) return grant('ghosts', `ghosts-${game}`, seat, true);
    return nobody();
  }
  return grant('day', `day-${game}-${schedule.round}`, seat, me.alive && !me.silenced);
}

/** The member a LiveKit identity stands for in [room], if any. */
export function memberOf(room: VoiceRoom, identity: string): VoiceMember | null {
  if (/^m\d+$/.test(identity)) {
    if (!lobbyLike(room)) return null;
    const seat = Number(identity.slice(1));
    return room.members.find((m) => m.memberSeat === seat) ?? null;
  }
  if (lobbyLike(room)) return null;
  return room.members.find((m) => m.gameSeat === identity) ?? null;
}

/**
 * Everything the permissions depend on, except the clock. When it changes
 * the LiveKit rooms must be told; opening a stage needs no push (the phones
 * ask for a token at retryAt), closing one always comes with a change here.
 */
export function voiceSignature(room: VoiceRoom): string {
  const members = [...room.members]
    .sort((a, b) => a.memberSeat - b.memberSeat)
    .map((m) => [m.profile, m.memberSeat, m.gameSeat, m.alive, m.family, m.silenced]);
  const s = room.schedule;
  return JSON.stringify([room.status, room.gameId, s?.stage ?? null, s?.round ?? null, members]);
}
