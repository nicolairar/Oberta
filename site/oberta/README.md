# Pubblicare Obertà con Cloudflare Pages

Questa è una pagina statica: non richiede un framework né una fase di compilazione.

## Collegamento Git

Nel progetto Cloudflare Pages collegato al repository, imposta:

- **Production branch:** `main`
- **Root directory:** `site/oberta`
- **Build command:** `exit 0`
- **Build output directory:** `.`
- **Build watch path:** includi `site/oberta/**`

Dopo il collegamento, ogni push su `main` che modifica questa cartella genera una nuova build e pubblica l'anteprima Pages. Verifica l'anteprima prima di collegare un dominio.

## URL `charliemobile.dev/oberta`

Pages collega un progetto a un hostname, non assegna da solo una sottocartella di un sito già esistente. Non collegare il dominio principale `charliemobile.dev` a questo progetto: sostituirebbe il sito aziendale.

Per mantenere esattamente `charliemobile.dev/oberta`, il progetto che serve il sito aziendale deve instradare quel percorso verso questa pubblicazione Pages (per esempio tramite una regola Worker/proxy) oppure includere questa cartella nel proprio output. Se si vuole pubblicare la landing come progetto Pages indipendente senza modificare il sito aziendale, usare invece un sottodominio dedicato, per esempio `oberta.charliemobile.dev`.

## Immagini e video

Le schermate (`img/*.jpg`) e i video (`video/`) si rifanno con un solo comando, dalla radice del repository:

```sh
tool/site/refresh_media.sh              # schermate + video
SKIP_VIDEO=1 tool/site/refresh_media.sh # solo le schermate
SKIP_SHOTS=1 tool/site/refresh_media.sh # solo i video
```

- Le schermate vengono dall'app vera, renderizzata dai test in `tool/render/` (vetrina dello store con `RAW=1`, classificata, collezione dei ruoli), ridotte a 600 px di larghezza in JPEG con `sips`.
- I video vengono dai corti promozionali (`~/Documents/VitoLong19201080.mp4` e `Tony15sec19201080.mp4`, o `VITO=` / `TONY=`), ricodificati con AVFoundation da `tool/site/web_video.swift`: senza traccia audio, H.264, `hero.mp4` 540×960 (~3,6 MB, tutto zio Vito), i loop delle sezioni 360×640 di 2–4 secondi (~150–250 KB), ognuno con la sua locandina JPEG.
- Niente da installare: solo Flutter, `sips` e Swift di macOS.

I video partono solo quando sono in vista (`app.js`); con «riduci movimento» o il risparmio dati si vede solo la locandina e il video non si scarica. Il numero dei ruoli nel titolo della sezione «ruoli» lo scrive `dart run tool/site/roles_page.dart`.

## Lista d'attesa

Il modulo «Avvisami» nell'apertura e `disiscriviti.html` parlano con la Edge Function `waitlist` (indirizzo in `app.js`); iscrizione singola, `conferma.html` rimanda solo all'inizio. `email/` contiene le immagini e le anteprime della mail di benvenuto. Tutto in `docs/release.md`, sezione 12.
