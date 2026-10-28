# Economia: solo guadagnata, mai comprata

Obertà è un progetto per imparare, senza partita IVA: **niente si compra con
soldi veri, mai**. Nell'app non c'è codice di acquisto, il server non accetta
più il motivo `purchase` nel registro delle monete né la fonte `purchase`
nell'armadio (`20261122100000_earn_only_missions.sql`). Le monete si
guadagnano solo giocando e si spendono solo in bottega, in cosmetici che non
cambiano la partita.

## Da dove vengono le monete

Tutto è deciso dal server, nella stessa transazione che chiude la partita
(`settle` in Dart compilato in `engine.js`, poi `internal.record_match`). Il
telefono non dichiara mai niente.

| Fonte | Monete | Esperienza |
| --- | --- | --- |
| Vittoria | 10 | 100 |
| Sconfitta | 4 | 30 |
| Prima vittoria del giorno (UTC) | +30 | +100 |
| Ogni livello | 50, ogni 5 livelli +200 | — |
| Missione del giorno (3, una per gruppo) | 25–50 | 60–100 |
| Missione della settimana (3, una per gruppo) | 120–250 | 200–350 |
| Obiettivi lunghi (13, sempre lì) | 150–800 + pezzi esclusivi | — |
| Medaglie | 50–500 una volta | 100–1000 |

- Le monete della partita e dei livelli finiscono in **una riga sola** del
  registro (`reason = 'match'`) per giocatore e partita.
- Tra amici pagano solo le prime 5 partite del giorno, e solo con almeno 2
  persone al tavolo: una stanza piena di bot non è una zecca. La classificata
  paga sempre. Chi abbandona, resta fermo o esce da morto non prende niente.
- Le missioni si completano con la partita (l'esperienza arriva subito) e si
  **riscuotono** dal pannello Missioni (`claim_mission`): monete, rispetto e,
  per alcuni obiettivi, un pezzo che in bottega non si vende.
- **Rispetto** (`reputation`): +1 per ogni partita che conta, +2 in più per la
  vittoria, più quello che pagano le missioni. Si vede nel pannello Missioni.

## Prezzi e tempi

| Classe | Prezzo | Obiettivo |
| --- | --- | --- |
| Comune | 120 | la prima sera: un paio di partite |
| Raro | 700 | una settimana di gioco tranquillo |
| Epico | 1100–1799 | una-tre settimane |
| Leggendario | 2900–8000 (×1,6 dei vecchi prezzi) | uno-due mesi |
| Pacchetti di lusso | 5500–17400 | uno-quattro mesi (sconto 30–45%) |

"Gioco tranquillo" = 4 giorni a settimana, 3 partite al giorno, 45% di
vittorie, 2 missioni del giorno su 3 e 1 della settimana su 3. Con questi
numeri, dopo il primo mese, una settimana vale circa 730 monete: un raro. Un
giocatore nuovo sale i primi livelli in fretta e va più veloce (circa 1200
monete la prima settimana). Chi gioca quasi ogni giorno (6 giorni, 5 partite)
ci mette meno della metà. Il modello è un test: `test/online/economy_test.dart`
fallisce se un ritocco ai numeri esce da questi obiettivi.

## Pezzi delle missioni

Non si comprano a nessun prezzo (prezzo 0, `shop_items.unlock`; un trigger su
`shop_inventory` li lascia entrare solo come regalo). In bottega si vedono
chiusi con «Si sblocca con: …» e il bottone porta agli obiettivi.

| Pezzo | Obiettivo |
| --- | --- |
| Berretto da sbirro (cappello) | Vinci 5 partite da Commissario |
| Il distintivo (cornice) | Smaschera 5 mafiosi da Commissario |
| Il cappio (cornice) | Manda al patibolo 3 picciotti |
| Alloro d'oro (cornice) | Vinci 50 partite |
| Chiaro di luna (nome) | Sopravvivi a 10 notti |
| Inchiostro di sangue (nome) | Vinci 10 volte con la famiglia |
| Sirena (nome) | Vinci 10 volte con la città |

## Missioni: come girano

- Il pool sta in `internal.mission_defs` ed è lo stesso di `missionPool` in
  `lib/online/game/progress.dart` (un test li tiene uguali). Ogni missione del
  giorno e della settimana appartiene a uno di tre gruppi (partecipa, vinci,
  ruolo/fiuto): se ne pesca una per gruppo.
- La pesca è deterministica, senza cron: un hash di persona, periodo e
  missione (`internal.ensure_missions`), fatta alla prima lettura del giorno o
  della settimana, o alla prima partita.
- Gli obiettivi lunghi non hanno righe finché non si riscuotono: il progresso
  è il contatore a vita (`internal.player_stats`) che la partita già scrive.
- Le missioni compiute e non riscosse restano riscuotibili per 35 giorni,
  poi le righe vecchie si cancellano da sole quando si pescano le nuove.

## Supabase gratuito: quanto pesa

Nessuna tabella nuova: tutto sta in `internal.mission_defs` (41 righe),
`internal.player_missions`, `internal.player_stats` e `public.coin_ledger`.
Niente realtime su queste tabelle, niente cron, nessuna scrittura per evento:
solo la transazione di fine partita e il tasto Riscuoti.

| Per giocatore attivo | Righe | Spazio (con indici) |
| --- | --- | --- |
| Missioni (35 giorni di storia + obiettivi riscossi) | ≤ 133 | ~20 KB |
| Contatori a vita | ~40 | ~4 KB |
| Registro monete | ~1 a partita + 1 a riscossione | ~0,15 KB a riga |

Con 1000 giocatori attivi: missioni e contatori ~25 MB fissi; il registro
cresce di ~25 MB l'anno a 12 partite a settimana. Il traffico è minimo: il
pannello Missioni legge un solo JSON (~6 KB) per apertura, il cartellino della
home lo stesso una volta per accesso e al ritorno dall'app in primo piano.

## Controlli

- `deno test -A supabase/functions/tests/missions_test.ts` (PGlite): riscossione
  una volta sola, solo se il server l'ha compiuta, pezzi solo in regalo,
  niente motivi da soldi veri, prezzi sulla scala nuova.
- `supabase/tests/missions.sql`: gli stessi controlli sul database vero,
  dentro `begin … rollback` (docs/sicurezza.md).
