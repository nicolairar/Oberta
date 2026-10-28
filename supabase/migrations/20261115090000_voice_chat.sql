-- Voice chat in friends rooms (supabase/functions/voice-token, LiveKit Cloud,
-- EU). Live audio only: nothing is recorded, transcribed or stored, here or
-- at LiveKit. The database keeps no audio and no voice history, only what
-- the server needs to take rights away when the game changes:
--
--   internal.voice_sessions   per room: the LiveKit rooms tokens were minted
--                             for (to be watched) and the signature of the
--                             rights last pushed (_shared/voice_sync.ts).
--
-- Switches in internal.config ('1' on, '0' off):
--   voice_friends    voice in friends rooms (on)
--   voice_ranked     voice in ranked rooms (off for now)
--   voice_ghosts     the dead talk among themselves at night (on)
--   voice_settle_ms  after a stage's published start, before its voice
--                    opens: every phone has finished the transition (1000)

create table if not exists internal.voice_sessions (
  room_id uuid primary key references public.rooms (id) on delete cascade,
  signature text,
  rooms text[] not null default '{}',
  updated_at timestamptz not null default now()
);
alter table internal.voice_sessions enable row level security;
revoke all on internal.voice_sessions from public, anon, authenticated;

insert into internal.config (key, value) values
  ('voice_friends', '1'),
  ('voice_ranked', '0'),
  ('voice_ghosts', '1'),
  ('voice_settle_ms', '1000')
on conflict (key) do nothing;
