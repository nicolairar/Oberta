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

- **Dodici ruoli, da 3 a 12 giocatori**: vedi [I dodici ruoli](#i-dodici-ruoli).
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
- **Sei lingue**: italiano, inglese, spagnolo, francese, tedesco e
  portoghese brasiliano. L'app segue la lingua del telefono (una lingua non
  ancora tradotta, giapponese o arabo, gioca in inglese) e dalle impostazioni
  si sceglie a mano, con le bandierine. Copione, ruoli e interfaccia esistono
  in tutte; la voce del narratore solo in italiano e inglese (le altre lingue
  leggono il copione sullo schermo). Vedi «Le lingue» più sotto.

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

Si gioca da 3 a 12, narratore escluso. Circa uno su quattro sta con la
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

## Le lingue

Due lingue sorgente, l'italiano e l'inglese, e quattro tradotte (spagnolo,
francese, tedesco, portoghese brasiliano). Tre livelli:

- **`AppStrings`, `OnlineStrings`, `ShopStrings`**: classi astratte con un
  membro per testo; `ItalianStrings` ed `EnglishStrings` (e le compagne)
  dicono tutto, il compilatore segnala cosa manca. Plurali e accordi stanno
  nel codice della lingua.
- **I messaggi a chiave** (`lib/l10n/messages_en.dart`, `messages_it.dart`):
  le classi più piccole (impostazioni, tavolo, resoconto, missioni, regole,
  tutorial...) chiedono `language.message('scope.chiave', {...})`. I testi
  usano `{nome}` e le forme in stile ICU `{n, plural, one{# partita}
  other{# partite}}` e `{gender, select, feminine{..} masculine{..}
  other{..}}` (lib/l10n/message_format.dart, senza l'escape degli apostrofi).
  `gender` si passa solo dove l'italiano accorda; altrove nessuna frase dà un
  genere al giocatore.
- **Il copione** (`NarrationPack`): uno per lingua; senza, si legge
  l'inglese. Le regole lette ad alta voce (`RulesStrings`) hanno italiano e
  inglese nel file, le altre lingue le portano con `rulesSteps`.

Una lingua che non traduce un testo ripiega sull'inglese, mai sull'italiano.
Chi aggiunge un testo lo scrive in `messages_en.dart` e `messages_it.dart`
(o come membro di `AppStrings`) e lo traduce nei file di `languages/`:
`test/l10n/translations_test.dart` controlla che ogni chiave ci sia in ogni
lingua, con gli stessi segnaposto, e che quasi niente sia rimasto in inglese.

### Aggiungere una lingua

1. Copiare `lib/l10n/languages/es.dart` in `lib/l10n/languages/<codice>.dart`
   (codice ISO 639-1) e rinominare le classi: `XxxStrings extends
   EnglishStrings`, `XxxOnlineStrings`, `XxxShopStrings`, `xxxMessages`,
   `xxxPack`, le regole `_quickXx`/`_stageXx`. Ogni classe estende quella
   inglese: quello che non si traduce resta in inglese.
2. Aggiungere una riga all'enum `AppLanguage` (lib/l10n/app_language.dart):
   `xx(Locale('xx'), 'Nome nella lingua', XxxStrings())`. Se la lingua si
   scrive da destra a sinistra il codice è già in `rtlLanguageCodes`, e
   `textDirection` la gira sul telefono (il riquadro del desktop resta da
   sinistra a destra). Se ha un ruolo con la maiuscola anche a metà frase,
   aggiornare `capitalizesRoles`.
3. Una bandierina: `LanguageFlag` (lib/ui/widgets/language_flag.dart) dipinge
   quelle delle lingue tradotte; senza, il tavolo mostra il codice.
4. Le virgolette dei motti in `test/l10n/role_texts_test.dart`.
5. `flutter test test/l10n`: la prova di completezza dice cosa manca.

Il server accetta già ogni codice ISO 639-1 per stanze, coda classificata,
rating e classifica (migrazione `20261123090000_lobby_languages`), quindi una
lingua nuova non chiede migrazioni. La voce del narratore per le lingue
nuove è da fare (TODO): `NarratorVoice.speaks` è falso dove non ci sono clip,
e il narratore resta solo testo.

### I tavoli per lingua

Ognuno vede i tavoli in italiano e in inglese, più quelli della sua lingua
(`LobbyLanguage.offered`): quella scelta nelle impostazioni o, in automatico,
quella del telefono anche se l'app non è tradotta (un telefono giapponese
gioca in inglese ma trova i tavoli giapponesi). La classificata e la
classifica filtrano per lingua, ogni tavolo ha la sua bandierina.

### I caratteri

Georgia e Courier coprono il latino, il cirillico e il greco. Per gli altri
sistemi (cinese, giapponese, coreano, arabo, ebraico, devanagari, thai) ogni
stile ha un `fontFamilyFallback` (lib/ui/theme/script_fonts.dart) con i
caratteri di sistema di iOS/macOS, Windows e Android/Linux (Noto): niente è
incluso nell'app, perché le famiglie Noto CJK pesano 10-20 MB l'una. Se una
piattaforma ne restasse senza (il web, un Linux spoglio), si aggiunge un
sottoinsieme Noto Sans in `assets/fonts/` e lo si mette in testa a
`scriptFallback`. Nella chat i messaggi da destra a sinistra sono isolati
(`bidiIsolate`): il nome e il numero del posto restano al loro posto.

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

  l10n/       -> Le lingue dell'app (`AppLanguage`), le lingue dei tavoli
                 (`LobbyLanguage`, ogni codice ISO 639-1) e i testi:
                 `AppStrings` (una classe per lingua), i messaggi a chiave
                 (`messages_en.dart`, `messages_it.dart`) e una cartella
                 `languages/` con un file per ogni lingua tradotta.

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

## L'accesso online

Si entra con Apple (iPhone), Google (iPhone e Android, se l'app ha i client id), Steam (desktop) o
con **un indirizzo email, senza password**: Supabase manda un codice di 6 cifre che vale 15 minuti,
e sui telefoni nella stessa mail un link che riapre l'app già dentro (`oberta://login-callback`,
scambiato da supabase_flutter). Niente password da nessuna parte, quindi niente «password
dimenticata».

- App: `SignInPanel` in `lib/ui/screens/online/sign_in_sheet.dart` (i passi: modi d'accesso →
  indirizzo → codice), le sei caselle in `email_code_field.dart`, le chiamate in
  `SupabaseAuth.sendEmailCode` / `verifyEmailCode` (`lib/online/supabase_online.dart`).
- Server: il Send Email Hook di Supabase Auth chiama la Edge Function `auth-email`, che manda la
  mail con Brevo. Il modello della mail è `supabase/functions/auth-email/templates/code.ts`, le
  anteprime `site/oberta/email/accesso*.html`.
- Impostazioni, segreti, prove e limiti: `docs/release.md`, sezione 13.

## Roadmap (vedi anche il brief di progetto)

0. ✅ Setup ambiente (Flutter, Xcode, Simulator iOS)
1. ✅ Preparazione: stanza con codice, lobby, narratore, ruota, carta ruolo
2. ✅ Partita completa su un telefono: notte, alba, giorno, voto, vittoria,
   dodici ruoli e tavoli fino a 12, con test sulle regole e sul copione
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

## Prestazioni

Obiettivo: 120 Hz su ProMotion, cioè 8,3 ms per fotogramma sia per il
lavoro del framework (build, layout, paint) sia per il raster.

### Come si misura

- `flutter test tool/perf/frame_cost_test.dart` — nel motore dei test,
  senza finestre: telefono 393×852 a 3x e desktop 1920×1080, gli stessi
  scenari di `tool/perf/scenarios.dart`. Per ogni scenario: ms del framework
  (JIT di debug, quindi più lento del vero, ma i rapporti tengono), raster
  sulla CPU, widget ricostruiti, oggetti ridipinti, immagini registrate di
  nuovo, `Baked` rifatti, strati e filtri. `DIG=1` dice chi ridipinge, chi
  chiede il paint e quali immagini costano; `PERF_SHOTS=dir PERF_STILL=1`
  salva i fotogrammi fermi per il confronto pixel per pixel (la notte
  rimescola i posti sempre allo stesso modo, così si confronta anche lei).
- `flutter drive --profile -d macos --driver=test_driver/perf_driver.dart
  --target=integration_test/perf_test.dart` — l'app vera in profile
  (Impeller/Metal), con le tracce di `traceAction`: build e raster medi e al
  90°. Finestra 393×852 punti (Retina 2x) e 960×540 punti (1920×1080 px).
  `--dart-define=PERF_ONLY=phone: partita` per pochi scenari,
  `--dart-define=PERF_DIG=true` con `PERF_RAW=1` per la traccia completa di
  ogni widget. Una sola app per volta sul Mac (`/tmp/oberta_app.lock`).

### Cosa costava, e cosa si è fatto

- **Tavolo di giorno (e di notte, voto, verdetto, fine)**: il timer da 250 ms
  del cronometro ricostruiva tutta `OnlineGameScreen` quattro volte al
  secondo; col tavolo a dodici e la chat costava 6–13 ms di build, e l'app
  in profile riusciva a dare 20–30 fotogrammi su 96. Adesso si ricostruisce
  solo quando cambia qualcosa che dipende dall'ora (fase aperta, inizio
  comune, scena del film, server muto); l'orologio in testa si aggiorna da
  solo (`ValueListenableBuilder`).
- **Vicolo**: le due insegne che dondolano erano `AnimatedBuilder` dentro il
  `LayoutBuilder` della pagina: ogni fotogramma rifaceva layout e paint di
  tutto il vicolo (144 oggetti). Ora girano in un `Flow` che ruota lo strato
  al paint, senza ricostruire; la pagina ha il suo `RepaintBoundary` (la
  didascalia che si scrive non la ridipinge), e il riflesso sul pulsante del
  manifesto si ridisegna solo quando passa.
- **Camminata per strada**: `StreetDrift` ricostruiva a ogni passo dentro lo
  stesso `LayoutBuilder`; ora è un oggetto di render che sposta e sfuma lo
  strato già disegnato (stessi strati di `Opacity` + `Transform.translate`).
- **Bottega**: il ritratto grande, i pezzi sulla ruota e i medaglioni si
  dipingevano dal vivo a ogni fotogramma (un ritratto con scena ed effetti
  costava da solo 1 s di raster CPU). Ora sono `Baked` (la ruota con
  `tilted`).
- **Riscaldamento**: `WarmUp` disegna anche un ritratto per ogni scena della
  bottega, con spalle, effetti in testa e davanti, mani e occhi.

Pixel: vicolo, regole e fine partita identici prima/dopo (a parte la battuta
della didascalia, che è a caso). Nella bottega cambiano solo i bordi
antialiasati del ritratto (l'immagine si posa sul pixel intero) e dei pezzi
girati sulla ruota: 0,9% dei pixel oltre 8 livelli sul telefono.

### Numeri (app in profile sul Mac, ms per fotogramma, media → media)

| scenario | build | raster | fotogrammi dati / 96 |
|---|---|---|---|
| telefono, vicolo fermo | 0,57 → 0,42 | 3,0 → 3,6 | 96 → 96 |
| telefono, camminata | 1,03 → 1,06 | 2,8 → 2,7 | |
| telefono, bottega, ruota che gira | 2,31 → 2,45 | 4,8 → 4,3 | |
| telefono, giorno, chat che arriva | 3,33 → 0,39 | 7,5 → 8,3 | 52 → 104 |
| telefono, giorno, anelli della voce | 6,18 → 0,56 | 9,7 → 11,6 | 22 → 96 |
| telefono, voto fermo | 9,06 → 0,40 | 13,7 → 10,1 | 23 → 96 |
| telefono, voti che cambiano | 9,49 → 1,96 | 13,8 → 12,1 | 21 → 95 |
| telefono, verdetto | 8,93 → 0,46 | 13,8 → 11,2 | 24 → 144 |
| telefono, fine partita | 6,02 → 0,36 | 9,5 → 8,3 | 33 → 144 |
| desktop, vicolo fermo | 1,59 → 0,83 | 6,5 → 3,9 | |
| desktop, camminata | 0,87 → 0,53 | 36,0 → 7,4 | |
| desktop, bottega | 0,34 → 0,22 | 38,3 → 8,1 | |
| desktop, notte | 9,34 → 0,53 | 10,6 → 9,6 | 25 → 96 |
| desktop, giorno, chat che scorre | 11,52 → 1,05 | 11,9 → 7,2 | 20 → 93 |
| desktop, voto fermo | 12,52 → 0,56 | 13,6 → 11,0 | 22 → 96 |
| desktop, verdetto | 11,62 → 0,54 | 14,1 → 10,9 | 22 → 144 |

Nel motore dei test (per fotogramma): vicolo fermo 144 → 3 oggetti
ridipinti e 6 → 1 immagini registrate; camminata 170 → 31; giorno fermo
17 → 0,3 widget ricostruiti; bottega ferma 887 → 49 ms di raster CPU.

### Il tavolo a dodici, posto per posto

Impeller non tiene niente da parte: a ogni fotogramma in cui qualcosa si
muove (un messaggio, l'anello di chi parla, un voto) ridisegna da capo tutti
e dodici i posti. E ogni posto costava: l'ombra sfocata dell'arco (gli
angoli in alto e in basso sono diversi, e allora il motore la fa in uno
strato fuori schermo, con la sfocatura), le ombre della targhetta e del
gettone, e due strati di trasparenza, perché in Flutter `Opacity` è sempre
uno strato suo, anche a 1.

- Ogni posto fermo adesso è un'immagine sola: `Baked(exact: true)` intorno a
  `SeatCard`. «Al punto esatto»: l'immagine si fa col posto dove cade
  davvero sullo schermo, frazioni di pixel comprese, così è uguale al
  disegno dal vivo, e i ritratti già tenuti da parte lì dentro cadono sui
  pixel interi (posati di traverso si sfocherebbero). Quanto il posto
  sborda (ombre, targhetta, gettone, nastro, bagliori della cornice e del
  nome, il posto scelto che si ingrandisce) lo calcola `SeatCard`.
- Quando un posto cambia (un voto, il nastro dell'accusato, il posto scelto
  che si ingrandisce) si disegna dal vivo finché si muove, poi l'immagine si
  rifà; gli altri undici restano immagini. Un `Baked` dentro un altro (il
  ritratto, la cornice ferma) avvisa quello fuori quando cambia.
- Dentro il posto c'è `PlainOpacity` invece di `Opacity`: la stessa
  trasparenza, senza strato suo, così finisce nell'immagine.
- Anche l'alone di chi parla (`VoiceRing`) è un'immagine.
- Restano dal vivo i posti con dentro qualcosa che si muove da sé: le
  cornici leggendarie, i nomi che luccicano, il riflesso dei ritratti d'oro.

Pixel (motore dei test, fotogrammi fermi): notte, giorno, voto, verdetto e
anelli della voce cambiano di 1–6 livelli su 255 (quasi tutti 1–2) sul
2–5% dei pixel, nelle ombre: è l'arrotondamento dell'immagine. Fine
partita: una manciata di pixel a 13 livelli dove lo scorrimento taglia i
gettoni. Vicolo, regole e bottega uguali (a parte la didascalia a caso e i
conti alla rovescia della bottega, che vanno con l'ora).

Numeri (app in profile sul Mac, ms per fotogramma, media di tre coppie di
prove prima → dopo, prese alternate, col Mac più o meno carico). Già prima
erano più bassi della tabella sopra (lì 10–12 ms, oggi 3,5–5,5 per gli
stessi scenari): si confrontano le due colonne di ogni riga, non le
tabelle.

| scenario | build | raster | raster al 90° |
|---|---|---|---|
| telefono, notte | 0,17 → 0,36 | 3,8 → 2,0 | 4,5 → 2,3 |
| telefono, giorno fermo | 0,21 → 0,34 | 4,3 → 2,1 | 5,4 → 2,5 |
| telefono, giorno, chat che arriva | 0,17 → 0,35 | 5,3 → 3,0 | 6,6 → 3,4 |
| telefono, giorno, anelli della voce | 0,22 → 0,43 | 4,5 → 2,7 | 5,5 → 3,3 |
| telefono, voto fermo | 0,15 → 0,33 | 4,6 → 2,6 | 5,5 → 3,1 |
| telefono, voti che cambiano | 0,66 → 0,98 | 4,3 → 2,5 | 5,9 → 3,4 |
| telefono, verdetto | 0,14 → 0,34 | 4,2 → 2,6 | 4,8 → 3,2 |
| desktop, notte | 0,24 → 0,42 | 4,2 → 1,9 | 6,0 → 2,1 |
| desktop, giorno, chat che arriva | 0,21 → 0,40 | 4,4 → 3,0 | 5,0 → 3,3 |
| desktop, giorno, anelli della voce | 0,30 → 0,55 | 4,0 → 2,7 | 4,7 → 3,4 |
| desktop, voto fermo | 0,20 → 0,38 | 4,2 → 2,5 | 4,8 → 3,1 |
| desktop, voti che cambiano | 1,08 → 1,29 | 4,3 → 2,4 | 5,6 → 4,2 |
| desktop, verdetto | 0,17 → 0,44 | 3,6 → 2,8 | 4,6 → 3,1 |

Nel motore dei test: strati per fotogramma 142 → 82 (telefono, notte),
strati di trasparenza e filtri 2 → 1; da fermi nessun posto si rifà, quando
cambiano i voti 0,9 immagini per fotogramma.

### Cosa resta

- **Il build del tavolo** è salito di 0,1–0,3 ms per fotogramma: a fine
  fotogramma ogni `Baked` guarda se si è spostato (`getTransformTo` fino
  alla radice), e adesso sono una trentina (posti, ritratti, aloni). Poco
  contro gli 8,3 ms, ma si potrebbe guardare una volta sola per tutto il
  tavolo.
- I posti con le cornici leggendarie, i nomi che luccicano e i ritratti
  d'oro restano dal vivo: un tavolo pieno di quelli torna verso i numeri di
  prima. Si potrebbero tenere due immagini, sotto e sopra la cornice che si
  muove.
- I voti che cambiano ricostruiscono tutto il tavolo (giusto, ma 1–2 ms) e
  rifanno l'immagine dei posti toccati.
- La ruota della bottega ricostruisce la pagina intera a ogni trascinamento
  (2,5 ms di build): da isolare in un widget suo.
- `VerdictScene` (il film del verdetto) non si vede più nell'app: il
  verdetto è sul tavolo. Misurato solo nel motore dei test.
