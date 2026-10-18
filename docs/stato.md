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
