# Obertà — short POV (Reels / TikTok / Shorts)

Verticale 9:16, 1080×1920, 60 fps, MP4 H.264 + AAC, **25,5 secondi**.
Una sola storia in formato POV, solo sottotitoli (niente narratore).

- **Musica**: `assets/music/day.m4a` dal secondo ~49,9, 136 bpm → un battito
  ogni 0,44 s. Tagli e colpi cadono sui battiti; la musica si spegne per il
  battito di buio e riparte sul vine boom.
- **Ritmo**: circa 1 s ogni 3–4 parole. Ogni frase resta il tempo di leggerla
  una volta, poi si taglia.
- **Sottotitoli**: parola per parola (karaoke), Georgia Bold maiuscolo,
  bianco con contorno nero spesso, la parola chiave in rosso o giallo. Sempre
  fra il 12% e il 74% dell'altezza, un po' a sinistra del centro: niente nel
  20% in basso né sul bordo destro, dove ci sono i pulsanti dell'app. Dove
  sotto c'è l'interfaccia del gioco, una fascia scura dietro al testo.
- **Montaggio**: punch-in su ogni taglio, zoom sui colpi, rampa di velocità
  (ralenti sulla spinta nel fiume), shake leggero, scia (motion blur) sui
  movimenti veloci, grana e vignettatura.
- **Effetti**: nostri (`assets/sounds`, `assets/sfx`) + 3 meme brevi
  (`faaah`, `vine_boom`, `hee_hee`), con la musica abbassata sotto.

| # | Tempo s (battiti) | Visivo | Testo (parola per parola) | Audio |
|---|---|---|---|---|
| 1 | 0,00–2,64 (0–6) | Il fratello, grande, seduto al tavolo della notte: fedora, gessato, sigaro, sorrisetto. Entra con uno zoom, colpo sul battito 2,6 | **POV:** / **TUO FRATELLO** / **È UN MAFIOSO.** | `punch` sulla parola MAFIOSO |
| 2 | 2,64–5,72 (6–13) | Il tavolo del giorno (numeri bianchi dei posti), cartellino giallo «TUO FRATELLO» sul suo posto; tre fumetti della chat che lo difendono: «Ma dai, è un santo!», «Lui? Impossibile.», «Accusi tuo fratello?!» | **NESSUNO TI CREDE.** | `swish`, un `pizzi` per fumetto |
| 3 | 5,72–10,56 (13–24) | Stesso tavolo: i voti su di lui salgono 1→6, uno per battito, la camera spinge sul suo posto; timbro **ACCUSATO** | **DEVI CONVINCERE** / **LA CITTÀ.** | una fiche per voto, `impact` sul timbro |
| 4 | 10,56–14,52 (24–33) | Il film del verdetto del gioco (il molo): camminata veloce, ralenti sulla spinta, tuffo | **LINCIATO.** | `gavel` sulla parola, `faaah` sulla spinta, `splash` |
| 5 | 14,52–15,40 (33–35) | Nero | — | silenzio |
| 6 | 15,40–18,92 (35–43) | La carta ruolo del gioco si gira (i suoi fotogrammi veri): Il Picciotto. Lampo rosso, zoom, shake | **ERA DAVVERO** / **UN MAFIOSO.** | `swish`, `flip`, `vine_boom` e la musica che riparte |
| 7 | 18,92–21,56 (43–49) | Il fratello di nuovo, ora con le corna da diavolo, la nuvoletta di pioggia e una lacrima | **TE L'AVEVO** … **DETTO.** (l'ultima parola da sola, sul battito 45, con zoom) | `punch` + `hee_hee` |
| 8 | 21,56–25,51 (49–58) | L'insegna al neon OBERTÀ si accende; sotto, su fondo scuro pulito, **PRESTO DISPONIBILE** e i badge ufficiali App Store, Google Play e Steam (gli stessi del sito, non modificati); nell'ultimo quarto di secondo l'insegna salta e torna il buio | **GIOCA GRATIS** / **CON GLI AMICI** | `bulb`, `spark` al guasto, musica in dissolvenza |

Il finale torna al buio e il video riparte dal primo fotogramma (loop).

## La battuta finale

Si cambia con `PAYOFF=` al momento del render (l'ultima parola arriva sempre
da sola, sul battito 45):

| `PAYOFF` | Testo |
|---|---|
| `detto` (predefinita) | TE L'AVEVO … **DETTO.** |
| `mamma` | MAMMA NON DEVE … **SAPERLO.** |
| `sangue` | IL SANGUE NON È … **ACQUA.** |

## Come si rifà

```sh
# 0. I badge degli store, dai file del sito (site/oberta/img/badges).
swift tool/promo/badges.swift
# 1. I fotogrammi (PNG) in build/promo/frames/ e il poster in build/promo/.
flutter test tool/promo/promo_render_test.dart          # PAYOFF=mamma …
# 2. Il video con l'audio mixato: build/promo/oberta_short_pov.mp4.
swift tool/promo/encode.swift
```

`FRAMES=0,90,500` nel test rende solo quei fotogrammi e un foglio di
provini (`build/promo/contact.png`). `swift tool/promo/beats.swift <traccia>`
stampa tempo e tratto più forte di una traccia, per rifare i tagli su
un'altra musica.
