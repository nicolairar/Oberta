# Sicurezza della partita online (anti-cheat)

Obiettivo: chi chiama direttamente l'API (PostgREST, RPC, Realtime) con il proprio token non deve
scoprire niente di nascosto: ruoli, mosse notturne, chat della famiglia, segreti degli altri.

## Come è fatto

- **Stato segreto** (`internal.game_state`, `internal.config`, …): schema `internal` senza `USAGE` per
  `anon`/`authenticated`. Lo leggono solo la Edge Function `game` (come postgres) e le funzioni
  `security definer`.
- **`game_public`**: solo il tavolo pubblico, ripulito da `sanitizeBoard` (niente ruoli tranne
  condannati e scoop, niente scelte notturne, chi è stato salvato resta «qualcuno», il resoconto solo
  a partita finita). Lo leggono solo i membri della stanza.
- **`game_seat_views`**: una riga per posto umano, letta solo se `profile_id = auth.uid()` e si è
  ancora nella stanza.
- **`game_seats`, `game_intents`**: nessun permesso ai client (nemmeno su una colonna), non pubblicate
  a Realtime; si passa da `submit_intent`, `send_chat`, `game_ping`, `game_leave`, che timbrano il
  posto di chi chiama. Dalla `20261114090000_intent_tokens.sql` `submit_intent` restituisce un
  `token` casuale e il motore lo rimette nella risposta della vista del posto (`receipt.token`); l'id
  di `game_intents` (l'ordine di arrivo, da una sequenza unica) lo leggono solo la Edge Function e
  `internal.game_commit`.
- **`game_chat`**: stanza e piazza per i membri; famiglia solo per i vivi della famiglia nella partita
  in corso (`is_family_reader`; il Compare ci scrive anche di giorno). Dalla
  `20261111090000_chat_random_ids.sql` l'id è un uuid casuale (`send_chat` lo restituisce,
  `report_player` lo riceve) e l'ordine è `n`, contato per stanza, partita e canale: dai numeri della
  piazza non si conta niente della famiglia. La vecchia sequenza unica non esiste più. I telefoni
  ordinano per `created_at`, poi `n`.
- **Niente si muove quando parla la famiglia**: `send_chat` scrive solo la riga del messaggio; niente
  `updated_at`, versioni, presenza o wake. La regola AFK del motore ascolta solo la piazza (il
  cursore `lastChat` è l'`n` della piazza): un messaggio della famiglia non cambia chi viene mandato a
  casa, quindi neanche il tavolo pubblico.
- **`game_events`** (nuova, `20261110090000_game_events.sql`): le righe di sistema della chat. Quelle
  pubbliche (`recipient` null) per i membri; quelle «solo tu» solo per `recipient = auth.uid()`; solo
  la partita in corso. Le scrive solo `internal.game_commit`. Id casuale e numero d'ordine `n` contato
  solo dentro ciò che un lettore vede: dai buchi non si capisce quanti segreti hanno ricevuto gli altri.
  Il motore le calcola solo dal tavolo pubblico e dalla vista di ciascun posto, mai dallo stato segreto.
- **Realtime**: `postgres_changes` applica le stesse policy a chi è abbonato; sono pubblicate solo
  tabelle con RLS, nessuna tabella segreta.

- **Voce al tavolo** (`supabase/functions/voice-token`, LiveKit Cloud UE; regole in
  `supabase/functions/_shared/voice_rules.ts`): solo dal vivo, **zero dati registrati**. Nessuna
  egress, registrazione, trascrizione, agent o observability su LiveKit; nessun audio sul server. I
  token dei telefoni (HS256, 3 minuti) danno una sola stanza e al più il microfono: niente
  `roomAdmin`, `roomCreate`, `roomList`, `roomRecord`, `recorder`, `hidden`, `canPublishData` (falso),
  `canUpdateOwnMetadata` (falso); il token admin per RoomService resta nella funzione (60 s, una
  stanza). LiveKit vede solo un posto (`s3` in partita, `m3` nella stanza), mai account o nome: il
  posto è sia `sub` (identità) sia `name` del token, nessun `metadata`/`attributes`, e con
  `canUpdateOwnMetadata` falso il telefono non può cambiare nome, metadati o attributi; niente canale
  dati (`canPublishData` falso, `canPublishSources` solo `microphone`). L'identità la decide il server
  dal JWT di Supabase e dai posti (`room_members`, `game_seats`): qualunque campo in più nella richiesta
  (identità, posto, nome, tipo di stanza) è ignorato, quindi nessuno può spacciarsi per un altro posto
  né entrare in una stanza che non è la sua. I nomi delle stanze LiveKit sono un HMAC-SHA256
  (`roomSeal`, `_shared/livekit.ts`) del nome leggibile per fase (`day-<partita>-<giro>`,
  `family-<partita>-<giro>`, `ghosts-<partita>`, `lobby-<partita>`) sotto una chiave derivata da
  `LIVEKIT_API_SECRET`: `ob-` + 40 cifre esadecimali, senza id di stanza o partita, impossibili da
  indovinare senza il segreto (e in ogni caso entrare richiede un token firmato per quella stanza).
  L'app mostra l'anello di chi parla e la lista di chi si sente solo dall'identità firmata dal
  server, tradotta in posto/nome dal tavolo della partita; il nome dichiarato dal partecipante non
  viene mai letto. Chi decide è il server, dalla fase pubblicata (`schedule` di
  `game_public`) e dai posti (`game_seats`): stanza e dopo la partita tutti; discussione e voto i vivi
  (il cucito dal Sarto e i morti solo ascoltano); notte solo la famiglia viva, e i morti fra loro;
  carta, film, alba e verdetto nessuno. Notte e discussione si aprono solo a `startsAt` +
  `voice_settle_ms` (1 s, `internal.config`), cioè dopo che tutti hanno confermato la fase prima e
  finito la transizione; prima la funzione risponde `{room: null, retryIn}`. Una fase che finisce
  chiude la voce subito: dopo ogni passo che cambia fase o posti la Edge Function `game` spinge i
  permessi con RoomService (`RemoveParticipant` per chi non può restare, `UpdateParticipant` per gli
  altri), così un token vecchio non tiene la parola; chi ha lasciato la stanza, un'identità di un
  altro tipo (`m3` durante la partita, `s3` nella stanza) o un posto che non appartiene più a quella
  stanza LiveKit viene tolto. Il microfono parla solo tenendo premuto il tasto (premi-per-parlare,
  niente microfono aperto). Silenziare qualcuno (dal menu del posto o dalla lista della voce) vale
  solo su quel telefono: non ci si abbona più alla sua voce. `internal.voice_sessions` tiene solo le stanze
  LiveKit da sorvegliare e la firma dell'ultimo invio. La classificata è spenta (`voice_ranked = 0`). I
  bloccati non si sentono mai e non ci sentono: il telefono di chi blocca non si abbona alla loro voce
  e la nega loro con i permessi d'ascolto che LiveKit applica.

## Verifica

`deno test -A supabase/functions/tests/voice_token_test.ts supabase/functions/tests/voice_rules_test.ts`:
le regole della voce e le claim dei token (identità e nome = il posto di chi chiede, campi falsi nella
richiesta ignorati, niente metadati, dati o poteri admin, nomi di stanza HMAC senza id), la spinta a
LiveKit che toglie chi non può restare, e il percorso intero sulle migrazioni vere in PGlite.

`supabase/tests/anticheat.sql`: 43 controlli sul database vero dentro `begin … rollback`, impersonando
un cittadino, un mafioso, un mafioso morto, un estraneo, chi ha lasciato la stanza e `anon`. Si lancia
dal SQL editor o via Management API (`SUPABASE_ACCESS_TOKEN` in `fastlane/.env`, ref da
`config/supabase.json`); per provare anche una migrazione nuova, incollarla subito dopo il `begin`.
Ogni riga deve avere `ok = true`. I test pgTAP in `supabase/tests/database/` restano per `supabase test db`.

## Esito dell'audit (ottobre 2026)

- Nessun buco trovato: viste per posto, chat della famiglia, stato interno, intenzioni e RPC non
  rivelano niente a chi non deve sapere.
- Chiuso (novembre 2026): gli id di `game_chat` venivano da una sequenza unica per tutte le stanze; un
  buco tra due messaggi della piazza diceva che di notte qualcuno aveva scritto altrove, cioè che
  almeno due della famiglia erano vivi (e quindi che l'ultima vittima non era della famiglia). Ora id
  casuali e `n` per canale; l'anti-cheat fotografa tutto ciò che un cittadino può leggere (ogni
  tabella e vista di `public`, quindi anche ogni riga che Realtime gli manderebbe, versione e
  `updated_at` del tavolo compresi), fa scrivere la famiglia e controlla che non cambi niente.
- Le cancellazioni (`DELETE`) arrivano via Realtime senza policy, ma solo con la chiave: ora un uuid,
  e i messaggi della partita si cancellano solo all'inizio della successiva.
- Chiuso (novembre 2026): `submit_intent` restituiva l'id di `game_intents` e la vista del posto lo
  ripeteva nella risposta; tra due proprie mosse si vedeva quante mosse (anche notturne) erano state
  mandate nel frattempo. Ora un token casuale; l'anti-cheat controlla che `submit_intent` e
  `send_chat` restituiscano un uuid, che i client non abbiano alcun permesso su `game_intents` e che
  nessuna vista contenga un id di mossa.
- Rischio residuo, bassissimo: `send_reaction` e `table_reactions.id` usano ancora una sequenza unica.
  I gesti si vedono già da tutta la stanza e mai di notte, quindi i buchi dicono solo quanti gesti si
  lanciano nelle altre stanze, niente della propria partita.
- Il numero di chi deve ancora agire di notte (`nightPending`) è pubblico per scelta.
