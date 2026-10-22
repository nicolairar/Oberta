# Uscire con una versione nuova (e l'aggiornamento obbligatorio)

L'app si blocca con «Aggiornamento obbligatorio» / «Update required» e un pulsante per il negozio
(non si chiude) in due casi:

1. **il negozio ha una versione più alta di questa** (`version` di pubspec, la parte prima del `+`):
   - iOS: `https://itunes.apple.com/lookup?bundleId=com.obertagame.oberta&country=it`, campo
     `version`, il pulsante apre `trackViewUrl`;
   - desktop (macOS, Windows, Linux, non Steam): l'ultima release di GitHub
     `nicolairar/Oberta` (tag `v1.2.0`), il pulsante scarica lo zip della piattaforma o apre la
     pagina della release. Le build Steam le aggiorna Steam: per loro vale solo il punto 2;
   - Android: per ora nessun negozio, solo il punto 2;
   - nelle build di debug il negozio non si guarda.

   La risposta resta in cache un'ora. Se non risponde (offline, limite di GitHub, repo privato)
   non si blocca niente: il gioco su un telefono solo resta giocabile.
2. **il server non accetta più questa build**: `internal.config min_build_<platform>`
   (il `+N` di pubspec). Ogni chiamata di una build più bassa torna `update_required`.
   Tutti i minimi partono da 0. Le build uscite prima dell'aggiornamento obbligatorio non mandano
   `x-app-build` e non vengono mai bloccate. Controllo all'avvio, al ritorno in primo piano e a
   ogni `update_required`.

## iOS

1. `bundle exec fastlane ios beta` (TestFlight). **Non** alza la build minima.
2. Revisione Apple e uscita sull'App Store: da quel momento chi ha una versione più vecchia vede
   il cartello (la ricerca dell'App Store può anticipare di qualche ora la disponibilità reale in
   tutti i paesi).
3. Solo se le build vecchie devono smettere anche di giocare online (cambio di regole, di
   database): `bundle exec fastlane min_build platform:ios build:<N>`, oppure
   `tool/release/set_min_build.sh ios <N>`.

## Desktop (GitHub Release)

1. Versione in pubspec (es. `1.2.0+61`), commit su main.
2. `git tag v1.2.0 && git push origin v1.2.0`. Il workflow `Desktop builds` compila Windows,
   Linux e macOS e pubblica la release con `oberta-<platform>-v1.2.0.zip`. Il tag deve essere
   uguale alla versione di pubspec, altrimenti il job si ferma.
3. Se serve: `tool/release/set_min_build.sh windows <N>` (e `linux`, `macos`).

## La build minima

    tool/release/set_min_build.sh show               # minimi e link attuali
    tool/release/set_min_build.sh ios 61             # da qui in giù: aggiornamento obbligatorio
    tool/release/set_min_build.sh ios 0              # nessuno bloccato

Usa `SUPABASE_ACCESS_TOKEN` di `fastlane/.env` e il progetto di `config/supabase.json`, senza
stamparli. Alzarla solo quando la build nuova si può davvero scaricare.
