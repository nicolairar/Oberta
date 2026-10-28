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

## Verifica

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
