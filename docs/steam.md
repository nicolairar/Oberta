# Obertà su Steam — piano

Solo piano: niente codice Steam ancora. Si parte gratis (Fase 1) e si paga
solo quando il gioco è pronto per il negozio (Fase 2).

Legenda: **[TU]** = lo fa / paga il proprietario. **[NOI]** = lo codifichiamo noi.

---

## Fase 1 — gratis, adesso

### 1.1 Build desktop di Flutter
- **[NOI]** Abilitare i target `macos`, `windows`, `linux` (`flutter create --platforms=macos,windows,linux .`),
  verificare audio, Realtime, font, voce del narratore su ognuno.
- **[NOI]** Build: `flutter build macos|windows|linux --release`. Windows e Linux si compilano sulle
  rispettive macchine (o in CI: GitHub Actions con runner `windows-latest` / `ubuntu-latest`).
- **[NOI]** Sign in with Apple resta su Mac; su Windows/Linux si entra con Steam (sotto) o con Google via browser.
- **[TU]** Per distribuire il Mac fuori dall'App Store: firma Developer ID + notarizzazione (già incluse
  nell'Apple Developer Program che hai). Nessun costo extra.

### 1.2 Schermo su desktop
- Finestra a schermo intero o **finestra senza bordi a schermo intero** (borderless), scelta nelle Impostazioni.
- Risoluzioni supportate, lista fissa: **1280×720, 1600×900, 1920×1080, 2560×1440**. Gli ultrawide
  (21:9, 32:9) giocano a 16:9 con **letterbox** (bande nere/sfondo noir ai lati), niente layout stirati.
- Layout predefinito **ORIZZONTALE**: due colonne, tavolo a sinistra; a destra pannello ruoli sopra e chat
  sotto (quello che oggi facciamo già sugli schermi grandi, `wide_scale.dart`).
- Opzione nelle Impostazioni: **gioca in VERTICALE** — layout da telefono, finestra a 9:16 centrata con
  letterbox; utile per chi vuole il gioco in una finestrella a lato.
- Come: pacchetto `window_manager` (`setFullScreen`, `setAsFrameless` + `setBounds` sullo schermo per il
  borderless, `setAspectRatio`, `setMinimumSize`); un widget radice che calcola il rettangolo 16:9 (o 9:16)
  più grande che sta nello schermo e ci mette dentro l'app con `FittedBox`/`SizedBox` a una delle
  risoluzioni della lista (scala intera più vicina), il resto è letterbox.
- La scelta (modo finestra, risoluzione, orizzontale/verticale) si salva **per dispositivo** in
  `AppSettings` (shared_preferences), non nel profilo: un PC e un telefono hanno esigenze diverse.

### 1.3 Accesso con Steam via OpenID 2.0 (senza account partner)
Steam offre "Sign in through Steam" con OpenID 2.0 a chiunque, gratis, senza App ID.
1. **[NOI]** L'app apre il browser di sistema (o una webview) su
   `https://steamcommunity.com/openid/login` con `openid.mode=checkid_setup`, `openid.return_to` =
   l'URL della nostra Edge Function (`.../functions/v1/steam-openid`) più un `state` monouso legato all'app.
2. L'utente entra su Steam (password solo sul sito di Steam, mai da noi) e Steam rimanda a `return_to`
   con l'asserzione firmata.
3. **[NOI]** Edge Function `steam-openid`:
   - rimanda a Steam gli stessi parametri con `openid.mode=check_authentication`; accetta solo se la
     risposta contiene `is_valid:true`;
   - controlla `openid.return_to` e `state` (anti-replay), `op_endpoint` = steamcommunity;
   - estrae lo **SteamID64** da `openid.claimed_id` (`https://steamcommunity.com/openid/id/<17 cifre>`);
   - trova o crea l'utente Supabase legato a quello SteamID (tabella `internal.steam_identities
     (steam_id pk, profile_id)`), con l'admin API (service role, solo lato server) crea l'utente se manca
     e genera un magic link / OTP per farlo entrare;
   - riporta l'app indietro con un deep link (`oberta://steam?token=...`, token monouso e breve) e l'app
     chiama `verifyOTP` per ottenere la sessione Supabase normale. Da lì tutto è come su mobile.
4. Nome: il **nome Steam (persona) non serve**. Il giocatore sceglie il nome unico come oggi, con le
   nostre regole di moderazione (`handle_rules`, parole riservate). Più avanti, con una Web API key
   personale gratuita (**[TU]**: steamcommunity.com/dev/apikey), si può proporre la persona come
   suggerimento — sempre filtrata dalle nostre regole.

### 1.4 Collegare gli account (mobile ↔ Steam)
- **[NOI]** In Impostazioni, da un account già entrato: "Collega un altro dispositivo" → il server genera
  un **codice monouso** (8 caratteri, alfabeto di `join_code`, scade in 10 minuti, un tentativo sbagliato
  in più blocca dopo 5).
- Sull'altro client (Steam o mobile) si entra e si digita il codice: RPC `redeem_link_code` lega la
  seconda identità (Apple/Google/Steam) al **profilo** del primo. Funziona in tutte e due le direzioni.
- Regole di fusione quando entrambi hanno già un profilo:
  - si sceglie esplicitamente quale profilo resta (nome, aspetto, rating); l'altro viene assorbito;
  - **monete**: somma; **XP**: il massimo (il livello si ricalcola); **cosmetici**: unione;
  - **rating classificata** per lingua: si tiene quello con più partite (niente somma, niente abuso);
  - abbandoni/cooldown: si tiene il peggiore (non si "lava" un cooldown fondendo);
  - acquisti con soldi veri: le ricevute seguono il profilo che resta;
  - fusione vietata se uno dei due è in partita o in coda.
- Tutto resta sul server (monete, XP, cosmetici, rating): il client non porta niente con sé.

### 1.5 Un dispositivo alla volta (già fatto)
La regola di `20261029090000_one_active_device.sql` vale anche per Steam: il client desktop manda la
sua sessione (etichetta "Steam" quando gira da Steam, altrimenti "Mac"/"Windows"/"Linux"), e se il
telefono è aperto compare su entrambi «Puoi giocare su un solo dispositivo alla volta» con **GIOCO QUA**.

### 1.6 Cross-play
Steam e mobile usano lo stesso Supabase, le stesse stanze, la stessa coda classificata per lingua:
il cross-play c'è da subito, senza lavoro in più. Unica attenzione: chat e tempi uguali per tastiera
e touch (nessun vantaggio).

### 1.7 Progressione nostra, prima di Steam
Prima facciamo il **nostro** sistema, sul server, così vale su mobile e desktop allo stesso modo:
- **missioni** giornaliere e settimanali (es. "vinci 2 partite da cittadino", "sopravvivi a 3 notti");
- **traguardi** (achievement) con id stabili (`win_as_mafia_10`, ...);
- **figurine** da collezione dentro il gioco.
Tabelle Supabase (`missions`, `mission_progress`, `achievements`, `cards_owned`), assegnate dal motore
di gioco a fine partita come le ricompense attuali. In Fase 2 si specchiano su Steam con **gli stessi id**.

### 1.8 Provare Steamworks gratis con AppID 480
- **[NOI]** Con il plugin Steamworks (`steamworks.dart` via FFI, o un piccolo plugin nativo) e
  `steam_appid.txt = 480` (Spacewar, l'app di prova di Valve) si prova in locale: avvio col client
  Steam aperto, overlay, ticket di sessione, sblocco di un traguardo.
- **Limiti**: 480 ha solo i traguardi fissi di Spacewar — buono per provare l'idraulica
  (sblocco/overlay), **non** la nostra lista. Traguardi e statistiche nostri richiedono il nostro App ID
  (Fase 2). Le **carte collezionabili di Steam** (Trading Cards) le concede Valve solo dopo il lancio,
  in base a vendite/attività: non si possono provare prima.

**Costo Fase 1 per te: 0 €.**

---

## Fase 2 — a pagamento, quando si va sul negozio

### 2.1 Steamworks e App ID — [TU]
- Iscrizione a **Steamworks** (partner.steamgames.com): dati fiscali e bancari, identità.
- **Steam Direct fee: 100 $ (~85-95 €) per gioco**, restituita quando il gioco incassa 1.000 $ lordi.
- Si ottiene il nostro **App ID** e si crea la **Web API key del publisher** (segreta, solo sul server:
  va nei secrets delle Edge Function, mai nell'app).
- Pagina del negozio: capsule, screenshot, trailer, descrizione IT/EN, classificazione età, prezzo
  (o free-to-play). Revisione di Valve della pagina e della build (qualche giorno). La pagina va
  pubblicata come "in arrivo" almeno 2 settimane prima del lancio.

### 2.2 Build con SteamPipe — [NOI]
- Depot separati: Windows x64, macOS (universale), Linux x64 (e Steam Deck: Linux + controlli).
- Upload con `steamcmd` + script `app_build_<appid>.vdf` / `depot_build_*.vdf`, in CI; branch `beta`
  protetto da password per i tester, poi `default`.
- Il Mac Steam va comunque firmato e notarizzato.

### 2.3 Accesso con ticket Steam dentro il client — [NOI]
Sostituisce (o affianca) OpenID: niente browser.
1. Il client chiede un **auth session ticket** allo Steamworks SDK (`GetAuthTicketForWebApi("oberta")`).
2. Lo manda alla Edge Function `steam-auth`, che lo verifica con
   `ISteamUserAuth/AuthenticateUserTicket` (App ID + **publisher key**, segreta lato server) e ottiene lo
   SteamID64 (controlla anche `ownersteamid` per il family sharing e i ban VAC/publisher).
3. Stesso percorso di 1.3: SteamID → `internal.steam_identities` → sessione Supabase. Gli account già
   creati con OpenID restano gli stessi (stessa chiave: lo SteamID).

### 2.4 Traguardi, overlay, statistiche — [NOI]
- Si caricano su Steamworks i traguardi con gli stessi id del nostro sistema (1.7); quando il server
  li assegna, il client desktop li sblocca anche su Steam (`SetAchievement` + `StoreStats`). Se Steam
  non c'è, resta valido il nostro.
- Overlay Steam (inviti amici → codice stanza), Rich Presence ("In partita a Palermo").
- Trading Cards: si chiedono a Valve quando il gioco ne diventa idoneo.

---

## Riepilogo: chi fa cosa

| | Fase 1 (gratis) | Fase 2 (a pagamento) |
|---|---|---|
| **[TU]** | (facoltativo) Web API key personale; firma Mac già coperta | Steamworks, 100 $ Steam Direct, dati fiscali, publisher Web API key, materiale per la pagina |
| **[NOI]** | build desktop, schermo/letterbox, OpenID + Edge Function, codice di collegamento, missioni/traguardi/figurine nostri, prove con AppID 480 | SteamPipe/depot/CI, ticket Steam + `AuthenticateUserTicket`, specchio dei traguardi, overlay e Rich Presence |

## Modalità su desktop (decisione del 20 ottobre 2026)

Su desktop ci sono solo due modalità:
- **Classificata**, sempre a 12 giocatori.
- **Gioca con amici**, con stanze chiuse a cui si entra solo con il codice.

«Un telefono per tutti» non c'è su desktop: nella home desktop il suo manifesto non compare.

## Login automatico e anti-pirateria (20 ottobre 2026)

- Fase 2: aprendo il gioco da Steam il login è automatico. Il client chiede a Steam un biglietto (GetAuthTicketForWebApi), l'Edge Function lo verifica con ISteamUserAuth/AuthenticateUserTicket e la chiave da editore, e controlla che quell'account **possieda il gioco** (ownerSteamID / ISteamUser/CheckAppOwnership). Senza licenza vera il server rifiuta l'accesso.
- Fase 1: accesso Steam via web la prima volta, poi la sessione resta salvata.
- Su desktop si gioca solo online: ogni partita, acquisto, moneta e XP passa dal server, che verifica la licenza a ogni accesso. Un client craccato non può entrare nelle code né nelle stanze.
- I ruoli segreti restano sul server (già oggi): il client vede solo quello che deve vedere, quindi modificare il client non scopre niente.
- iPhone, se l'app diventa a pagamento: App Attest (DeviceCheck) per accettare solo app originali, verificato dal server.

## Fase 1 desktop — fatto (31 ottobre 2026)

- **Target**: `macos/`, `windows/`, `linux/` creati (bundle id `com.obertagame.oberta`, icone dall'icona iOS).
  Sul Mac: `flutter run -d macos` o `flutter build macos`. Windows/Linux si compilano solo sulle loro macchine
  (o in CI); il codice non usa API solo-iOS senza controllo (`DesktopPlatform.isDesktop`, `lib/ui/desktop/`).
  L'app iOS aperta su Mac Apple silicon resta l'app del telefono.
- **Home desktop**: solo «Gioca con amici» e «Classificata» (ancora dietro `RANKED_DEBUG` come su mobile).
- **Schermo** (Impostazioni → SCHERMO, solo desktop, salvato per dispositivo): in finestra / schermo intero /
  senza bordi, risoluzione 1280×720 · 1600×900 · 1920×1080 · 2560×1440, orientamento orizzontale (due colonne
  + pannello ruoli) o verticale (layout del telefono 9:16 al centro). Ultrawide → letterbox 16:9
  (`DesktopFrame`, `window_manager`).
- **Accedi con Steam**: Edge Function `steam-auth` (OpenID 2.0, `verify_jwt = false`). L'app apre il browser,
  ascolta su `127.0.0.1:<porta casuale>/steam`, riceve un codice monouso (2 minuti, legato a uno `state`
  casuale), lo scambia con un token magic link e chiama `verifyOTP`: la sessione Supabase resta salvata e i
  prossimi avvii entrano da soli. Gli utenti Steam hanno un'email sintetica `steam-<id>@steam.oberta.invalid`
  (mai usata per mandare posta). Nome unico: lo stesso flusso di oggi (regole e parole riservate).
- **Collega account** (Impostazioni → ACCOUNT, ogni dispositivo): codice di **6 caratteri** (alfabeto di
  `join_code`), 10 minuti, 5 tentativi sbagliati ogni 10 minuti. RPC `link_code_create` / `link_code_redeem`.
- **Regole di fusione (decise ora, sostituiscono quelle sopra)**: resta il profilo **più vecchio**, con nome,
  aspetto, monete, XP, cosmetici, rating e ricevute; il più nuovo **non porta niente** (niente somme: nessun
  abuso). Le identità del più nuovo (Steam, Apple, Google) passano al più vecchio; quello nuovo viene
  disconnesso, bloccato e il suo nome liberato. Rifiutato se entrambi hanno Steam o lo stesso provider
  (`link_conflict`), se uno dei due è in partita o in coda (`already_in_game`). Gli account di prova
  email/password non si spostano.
- **Un dispositivo alla volta**: etichetta «Mac» sul Mac, «Steam/PC» su Windows e Linux.

### Cosa deve fare il proprietario [TU]
1. Fare il push su `main`: l'integrazione GitHub applica la migrazione
   `20261031090000_steam_login_and_links.sql` e pubblica la funzione `steam-auth` (dichiarata in `config.toml`).
2. Supabase → Authentication: il provider **Email** deve restare acceso (serve al magic link interno; la
   conferma via email può restare spenta). Nessun segreto nuovo: la funzione usa il service role già fornito.
3. Sign in with Apple sul Mac: aggiungere la capability al target macOS in Xcode (Signing & Capabilities) e
   compilare con `--dart-define=MAC_APPLE_SIGN_IN=true`; finché no, il Mac entra con Steam.
4. Distribuzione Mac fuori dallo store: firma Developer ID + notarizzazione.
