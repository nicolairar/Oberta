# Guida per generare le icone dei ruoli

Questa guida permette a un agente o collaboratore senza contesto di creare nuove icone coerenti per Obertà. Le regole visive e l'elenco canonico dei ruoli sono in [`ruoli-icone.md`](ruoli-icone.md); prima di generare o rinominare un'icona, consultare quel file.

## Riferimento approvato

- Usare [`../assets/roles/piromane.png`](../assets/roles/piromane.png) come riferimento visivo approvato per forma, contorno e stile.
- `piromane-concept.png` è la prima prova; per la produzione usare `piromane.png`.
- `piromane.svg` è un ridisegno vettoriale semplificato fatto a mano. Gli altri PNG generati non diventano automaticamente vettoriali solo perché sono inseriti in un contenitore SVG.
- Non cambiare stile, proporzioni, leggibilità o colori delle fazioni senza chiedere una review all'utente.

## Regole visive

- Noir mafioso tra gli anni '20 e '50: emblema circolare, oggetto centrale, silhouette grandi e semplici.
- Contorno spesso color inchiostro `#100B09`, medaglione circolare dello stesso diametro e stessa inquadratura per tutti i ruoli.
- Illustrazione piatta, pochi dettagli, niente sfumature, texture, ombre, scenari, testo o numeri.
- La forma deve distinguersi a 24 px. Se il simbolo si confonde quando ridotto, semplificarlo o ingrandirlo.
- Colore del fondo del medaglione per fazione:
  - Famiglia: rosso sangue `#A51D25`.
  - Città: ottone `#D6AD48`.
  - Neutrali: verde salvia `#7A9A6A`.
- Accenti: carta `#EFDFB9`, inchiostro `#100B09`, ottone `#D6AD48`, rosso `#A51D25` e verde salvia `#7A9A6A`. Usare colori che facciano risaltare il simbolo sul fondo della fazione.
- Non mettere il nome del ruolo dentro l'icona. Il nome e l'idea semantica si prendono dalla tabella in `ruoli-icone.md`.

## Flusso consigliato con ImageGen

1. Leggere `docs/ruoli-icone.md` e verificare id, nome, fazione e idea per l'icona. Quella tabella è la fonte di verità, non un prompt precedente.
2. Allegare `assets/roles/piromane.png` come riferimento di stile. Chiedere un foglio di icone trasparente, tutte della stessa dimensione e in una griglia esplicita. Specificare il colore di fondo per ciascuna fazione.
3. Per ridurre le differenze di stile, generare in un singolo foglio le icone mancanti. Scrivere l'ordine da sinistra a destra, dall'alto in basso, e mantenerlo in una mappa id→cella prima di ritagliare.
4. Chiedere un'icona distinta e centrata per cella, medaglioni della stessa dimensione, spazio trasparente fra celle, nessun testo e nessun elemento che attraversi i bordi delle celle.
5. L'ImageGen restituisce un PNG con trasparenza e può variare le dimensioni rispetto alla griglia chiesta. Controllare il file e la griglia prima del ritaglio; non assumere dimensioni fisse.
6. Ritagliare ogni cella in un PNG separato e salvarlo come `assets/roles/<id>.png`, usando esattamente l'id in `ruoli-icone.md`. Per un file già approvato, conservarne il riferimento e non sostituirlo durante la generazione del foglio.
7. Controllare visivamente tutte le icone ritagliate su fondo chiaro e scuro, verificare la trasparenza e provarle ridotte a 24 px. Rifare le celle sbagliate prima di consegnare il set.

### Prompt di partenza

Adattare l'elenco e l'ordine delle celle al lavoro in corso. Non lasciare nel prompt ruoli che non si stanno generando.

```text
Create a transparent sprite sheet of [N] distinct square role icon badges for Obertà, a mafia-themed social deduction game. Use the attached assets/roles/piromane.png only as the approved style reference: centered circular medallion, thick clean near-black outline (#100B09), flat bold shapes, simple readable silhouettes, restrained palette, no gradients, texture, shadows, scenery, lettering, text or numbers. Keep the same badge diameter, border weight, framing and visual detail across all cells. Each icon must remain recognizable at 24 px.

Use faction-colored medallion fills: Family = blood red #A51D25; City = brass #D6AD48; Neutral = sage #7A9A6A. Ivory #EFDFB9 and the same faction colors may be used for object accents. Keep the object high-contrast against its circle.

Arrange exactly [COLUMNS] columns x [ROWS] rows, in this exact row-major order. Leave transparent gutters between cells, keep each complete badge inside its cell, and do not add grid lines or a sheet background:
[ROW 1: role id, faction, simple icon subject; ...]
[ROW 2: ...]
...
```

Descrivere l'oggetto usando l'idea breve nella tabella dei ruoli. Se un'idea produce un simbolo troppo dettagliato, scegliere la variante più semplice, senza inventare una nuova meccanica del ruolo.

## Ritaglio e nomi

Le dimensioni del foglio cambiano a seconda della generazione. Prima di ritagliare, leggere larghezza e altezza e ispezionare dove cadono i centri delle icone. Su macOS `sips` ritaglia usando `--cropOffset <y> <x>`:

```sh
sips -c ALTEZZA LARGHEZZA --cropOffset OFFSET_Y OFFSET_X foglio.png --out assets/roles/ID.png
```

Per il foglio usato nel set attuale il canvas era 1254×1254; ogni cella ritagliata era 250×250. Gli offset X erano `0, 251, 502, 753, 1004`; gli offset Y erano `87, 337, 587, 837`. Questi valori sono un riferimento per quel foglio, non una regola per fogli futuri: ricontrollare sempre l'immagine e assicurarsi che il medaglione non sia tagliato.

Usare l'id della tabella come nome file, tutto minuscolo, per esempio `guardaspalle.png` o `cacciatore.png`. Il set deve contenere un PNG per ciascuno dei 21 id. Evitare varianti con suffissi come `-final2`; per prove temporanee usare una cartella separata.

## PNG e SVG

ImageGen crea immagini raster PNG, non SVG vettoriali. Il set attuale è composto dai PNG trasparenti in `assets/roles/`. Mettere il PNG dentro un tag `<image>` SVG non lo rende vettoriale e non equivale a una conversione.

Se il progetto richiede SVG scalabili, tracciare o ridisegnare davvero ciascun simbolo in vettori, mantenendo una `viewBox="0 0 64 64"`, e confrontare il risultato con il PNG approvato a 24 px. Non cancellare il PNG sorgente durante la vettorializzazione. `piromane.svg` è un esempio di ridisegno semplificato; non implica che gli altri ruoli abbiano già una versione SVG.

## Controllo finale

- [ ] Ogni id in `ruoli-icone.md` ha una sola icona col nome corrispondente.
- [ ] Nessun medaglione o elemento è tagliato; lo sfondo esterno è trasparente.
- [ ] Famiglia, Città e Neutrali hanno rispettivamente fondo rosso, ottone e verde salvia.
- [ ] Contorno, diametro, peso visivo e palette restano coerenti con `piromane.png`.
- [ ] Il simbolo si riconosce a 24 px e non viene confuso con quello di un altro ruolo.
- [ ] Le icone sono state mostrate all'utente prima di sostituire lo stile approvato o integrarle nell'interfaccia.
