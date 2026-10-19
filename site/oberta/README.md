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
