# Visione: dove va Obertà

Contesto per le prossime sessioni, **non** un elenco di cose da fare adesso.
Si procede a piccoli passi, senza toccare quello che già funziona.

## Priorità

1. Continuare a migliorare l'app esistente (un telefono per tutti).
2. Un telefono a testa **in locale, senza internet** (host sulla rete Wi-Fi).
3. Supabase: account, profili, statistiche, stanze online con codice/QR.
4. Personalizzazione del profilo (avatar, outfit, cappelli, cornici, badge,
   titoli). Niente valute virtuali né acquisti per ora.
5. Classificata: matchmaking, rating, classifiche, validazione lato server.

L'ordine 2 → 3 è voluto: il protocollo della partita (chi manda cosa, chi
vede cosa) è lo stesso per il locale e per l'online. Fatto bene una volta
in locale, l'online cambia solo il trasporto.

## Aggiornamento (16 ottobre 2026): niente rete locale, tutto online

Il proprietario ha fatto un passo indietro sulla modalità in rete locale
(host sul Wi-Fi o sull'hotspot). La direzione nuova, sul modello di
Wolvesville ma più curata (animazioni, morti, avatar):

- **Gioca con amici:** stanza online con QR o codice. I profili si collegano:
  richiesta d'amicizia, oppure si entra nella partita e da lì si aggiungono
  gli amici.
- **Classificata:** partite con sconosciuti, divise per lingua (server/code
  italiano e inglese). Serve una **chat** fatta bene, con moderazione, perché
  i giocatori non si conoscono.
- **Un telefono per tutti** resta com'è.
- **UI della partita da rifare:** scelta dei giocatori con gli avatar in
  evidenza, e **posizioni mescolate per ogni telefono e ogni turno**: se uno
  è sempre in alto a sinistra, chi guarda il dito del vicino capisce chi
  sta per essere ucciso.
- Supabase è il backend (account creato). Con sconosciuti l'autorità deve
  stare sul server: le scelte del motore ("presto" sopra) restano valide.

## Bot per provare (17 ottobre 2026)

La partita online va costruita insieme ai bot: il proprietario ha due
telefoni, e per provare una partita da 8–16 servono giocatori finti. Nelle
build di prova la stanza ha "+ BOT"; ogni bot riceve solo la sua `PlayerView`
e manda `PlayerIntent` validate dal motore come quelle dei giocatori veri (si
parte da `test/support/random_game.dart`, che già sceglie le mosse dalla vista
del posto). Prima scelte a caso tra le mosse permesse, poi qualche regola
furba; votano anche di giorno.

## Disconnessioni e penalità (17 ottobre 2026)

- Chi si scollega: icona "offline" per tutti, 60 secondi per rientrare (ritrova
  la partita dov'era). Mentre è offline non blocca niente (timer: si astiene,
  passa) e resta al tavolo: può essere ucciso e votato, scollegarsi non protegge.
- Oltre i 60 secondi il personaggio "lascia la città": esce come un morto, ruolo
  rivelato, controllo di vittoria immediato. Ogni abbandono è registrato dal server.
- Penalità solo in classificata: prime 2 volte avviso, alla 3ª 5 minuti senza
  giocare, poi 15, 30, 60; ogni partita finita senza abbandoni toglie un
  abbandono, 24 ore pulite azzerano. Tra amici nessuna penalità. Il conteggio degli
  abbandoni non si mostra da nessuna parte: serve solo al server per le penalità.

## Economia e cosmetici (17 ottobre 2026)

- **Cosa si compra:** solo estetica, mai vantaggi di gioco. Facce, capelli,
  baffi, cappelli, occhiali, vestiti, accessori, skin complete; più avanti
  cornici, titoli, badge. Il look (`AvatarLook`, colonna `avatar` dei profili)
  si vede ovunque: al tavolo in prima persona, nei ritratti, nei filmati.
- **Come si guadagna:** vincendo le partite si prende esperienza, con
  l'esperienza si sale di livello, e salire di livello dà monete.
- **Soldi veri:** si compra la valuta con acquisti in-app (StoreKit, obbligatorio
  su iOS per beni digitali), e con la valuta si comprano i cosmetici.
- **Una valuta sola: le monete** (deciso il 17 ottobre). Si guadagnano solo
  salendo di livello; si sale di livello vincendo. Con soldi veri si comprano
  monete.
- **Classi e prezzi** (deciso il 17 ottobre, prezzi in euro voluti dal
  proprietario): comune (baffi, cravatta) 350 monete ≈ 3–4 €; raro (cappello,
  occhiali, capelli) 700 ≈ 7 €; epico (vestito completo) 1100 ≈ 11 €;
  leggendario (skin intera) 1800 ≈ 15–20 €.
- **Pacchetti:** 4,99 € = 500, 9,99 € = 1050, 19,99 € = 2200, 49,99 € = 6000.
- **Guadagno giocando** (da tarare con i dati): vittoria 100 XP, sconfitta 30,
  prima vittoria del giorno +100; dal livello L al successivo 150 + 25·L XP;
  150 monete a livello + 250 ogni 5 livelli. Obiettivo: primo comune in 2–3
  ore, leggendario in 20–30 ore, mai tutto in poche ore. Numeri in un file di
  configurazione unico + simulatore.
- **Pacchetti "skin + monete"** (idea del proprietario): si comprano SOLO con
  soldi veri, es. 9,99 € = skin epica + 1100 monete ("due al prezzo di uno").
  Valore "a parte" sempre vero (stessi prezzi del negozio), 1–2 pacchetti alla
  volta e a tempo; se la skin è già posseduta il pacchetto non si propone.
  Il server verifica l'acquisto e accredita skin e monete insieme.
- **Rotazioni:** la vetrina (skin e pacchetti in evidenza, date di inizio e
  fine, prezzi) sta in tabelle Supabase, così cambia senza una build nuova. Le
  skin nuove arrivano con gli aggiornamenti dell'app (i disegni sono nel
  codice); il server le fa ruotare nelle settimane dopo.
- **Regole tecniche:** saldo, inventario ed esperienza li scrive solo il server
  (già oggi l'app non può modificarli); ogni acquisto Apple si verifica lato
  server (App Store Server API) prima di accreditare la valuta; l'esperienza
  della classificata si assegna solo da partite validate dal server.
- **Da evitare:** casse a sorpresa a pagamento (regole e rating più severi in
  vari paesi UE); prezzi sempre chiari.

## Le scelte di fondo

### Il motore resta Dart puro
`lib/rules/` non importa Flutter, la rete o la UI. È la condizione per far
girare **lo stesso motore** sul telefono host (locale) e su un server
(classificata). Il motore accetta un `Random` dall'esterno: con un seme
salvato una partita si può rigiocare e verificare.

### Un'autorità per partita
- **Un telefono per tutti / locale:** l'autorità è il telefono host. Conosce
  tutti i ruoli, applica le regole, decide l'esito.
- **Online classificato:** l'autorità è il server. I telefoni mandano solo
  intenzioni, il server le valida e risponde.
- Ogni client manda **intenzioni** ("voto Marco", "la famiglia sceglie
  Anna") e riceve solo la **sua vista**: il proprio ruolo e i fatti che
  `knowledge.dart` gli concede (`Visibility.private/team/acquired/public`).
  Mai l'elenco completo dei ruoli a tutti.

### Multiplayer locale senza internet
- Host = server WebSocket sulla rete locale; gli altri entrano con un **QR**
  (indirizzo + codice stanza + token) o con la ricerca automatica (Bonjour/mDNS).
- **Se manca una rete Wi-Fi comune: l'host accende l'hotspot personale.** È la
  stessa rete locale, quindi niente BLE o peer-to-peer da sviluppare a parte.
  Multipeer (solo Apple) o BLE solo se un giorno ci sarà un motivo concreto.
- Disconnessioni: ogni giocatore ha un token di posto; chi rientra con lo
  stesso token riprende il suo posto e riceve di nuovo la sua vista attuale.
  La partita non si blocca: chi è fuori a un'azione salta il turno dopo un timeout.
- iOS chiede il permesso di rete locale: servono `NSLocalNetworkUsageDescription`
  e `NSBonjourServices` nell'`Info.plist` quando si arriva lì.
- Niente account né Supabase in locale.

### Supabase, e cosa non può fare da solo
- Supabase per: **auth** (anche anonima per iniziare), **profili**, **storico
  partite e statistiche**, **stanze/presenza** (Realtime), **storage** per gli avatar.
- La validazione della classificata ha bisogno del motore. Le Edge Function di
  Supabase sono TypeScript, il motore è Dart: la via pragmatica è un piccolo
  **servizio Dart** (lo stesso `lib/rules/`) per le partite classificate, con
  Supabase per tutto il resto. Riscrivere il motore in TypeScript solo se non
  c'è alternativa. Decisione da prendere quando si arriva alla classificata.
- Online non classificato si può fare anche con l'host come autorità e
  Supabase Realtime come semplice "tubo" (messaggi per destinatario).

### Identità
- Oggi `Player.id` è un id di posto locale. In rete servirà distinguere:
  **id del posto in partita** (temporaneo) e **id del profilo** (account,
  facoltativo). Il motore conosce solo i posti; profili e statistiche si
  agganciano ai posti a fine partita.

### Personalizzazione
- Il look è **dati, non disegni fissi**: un profilo ha un elenco di oggetti
  posseduti e un outfit equipaggiato (`{cappello: id, occhiali: id, ...}`).
  Gli oggetti stanno in un catalogo con id stabili, così si possono aggiungere
  oggetti, sbloccarli o (un giorno) venderli senza cambiare lo schema.
- Le foto del roster restano sul telefono; l'avatar di profilo è un'altra cosa.

### Classificata
- Gioco a squadre asimmetriche con molti giocatori: niente Elo semplice.
  Candidato: **OpenSkill (Weng-Lin)** o TrueSkill, con il rating aggiornato per
  squadra e corretto per ruolo/fazione (la famiglia vince più o meno spesso a
  seconda del tavolo).
- Lo storico salva per ogni partita: seme, mazzo, ruoli, azioni, esito. Basta
  per statistiche per ruolo, verifiche anti-trucco e ricalcolo dei rating.

## Cosa conviene decidere presto (e cosa no)

**Presto, perché costa poco ora e tanto dopo:**
- Il motore espone lo stato come **dati serializzabili** (stato + intenzioni
  + eventi in JSON), così locale, online e storico parlano la stessa lingua.
- La **vista per giocatore** si calcola nel motore (`viewFor(player)`), non
  nella UI: la UI dell'"un telefono per tutti" diventa solo un caso particolare.
- Separare id del posto e id del profilo prima di scrivere il protocollo.

**Si può rimandare tranquillamente:**
- Schema del database Supabase, auth, Realtime.
- Servizio di validazione per la classificata e sistema di rating.
- Matchmaking, classifiche, catalogo estetico, negozio.
