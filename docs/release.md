# Uscire con una versione nuova (procedura)

Da seguire **ogni volta**, nell'ordine. I comandi si lanciano dalla radice del repository
(il checkout principale, dove ci sono `fastlane/.env` e `config/supabase.json`).

## La release in 10 righe

1. Decidi la versione (`x.y.z`, regole sotto) e scrivila in `pubspec.yaml`; la build `+N` la alza fastlane.
2. `flutter analyze && flutter test` verdi; migrazioni e Edge Function sul server; voce, landing e screenshot aggiornati se servono.
3. iOS di prova: `RANKED_DEBUG=1 bundle exec fastlane ios beta` → TestFlight interno, commit del `+N`.
4. Tester esterni: `bundle exec fastlane ios external_beta` (gruppo «External Tester»).
5. App Store: `bundle exec fastlane ios beta` **senza** `RANKED_DEBUG`, poi `bundle exec fastlane ios metadata`.
6. App Store Connect: scegli la build, rilascio graduale, invia alla revisione.
7. Desktop: `git tag vX.Y.Z && git push origin vX.Y.Z` → il CI compila, zip privati negli artifact.
8. Steam (Fase 2): carica gli zip con SteamPipe sul branch `beta`, prova, poi metti live su `default`.
9. Solo se le build vecchie non devono più giocare online: `tool/release/set_min_build.sh <platform> <N>`.
10. Dopo: link e badge della landing, `./deploy.sh` di CharlieWebsite sul server, note in `docs/stato.md`.

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
3. `RANKED_DEBUG` serve **solo** ai tester: non deve mai arrivare all'App Store.
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
3. Prima del primo invio: segnaposto di `docs/app-store.md` riempiti, accesso email/password non
   raggiungibile nella build di release, provider Email di Supabase spento se previsto lì.
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

## 7. Android

Non c'è ancora. Quando arriverà: `bundle exec fastlane android …` verso la traccia interna di
Google Play, poi produzione con rilascio graduale; stessa numerazione `+N`; la build minima si alza
con `set_min_build.sh android <N>`.

### 7.1 Play Games Services: i traguardi

Stesso meccanismo di Game Center (`lib/platform/achievements.dart`), ma Play genera gli id da sé:
finché `playGamesIds` è vuota Android non chiama mai Play Games.

1. Play Console → *Crescita* → **Play Games Services** → *Configurazione*: crea il progetto, collega il
   progetto Google Cloud e le credenziali OAuth Android (SHA-1 della chiave di firma di Play).
2. L'**ID progetto** (solo cifre) va in `android/app/src/main/res/values/games.xml`
   (`game_services_project_id`, oggi `0`: è il segnaposto letto da
   `com.google.android.gms.games.APP_ID` nel manifest).
3. *Traguardi* → crea ognuno con nome e descrizione IT/EN (stessi testi), icona 512×512, punti
   (totale massimo 1000), non incrementali. Elenco: `docs/steam.md`.
4. Copia gli id generati (`CgkI...`) nella mappa `playGamesIds` di `lib/platform/achievements.dart`
   (`'role_medico': 'CgkI...'`). Un id non in mappa non viene mai mandato.
5. *Tester*: aggiungi gli account di prova, poi **Pubblica** la configurazione di Play Games.

## 8. Interruttori del server prima di un lancio pubblico

Da controllare prima della prima uscita pubblica (e dopo ogni periodo di prove):

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
