# Obertà — short «Zio Vito» (storytime, Reels / TikTok / Shorts)

Verticale 9:16, 1080×1920, 60 fps, MP4 H.264 + AAC, **44,7 secondi**,
sotto i 30 MB (più un'anteprima leggera 720×1280).
Una storia in prima persona, solo sottotitoli (niente narratore): il nipote
racconta come lo zio Vito, della Famiglia, ha rovinato le domeniche.

- **Musica**: `assets/music/day_2.m4a` dal secondo ~19,9, 139,5 bpm → un
  battito ogni 0,43 s. Tagli e colpi cadono sui battiti; la musica si
  abbassa sotto i meme e si spegne sull'ultimo battito.
- **Ritmo**: circa 1 s ogni 3–4 parole; ogni frase resta il tempo di
  leggerla una volta.
- **Sottotitoli**: parola per parola, Georgia Bold maiuscolo, bianco con
  contorno nero spesso, la parola chiave colorata. Sempre fra il 12% e il
  74% dell'altezza, un po' a sinistra del centro; fascia scura dietro quando
  sotto c'è l'interfaccia del gioco.
- **Il tavolo vero**: una partita della famiglia sul backend finto, con i
  nomi e i look di tutti (`tool/promo/zio_plates.dart`): VITO (fedora,
  gessato, sigaro) e la zia sono la Famiglia, io sono il Medico. La scelta
  su Nonna, il «Nessun morto stanotte» e il «Stanotte hai vegliato su
  nonna» sono schermate vere del gioco.
- **Montaggio**: punch-in su ogni taglio, zoom sui colpi, shake, scia sui
  movimenti veloci, grana e vignettatura; niente pause al buio.

| # | Battiti (s) | Visivo | Testo | Audio |
|---|---|---|---|---|
| 1 | 0–6 (0,0) | Il tavolo del giorno, la famiglia ai posti, entra con uno zoom | **QUESTO GIOCO / HA ROVINATO / LA MIA FAMIGLIA.** | `punch` su FAMIGLIA |
| 2 | 6–11 (2,6) | Prato a strisce: papà, Vito e il cugino con le cuffie da stadio, saltellano a tempo | **PRIMA LA DOMENICA / SI PARLAVA DI CALCIO.** | `swish`, tifo basso |
| 3 | 11–15 (4,7) | L'insegna OBERTÀ si accende lettera per lettera, lampo bianco | **POI È ARRIVATO / OBERTÀ.** | `bulb`, `punch_2` |
| 4 | 15–22 (6,5) | Zio Vito grande al tavolo, targhetta ZIO VITO; sulla seconda frase la luce diventa rossa | **ZIO VITO / ERA DELLA FAMIGLIA. / QUELLA SBAGLIATA.** | sigaro, `impact` |
| 5 | 22–29 (9,5) | La notte della Famiglia (schermo di Vito, chat «Stanotte la nonna.»); la camera va su Nonna, il dito la sceglie: ACCUSATO | **LA PRIMA NOTTE / HA PROVATO A FAR FUORI / LA NONNA.** | `ui_confirm`, sussulto |
| 6 | 29–34 (12,5) | Il giorno: la chat vera «Stanotte hai vegliato su nonna» / «Nessun morto stanotte. Qualcuno è stato salvato.» si illumina; salta fuori l'icona del Medico | **IL DOTTORE / L'HA SALVATA.** | siringa, `tada` |
| 7 | 34–39 (14,6) | Vito sotto la luce blu della notte, ghigno | **LA SECONDA NOTTE / NON HA UCCISO / NESSUNO.** | civetta |
| 8 | 39–43 (16,8) | Vito col rossetto e gli occhi a cuore, la carta della Prostituta entra da destra, la sua icona salta fuori | **ERA CON / LA PROSTITUTA.** | `hee_hee`, bacio |
| 9 | 43–53 (18,5) | La cella: le sbarre cadono sul battito; icona del Carceriere; fumetti «Dov'eri ieri notte?» e VITO: «Io? Ero a messa.» (gli spunta l'aureola) | **IL CARCERIERE / L'HA CHIUSO IN CELLA.** | sbarre, catene, due tocchi, campane |
| 10 | 53–58 (22,8) | Il tavolo del giorno, zoom su Vito con l'anello rosso di chi parla; il pulsante push-to-talk premuto | **DI GIORNO / URLAVA / PIÙ DI TUTTI.** | interruttore, urlo |
| 11 | 58–63 (24,9) | Il tavolo: MAMMA «Lo zio? Ma dai!», NONNA «Zio Vito è un santo.» | **NESSUNO MI CREDEVA.** | un tocco per fumetto |
| 12 | 63–70 (27,1) | I voti su Vito salgono 1→6, uno per battito, la camera spinge sul suo posto; timbro ACCUSATO | **HO CONVINTO / TUTTI.** | una fiche per voto, martelletto |
| 13 | 70–77 (30,1) | Il film del verdetto del gioco (il molo), ralenti sulla spinta | **LO ABBIAMO BUTTATO / NEL FIUME.** | `faaah` sulla spinta, tuffo |
| 14 | 77–84 (33,1) | Dritto (senza buio) sulla carta che si gira: Il Picciotto; l'icona salta fuori, lampo rosso, shake | **ERA DAVVERO / UN MAFIOSO.** | `swish`, `flip`, `vine_boom` |
| 15 | 84–88 (36,1) | Vito fantasma: corna, nuvoletta di pioggia, lacrima | **NE È VALSA / LA PENA.** | `punch_2` sulla parola PENA |
| 16 | 88–95 (37,8) | Il guardaroba: Vito con un costume assurdo diverso a ogni battito | **E ALMENO ORA / SI VESTE MEGLIO.** | `cashreg`, uno `swish` per costume |
| 17 | 95–104 (40,9) | L'insegna OBERTÀ come quella del gioco: si accende, la B sfrigola e muore e dietro sfarfalla la M (per un attimo è OMERTÀ), poi la B torna; sotto **PRESTO DISPONIBILE** e i badge App Store, Google Play e Steam; nell'ultimo quarto di secondo va in corto e torna il buio | **GIOCA GRATIS / CON GLI AMICI** | `bulb`, scintille sul guasto, `bulb` al ritorno, `spark` al corto |

Il finale torna al buio e il video riparte dal primo fotogramma (loop).
L'insegna finale è in `tool/promo/neon_end.dart`, cablata come
`home_screen.dart` (`powerAt` + `ghostAt`).

## Come si rifà

```sh
# 0. I badge degli store, dai file del sito (site/oberta/img/badges).
swift tool/promo/badges.swift
# 1. I fotogrammi (PNG) in build/promo/zio_frames/ e il poster.
flutter test tool/promo/zio_render_test.dart
# 2. Il video con l'audio mixato: build/promo/oberta_short_zio.mp4 (<30 MB).
swift tool/promo/zio_encode.swift
# 3. L'anteprima leggera, 720×1280: build/promo/oberta_short_zio_720p.mp4.
PREVIEW=1 swift tool/promo/zio_encode.swift
```

`FRAMES=0,90,500` nel test rende solo quei fotogrammi e un foglio di
provini (`build/promo/zio_contact.png`); `PLATES=1` salva anche le schermate
del gioco in `build/promo/zio_plates/`.
