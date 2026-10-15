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
