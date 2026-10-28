# Obertà — short da 15 secondi (Reels / TikTok / Shorts)

Verticale 9:16, 1080×1920, **60 fps**, MP4 H.264 + AAC. Testi in italiano.
Pensato per lo scroll: gancio nel primo secondo, tagli secchi sul battere,
colpo di scena, finale che si richiude sull'inizio (loop).

- **Musica**: `assets/music/day.m4a` dal secondo ~49,9 (il tratto più pieno),
  136 bpm → un battito ogni 0,44 s. Tutti i tagli cadono su un battito.
- **Didascalie**: stile TikTok, Georgia Bold maiuscolo, bianco con contorno
  nero spesso, la parola chiave in giallo o rosso. Sempre nella fascia
  12–70% dell'altezza e lontane dal bordo destro (lì ci sono i pulsanti
  dell'app): niente nel 20% in basso.
- **Look**: palette noir del gioco, grana leggera, vignettatura, punch-in con
  curve morbide e scia (motion blur) sui movimenti veloci.
- **Voce**: narratore Kokoro (im_nicola), clip già incise per il gioco.
- **Effetti**: nostri (`assets/sounds`, `assets/sfx`) + 3 meme brevi
  (`faaah`, `vine_boom`, `hee_hee`), con la musica abbassata sotto.

| # | Tempo s (battiti) | Visivo | Animazione | Testo a schermo | Audio | Transizione |
|---|---|---|---|---|---|---|
| 1 | 0,00–1,76 (0–4) | Il tavolo della notte, i giocatori seduti | Push-in lento; al battito 2 shake + lampo rosso | **UNO DEI TUOI AMICI** → **È UN MAFIOSO.** | colpo `punch` sul battito 2 | taglio secco |
| 2 | 1,76–3,52 (4–8) | Notte: la chat della Famiglia | Punch-in 1,10→1,0 sul taglio, deriva lenta | **DI NOTTE LA FAMIGLIA UCCIDE.** | `swish`, voce «Quando cala la notte» | taglio secco |
| 3 | 3,52–5,28 (8–12) | Giorno: il tavolo con i numeri bianchi dei posti | Zoom lento, shake piccolo sul battito 10 | **DI GIORNO SI ACCUSA.** | voce «Tu! Dov'eri stanotte?» | taglio secco |
| 4 | 5,28–6,60 (12–15) | Il voto: le preferenze sui posti | Punch-in sul tavolo votato | **VOTA CHI MENTE.** | `gavel` sul battito 14 | taglio secco |
| 5 | 6,60–8,36 (15–19) | Il film del verdetto, quello del gioco | La scena scorre accelerata, camera che spinge | **E IL CONDANNATO…** | `faaah` quando parte il condannato | taglio al nero |
| 6 | 8,36–9,68 (19–22) | Fondo rosso con l'icona del ruolo | Sbatte dentro, shake forte, lampo bianco | **ERA IL PICCIOTTO.** | `vine_boom` sul battito 19, voce «Il Picciotto» | taglio secco |
| 7 | 9,68–11,88 (22–27) | Bottega: un personaggio assurdo per battito | Ogni battito un ritratto nuovo che entra con un colpo di zoom | **VESTITI DA PAZZO.** | `cashreg` sul primo, `hee_hee` a metà | tagli a ogni battito |
| 8 | 11,88–13,20 (27–30) | Tre targhe del gioco, una per battito | Cadono dall'alto con rimbalzo | **CON GLI AMICI / CLASSIFICATA / UN TELEFONO** | `wood_heavy` a ogni targa | taglio secco |
| 9 | 13,20–15,00 (30–34) | L'insegna al neon OBERTÀ | Le lettere si accendono una per una; nell'ultimo quarto di secondo l'insegna salta e torna il buio | **GRATIS • IPHONE E STEAM** | `spark` al guasto, musica in dissolvenza | buio → riparte la scena 1 (loop) |

## Come si rifà

```sh
# 1. I fotogrammi (PNG) in build/promo/frames/ e il poster in build/promo/.
flutter test tool/promo/promo_render_test.dart
# 2. Il video con l'audio mixato: build/promo/oberta_short_15s.mp4.
swift tool/promo/encode.swift
```

`swift tool/promo/beats.swift <traccia>` stampa tempo e tratto più forte di una
traccia, per rifare i tagli su un'altra musica. `FRAMES=0,60,120` nel test
rende solo quei fotogrammi, per provare.
