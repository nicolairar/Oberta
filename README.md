# Omertà — gioco di ruoli nascosti sugli smartphone

Gioco tipo Lupus in Fabula / Mafia / Assassino, giocato **solo con gli smartphone**
(niente carte, niente fogli). Tema noir/mafia, stile cartoon-noir.

Due modalità: **LIVE** (tutti allo stesso tavolo, un telefono a testa, si parla a voce)
e **ONLINE** (stanze con codice, da remoto).

## Stato attuale

Fase 0 completata: ambiente di sviluppo pronto, progetto scaffoldato.
Si lavora **solo su iOS** per ora (Simulator + eventuale iPhone fisico).
Android è già scaffoldato ma non verrà testato finché non lo decidiamo insieme.

## Stack tecnico e perché

- **Flutter/Dart**: un solo codice per iOS e Android, controllo totale sulla grafica
  e sulle animazioni (fondamentale per l'effetto "carta da tavolo noir").
- **Animazioni**: Flutter nativo (CustomPainter/AnimationController) per iniziare;
  Rive/Lottie e Flame valutati più avanti per scene di morte ed effetti.
- **Rete**: fase 1 locale (il telefono del narratore/host fa da server), fase 2
  Supabase (free tier) per la modalità online e il narratore automatico sicuro.
- **Distribuzione**: gratuita all'inizio (build di test / installazione diretta),
  store solo se il gioco decolla (costi: Google Play 25€ una tantum, Apple 99$/anno).

## Architettura a 3 strati

Il codice di gioco è diviso in tre strati indipendenti, per poter cambiare
la UI o il tipo di connessione senza riscrivere le regole:

```
lib/
  rules/     -> Logica di gioco PURA (Dart puro, zero rete, zero UI).
               Mescolare ruoli, risolvere la notte, contare voti, vittoria,
               generare compiti di copertura, calcolare le "viste" per
               giocatore. Testabile con unit test semplici (vedi test/rules/).

  network/   -> Strato di comunicazione, sostituibile dietro un'unica interfaccia:
               - HostLocale: il telefono del narratore/host fa da server
                 (fase 1, rete locale/relay)
               - ServerRemoto: Supabase (fase 2, per narratore automatico e
                 modalità online)
               Passare da uno all'altro non deve richiedere di toccare rules/ o ui/.

  ui/        -> Schermate e widget. Mostra solo quello che riceve dallo strato
               network (viste personalizzate per giocatore). Non contiene
               logica di gioco.
    screens/
    widgets/
    theme/
```

Principio di sicurezza: ogni telefono manda solo **intenzioni** ("voto Marco") e
riceve solo la **vista personalizzata** che gli spetta — mai l'elenco completo
dei ruoli (eccetto il narratore umano, che già li conosce).

## Roadmap (vedi anche il brief di progetto)

0. ✅ Setup ambiente (Flutter, Xcode, Simulator iOS) + hello world
1. ⏳ Prototipo giocabile: stanza con codice, lobby, scelta narratore, ruota
   sincronizzata, carta ruolo con flip 3D, host come server
2. Ciclo completo notte/giorno, compiti di copertura, griglia con viste
   personalizzate, voto, linciaggio, vittoria + unit test sulle regole
3. Sistema di animazioni a strati (scena/metodo/regia/dettaglio)
4. Narratore automatico (voce/copione/musica) + Supabase per sicurezza e online
5. Più ruoli, modalità menu, matchmaking online, rifinitura, pubblicazione

**Regola d'oro:** prima il gioco deve divertire, poi si abbelliscono le animazioni.

## Come lanciare il progetto

```bash
flutter pub get
flutter devices          # elenca simulatori/telefoni disponibili
flutter run               # lancia sul device selezionato (o te lo chiede)
```

## Test

```bash
flutter test
```
