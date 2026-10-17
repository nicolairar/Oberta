# Stato del progetto — 17 ottobre 2026 (build 28)

## Cosa c'è
- **Un telefono per tutti:** partita completa con narratore umano o automatico,
  12 ruoli, 4–16 giocatori, roster con foto, italiano e inglese.
- **Narratore automatico parlato:** voce Kokoro (Nicola IT, Adam EN, effetto
  "godfather"), 719 frasi pre-registrate, sottotitoli a macchina da scrivere,
  dizionario di pronuncia nascosto. Si rigenera con `tool/voice/regenerate.sh`.
- **Filmati:** 36 morti della famiglia, 5 salvataggi del Dottore, 5 colpi del
  Cecchino, 5 scampati pericoli; i salvataggi riusano l'agguato pescato dal
  mazzo; 5 verdetti comici; "si va a nanna" all'imbrunire e all'alba.
- **Audio:** musiche per momento (menu, tavolo, notte, giorno, finali), effetti
  registrati CC0 a tempo coi fotogrammi, sottofondi a strati, tasti con suono e
  vibrazione, modalità meme (spenta di default).
- **Tavolo in prima persona:** gli altri seduti come personaggi dei filmati, con
  il loro look (`AvatarLook`: base, cappello, occhiali, vestito, accessorio);
  nelle scelte segrete cambiano sedia a ogni turno.
- **Online (Supabase):** login Apple (+ account di prova email/password tenendo
  premuto ACCEDI), nome utente solo lettere, badge con avatar/livello/monete,
  amici, stanze con codice e QR (`oberta://room/CODICE`), uscita con conferma e
  passaggio del ruolo di padrone di casa, stanze vuote cancellate.
- **Partita online nelle stanze:** il telefono del padrone di casa fa da
  autorità (motore, bot, scadenze) e pubblica su Supabase il tavolo pubblico
  e una vista per posto, leggibile solo da chi ci siede; le intenzioni passano
  da `submit_intent`. Bot di prova (`bot.alfa`...) col pulsante «+ BOT» nelle
  build di prova (`--dart-define=OBERTA_BOTS=false` li spegne). Chi chiude
  l'app rientra dalla sala («Rientra al tavolo»).
- **Nome unico = unico nome:** 3–12 caratteri `a-z 0-9 . _`, moderazione
  IT/EN (`reserved_words` nel database, copia in `lib/online/reserved_words.dart`).
- **Motore pronto per l'online:** stato salvabile, intenzioni validate, vista
  per giocatore senza fughe di ruoli, posto separato dall'account.

## In programma (in ordine)
1. Google login (serve configurare Google Cloud).
2. Livelli e monete assegnati dal server alle vittorie.
3. Negozio cosmetici: una valuta (monete), 4 classi (comune 350 ≈ 3–4 €,
   raro 700, epico 1100, leggendario 1800 ≈ 15–20 €), pacchetti skin+monete a
   soldi veri, vetrina a rotazione decisa dal server, acquisti Apple verificati.
4. Classificata per lingua (IT/EN) con chat moderata.

## Rifiniture note
- Tavolo: con 12–16 giocatori una sola fila lunga (niente seconda fila).
- Filmati: punti di sutura (ago piccolo), banana (killer sul bordo), coltello/
  garrota/tango (killer ancora vicino quando arriva il Dottore), fascio
  dell'ambulanza prima del furgone, scia sulla fiaschetta col coltello.
- Pronunce da ascoltare: luoghi italiani in inglese, "Scicàgo", nomi in pausa.

## Come si lavora
- Build: `bundle exec fastlane ios beta` (firma con chiave API, si ferma se
  manca il permesso di Accedi con Apple). Config online in `config/supabase.json`
  (non in git). Migrazioni Supabase in `supabase/migrations`, applicate da
  GitHub a ogni push su `main`.
- Ogni frase nuova del narratore va registrata (`tool/voice/regenerate.sh`).
