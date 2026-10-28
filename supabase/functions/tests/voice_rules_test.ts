// The voice chat's rules (pure): who speaks and who listens, stage by stage.
//
//   deno test -A supabase/functions/tests/voice_rules_test.ts
import { assert, assertEquals, assertNotEquals } from 'jsr:@std/assert@1';
import {
  defaultVoiceConfig,
  memberOf,
  type VoiceConfig,
  voiceGrant,
  type VoiceGrant,
  type VoiceMember,
  type VoiceRoom,
  voiceSignature,
} from '../_shared/voice_rules.ts';

const id = 'aaaaaaaa-0000-4000-8000-000000000001';
const game = 'bbbbbbbb-0000-4000-8000-000000000002';
const config: VoiceConfig = { ...defaultVoiceConfig, settleMs: 1000 };
const t0 = 1_800_000_000_000;

const member = (n: number, extra: Partial<VoiceMember> = {}): VoiceMember => ({
  profile: `p${n}`,
  memberSeat: n,
  gameSeat: `s${n}`,
  alive: true,
  family: false,
  silenced: false,
  ...extra,
});

/** p1 family, p2 town, p3 dead, p4 silenced, p5 dead family. */
const members = [
  member(1, { family: true }),
  member(2),
  member(3, { alive: false }),
  member(4, { silenced: true }),
  member(5, { alive: false, family: true }),
];

function room(stage: string | null, extra: Partial<VoiceRoom> = {}): VoiceRoom {
  return {
    id,
    status: stage === null ? 'lobby' : 'playing',
    ranked: false,
    gameId: stage === null ? null : game,
    schedule: stage === null ? null : { stage, round: 2, startsAt: t0 },
    members,
    ...extra,
  };
}

function grant(r: VoiceRoom, profile: string, now = t0 + 5000, c = config): VoiceGrant {
  const decision = voiceGrant(r, profile, c, now);
  assert(decision.ok, `${profile}: ${JSON.stringify(decision)}`);
  return decision;
}

const none = (retryAt: number | null = null): VoiceGrant => ({
  ok: true as const,
  room: null,
  kind: null,
  identity: null,
  canPublish: false,
  canSubscribe: false,
  retryAt,
});

Deno.test('lobby: every member speaks and listens, as a member seat', () => {
  for (const m of members) {
    const g = grant(room(null), m.profile);
    assertEquals(g.room, `ob-${id}-lobby-new`);
    assertEquals(g.kind, 'lobby');
    assertEquals(g.identity, `m${m.memberSeat}`);
    assertEquals([g.canPublish, g.canSubscribe], [true, true]);
  }
});

Deno.test('outsiders, ranked rooms (voice_ranked=0) and closed rooms get nothing', () => {
  assertEquals(voiceGrant(room(null), 'stranger', config, t0), { ok: false, error: 'not_member' });
  assertEquals(voiceGrant(room('vote', { ranked: true }), 'p1', config, t0), { ok: false, error: 'voice_off' });
  assert(voiceGrant(room('vote', { ranked: true }), 'p1', { ...config, ranked: true }, t0 + 5000).ok);
  assertEquals(voiceGrant(room(null), 'p1', { ...config, friends: false }, t0), { ok: false, error: 'voice_off' });
  assertEquals(voiceGrant(room(null, { status: 'ended' }), 'p1', config, t0), { ok: false, error: 'room_closed' });
});

Deno.test('the card, the films, the dawn and the verdict: nobody is connected, nobody speaks', () => {
  for (const stage of ['reveal', 'dawnFilms', 'dawn', 'verdictFilm', 'verdict']) {
    for (const m of members) {
      // Not even long after the start: these stages never open.
      assertEquals(grant(room(stage), m.profile, t0 + 3_600_000), none(), `${stage} ${m.profile}`);
    }
  }
  // A game still being dealt (no board yet) is closed too.
  assertEquals(grant(room('night', { schedule: null }), 'p1'), none());
});

Deno.test('night: closed until the server start plus the settle, then only the living family', () => {
  const night = room('night');
  // Published, not started yet (the transition is still playing): nobody,
  // and the family is told when to ask again.
  assertEquals(grant(night, 'p1', t0 - 1500), none(t0 + 1000));
  assertEquals(grant(night, 'p1', t0 + 999), none(t0 + 1000));
  assertEquals(grant(night, 'p2', t0 + 999), none(t0 + 1000));
  const family = grant(night, 'p1', t0 + 1000);
  assertEquals(family.room, `ob-${id}-family-${game}-2`);
  assertEquals([family.kind, family.identity, family.canPublish, family.canSubscribe], ['family', 's1', true, true]);
  // The town hears nothing and cannot speak.
  assertEquals(grant(night, 'p2'), none());
  assertEquals(grant(night, 'p4'), none());
  // The dead, family or not, are among the ghosts: never in the family room.
  for (const dead of ['p3', 'p5']) {
    const ghost = grant(night, dead);
    assertEquals(ghost.room, `ob-${id}-ghosts-${game}`);
    assertEquals([ghost.kind, ghost.canPublish], ['ghosts', true]);
  }
  assertEquals(grant(night, 'p3', t0 + 5000, { ...config, ghosts: false }), none());
});

Deno.test('day: the living speak after the settle, the dead and the silenced only listen', () => {
  const discussion = room('discussion');
  assertEquals(grant(discussion, 'p2', t0 + 500), none(t0 + 1000));
  const town = grant(discussion, 'p2');
  assertEquals(town.room, `ob-${id}-day-${game}-2`);
  assertEquals([town.kind, town.identity, town.canPublish, town.canSubscribe], ['day', 's2', true, true]);
  assertEquals(grant(discussion, 'p1').canPublish, true, 'the family speaks in the square like everyone');
  assertEquals(grant(discussion, 'p1').room, town.room, 'never a family room by day');
  for (const quiet of ['p3', 'p4', 'p5']) {
    const g = grant(discussion, quiet);
    assertEquals([g.room, g.canPublish, g.canSubscribe], [town.room, false, true], quiet);
  }
});

Deno.test('the vote: nobody speaks, everyone stays in the day room listening', () => {
  const vote = room('vote');
  for (const m of members) {
    // From the moment it is published: no break, no reconnect, no microphone.
    for (const now of [t0 - 1500, t0, t0 + 60_000]) {
      const g = grant(vote, m.profile, now);
      assertEquals([g.room, g.kind, g.identity, g.canPublish, g.canSubscribe], [`ob-${id}-day-${game}-2`, 'day', `s${m.memberSeat}`, false, true], `${m.profile} ${now}`);
    }
  }
});

/**
 * Every state a seat can be in, stage by stage: [room kind or null, speaks].
 * The Compare is on the mafia team, so family (it opens the family chat by
 * day, never a family voice room). There is no jail role yet (see
 * voice_rules.ts).
 */
Deno.test('the matrix: every role state, every stage', () => {
  const seats = {
    town: member(1),
    family: member(2, { family: true }),
    compare: member(3, { family: true }),
    silenced: member(4, { silenced: true }),
    silencedFamily: member(5, { family: true, silenced: true }),
    dead: member(6, { alive: false }),
    deadFamily: member(7, { alive: false, family: true }),
  };
  type Seat = keyof typeof seats;
  type Cell = [string | null, boolean];
  const off: Cell = [null, false];
  const day: Cell = ['day', true];
  const listen: Cell = ['day', false];
  const fam: Cell = ['family', true];
  const ghost: Cell = ['ghosts', true];
  const closed: Record<Seat, Cell> = {
    town: off, family: off, compare: off, silenced: off, silencedFamily: off, dead: off, deadFamily: off,
  };
  const expected: Record<string, Record<Seat, Cell>> = {
    reveal: closed,
    night: { town: off, family: fam, compare: fam, silenced: off, silencedFamily: fam, dead: ghost, deadFamily: ghost },
    dawnFilms: closed,
    dawn: closed,
    discussion: {
      town: day, family: day, compare: day, silenced: listen, silencedFamily: listen, dead: listen, deadFamily: listen,
    },
    vote: {
      town: listen, family: listen, compare: listen, silenced: listen, silencedFamily: listen, dead: listen, deadFamily: listen,
    },
    verdictFilm: closed,
    verdict: closed,
  };
  const all = Object.values(seats);
  for (const [stage, row] of Object.entries(expected)) {
    const r = room(stage, { members: all });
    for (const [name, [kind, speaks]] of Object.entries(row) as [Seat, Cell][]) {
      const g = grant(r, seats[name].profile, t0 + 5000);
      assertEquals([g.kind, g.canPublish], [kind, speaks], `${stage} / ${name}`);
      // Whoever is in a room listens there; whoever is out hears nothing.
      assertEquals(g.canSubscribe, kind !== null, `${stage} / ${name} listens`);
    }
  }
  // The lobby and the end of the game: everyone speaks, as a member seat.
  for (const stage of [null, 'ended']) {
    for (const m of all) {
      const g = grant(room(stage, { members: all, gameId: game }), m.profile);
      assertEquals([g.kind, g.canPublish, g.identity], ['lobby', true, `m${m.memberSeat}`], `${stage} / ${m.profile}`);
    }
  }
});

Deno.test('the end of the game: everyone, in the lobby room of that game', () => {
  const ended = room('ended');
  for (const m of members) {
    const g = grant(ended, m.profile);
    assertEquals([g.room, g.identity, g.canPublish], [`ob-${id}-lobby-${game}`, `m${m.memberSeat}`, true]);
  }
  const back = grant(room(null, { gameId: game }), 'p3');
  assertEquals(back.room, `ob-${id}-lobby-${game}`, 'the room after the game: the same lobby room');
});

Deno.test('identities map back to members only in the right kind of room', () => {
  assertEquals(memberOf(room('vote'), 's4')?.profile, 'p4');
  assertEquals(memberOf(room('vote'), 'm4'), null);
  assertEquals(memberOf(room(null), 'm2')?.profile, 'p2');
  assertEquals(memberOf(room(null), 's2'), null);
  assertEquals(memberOf(room('vote'), 's9'), null);
});

Deno.test('the signature changes with the stage and the seats, never with the clock', () => {
  const day = voiceSignature(room('discussion'));
  assertEquals(voiceSignature(room('discussion', { schedule: { stage: 'discussion', round: 2, startsAt: t0 + 9 } })), day);
  assertNotEquals(voiceSignature(room('vote')), day);
  assertNotEquals(voiceSignature(room('discussion', { members: members.slice(1) })), day);
  assertNotEquals(voiceSignature(room('discussion', { members: [member(1, { alive: false }), ...members.slice(1)] })), day);
});
