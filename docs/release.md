# Uscire con una versione nuova (procedura)

Da seguire **ogni volta**, nell'ordine. I comandi si lanciano dalla radice del repository
(il checkout principale, dove ci sono `fastlane/.env` e `config/supabase.json`).

## La release in 11 righe

1. Decidi la versione (`x.y.z`, regole sotto) e scrivila in `pubspec.yaml`; la build `+N` la alza fastlane.
2. `flutter analyze && flutter test` verdi; migrazioni e Edge Function sul server; voce, landing e screenshot aggiornati se servono.
3. iOS di prova: `RANKED_DEBUG=1 bundle exec fastlane ios beta` → TestFlight interno, commit del `+N`.
4. Tester esterni: `bundle exec fastlane ios external_beta` (gruppo «External Tester»).
5. App Store: `bundle exec fastlane ios beta` **senza** `RANKED_DEBUG`, poi `bundle exec fastlane ios metadata`.
6. App Store Connect: scegli la build, rilascio graduale, invia alla revisione.
7. Android: `bundle exec fastlane android internal` → bozza sulla traccia interna di Play; da Play Console ai tester, poi produzione graduale (sezione 7).
8. Desktop: `git tag vX.Y.Z && git push origin vX.Y.Z` → il CI compila, zip privati negli artifact.
9. Steam (Fase 2): carica gli zip con SteamPipe sul branch `beta`, prova, poi metti live su `default`.
10. Solo se le build vecchie non devono più giocare online: `tool/release/set_min_build.sh <platform> <N>`.
11. Dopo: link e badge della landing, `./deploy.sh` di CharlieWebsite sul server, note in `docs/stato.md`.

---

## 1. Numeri di versione

`pubspec.yaml` → `version: x.y.z+N`.

| Parte | Quando sale | Esempio |
|---|---|---|
| `x` (maggiore) | cambio che rompe: regole o server incompatibili con le build vecchie (di solito insieme a `set_min_build.sh`), rifacimento grosso | `1.4.2` → `2.0.0` |
| `y` (minore) | cose nuove per i giocatori: ruoli, modalità, negozio, schermate | `1.4.2` → `1.5.0` |
| `z` (correzione) | solo correzioni, testi, bilanciamenti piccoli | `1.4.2` → `1.4.3` |
| `+N` (build) | **ogni** build caricata su qualunque negozio; solo in salita, una sola numerazione per tutte le piattaforme | `+59` → `+60` |

- Quando sale `x`, `y` e `z` tornano a 0; quando sale `y`, `z` torna a 0. `+N` non torna mai indietro.
- `+N` lo alza da solo `fastlane ios beta` (se dall'ultimo commit non è già salito). Dopo l'upload
  **committa** `pubspec.yaml`, altrimenti il prossimo upload riusa lo stesso numero.
- Per una release solo desktop, alza `+N` a mano.
- `x.y.z` lo cambi a mano, una volta per release, prima della prima build di quella versione.

```sh
# vedere la versione attuale
grep '^version:' pubspec.yaml
# dopo un upload di fastlane
git add pubspec.yaml && git commit -m "Bump build to $(sed -n 's/^version: .*+//p' pubspec.yaml)"
```

## 2. Prima di ogni release (checklist)

1. Codice pulito e test verdi:
   ```sh
   flutter analyze
   flutter test
   deno test -A supabase/functions/tests/
   ```
2. Motore online: se sono cambiate regole, bot o passo del server, rigenera e committa il bundle
   (un test fallisce finché è vecchio):
   ```sh
   tool/edge/build.sh
   ```
3. Migrazioni: si applicano da sole a ogni push su `main` (integrazione GitHub di Supabase). Prima del
   push provale con `begin; … rollback;` (SQL editor o API, token in `fastlane/.env`); dopo il push
   controlla che ci siano: Supabase → Database → Migrations, oppure
   ```sh
   supabase migration list --linked
   ```
   Le build nuove non devono mai uscire prima delle migrazioni che usano.
4. Edge Function: l'integrazione GitHub pubblica solo quelle dichiarate in `supabase/config.toml`
   (`game`, `account`, `steam-auth`). Controlla in Supabase → Edge Functions che la data di
   pubblicazione sia quella del tuo push. A mano, se serve:
   ```sh
   supabase functions deploy game
   ```
5. Voce: se è cambiato un testo del narratore (`lib/narration/*_pack.dart`) o un dialogo nuovo:
   ```sh
   tool/voice/regenerate.sh
   ```
   e committa `assets/voice/` (Kokoro `im_nicola` / `am_adam`, 0.86, effetto godfather).
6. Landing (`site/oberta/`): testi aggiornati se la UI o le funzioni sono cambiate, poi
   schermate e video rifatti in un colpo (vedi `site/oberta/README.md`):
   ```sh
   tool/site/refresh_media.sh && dart run tool/site/roles_page.dart
   ```
   Pubblica da sola a ogni push su `main` (Cloudflare Pages).
7. Screenshot dello store, se è cambiata la UI:
   ```sh
   flutter test tool/render/store_screenshots_render_test.dart
   ```
   (vanno in `fastlane/screenshots/{it,en-US}/`; si caricano col passo 5.2).
8. «Cosa provare»: `fastlane/testflight/what_to_test_{it,en-US}.txt` riscritti per questa versione.
9. Tutto committato e pushato su `main`:
   ```sh
   git pull --rebase && git push
   ```

## 3. iOS: TestFlight interno (amici e noi)

1. Build di prova con la classificata aperta:
   ```sh
   RANKED_DEBUG=1 bundle exec fastlane ios beta
   git add pubspec.yaml && git commit -m "Bump build" && git push
   ```
2. App Store Connect → TestFlight: aspetta che la build finisca «Processing» (10–30 minuti); i tester
   interni la ricevono da soli.
3. `RANKED_DEBUG` serve **solo** ai tester: non deve mai arrivare all'App Store. Fa della build una
   build di prova (`--dart-define=OBERTA_TEST=true`, `lib/build_flags.dart`): classificata aperta,
   accesso con email e password, stanze che partono in due. Senza, è la build da negozio.
4. Il caricamento **non** alza la build minima.

## 4. iOS: TestFlight esterno

1. Serve almeno una build processata e, in App Store Connect → TestFlight, il gruppo esterno
   **«External Tester»** con almeno un tester invitato (email o link pubblico).
2. Nell'ambiente: `BETA_CONTACT_EMAIL`, `BETA_CONTACT_FIRST_NAME`, `BETA_CONTACT_LAST_NAME`,
   `BETA_CONTACT_PHONE` (in `fastlane/.env`, mai nel repo).
3. La lane distribuisce **l'ultima build caricata**: assicurati che sia quella giusta
   (con o senza `RANKED_DEBUG`).
   ```sh
   bundle exec fastlane ios external_beta
   ```
4. La prima build di ogni versione passa dalla Beta App Review (di solito meno di un giorno); poi i
   tester ricevono la notifica.

## 5. iOS: App Store

1. Build da negozio, **senza** `RANKED_DEBUG`:
   ```sh
   bundle exec fastlane ios beta
   git add pubspec.yaml && git commit -m "Bump build" && git push
   ```
2. Testi e screenshot della scheda (nessuna revisione, nessuna build):
   ```sh
   bundle exec fastlane ios metadata
   ```
3. Prima del primo invio: `docs/app-store.md` spuntato; l'accesso email/password nella build da
   negozio non c'è già (`lib/build_flags.dart`); provider Email di Supabase spento e
   `supabase/scripts/prelaunch.sql` eseguito (sezione 8).
4. App Store Connect → App → **+ Versione** `x.y.z` → *Build*: scegli la build appena processata.
5. *Rilascio della versione*: **manuale** dopo l'approvazione, e attiva
   **Rilascio graduale (7 giorni)**.
6. *Invia per la revisione*. Dopo l'approvazione: *Rilascia questa versione*.
7. Da quando è in vendita, chi ha una versione più vecchia vede «Aggiornamento obbligatorio»
   (ricerca dell'App Store, cache un'ora; può anticipare di qualche ora la disponibilità in tutti i
   paesi). Se il rilascio graduale va in pausa, il cartello resta: il pulsante porta comunque
   all'App Store, dove l'aggiornamento manuale è sempre disponibile.

## 5.1 Game Center (iOS): i traguardi

Il gioco decide i traguardi sul server; l'iPhone li specchia su Game Center **solo dopo** la conferma
(`lib/platform/achievements.dart`, plugin `games_services`): a fine partita quelli di `game_unlocks`,
e tutti quelli già presi quando si aprono Medaglie o I ruoli. All'avvio l'app chiede l'accesso a Game
Center in sottofondo (il banner o il foglio di Apple, mai un'attesa); senza accesso non manda niente e
riprova più tardi.

- Capability: Game Center è attivo di default su ogni App ID; l'entitlement
  `com.apple.developer.game-center` è in `ios/Runner/Runner.entitlements`. Se fastlane/match si lamenta
  del profilo, rigenerarlo (`bundle exec fastlane match appstore --force`).
- App Store Connect → App → *Funzionalità* → **Game Center**: attivarlo per l'app e, nella pagina della
  versione, spuntare **Game Center** prima dell'invio (altrimenti in produzione i traguardi non si vedono).
- *Traguardi* → **+** per ognuno:
  - **ID traguardo**: `oberta.<id>`, con `<id>` il nostro id esatto (`oberta.wins_10`,
    `oberta.role_medico`, `oberta.roles_town_all`, ...). L'elenco completo è in `docs/steam.md`
    («Traguardi Steam»), lo stesso per tutte le piattaforme. Non si rinomina mai.
  - **Nome di riferimento**: l'id stesso.
  - **Punti**: totale massimo 1000 per app. Proposta: 5 per ogni `role_<ruolo>`, 25 per i
    `roles_*_all`, 10–50 per gli altri secondo il livello (1/2/3).
  - **Nascosto**: no. **Ottenibile più volte**: no.
  - **Localizzazioni** Italiano e Inglese: titolo e descrizione da `lib/l10n/progress_strings.dart`
    (prima e dopo lo sblocco), immagine 512×512 o 1024×1024 PNG.
- Un ruolo nuovo = un traguardo nuovo `oberta.role_<nome>`; finché non c'è su App Store Connect
  l'iPhone lo manda e Game Center lo ignora, senza danni.
- Prova: in TestFlight / Sandbox Game Center i traguardi funzionano già prima della pubblicazione.

## 6. Desktop (solo Steam)

Il desktop esce **solo su Steam**: niente download pubblici, niente release GitHub. Gli
aggiornamenti li fa Steam; l'app desktop non controlla le versioni, conta solo la build minima del
server (sezione 9).

1. Versione in `pubspec.yaml` (`+N` alzato) committata e pushata su `main`.
2. Tag uguale alla versione di pubspec (altrimenti il job «Release check» fallisce):
   ```sh
   v=$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' pubspec.yaml)
   git tag "v$v" && git push origin "v$v"
   ```
3. GitHub → Actions → *Desktop builds* (run del tag): quando è verde, scarica gli artifact
   `oberta-windows`, `oberta-linux`, `oberta-macos` (privati, restano 90 giorni).
   ```sh
   gh run download --repo nicolairar/Oberta -D dist $(gh run list --repo nicolairar/Oberta --workflow desktop.yml --branch "v$v" --limit 1 --json databaseId -q '.[0].databaseId')
   ```
4. **(Fase 2, quando c'è l'App ID)** Le build Steam si compilano con
   `--dart-define=STEAM=true --dart-define=STEAM_APP_ID=<APPID>`, il Mac firmato Developer ID e
   notarizzato. Carica con SteamPipe sul branch `beta` (protetto da password):
   ```sh
   steamcmd +login <utente_build> +run_app_build "$PWD/steam/app_build_<APPID>.vdf" +quit
   ```
5. Prova dal branch `beta` (Steam → Proprietà → Beta) su Windows, Mac e Linux/Steam Deck.
6. Steamworks → *SteamPipe* → *Builds*: metti la build live sul branch **`default`**.
   Steam aggiorna tutti da solo.

## 7. Android / Google Play

Pacchetto `com.obertagame.oberta`, stessa numerazione di iOS: `versionCode` = `+N`, `versionName` =
`x.y.z` (pubspec). `minSdk` 24 (Android 7), `targetSdk` 36 (Play chiede almeno 35). Su Play va un
**AAB** firmato con la **chiave di caricamento**; la chiave con cui l'app arriva ai telefoni la
genera e la tiene Google (Play App Signing).

### 7.1 La chiave di caricamento (fatta: da custodire)

- `android/upload-keystore.jks` (PKCS12, RSA 4096, alias `upload`, valida fino al 2054) e
  `android/key.properties` (password, alias, `storeFile=../upload-keystore.jks`): **mai in git**
  (`android/.gitignore`, controlla con `git check-ignore -v android/key.properties android/upload-keystore.jks`).
  Le stesse password sono in `fastlane/.env` (`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`).
- **Copia di sicurezza adesso**: il `.jks` e la password fuori dal Mac (gestore di password). Persa la
  chiave, Play la sostituisce (Play Console → *Integrità dell'app* → *Richiedi la reimpostazione della
  chiave di caricamento*), ma ci vogliono giorni.
- Senza `key.properties` la release si firma con la chiave di debug: va bene per provarla a mano, Play
  la rifiuta, e la lane `android internal` si ferma prima di compilare.
- Su un altro Mac: copia i due file in `android/`.
- Impronte della chiave di caricamento (non sono segrete; servono a Google Sign-In, 7.5):

  ```
  SHA-1:   D0:2F:C8:E2:C3:04:61:8B:F8:AD:65:88:2E:B4:11:67:14:3E:0A:ED
  SHA-256: 41:ED:EC:90:36:22:4E:A9:A0:76:44:6F:FD:71:19:D7:C8:D5:8B:57:D6:E4:AF:68:CE:CD:88:E3:F5:00:77:94
  ```

  Per rileggerle: `keytool -list -v -keystore android/upload-keystore.jks -alias upload` (chiede la password).

### 7.2 Compilare e provare

Una volta sola sul Mac: Android Studio → *SDK Manager* → *SDK Tools* → **Android SDK Command-line
Tools (latest)**, poi `flutter doctor --android-licenses`. Senza, `flutter build appbundle` scrive
l'AAB ma finisce con «Release app bundle failed to strip debug symbols» (Flutter controlla l'AAB con
`apkanalyzer`, che sta lì) ed esce con errore: la lane si ferma.

```sh
# per Play (lo fa la lane, 7.8)
flutter build appbundle --release --dart-define-from-file=config/supabase.json
# per installarla a mano su un telefono col debug USB
flutter build apk --release --dart-define-from-file=config/supabase.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

- AAB: `build/app/outputs/bundle/release/app-release.aab`, circa 157 MB (tre architetture, simboli
  nativi e mapping di R8 dentro: Play li usa da solo per i crash). Un telefono ne scarica molto meno
  (Play Console → *App bundle explorer* dice quanto).
- Durante la build niente `flutter test` / `flutter drive` nello stesso checkout: rigenerano
  `GeneratedPluginRegistrant.java` con `integration_test` e la release fallisce con «package
  dev.flutter.plugins.integration_test does not exist». Basta rilanciare.
- R8 è acceso. Le regole le portano i plugin; `android/app/proguard-rules.pro` aggiunge i tipi Kotlin
  che `package:jni` e `shared_preferences_android` cercano per nome: senza, la release parte e
  resta ferma sul caricamento (le impostazioni non si aprono). Se un plugin nuovo chiama Kotlin da
  Dart con JNI, prova **sempre** la release su un telefono o un emulatore, non solo il debug.
- Librerie native allineate a 16 KB (obbligatorio su Play per target 35+): verificato.
- Permessi: Internet; microfono solo quando si sceglie «Microfono» (prima la spiegazione dell'app, poi
  la domanda di Android; negato → si ascolta e basta, con il pulsante per le impostazioni);
  fotocamera solo per il lettore QR; Bluetooth per le cuffie. Niente notifiche (l'app non ne manda:
  `POST_NOTIFICATIONS` non serve), niente ID pubblicità. Microfono, fotocamera e Bluetooth non sono
  obbligatori per installarla.
- Schermo intero (Android 15+): le schermate stanno dentro le barre di sistema, anche con i tre
  pulsanti in basso; il tema della finestra è sempre scuro (avvio e barra di navigazione).
- Icona: adattiva (`mipmap-anydpi-v26`), dagli stessi disegni di iOS: `tool/make_app_icons.sh`
  rifà tutte e due.
- Prova veloce senza telefono: c'è l'AVD `oberta_smoke` (Android 17, Play Store, pagine da 16 KB):
  `~/Library/Android/sdk/emulator/emulator -avd oberta_smoke`, poi `adb install -r ...apk`.

### 7.3 Play Console: la prima volta

1. Account sviluppatore Google Play (25 $ una tantum, verifica dell'identità). **Attenzione**: un
   account **personale** creato dopo il 13 novembre 2023 deve fare un **test chiuso con almeno 12
   tester per 14 giorni di fila** prima di poter chiedere la produzione. Per uscire a dicembre il
   test chiuso deve partire **entro metà novembre**. Un account **organizzazione** (serve il D-U-N-S)
   non ha questo obbligo.
2. *Crea app*: nome **Obertà**, lingua predefinita **Italiano – it-IT**, **Gioco**, **Senza costi**;
   accetta le dichiarazioni.
3. **Il primo AAB si carica a mano**: l'API di Play (fastlane) non crea la prima release di un'app
   nuova. *Test e rilascio* → *Test* → **Test interno** → *Crea nuova release* → carica
   `build/app/outputs/bundle/release/app-release.aab` (7.2) → *Salva*. Con il primo AAB Google attiva
   **Play App Signing** da solo (accetta la chiave generata da Google).
4. *Test e rilascio* → *Configurazione* → **Integrità dell'app** → *Firma dell'app*: copia SHA-1 e
   SHA-256 del **certificato della chiave di firma dell'app** (non di quella di caricamento). Servono
   a Google Sign-In (7.5) e a Play Games (7.9); scrivile qui sotto quando le hai:

   ```
   Firma dell'app (Play) SHA-1:   <da Play Console>
   Firma dell'app (Play) SHA-256: <da Play Console>
   ```

5. *Test interno* → *Tester*: un elenco di email (fino a 100), salva, copia il **link per i tester**
   (lo aprono dal telefono, accettano, poi scaricano da Play).

### 7.4 Il service account per fastlane

1. [Google Cloud Console](https://console.cloud.google.com), lo stesso progetto dei client OAuth
   (7.5): *API e servizi* → *Libreria* → abilita **Google Play Android Developer API**.
2. *IAM e amministrazione* → *Service account* → *Crea*: nome `fastlane-play`, nessun ruolo.
3. Il service account → *Chiavi* → *Aggiungi chiave* → **JSON**: salvalo come
   `fastlane/play-service-account.json` (fuori da git per `.gitignore`).
4. Play Console → **Utenti e autorizzazioni** → *Invita nuovi utenti*: l'email del service account
   (`...@...iam.gserviceaccount.com`); autorizzazioni per l'app Obertà: *Rilascia app nei canali di
   test*, *Gestisci canali di test e modifica elenchi di tester*, *Gestisci la presenza nello store*
   (per i testi); più avanti *Rilascia in produzione*. Possono servire alcune ore prima che valgano.
5. In `fastlane/.env`: `PLAY_JSON_KEY=fastlane/play-service-account.json` (percorso dalla radice del
   repo). Senza, le lane `android` si fermano subito e dicono cosa manca. Prova:
   ```sh
   bundle exec fastlane run validate_play_store_json_key json_key:fastlane/play-service-account.json
   ```

### 7.5 Accedi con Google su Android

Su Android l'app chiede a Google un token per il **client web** (`GOOGLE_WEB_CLIENT_ID`, quello che
usa già Supabase) e Google riconosce l'app da **pacchetto + SHA-1 della firma**: il client Android
non compare nel codice, ma deve esistere, per **ogni** chiave che firma l'app. Finché in
`config/supabase.json` non c'è `GOOGLE_ANDROID_CLIENT_ID`, su Android il pulsante di Google non si
mostra (e il foglio dice che non c'è un modo per entrare).

Google Cloud Console, **lo stesso progetto** del client web e di quello iOS (e poi di Play Games:
due progetti diversi non possono avere lo stesso pacchetto con la stessa SHA-1):

1. *API e servizi* → **Schermata consenso OAuth** (*Branding*): nome Obertà, email di assistenza
   `oberta@charliemobile.dev`, dominio autorizzato `charliemobile.dev`, link a privacy e termini;
   ambiti solo `openid`, `email`, `profile`. Stato di pubblicazione **In produzione** (in «Test»
   entrano solo gli utenti di prova).
2. *Credenziali* → *Crea credenziali* → **ID client OAuth** → tipo **Android**:
   - «Obertà Android (Play)»: pacchetto `com.obertagame.oberta`, **SHA-1 della firma dell'app di
     Play** (7.3, punto 4). È quella delle build scaricate da Play, tester compresi.
   - «Obertà Android (caricamento)»: stesso pacchetto, **SHA-1 della chiave di caricamento**
     `D0:2F:C8:E2:C3:04:61:8B:F8:AD:65:88:2E:B4:11:67:14:3E:0A:ED` (le APK installate a mano, 7.2).
   - Facoltativo, per `flutter run`: la SHA-1 della chiave di debug del Mac
     (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
3. Il **client web** c'è già (`GOOGLE_WEB_CLIENT_ID`). Se mai andasse rifatto: tipo *Applicazione
   web*, URI di reindirizzamento `https://<ref>.supabase.co/auth/v1/callback` (il login dal
   desktop passa di lì).
4. Supabase → *Authentication* → *Sign In / Providers* → **Google**: attivo; *Client IDs*: il client
   **web** (i token Android hanno lui come destinatario) e quello iOS, separati da virgola; *Client
   Secret*: quello del client web; **Skip nonce checks spento** (l'app manda il nonce).
5. `config/supabase.json` (non nel repo, vedi `config/supabase.example.json`): aggiungi
   `"GOOGLE_ANDROID_CLIENT_ID": "<id del client «Obertà Android (Play)»>"`. Il valore serve solo ad
   accendere il pulsante: aggiungilo **dopo** aver creato il client con la SHA-1 di Play, altrimenti
   chi scarica da Play vede un errore di Google invece del login.
6. Prova: APK a mano (7.2) → «Accedi con Google» entra (client di caricamento); poi la build della
   traccia interna (client di Play).

### 7.6 Contenuti dell'app (Policy → Contenuti dell'app)

Tutti da compilare prima di uscire dal test interno.

- **Norme sulla privacy**: `https://charliemobile.dev/oberta/privacy.html`.
- **Accesso all'app**: «Alcune funzionalità sono limitate». Istruzioni: la modalità a un telefono non
  chiede nessun account; l'online si apre con *Accedi con Google* e qualunque account Google va bene,
  nessuna credenziale da dare. Una partita online parte da 4 persone; con due telefoni la sala della
  stanza basta per chat, «Segnala» e «Blocca» (come `fastlane/metadata/review_information/notes.txt`).
- **Annunci**: No. **ID pubblicità**: No (nessun SDK lo usa; il manifest non ha `AD_ID`).
- **Classificazione dei contenuti** (questionario IARC), categoria *Gioco*, le stesse risposte
  dell'App Store (`docs/app-store.md`): violenza fantasy/non realistica, rara, niente sangue
  (omicidi raccontati); riferimenti alla criminalità organizzata (tema mafia); tabacco solo come
  sigaretta degli avatar; niente linguaggio volgare, sesso, droghe, gioco d'azzardo simulato;
  **interazione fra utenti: Sì** (chat scritta e voce); condivisione della posizione: No; acquisti
  digitali: No. Risultato atteso intorno a PEGI 12.
- **Pubblico di destinazione**: 13–15, 16–17, 18+ (niente sotto i 13: il gioco non è per bambini e
  l'online vuole 14 anni, `docs/legal/terms_it.md`). «Potrebbe attirare i bambini?»: No.
- **App di notizie**: No. **App governativa**: No. **Funzionalità finanziarie / salute**: nessuna.
- **Eliminazione dell'account**: nell'app Impostazioni → Account → «Elimina account»; link web:
  `https://charliemobile.dev/oberta/privacy.html` (sezione dei diritti: dall'app, o scrivendo a
  `oberta@charliemobile.dev`).
- **Sicurezza dei dati**, la stessa tabella di `docs/app-store.md` nelle categorie di Play. Per tutti:
  raccolti, **non condivisi** (Supabase e LiveKit trattano per nostro conto: per Play non è
  «condivisione»), **facoltativi** (senza account si gioca lo stesso), scopo *Funzionalità
  dell'app* (più *Gestione dell'account* per email e ID utente).

  | Categoria Play | Dato | Da dove |
  |---|---|---|
  | Informazioni personali > ID utente | id dell'account Supabase | accesso online |
  | Informazioni personali > Indirizzo email | email dell'account Google | Accedi con Google, a Supabase Auth |
  | Informazioni personali > Nome | nome utente unico (handle) | profilo |
  | Messaggi > Altri messaggi in-app | messaggi della chat delle stanze (90 giorni) | chat |
  | Audio > Registrazioni vocali o audio | la voce al tavolo, **trattata temporaneamente** (dal vivo, mai registrata) | voce LiveKit, premi-per-parlare |
  | Attività nelle app > Interazioni con l'app | partite, ruoli, vittorie, livello, esperienza, monete, missioni, medaglie, oggetti, amici | statistiche e bottega |
  | Attività nelle app > Altri contenuti generati dagli utenti | avatar (faccia del barbiere, abiti, cornice), segnalazioni e giocatori bloccati | profilo, «Segnala», «Blocca» |
  | Informazioni e prestazioni dell'app > Altre informazioni | tipo di dispositivo («Android») e numero di build | un solo dispositivo attivo, ruoli che la build conosce |

  Differenza da Apple: Play conta anche la voce dal vivo (con «trattamento temporaneo»), Apple no.
  Non raccolti: posizione, contatti, foto (restano sul telefono), file, calendario, salute, dati
  finanziari, cronologia web, diagnostica. **Dati criptati in transito**: Sì. **Richiesta di
  eliminazione**: Sì. I traguardi di Play Games li gestisce Google.

### 7.7 La scheda dello store

- Testi in `fastlane/metadata/android/{it-IT,en-US}/` (`title.txt` max 30 caratteri,
  `short_description.txt` max 80, `full_description.txt` max 4000, `changelogs/default.txt` max
  500): ripresi dai testi iOS (`fastlane/metadata/{it,en-US}/`), quando cambiano lì vanno cambiati
  anche qui. Icona 512: `images/icon.png` (da `tool/make_app_icons.sh`).
- **Da fare**: `images/featureGraphic.png` (1024×500, obbligatoria) e `images/phoneScreenshots/`
  (da 2 a 8, PNG o JPEG, lato lungo **al massimo il doppio** del corto: quelli iPhone, 2,17:1, Play
  li rifiuta; per esempio 1080×2160). Facoltativi i tablet: gli iPad 13" (2064×2752) vanno bene in
  `images/tenInchScreenshots/`.
- Categoria *Giochi › Da tavolo* (come su iOS), email
  `oberta@charliemobile.dev`, sito `https://charliemobile.dev/oberta/`.
- Carica testi e immagini (nessuna build, nessuna revisione):
  ```sh
  bundle exec fastlane android metadata
  ```

### 7.8 Uscire: traccia interna, test chiuso, produzione

1. Build per i tester: `bundle exec fastlane android internal` (con `RANKED_DEBUG=1` è la build di
   prova di `lib/build_flags.dart`, come su iOS: **mai** in produzione). Alza `+N` se serve, compila
   l'AAB, controlla che non sia firmato con la chiave di debug e lo carica sulla traccia interna
   **come bozza**. Poi committa `pubspec.yaml`, come per iOS.
   Per avere lo stesso `+N` di iOS, lancia `ios beta` e `android internal` prima del commit.
2. Play Console → *Test interno* → la release in bozza → *Rivedi release* → **Avvia
   implementazione**. I tester la ricevono in pochi minuti.
3. Test chiuso (obbligatorio per gli account personali, 7.3): *Test chiuso* → *Crea traccia* (per
   esempio «Amici») → tester → *Promuovi release* dalla traccia interna. 12 persone per 14 giorni.
4. Produzione (dopo *Richiedi l'accesso alla produzione*, se serve): build **senza**
   `RANKED_DEBUG`, *Produzione* → *Crea release* (o *Promuovi* dalla traccia interna) →
   **implementazione graduale** (per esempio 20%, poi 50%, poi 100%) → *Invia per la revisione*.
   La prima revisione può chiedere qualche giorno.
5. Build minima: solo quando la versione è davvero su Play per tutti,
   `tool/release/set_min_build.sh android <N>` (sezione 9).

### 7.9 Play Games Services: i traguardi

Stesso meccanismo di Game Center (`lib/platform/achievements.dart`), ma Play genera gli id da sé:
finché `playGamesIds` è vuota Android non chiama mai Play Games.

1. Play Console → *Crescita* → **Play Games Services** → *Configurazione*: crea il progetto, collega il
   progetto Google Cloud **di Google Sign-In** (7.5) e le credenziali OAuth Android (SHA-1 della
   firma dell'app di Play, 7.3).
2. L'**ID progetto** (solo cifre) va in `android/app/src/main/res/values/games.xml`
   (`game_services_project_id`, oggi `0`: è il segnaposto letto da
   `com.google.android.gms.games.APP_ID` nel manifest).
3. *Traguardi* → crea ognuno con nome e descrizione IT/EN (stessi testi), icona 512×512, punti
   (totale massimo 1000), non incrementali. Elenco: `docs/steam.md`.
4. Copia gli id generati (`CgkI...`) nella mappa `playGamesIds` di `lib/platform/achievements.dart`
   (`'role_medico': 'CgkI...'`). Un id non in mappa non viene mai mandato.
5. *Tester*: aggiungi gli account di prova, poi **Pubblica** la configurazione di Play Games.

## 8. Interruttori del server prima di un lancio pubblico

Da controllare prima della prima uscita pubblica (e dopo ogni periodo di prove). Il modo più corto:
`supabase/scripts/prelaunch.sql` nel SQL editor (prima com'è, prova con `rollback`; poi con `commit`
in fondo). Spegne i bot di prova di stanze e classificata ed elenca quello che resta a mano.

```sh
tool/release/set_min_build.sh show
```

Nel SQL editor di Supabase:

```sql
-- tutte le impostazioni
select key, value from internal.config order by key;
-- classificata vera: nessun minimo di prova, quindi nessun bot nelle partite classificate
update internal.config set value = '0' where key = 'ranked_test_humans';
-- nessuna partita classificata di prova ancora aperta
select code, status, created_at from public.rooms where ranked and test_match and status <> 'ended';
```

- `ranked_test_humans` = `0`: senza, la classificata riempie i tavoli di bot.
- Nessuna build pubblica con `RANKED_DEBUG`.
- Account di prova email eliminati e provider Email come deciso in `docs/app-store.md`.

## 9. Aggiornamento obbligatorio

L'app si blocca con «Aggiornamento obbligatorio» / «Update required» e un pulsante per il negozio
(non si chiude) in due casi:

1. **iOS: l'App Store ha una versione più alta** (`version` di pubspec, la parte prima del `+`).
   Ricerca: `https://itunes.apple.com/lookup?bundleId=com.obertagame.oberta&country=it`, campo
   `version`; il pulsante apre `trackViewUrl`. Cache di un'ora; se non risponde non blocca niente.
   Nelle build di debug non si guarda. Sul desktop questo controllo non c'è (aggiorna Steam).
2. **Il server non accetta più questa build**: `internal.config min_build_<platform>` (il `+N`).
   Ogni chiamata di una build più bassa torna `update_required`. Tutti i minimi partono da 0; le
   build più vecchie dell'aggiornamento obbligatorio non mandano `x-app-build` e non sono mai
   bloccate.

**Quando alzare la build minima**: solo se le build vecchie **non devono più giocare online**
(regole cambiate, database incompatibile, falla di sicurezza) e solo **quando la build nuova si può
davvero scaricare** (App Store in vendita, build Steam live su `default`). Mai subito dopo un upload
su TestFlight: si chiuderebbe fuori tutti.

```sh
tool/release/set_min_build.sh show            # minimi e link attuali
tool/release/set_min_build.sh ios 61          # sotto 61: aggiornamento obbligatorio
tool/release/set_min_build.sh windows 61      # e macos, linux
tool/release/set_min_build.sh ios 0           # nessuno bloccato
# oppure
bundle exec fastlane min_build platform:ios build:61
```

Usa `SUPABASE_ACCESS_TOKEN` di `fastlane/.env` e il progetto di `config/supabase.json`, senza
stamparli. Sul desktop il pulsante apre `store_url_<platform>` (oggi la landing; la pagina Steam
quando esiste, vedi `docs/steam.md`).

## 10. Tornare indietro

- **Build TestFlight sbagliata**: App Store Connect → TestFlight → build → **Expire Build**. Poi
  carica una build nuova (`+N` più alto: i numeri non si riusano).
- **Versione App Store sbagliata**: non si ritira una versione già uscita. Metti **in pausa** il
  rilascio graduale, carica subito una correzione (`z` + 1) e chiedi la revisione accelerata
  (*Contact Us → Request an expedited review*). Solo in casi gravi: *Prezzi e disponibilità* →
  togli dalla vendita.
- **Steam**: Steamworks → *Builds* → rimetti live su `default` la build precedente (subito per tutti).
- **Google Play**: *Produzione* → la release → **Interrompi implementazione** (chi l'ha già la tiene,
  gli altri restano sulla precedente). Poi una build nuova con `+N` più alto: come su iOS, un
  `versionCode` già caricato non si riusa.
- **Build minima alzata per errore**: `tool/release/set_min_build.sh <platform> <N vecchio>` (o 0).
- **Migrazione sbagliata**: le migrazioni applicate **non si modificano né si cancellano**. Scrivi
  una migrazione nuova (timestamp nuovo) che rimette lo stato di prima, provala con
  `begin; … rollback;`, poi push su `main`. Per questo ogni migrazione deve essere reversibile a
  mano: niente `drop` di colonne o tabelle con dati nella stessa release che smette di usarle.
- **Tag sbagliato, nulla ancora su Steam**:
  ```sh
  git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z
  # correggi, commit, push, poi di nuovo il tag
  ```
  Se la build è già uscita, non si ritagga: si esce con `z` + 1.
- **Edge Function rotta**: `git revert <commit>` e push su `main` (si ripubblica la versione prima),
  oppure `supabase functions deploy <nome>` da un checkout del commit buono.

## 11. Dopo la release

1. Landing (`site/oberta/`): badge App Store / Steam e link aggiornati, versione nuova nei testi
   se c'è; push su `main` (Cloudflare Pages pubblica da solo). Controlla
   `https://charliemobile.dev/oberta/`.
2. Sito aziendale (CharlieWebsite), sul server:
   ```sh
   cd CharlieWebsite && git pull && ./deploy.sh
   ```
3. `docs/stato.md`: data, versione e build, cosa è uscito, cosa resta.
4. Tra una e due ore: crash e feedback in App Store Connect / TestFlight, log delle Edge Function
   in Supabase, partite online che partono.

## 12. Lista d'attesa «Avvisami quando esce»

Il modulo nell'apertura della landing chiama la Edge Function `waitlist`
(`supabase/functions/waitlist/`), che salva l'indirizzo in `internal.waitlist` (migrazione
`20261125090000_waitlist.sql`, non leggibile dall'API) e, **solo per un indirizzo nuovo**, manda con
Brevo la mail di benvenuto (iscrizione singola: casella spuntata + modulo = iscritto, `confirmed = true`
subito, con ora e versione del consenso come prova). Un indirizzo già in lista non riceve
niente e il sito risponde uguale. Informativa: `privacy.html#lista` e `docs/legal/privacy_*.md`.

**Segreti Brevo** (Edge Function secrets; mai nel repository, mai stampati):

```sh
supabase secrets set --project-ref <ref> BREVO_API_KEY=... BREVO_SENDER_EMAIL=oberta@charliemobile.dev BREVO_SENDER_NAME=Obertà
```

**Brevo → Security → Authorised IPs**: la protezione per IP va disattivata (o la chiave API resta
bloccata per le Edge Function, che escono da indirizzi AWS che cambiano): con la protezione attiva
Brevo risponde `401 unrecognised IP address` e la mail non parte (si vede in `confirm_error`).

Senza segreti l'iscrizione si salva lo stesso e la mail si salta (log «Brevo secrets missing»);
`confirm_sent_at` (ora della mail di benvenuto) resta vuoto e `confirm_error` dice perché (`secrets_missing`, oppure stato e messaggio di Brevo): `select email, confirm_error from internal.waitlist where confirm_error is not null;`. Facoltativi: `WAITLIST_SITE_URL` (default
`https://charliemobile.dev/oberta`) e `WAITLIST_ORIGINS` (origini ammesse, separate da virgola;
default `charliemobile.dev`, `www.charliemobile.dev`, `oberta.pages.dev` e le sue anteprime).

**La mail di benvenuto**: `supabase/functions/waitlist/templates/welcome.ts` (IT/EN secondo la lingua
dell'iscrizione), **senza immagini** (Outlook e molti client le bloccano: insegna in testo, cornici con
tabelle e `bgcolor`, ornamenti unicode, pulsante con VML), anteprime
`site/oberta/email/benvenuto-*.html` (`deno run -A supabase/functions/waitlist/templates/preview.ts`;
`waitlist_test.ts` fallisce se non sono aggiornate). Test: `deno test -A
supabase/functions/tests/waitlist_test.ts` e `supabase/tests/waitlist.sql` (`begin; … rollback;`).

**Link**:

- niente link di conferma (`conferma.html` rimanda all'inizio); il pulsante della mail porta a `ruoli.html`
- cancellazione: `https://charliemobile.dev/oberta/disiscriviti.html?t=<unsubscribe_token>`
  (cancella la riga); one-click per i client di posta:
  `POST https://<ref>.supabase.co/functions/v1/waitlist?unsubscribe=<unsubscribe_token>`

**Regole per ogni invio** (GDPR e Garante):

1. A tutti gli iscritti (tutti hanno `confirmed = true` dall'iscrizione).
2. Solo notizie su Obertà (l'uscita, poi di rado novità): è la finalità del consenso.
3. In ogni mail il link di cancellazione personale e gli header `List-Unsubscribe` /
   `List-Unsubscribe-Post: List-Unsubscribe=One-Click`.
4. Chi non ha ricevuto la mail di benvenuto (`confirm_sent_at is null`, vedi `confirm_error`) riceve
   comunque la mail di lancio: l'iscrizione vale dal modulo.
5. 12 mesi dopo l'uscita si cancella tutta la lista: `delete from internal.waitlist;`.
6. Un nuovo testo del consenso nel modulo = una nuova riga in `internal.waitlist_consents` e una nuova
   `data-consent` in `index.html` (le vecchie restano come prova).

**Esportare la lista** (CSV, Management API, `SUPABASE_ACCESS_TOKEN` di `fastlane/.env` e ref da
`config/supabase.json`, senza stamparli):

```sh
python3 - <<'PY' > waitlist.csv
import csv, json, pathlib, re, sys, urllib.request
root = pathlib.Path('/Users/nicolai/code/Lupus')
token = next(l.split('=', 1)[1].strip().strip('"') for l in (root / 'fastlane/.env').read_text().splitlines() if l.startswith('SUPABASE_ACCESS_TOKEN='))
ref = re.match(r'https://([a-z0-9]+)\.', json.loads((root / 'config/supabase.json').read_text())['SUPABASE_URL']).group(1)
sql = """select email, lang, 'https://charliemobile.dev/oberta/disiscriviti.html?t=' || unsubscribe_token as unsubscribe_url
         from internal.waitlist where confirmed order by created_at"""
req = urllib.request.Request(f'https://api.supabase.com/v1/projects/{ref}/database/query', data=json.dumps({'query': sql}).encode(),
                             headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json', 'User-Agent': 'oberta-waitlist'})
rows = json.loads(urllib.request.urlopen(req).read())
w = csv.DictWriter(sys.stdout, fieldnames=['email', 'lang', 'unsubscribe_url']); w.writeheader(); w.writerows(rows)
PY
```

Il CSV va in Brevo (Contatti → Importa, una lista «Obertà lancio», attributi `LANG` e
`UNSUBSCRIBE_URL`); nella campagna il link di cancellazione è `{{ contact.UNSUBSCRIBE_URL }}` (oltre a
quello di Brevo). Chi si cancella da Brevo va tolto anche qui (`delete from internal.waitlist where
email = '...'`). Il CSV contiene dati personali: non nel repository, cancellalo dopo l'import.
In alternativa gratuita, qualunque strumento di mailing con link personali (es. un piccolo script
che chiama l'API transazionale di Brevo, 300 mail al giorno gratis) va bene, con le stesse regole.
