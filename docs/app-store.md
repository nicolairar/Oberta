# App Store e TestFlight esterno: cosa resta da fare

Testi, screenshot e lane sono pronti nel repo. Niente è stato caricato né inviato.

- Testi: `fastlane/metadata/{it,en-US}/`, note per la revisione in `fastlane/metadata/review_information/`.
- «Cosa provare» per TestFlight: `fastlane/testflight/what_to_test_{it,en-US}.txt`.
- Screenshot: `fastlane/screenshots/{it,en-US}/` (iPhone 6,9" 1320×2868, iPhone 6,5" 1284×2778, iPad 13" 2064×2752). Si rigenerano con `flutter test tool/render/store_screenshots_render_test.dart`.
- Lane: `bundle exec fastlane ios metadata` (solo testi e screenshot, nessuna revisione) e `bundle exec fastlane ios external_beta` (ultima build al gruppo esterno «Amici», con invio alla Beta App Review).

## Segnaposto da riempire

- [x] `fastlane/metadata/review_information/{first_name,last_name,phone_number,email_address}.txt`: Nicolai Tana, +39 351 679 5391, oberta@charliemobile.dev.
- [x] `fastlane/metadata/copyright.txt`: `2026 Nicolai Tana`.
- [x] `notes.txt`: i passi per «Segnala» e «Blocca», in inglese, per il revisore. Si segnala e si blocca dal volto al tavolo (nella stanza e in partita), tenendo premuto un messaggio della chat, e dal fascicolo pubblico (amici, richieste, ricerca, classifica: «Blocca» e «Segnala» in fondo); i bloccati si tolgono da Impostazioni > Privacy e dati > «Giocatori bloccati». Nessun segnaposto rimasto in `fastlane/metadata/`.
- [ ] Per `external_beta`: `BETA_CONTACT_EMAIL`, `BETA_CONTACT_FIRST_NAME`, `BETA_CONTACT_LAST_NAME`, `BETA_CONTACT_PHONE` in `fastlane/.env` (gli stessi valori di `review_information`); il gruppo «External Tester» deve esistere in App Store Connect.

## Accesso per i revisori

- [x] I revisori entrano con **Accedi con Apple** (il loro Apple ID); la modalità a un telefono non chiede nessun account. Nessun account demo. Una partita online parte da 4 persone: con due telefoni la sala della stanza basta per chat, segnalazioni e blocchi (scritto in `notes.txt`).
- [x] L'accesso nascosto con email e password (pressione lunga su «Accedi» o sul titolo del foglio) **non è raggiungibile nella build da negozio**: c'è solo con `BuildFlags.testTools` (sotto, «Build di prova e build da negozio»).
- [ ] Spegnere il provider **Email** in Supabase (Authentication > Sign In / Providers) prima dell'invio, ed eliminare gli account di prova con email: `supabase/scripts/prelaunch.sql` li elenca e dice come.

## Build di prova e build da negozio

Un interruttore solo, `lib/build_flags.dart`. Una build `--release` **senza** dart-define è quella da negozio: è il caso di partenza, non c'è niente da ricordarsi.

| | Negozio (`fastlane ios beta` senza variabile) | Prova (`RANKED_DEBUG=1 bundle exec fastlane ios beta`, CI desktop con `steam_test`) | Debug / profile (`flutter run`, test) |
|---|---|---|---|
| Dart-define | nessuno | `OBERTA_TEST=true` (`RANKED_DEBUG=true` vale ancora uguale) | nessuno |
| Accesso con email e password | no | sì | sì |
| Classificata aperta dalla home | no («presto») | sì | no |
| Stanza con amici: si parte da | 4 persone | 2 (i bot li mette il server, se `friends_test_bots` è acceso) | 2 |
| Menu di prova Steam (Ctrl+Shift+S) | no | sì, con `STEAM=true` | sì, con `STEAM=true` |
| «+ giocatore di prova» nella lobby del telefono | no | no | solo debug |

- `BuildFlags.testBuild`: compilata come prova. `BuildFlags.testTools`: prova, debug o profile; in una build da negozio è falso e il compilatore toglie il codice.
- Le prove delle prestazioni (`tool/perf/`, `integration_test/`, `test_driver/`) non entrano nell'app: hanno i loro punti d'ingresso e le dipendenze di sviluppo.
- Un interruttore di prova nuovo passa da `BuildFlags`: `test/build_flags_test.dart` fallisce se in `lib/` compare un `fromEnvironment('..._DEBUG')` (o `TEST`, `BOTS`) altrove.
- Quello che decide il server (bot nelle stanze, minimo di prova della classificata, provider Email) non dipende dalla build: si spegne con `supabase/scripts/prelaunch.sql`.

## Classificazione per età (questionario App Store Connect)

- Violenza fumettistica o fantasy: **Rara/lieve** (omicidi raccontati dal narratore e dal giornale, niente sangue).
- Violenza realistica: Nessuna. Temi orrorifici o paura: Nessuno (al più «Rari/lievi», per i fondali notturni).
- Riferimenti a criminalità organizzata / attività criminali: **Rari/lievi** (tema mafia).
- Linguaggio volgare o umorismo crudo: Nessuno (la chat ha un filtro di parole).
- Alcol, tabacco, droghe: **Rari/lievi** se si conta la sigaretta degli avatar; altrimenti Nessuno.
- Contenuti sessuali, nudità, gioco d'azzardo simulato, gioco d'azzardo vero: Nessuno. Il «banco» di Las Vegas è solo ambientazione.
- Contenuti generati dagli utenti / comunicazione fra utenti: **Sì** (chat testuale nelle stanze online).
- Accesso web senza restrizioni: No. Acquisti in app: No.
- Risultato atteso: 12+.

## Privacy dell'app (etichette nutrizionali)

Nessun tracciamento, nessuna pubblicità, nessun SDK di analisi. Tutti i dati sotto sono **collegati all'identità** dell'utente, usati solo per **funzionalità dell'app**, mai per tracciamento.

| Categoria Apple | Dato | Da dove |
|---|---|---|
| Identificativi > ID utente | id dell'account Supabase | accesso online |
| Informazioni di contatto > Indirizzo email | email (anche l'inoltro privato di Apple) | Accedi con Apple la consegna a Supabase Auth |
| Contenuti utente > Altri contenuti utente | nome utente unico, avatar (faccia del barbiere, abiti, cornice) | profilo |
| Contenuti utente > Altri contenuti utente (messaggi in-game) | messaggi della chat delle stanze | chat |
| Utilizzo > Interazioni con il prodotto / Altri dati di gioco | partite, ruoli, vittorie, livello, esperienza, monete, missioni, medaglie, oggetti posseduti, amici | statistiche e bottega |
| Contenuti utente > Altri contenuti utente | segnalazioni (motivo, nota, copia del messaggio) e giocatori bloccati | «Segnala» e «Blocca» |
| Altri dati > Altri tipi di dati | tipo di dispositivo («iPhone») e numero di build | un solo dispositivo attivo, ruoli che la build conosce |

Non raccolti: posizione, contatti, foto (le foto dei giocatori nella modalità a un telefono restano sul telefono), audio (la voce al tavolo passa dal vivo con LiveKit, premi-per-parlare, e non si registra né si conserva: per Apple non è «raccolta»), dati di salute, dati finanziari (nessun acquisto), cronologia di navigazione, diagnostica. Le medaglie su Game Center le gestisce Apple, non noi.

- [x] Controllare che `privacy.html` dica le stesse cose: `docs/legal/privacy_{it,en}.md` e le pagine del sito sono allineati a questa tabella (segnalazioni e blocchi, fascicolo pubblico e classifiche, dispositivo e build, Game Center / Play Games / Steam, niente acquisti in-app). In più la versione inglese: `site/oberta/privacy-en.html` e `terms-en.html`; l'app apre la pagina della sua lingua, `privacy_url` en-US punta a `privacy-en.html`. Le pagine del sito si rifanno dai `.md` (stesso guscio HTML, una riga `> ...` del `.md` diventa un commento).

## Server e chiavi

- [ ] Chiave **Accedi con Apple** per la revoca del token all'eliminazione dell'account: crearla in Certificates, Identifiers & Profiles (Keys > Sign in with Apple) e impostare nei secret della funzione `account` `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID` (com.obertagame.oberta), `APPLE_PRIVATE_KEY` (contenuto del .p8).
- [ ] Il giorno del lancio, nel SQL editor: `supabase/scripts/prelaunch.sql` (fuori dalle migrazioni, non parte da solo). Così com'è è una prova: fa tutto, stampa i controlli e torna indietro con `rollback`; letti i controlli, si rilancia con `commit` in fondo. Cancella `ranked_test_humans`, `friends_test_bots` e `friends_test_size` (niente bot nelle stanze né nella classificata, quattro persone per partire), azzera i bot delle stanze in attesa, controlla che `set_room_bots` resti chiusa, elenca le partite classificate di prova ancora aperte e gli account con email da eliminare (a mano, uno per uno, col modello nel file).
- [ ] Build di release **senza** `RANKED_DEBUG=1` (`bundle exec fastlane ios beta` senza la variabile), con `config/supabase.json` presente: senza variabile è già la build da negozio (niente email, niente classificata, quattro persone).

## Pagine legali

- [x] Nome e cognome del titolare (Nicolai Tana), email e PEC ci sono in informativa e termini, in italiano e in inglese.
- [ ] Indirizzo del titolare: c'è un `TODO(owner)` in `docs/legal/{privacy,terms}_{it,en}.md` (riga `>`, non si vede nell'app) e lo stesso, come commento, in `site/oberta/{privacy,termini,privacy-en,terms-en}.html`. Scriverlo in tutti e otto, poi push su `main` (Cloudflare Pages ripubblica https://charliemobile.dev/oberta/). Le pagine inglesi devono essere online **prima** di `fastlane ios metadata`.

## Ultimi passi (a mano)

- [ ] `bundle exec fastlane ios metadata`, poi controllare la scheda in App Store Connect.
- [ ] Prezzo (gratis), disponibilità per paese, questionario sull'export (nessuna crittografia oltre a HTTPS).
- [ ] Scegliere la build e inviare alla revisione da App Store Connect.
