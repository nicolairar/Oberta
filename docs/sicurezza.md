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
- **`game_seats`, `game_intents`**: nessun permesso ai client; si passa da `submit_intent`,
  `send_chat`, `game_ping`, `game_leave`, che timbrano il posto di chi chiama.
- **`game_chat`**: stanza e piazza per i membri; famiglia solo per i vivi della famiglia nella partita
  in corso (`is_family_reader`; il Compare ci scrive anche di giorno).
- **`game_events`** (nuova, `20261110090000_game_events.sql`): le righe di sistema della chat. Quelle
  pubbliche (`recipient` null) per i membri; quelle «solo tu» solo per `recipient = auth.uid()`; solo
  la partita in corso. Le scrive solo `internal.game_commit`. Id casuale e numero d'ordine `n` contato
  solo dentro ciò che un lettore vede: dai buchi non si capisce quanti segreti hanno ricevuto gli altri.
  Il motore le calcola solo dal tavolo pubblico e dalla vista di ciascun posto, mai dallo stato segreto.
- **Realtime**: `postgres_changes` applica le stesse policy a chi è abbonato; sono pubblicate solo
  tabelle con RLS, nessuna tabella segreta.

## Verifica

`supabase/tests/anticheat.sql`: 31 controlli sul database vero dentro `begin … rollback`, impersonando
un cittadino, un mafioso, un mafioso morto, un estraneo, chi ha lasciato la stanza e `anon`. Si lancia
dal SQL editor o via Management API (`SUPABASE_ACCESS_TOKEN` in `fastlane/.env`, ref da
`config/supabase.json`); per provare anche una migrazione nuova, incollarla subito dopo il `begin`.
Ogni riga deve avere `ok = true`. I test pgTAP in `supabase/tests/database/` restano per `supabase test db`.

## Esito dell'audit (ottobre 2026)

- Nessun buco trovato: viste per posto, chat della famiglia, stato interno, intenzioni e RPC non
  rivelano niente a chi non deve sapere.
- Rischio residuo, basso: gli id di `game_chat` vengono da una sequenza unica per tutte le stanze; un
  buco tra due messaggi della piazza può far intuire che di notte qualcuno ha scritto altrove (anche la
  famiglia), non cosa né chi. Che la famiglia parli di notte lo sanno già tutti.
- Il numero di chi deve ancora agire di notte (`nightPending`) è pubblico per scelta.
