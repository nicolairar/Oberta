# Obertà — gioco di ruoli nascosti sugli smartphone

Gioco tipo Lupus in Fabula / Mafia / Assassino, giocato **solo con gli smartphone**
(niente carte, niente fogli). Tema noir/mafia, stile cartoon-noir.

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

- **Dodici ruoli, da 3 a 16 giocatori**: vedi [I dodici ruoli](#i-dodici-ruoli).
- **Notte con compiti di copertura**: tutti prendono il telefono e toccano
  qualcuno sulla stessa griglia. Solo alcune mosse sono vere.
- **Griglia personale**: ognuno vede i segni di ruolo solo dove ha diritto.
- **Copione del narratore**: ogni partita è ambientata in una città vera
  (Chicago 1929, New York 1947, Palermo 1955, Napoli 1950, Las Vegas 1955)
  e ogni morte è raccontata come la scena di un film, composta a strati.
  Ogni pagina affianca al racconto una frase chiara, in evidenza, che dice
  cosa è successo e cosa si fa adesso.

- **Grafica**: fondali animati con lo skyline di ogni città (luna, pioggia,
  finestre accese, l'alba che sorge), ritratti da foto segnaletica per ogni
  giocatore, il tamburo di un revolver per sorteggiare il narratore, un tavolo
  da poker che distribuisce le carte.
- **Il menu**: un vicolo sotto la pioggia, con l'insegna al neon che ogni
  tanto salta, il tizio che fuma sotto il lampione, il gatto, i fari delle
  auto; le modalità sono manifesti attaccati al muro.
- **Le scene della notte**: all'alba si appoggia il telefono sul tavolo e
  ogni agguato va in scena per com'è andato, a sagome nere: ventidue
  coreografie (dal pugnale al pianoforte, dalla lupara al bacio avvelenato,
  il colpo del Cecchino, il Dottore che arriva in tempo, la fiaschetta che
  ferma il proiettile), al rallentatore sul colpo, con le scritte da fumetto
  e il primo piano della vittima. Le azioni si pescano da un mazzo: nessuna
  si ripete finché non sono uscite tutte. Ogni scena si chiude sul ritratto
  e aspetta il tavolo; la Sala prove, dalle impostazioni, le fa rivedere.
- **Musica ed effetti**: ogni scena ha la sua colonna sonora (contrabbasso,
  archi che tremano, il cuore che accelera, il colpo d'orchestra) a tempo
  col film, e ogni momento della partita il suo suono: il tamburo del
  revolver, le carte, il gong della notte, le campane dell'alba, il
  ticchettio del timer, il rullo di tamburi sul condannato e il trombone
  triste se era innocente. Tutto è sintetizzato in codice: nessun file
  audio, nessuna licenza.
- **Italiano e inglese**: l'app segue la lingua del telefono, e dalle
  impostazioni si cambia a mano. Copione, ruoli e interfaccia esistono in
  tutte e due le lingue.

- **Il tavolo e le facce vere**: nella modalità un telefono ci si passa il
  telefono e ognuno si fa la sua scheda, nome e foto segnaletica (fotocamera
  frontale o libreria, oppure niente foto e resta il ritratto disegnato).
  L'elenco resta salvato: alla partita dopo si ritrova il tavolo di prima, si
  aggiunge chi arriva, si alza chi non gioca, si toglie chi se ne va o si
  cancellano tutti. Le foto compaiono in ogni ritratto del gioco, trattate in
  seppia dentro la stessa cornice; nella scena del delitto si vede solo la
  vittima, mai chi ha colpito.

Tutto è disegnato e suonato in codice (`CustomPainter`, un piccolo
sintetizzatore in `lib/sound/`): nessuna immagine, nessun font, nessun file
audio. Anche l'icona è disegnata in codice: `tool/make_app_icons.sh` la
rigenera in tutte le misure. Le dipendenze sono plugin con licenza libera:
`image_picker` e `path_provider` (fotocamera e cartella dell'app),
`shared_preferences` (le impostazioni), `audioplayers` (MIT, per suonare).

### Dove finiscono nomi e foto

Solo sul telefono. Il gioco non ha codice di rete: nomi e foto non vengono
mandati da nessuna parte. Stanno nella cartella privata dell'app
(`Application Support/roster/`): un `roster.json` con nomi e posti al tavolo, e
una cartella `photos/` con un JPEG piccolo per persona (lato lungo 800 punti,
un centinaio di kilobyte). Togliere una foto, una persona o tutti cancella
anche i file; disinstallare l'app cancella tutto. Come per ogni app, se il
telefono fa il backup su iCloud o sul computer, la cartella dell'app è
compresa nel backup del telefono.

Manca ancora la rete tra telefoni: `FakeLocalSession` fa da stanza finta.

Si lavora **solo su iOS** per ora (Simulator + eventuale iPhone fisico).
Android è già scaffoldato ma non verrà testato finché non lo decidiamo insieme.

## I dodici ruoli

Si gioca da 3 a 16, narratore escluso. Circa uno su quattro sta con la
famiglia; gli altri ruoli entrano man mano che il tavolo cresce, e a ogni
tavolo resta almeno un Onesto. Di notte ognuno fa **una sola mossa**: chi
non ne ha una vera riceve un compito di copertura.

**La famiglia** (si conoscono tra loro)

| Ruolo | Da | Cosa fa |
|---|---|---|
| **Il Picciotto** | 3 | Di notte vota con la famiglia chi non vedrà l'alba. |
| **Il Padrino** | 8 | Vota come un Picciotto, ma al Commissario risulta innocente. Se la parità la decide il capo, il capo è lui. |
| **Il Sarto** | 10 | «Cuce abiti di giorno e bocche di notte»: ogni notte sceglie chi, il giorno dopo, non potrà parlare (mai la stessa persona due notti di fila). Non vota l'agguato finché in famiglia c'è chi spara; rimasto solo, uccide lui. |

**Gli onesti**

| Ruolo | Da | Cosa fa |
|---|---|---|
| **L'Onesto** | 3 | Nessun potere: osserva, accusa, vota. |
| **Il Commissario** | 4 | Ogni notte indaga su qualcuno e scopre da che parte sta. O da che parte sembra stare. |
| **Il Dottore** | 5 | Ogni notte protegge qualcuno, anche se stesso. Mai la stessa persona due notti di fila. |
| **Il Cecchino** | 7 | Un solo proiettile in tutta la partita. |
| **Il Cronista** | 8 | Un solo scoop: all'alba tutti sanno da che parte sta davvero chi ha scelto. Se il Cronista muore quella notte, il giornale non esce. |
| **Il Becchino** | 8 | Ogni notte può scavare nella fossa di chi è morto di notte, e scopre (solo lui) che ruolo aveva. |
| **Il Reduce** | 9 | Pelle dura: il primo agguato notturno contro di lui va a vuoto. Il secondo no. |
| **Il Guardaspalle** | 10 | Ogni notte scorta qualcuno: se quella persona finisce nel mirino, muore lui al suo posto. Il tavolo vede solo la sua morte. |
| **Il Pregiudicato** | 11 | Sta con gli onesti, ma al Commissario risulta della famiglia. |

Solo il Commissario si fa ingannare da Padrino e Pregiudicato: il giornale,
la fossa e il patibolo dicono sempre la verità.

**Il mazzo, tavolo per tavolo**

| Giocatori | Famiglia | Onesti con un ruolo | Onesti |
|---|---|---|---|
| 3 | Picciotto | — | 2 |
| 4 | Picciotto | Commissario | 2 |
| 5 | Picciotto | + Dottore | 2 |
| 6 | Picciotto | come sopra | 3 |
| 7 | Picciotto | + Cecchino | 3 |
| 8 | Padrino, Picciotto | + Cronista, Becchino | 1 |
| 9 | Padrino, Picciotto | + Reduce | 1 |
| 10 | Padrino, Sarto | + Guardaspalle | 1 |
| 11 | Padrino, Sarto | + Pregiudicato (ci sono tutti e otto) | 1 |
| 12 | Padrino, Sarto, Picciotto | tutti e otto | 1 |
| 13 | Padrino, Sarto, Picciotto | tutti e otto | 2 |
| 14 | Padrino, Sarto, Picciotto | tutti e otto | 3 |
| 15 | Padrino, Sarto, Picciotto | tutti e otto | 4 |
| 16 | Padrino, Sarto, 2 Picciotti | tutti e otto | 4 |

**Come si chiude una notte.** Le mosse si risolvono tutte insieme, quindi
chi muore ha comunque fatto in tempo ad agire. Nell'ordine:

1. la famiglia e il Cecchino scelgono i loro bersagli (chi è nel mirino di
   tutti e due subisce un agguato solo);
2. il Dottore ferma l'agguato contro chi protegge;
3. il Guardaspalle prende il colpo destinato a chi scorta (se il Dottore
   proteggeva il Guardaspalle, vivono tutti e due);
4. il Reduce regge il primo colpo che lo ucciderebbe;
5. chi resta colpito muore, e il suo ruolo resta segreto.

All'alba ogni agguato va in scena per com'è andato: il delitto, il Dottore
che arriva in tempo, o il colpo che si ferma su una fiaschetta nel taschino.

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
                 i testi stanno in un pacchetto per lingua (`italian_pack`,
                 `english_pack`), insieme ai nomi, motti e spiegazioni dei
                 dodici ruoli.

  l10n/       -> Le lingue dell'app (`AppLanguage`) e i testi
                 dell'interfaccia (`AppStrings`, una classe per lingua).
                 Si segue la lingua del telefono: italiano se è italiano,
                 inglese altrimenti; dalle impostazioni si sceglie a mano.

  settings/   -> Le preferenze ricordate tra una sera e l'altra (lingua,
                 audio), con `shared_preferences`.

  network/    -> Strato di comunicazione, sostituibile dietro un'unica
                 interfaccia: sessione finta oggi, poi HostLocale (rete
                 locale) e ServerRemoto (Supabase).

  roster/     -> L'elenco di chi gioca su questo telefono: il modello (Dart
                 puro), l'archivio dietro un'interfaccia (in memoria nei
                 test, su file nell'app) e le facce che i ritratti mostrano.
                 Solo `device_roster.dart` tocca i plugin, e si installa
                 all'avvio in `main()`.

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
   dodici ruoli e tavoli fino a 16, con test sulle regole e sul copione
3. ✅ Grafica, animazioni e suoni: fondali, menu, ritratti e foto, scene
   della notte, musica ed effetti (le voci ⏳: servono registrazioni vere)
4. Un telefono a testa in rete locale
5. Server remoto (Supabase): partite a distanza, narratore automatico con voce
6. Classificata, pubblicazione (l'inglese c'è ✅)

**Regola d'oro:** prima il gioco deve divertire, poi si abbelliscono le animazioni.

La direzione a lungo termine (Supabase, un telefono a testa anche senza
internet, ruoli segreti, personalizzazione, classificata) è in
[docs/visione.md](docs/visione.md).

## TestFlight

- Bundle ID `com.obertagame.oberta`, team `RP26VC54CU`, app "Obertà" su
  App Store Connect.
- Serve un Apple ID collegato in Xcode (Settings → Accounts): la firma è
  automatica, Xcode crea da solo certificato e profilo.
- `bundle exec fastlane ios beta` alza il numero di build, compila, firma e
  carica su TestFlight con la chiave API di App Store Connect. La chiave
  (`fastlane/AuthKey_*.p8`) e i suoi id (`fastlane/.env`) non vanno in git.

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
