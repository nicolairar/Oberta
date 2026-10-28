-- The dead never speak in a game: no ghosts room at night, so its switch
-- goes (_shared/voice_rules.ts). They listen to the day discussion and the
-- vote, nothing more.
delete from internal.config where key = 'voice_ghosts';
