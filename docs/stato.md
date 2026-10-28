# Stato del progetto — 20 ottobre 2026 (build 44)

## Fatto
- **Un telefono per tutti:** partita completa, narratore umano o automatico parlato (Kokoro, 0.92, effetto godfather), 36+ filmati di morte, salvataggi con l'agguato della notte, 5 verdetti, "si va a nanna".
- **Online (Supabase, arbitro sul server):** Edge Function `game` (motore Dart compilato in JS, `tool/edge/build.sh`), fasi sincronizzate con conferme e timer (notte 30 s, discussione 60, voto 30), voto pubblico con mani che puntano e pizzini, chat (piazza di giorno, famiglia di notte, Compare di giorno), presenza/60 s per rientrare/abbandoni registrati, bot lato server, giornale per verdetto e alba, niente narratore online.
- **Account:** Apple + account di prova email (tieni premuto ACCEDI); nome utente stile Instagram (3–12, minuscolo, moderato IT/EN); badge con livello e monete.
- **Ruoli:** Sarto una volta per partita, Padrino senza voto doppio, mazzi con regole per ruolo, Compare (solo online).
- **Negozio "La Bottega":** ~200 pezzi (classi 350/700/1100/1800), case ispirate (Vaugirard, Arminio, Cuccioli, Versalli, Chanterelle, Nikea, Adelphi), Stramberie e Assurdo, acconciature e tatuaggi a pagamento, vetrina a rotazione dal server, specchio per provare, armadio.
- **Avatar:** "Lo specchio del barbiere" (insegna BARBIERE in home), Uomo/Donna/Altro, facce con molte opzioni e 20 preset, look salvato completo.
- **Impostazioni** a pagina intera: audio, lingua, sala prove, account, esporta dati, elimina account (funzione `account`), privacy e termini IT/EN (`docs/legal/`).

## In corso
- **Classificata:** costruita (coda per lingua, matcher ogni 2 s, OpenSkill per lingua, storico, penalità) ma BLOCCATA dalla home; si apre solo con `--dart-define=RANKED_DEBUG=true`. Prova con 2 telefoni: `internal.config` chiave `ranked_test_humans`. XP/livelli/monete dalle partite tra amici sono attivi (monete solo prime 5 partite al giorno). Mancano: grado nel profilo, soglie dei gradi reali, rating/storico nell'export dati.

## Da fare
- Acquisti con soldi veri (StoreKit + verifica server, `grant_coins`), pacchetti skin+monete.
- Fazioni neutrali e ruoli nuovi (Fesso, Piromane, Messia, Sindaco, Portinaio, investigatore mafioso).
- Bordi delle carte e colore del nome come cosmetici; versione iPad/Mac.
- Prima del lancio: pubblicare privacy/termini online con cognome e indirizzo, chiave Apple per la revoca, Google login (Google Cloud), verifica dei nomi delle marche, bot spenti lato server.

## Come si lavora
- Build: `bundle exec fastlane ios beta` (firma con la chiave API, controlla il permesso Accedi con Apple).
- Migrazioni in `supabase/migrations`, applicate da GitHub a ogni push su `main`: numeri di versione unici, provarle prima con begin…rollback (token in `fastlane/.env`).
- Ogni frase nuova del narratore va registrata (`tool/voice/regenerate.sh`).

## 19 ottobre 2026
- Fazione neutrale (Fesso, Piromane) e nuovi ruoli Messia, Sindaco, Portinaio uniti in main.
- Foglio ruoli in partita, schermata risultati a tutto schermo. Build 48 (classificata visibile solo in debug).

## Da fare (aggiornato il 28 ottobre 2026)

**Strumenti**
- Game Asset Generator (MCP, modelli gratuiti Hugging Face): grafica 2D/3D per avatar, skin, texture, sfondi. Installato in `~/code/tools/game-asset-mcp`, configurato in `.mcp.json`; serve `HF_TOKEN` (e una Space 3D duplicata per il 3D) nel suo `.env`. Le immagini finiscono in `assets/generated/`.
- Iris (MCP): test visivi in un browser vero. Funziona solo con pagine web: va valutato con la build web di Flutter, che oggi non c'è.
- Più avanti: Ludo AI per sprite e animazioni, Spine solo se servono animazioni a scheletro.

**Gioco**
- Direzione artistica: caratteri d'epoca, pulsanti nuovi, superfici, numero del posto e ritratti (in corso).
- Gesti anche nelle stanze d'attesa (ora solo al tavolo).
- Film della notte: separare lo sfondo città in parti fisse e animate (prestazioni).
- Ripresa del tester con report dei bug (`docs/playtest-report.md`), senza correggere durante i test.
- Classifica, missioni e obiettivi con la transizione della strada.
- Collega Google e Collega Apple dal PC: configurare i provider su Supabase.

**Pubblicazione**
- iPhone: fascia d'età, privacy e prezzo su App Store Connect; poi build finale senza debug, bot spenti (`ranked_test_humans`, `friends_test_bots`), build con `OBERTA_BOTS=false`.
- Steam: verifica fiscale in corso → App ID → chiave Web API e depot in `fastlane/.env` → login automatico, SteamPipe, obiettivi, pagina dello store (kit pronto in `steam/store/`).
- LiveKit: verificare nel pannello che registrazioni, egress, agenti e trascrizioni siano spenti.
- Landing: aggiornare schermate e testi dopo la direzione artistica.
- Ruotare le chiavi (Supabase, LiveKit) a fine sviluppo.
