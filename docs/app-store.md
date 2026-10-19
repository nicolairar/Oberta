# App Store e TestFlight esterno: cosa resta da fare

Testi, screenshot e lane sono pronti nel repo. Niente è stato caricato né inviato.

- Testi: `fastlane/metadata/{it,en-US}/`, note per la revisione in `fastlane/metadata/review_information/`.
- «Cosa provare» per TestFlight: `fastlane/testflight/what_to_test_{it,en-US}.txt`.
- Screenshot: `fastlane/screenshots/{it,en-US}/` (iPhone 6,9" 1320×2868, iPhone 6,5" 1284×2778, iPad 13" 2064×2752). Si rigenerano con `flutter test tool/render/store_screenshots_render_test.dart`.
- Lane: `bundle exec fastlane ios metadata` (solo testi e screenshot, nessuna revisione) e `bundle exec fastlane ios external_beta` (ultima build al gruppo esterno «Amici», con invio alla Beta App Review).

## Segnaposto da riempire

- [ ] `fastlane/metadata/review_information/{first_name,last_name,phone_number,email_address}.txt`: il contatto per Apple.
- [ ] `fastlane/metadata/copyright.txt`: `2026 <OWNER_NAME>`.
- [ ] `notes.txt`: `<REPORT_AND_BLOCK_INSTRUCTIONS>`. **Oggi nell'app non c'è né «Segnala» né «Blocca»**: il blocco esiste solo sul server (`block_player`), la segnalazione non esiste. La linea guida 1.2 (contenuti generati dagli utenti, cioè la chat) li richiede: vanno aggiunti all'app prima dell'invio, poi descritti qui. Se non ci sono, togliere la riga.
- [ ] Per `external_beta`: `BETA_CONTACT_EMAIL`, `BETA_CONTACT_FIRST_NAME`, `BETA_CONTACT_LAST_NAME`, `BETA_CONTACT_PHONE` nell'ambiente; il gruppo «Amici» deve esistere in App Store Connect.

## Accesso per i revisori

- [ ] I revisori entrano con **Accedi con Apple** (il loro Apple ID); la modalità a un telefono non chiede nessun account. Nessun account demo.
- [ ] L'accesso nascosto con email e password (pressione lunga su «Accedi» o sul titolo del foglio) **non deve essere raggiungibile nella build di release**: va tolto o chiuso dietro un flag di debug prima dell'invio.
- [ ] Spegnere il provider **Email** in Supabase (Authentication > Providers) prima dell'invio, ed eliminare gli account di prova con email.

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
| Utilizzo > Interazioni con il prodotto / Altri dati di gioco | partite, ruoli, vittorie, livello, esperienza, monete, oggetti posseduti, amici | statistiche e bottega |

Non raccolti: posizione, contatti, foto (le foto dei giocatori nella modalità a un telefono restano sul telefono), dati di salute, dati finanziari, cronologia di navigazione, diagnostica.

- [ ] Controllare che `privacy.html` dica le stesse cose.

## Server e chiavi

- [ ] Chiave **Accedi con Apple** per la revoca del token all'eliminazione dell'account: crearla in Certificates, Identifiers & Profiles (Keys > Sign in with Apple) e impostare nei secret della funzione `account` `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID` (com.obertagame.oberta), `APPLE_PRIVATE_KEY` (contenuto del .p8).
- [ ] Spegnere i **bot** di prova nelle stanze (`set_room_bots`): niente bot nella build di release.
- [ ] Cancellare `ranked_test_humans`: `delete from internal.config where key = 'ranked_test_humans';`
- [ ] Build di release **senza** `RANKED_DEBUG=1` (`bundle exec fastlane ios beta` senza la variabile), con `config/supabase.json` presente.

## Pagine legali

- [ ] `site/oberta/privacy.html` e `termini.html`: aggiungere cognome e indirizzo del titolare (obbligatori per il GDPR), poi ripubblicare su https://charliemobile.dev/oberta/.

## Ultimi passi (a mano)

- [ ] `bundle exec fastlane ios metadata`, poi controllare la scheda in App Store Connect.
- [ ] Prezzo (gratis), disponibilità per paese, questionario sull'export (nessuna crittografia oltre a HTTPS).
- [ ] Scegliere la build e inviare alla revisione da App Store Connect.
