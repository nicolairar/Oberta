# Omertà — gioco di ruoli nascosti sugli smartphone

Gioco tipo Lupus in Fabula / Mafia / Assassino, giocato **solo con gli smartphone**
(niente carte, niente fogli). Tema noir/mafia, stile cartoon-noir.

Due modalità: **LIVE** (tutti allo stesso tavolo, un telefono a testa, si parla a voce)
e **ONLINE** (stanze con codice, da remoto).

## Le tre modalità

| Modalità | Come si gioca | Cosa serve |
|---|---|---|
| **Un telefono** | Ce lo si passa di mano in mano, tutto offline | Niente: è giocabile |
| **Un telefono a testa** | Stanza con codice, al tavolo o a distanza con amici | Rete locale, poi server |
| **Classificata** | Partite con sconosciuti, punti e classifica | Server remoto |

Regole e schermate sono le stesse: cambia solo come i telefoni si parlano.

## Stato attuale

La modalità **un telefono** si gioca dall'inizio alla fine: stanza, lobby,
scelta del narratore, ruota dei ruoli, carta con flip 3D, poi notte, alba,
discussione, voto e verdetto finché una fazione vince.

- **Notte con compiti di copertura**: tutti prendono il telefono e toccano
  qualcuno sulla stessa griglia. Solo alcune mosse sono vere.
- **Griglia personale**: ognuno vede i segni di ruolo solo dove ha diritto.
- **Copione del narratore**: ogni partita è ambientata in una città vera
  (Chicago 1929, New York 1947, Palermo 1955, Napoli 1950, Las Vegas 1955)
  e ogni morte è raccontata come la scena di un film, composta a strati.
  Ogni pagina affianca al racconto una frase chiara, in evidenza, che dice
  cosa è successo e cosa si fa adesso.

Manca ancora la rete tra telefoni: `FakeLocalSession` fa da stanza finta.

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
  rules/      -> Logica di gioco PURA (Dart puro, zero rete, zero UI).
                 Mazzo e ruoli, mosse notturne, voto della mafia, linciaggio,
                 vittoria, e chi ha diritto di sapere cosa (`GameEngine`).

  narration/  -> Il copione del narratore (Dart puro). Il codice compone,
                 i testi stanno in un pacchetto per lingua (`italian_pack`):
                 aggiungere l'inglese è aggiungere un file.

  network/    -> Strato di comunicazione, sostituibile dietro un'unica
                 interfaccia: sessione finta oggi, poi HostLocale (rete
                 locale) e ServerRemoto (Supabase).

  ui/         -> Schermate e widget. Mostra quello che riceve, non decide.
    screens/
    widgets/
    theme/
```

Principio di sicurezza: ogni telefono manda solo **intenzioni** ("voto Marco") e
riceve solo la **vista personalizzata** che gli spetta — mai l'elenco completo
dei ruoli (eccetto il narratore umano, che già li conosce).

## Roadmap (vedi anche il brief di progetto)

0. ✅ Setup ambiente (Flutter, Xcode, Simulator iOS)
1. ✅ Preparazione: stanza con codice, lobby, narratore, ruota, carta ruolo
2. ✅ Partita completa su un telefono: notte, alba, giorno, voto, vittoria,
   con test sulle regole e sul copione
3. ⏳ Grafica e animazioni: fondali, avatar, scene di morte a strati
4. Un telefono a testa in rete locale
5. Server remoto (Supabase): partite a distanza, narratore automatico con voce
6. Classificata, altri ruoli, inglese, pubblicazione

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
