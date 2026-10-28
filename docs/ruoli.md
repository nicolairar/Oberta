# Ruoli: roster, livelli di potere, ruoli nuovi (28 ottobre 2026)

Documento di progetto. Le **decisioni del proprietario** (28 ottobre 2026) sono nella sezione 0 e valgono su tutto il resto; il batch 1 è già nel codice (sezione 5). Base: `lib/rules/role.dart`, `lib/rules/role_assignment.dart`, `lib/rules/game_engine.dart`, `lib/narration/italian_pack.dart`, `docs/ruoli-analisi.md` (regole di risoluzione già fissate). I numeri di bilanciamento sono valori iniziali, da tarare con la simulazione (`test/rules/new_neutrals_test.dart`).

Nomi dei ruoli nuovi: quelli che i giocatori conoscono dal genere (regola del proprietario, 28 ottobre 2026); l'ambientazione anni Quaranta passa solo per illustrazioni e motti.

Legenda livelli: **L0** nessun potere (o malus), **L1** base, **L2** medio, **L3** forte, **L4** super. Punti: L0 = 0, L1 = 1, L2 = 2, L3 = 3, L4 = 5 (il salto da 3 a 5 è voluto: un L4 pesa per due).

---

## 0. Decisioni del proprietario (finali, 28 ottobre 2026)

- **Sicario:** neutrale, uccide una persona ogni notte, vince **solo se resta l'ultimo vivo** (non più "con una persona" né "con la Famiglia"). *Nel codice.*
- **Prostituta:** della **Famiglia**; di notte passa la notte con una persona e ne blocca la mossa. *Nel codice.*
- **Carceriere:** Città; ogni notte chiude in cella una persona: ne blocca la mossa e la protegge (anche dal fuoco); **niente esecuzione**; può interrogarla in una chat privata per quella notte (il prigioniero non sa chi è il Carceriere); mai la stessa persona due notti di fila; il prigioniero quella notte non usa la voce. *Nel codice.*
- **Pacifista:** Città; una volta per partita, di giorno, svela a tutti il **ruolo esatto** di una persona e annulla il voto di quel giorno. *Nel codice.*
- **Cupido:** la prima notte lega due persone, qualunque ruolo abbiano; gli innamorati vincono solo se sono **vivi tutti e due a fine partita** (qualunque squadra vinca); se uno muore l'altro muore subito. Si conoscono (e hanno una chat privata). *Nel codice.* In locale niente chat: gli innamorati leggono «Il tuo cuore batte per…» al loro turno della notte dopo (e a ogni turno), Cupido «Hai legato…».
- **Presidente:** ammesso **sia in classificata sia tra amici** (nessuna differenza); tutti sanno chi è dall'inizio; la scorta lo salva dalle prime **due notti di attacco** (più attaccanti nella stessa notte contano come un attacco solo), con un'animazione dedicata; la terza notte in cui lo attaccano muore; se muore il Presidente la Città perde. *Nel codice:* pubblico dalla prima carta, non si vota e il Cecchino non gli spara; `AttackOutcome.escorted` con il film della scorta (`DeathAct.escort`); vale −2 punti, da 10 giocatori, mai con Piromane, Sicario o Capo della setta. Anche in locale, uguale (è tutto pubblico).
- **Capo della setta:** neutrale; ogni notte converte una persona; vince quando tutti i vivi sono della setta; se muore la setta si scioglie e non succede altro; il Commissario **non** vede i convertiti; solo il Capo vede l'elenco della setta: i convertiti **non** sanno chi è il Capo né chi altro è nella setta (sanno solo di essere stati convertiti e che ora vincono con la setta). *Nel codice:* compito `convert`; la conversione non passa su chi è in cella o protetto (Dottore, Strozzino), né sulla Famiglia, sul Piromane, sul Sicario o sul Presidente («porta chiusa», la vede solo il Capo), né su chi muore quella notte. Niente chat della setta (i convertiti non si conoscono). In locale il convertito legge «Hai visto la luce» al suo turno della notte dopo, il Capo l'elenco e le porte chiuse.
- **Cecchino** resta per i tavoli piccoli; **Tiratore scelto** per i tavoli grandi (meccanica in attesa della conferma finale: mira di notte, il giorno dopo spara o cambia mira, 2 colpi, muore se spara a un cittadino della Città, i neutrali non lo uccidono).
- **Classificata e stanze degli amici** usano lo stesso roster e le stesse regole dei livelli.
- **Gioco in locale:** ogni ruolo nuovo deve funzionare anche sul telefono unico (`PlayMode.sharedPhone`). Dove un meccanismo non può (una chat privata), si adatta e si scrive qui (vedi 3.1, 3.2, 3.10).

---

## 1. Roster attuale

| Ruolo (in gioco) | enum | Squadra | Potere | Soglia | Liv. | Punti deboli / rotture |
|---|---|---|---|---|---|---|
| Il Picciotto | `mafioso` | Famiglia | Vota l'agguato di notte | 3 | base | Nessuno. |
| Il Padrino | `padrino` | Famiglia | Vota l'agguato; al Commissario risulta onesto | 10 | L2 | Lo Scoop (fazione vera) lo smaschera comunque: va bene così. |
| Il Sarto | `sarto` | Famiglia | Vota l'agguato o, una volta, cuce una bocca per un giorno | 7 | L2 | Il silenzio blocca solo la chat scritta: deve bloccare anche il push-to-talk della piazza. Sul telefono unico non si può far rispettare (lo legge il narratore). |
| Il Compare | `compare` | Famiglia | Chat della Famiglia anche di giorno (solo online) | 7 | L1 | **Testo sbagliato:** dice "di notte uccidi con loro", ma `isKiller` lo esclude. Se resta l'unico mafioso la Famiglia non uccide più: può vincere solo per parità. |
| L'Onesto | `cittadino` | Città | Nessuno | 3 | L0 | Se pesca il Cacciatore di taglie come bersaglio, è solo un bersaglio. |
| Il Commissario | `detective` | Città | Ogni notte: è della Famiglia sì/no | 4 | L3 | Il ruolo più forte della Città. Ingannato da Padrino, Pregiudicato e Sicario; i neutrali risultano onesti. A 4–6 giocatori decide da solo la partita. |
| Il Dottore | `medico` | Città | Ogni notte salva una persona (anche sé, mai la stessa due notti) | 5 | L2 | Dal 20 ottobre non ferma il fuoco. |
| Il Cecchino | `cecchino` | Città | Un colpo di notte, segreto | 7 | L2 | Nessun rischio se sbaglia: spara a caso senza pagare. Si sovrappone ad Artigliere e Tiratore (vedi sotto). |
| Il Cronista | `giornalista` | Città | Una volta: la fazione vera di uno, pubblica all'alba | 8 | L2 | Ok. Se muore quella notte la notizia non esce. |
| Il Becchino | `becchino` | Città | Ogni notte: ruolo esatto di un morto di notte | 8 | L1 | Poca informazione, arriva tardi; le prime notti fa copertura. |
| Il Guardaspalle | `guardaspalle` | Città | Protegge uno e muore al suo posto | 9 | L2 | **È già il "protettore che muore al posto del bersaglio" chiesto dal proprietario.** Incoerenza tra documenti: regola 3 di `ruoli-analisi.md` dice che il fuoco passa a lui, l'aggiornamento del 20 ottobre dice che il fuoco non si ferma. Va scritta una regola sola. |
| Il Reduce | `reduce` | Città | Il primo attacco di notte va a vuoto | 9 | L1 | Ok. |
| Il Pregiudicato | `pregiudicato` | Città | Nessuno; al Commissario risulta della Famiglia | 10 | L0 (−1) | Malus per la Città: nel bilancio vale −1. |
| Il Messia | `messia` | Città | Una volta: resuscita un cittadino linciato | 10 | L2 | **Testo sbagliato:** dice "uno qualsiasi dei morti", la regola è "solo cittadini linciati". |
| Il Sindaco | `sindaco` | Città | Una volta, nel voto: si rivela e vale doppio quel giorno | 9 | L1 | **Testo sbagliato:** dice "da lì vale doppio", il motore lo conta solo quel giorno (domanda aperta da ottobre). |
| Il Portinaio | `portinaio` | Città | Ogni notte: qualcuno è passato da quella porta? | 9 | L1 | Informazione debole e tardiva (la legge la notte dopo). |
| Il Fesso | `fesso` | Neutrale | Vince se linciato | 8 | L1 | Ok. |
| Il Piromane | `piromane` | Neutrale ostile | Cosparge o accende; fuoco inarrestabile | 11 | L4 | Dal 20 ottobre nessuno lo ferma: unico contrasto è il linciaggio. La cella del Carceriere (nuovo) sarebbe il primo contrasto notturno. |
| Il Cacciatore di taglie | `cacciatore` | Neutrale | Vince se la sua taglia viene linciata; se muore altrimenti passa con la Città | 9 | L2 | **È già il "Cacciatore di teste" chiesto.** Unica differenza: dopo la taglia scaduta la carta dovrebbe mostrare "Ora sei un Onesto" (oggi passa con la Città senza dirlo chiaro). |
| Lo Strozzino | `strozzino` | Neutrale | Ogni notte protegge uno; vince se vivo a fine partita | 10 | L1 | È un secondo Dottore che non sceglie parte: aiuta chi protegge, quindi ok. |
| Il Sicario | `sicario` | Neutrale ostile | Uccide ogni notte; risulta della Famiglia; vince solo se resta l'ultimo vivo | 12 | L3 | Ok, fermabile da protezioni e dalla cella. |
| La Prostituta | `prostituta` | Famiglia | Blocca la mossa notturna di una persona; non vota l'agguato (lo vota se resta l'unica che può) | 9 | L2 | Anche in locale. |
| Il Carceriere | `carceriere` | Città | Chiude in cella: blocca e protegge (anche dal fuoco); chat anonima | 8 | L3 | In locale: domanda e risposta scritte. |
| Il Pacifista | `pacifista` | Città | Una volta, di giorno: ruolo esatto di uno a tutti, niente voto | 9 | L2 | Anche in locale. |

**Altre incoerenze trovate**
- `ruoli-analisi.md` dice "cittadini speciali al massimo il 40%", il codice (`maxSpecialCitizensFor`) usa due terzi. Va deciso quale vale.
- Il mazzo oggi conta solo categorie e tetti, non la forza: a 8 giocatori può uscire Commissario + Dottore + Cronista (8 punti) contro 2 Picciotti senza poteri.

---

## 2. Sistema a livelli e bilanciamento

### 2.1 Livelli dei ruoli (esistenti + nuovi)

| Liv. | Città | Famiglia (poteri) | Neutrali |
|---|---|---|---|
| L0 | Onesto (0), Pregiudicato (−1), Presidente (−2) | Picciotto (base) | — |
| L1 | Becchino, Reduce, Sindaco, Portinaio, Cupido | Compare | Fesso, Strozzino |
| L2 | Dottore, Cecchino, Cronista, Guardaspalle, Messia, Pacifista | Padrino, Sarto, Prostituta | Cacciatore di taglie |
| L3 | Commissario, Carceriere, Artigliere, Tiratore scelto | — | Sicario |
| L4 | — | — | Piromane, Capo della setta |

### 2.2 Regole del mazzo (classificata e stanze degli amici, uguali)

Nel codice (`lib/rules/role_assignment.dart`, campo `tier` in `RoleRule`, punti in `RoleInfo.points`). Restano quelle di prima (`maxFamilyPowersFor`, tetti per categoria, `neutralFits`, Compare e ruoli nuovi solo online). In più, con i valori tarati dalla simulazione (2.5):

1. **Famiglia** (`mafiaCountFor`): 1 fino a 6 giocatori, 2 da 7 a **11** (prima 3 a 11: la Famiglia vinceva due partite su tre), 3 a 12.
2. **Bilancio della Città** `V(n)` (`cityBudgetFor`): somma dei punti dei cittadini speciali ≤ `V(n)`; con un neutrale L4 al tavolo, +1.
3. **Bilancio della Famiglia** `F(n)` (`familyBudgetFor`): punti dei poteri di Famiglia ≤ `F(n)`.
4. **Bilancio neutrali** `N(n)` (`neutralBudgetFor`): punti dei neutrali ≤ `N(n)`, e al massimo un neutrale L3/L4.
5. **Al massimo un L4 per tavolo**, e solo da 11 giocatori.
6. **L3 della Città** (`maxStrongCitizensFor`): al massimo uno sotto gli 8 giocatori, due da 8.
7. **Colpo extra** (Cecchino, poi Artigliere e Tiratore): uno solo, mai con Piromane o Sicario.
8. **Contrappeso:** da 7 giocatori, se la Città usa almeno `V(n) − 1` punti e la Famiglia non ha poteri, un Picciotto ne riceve uno (se ce n'è uno ammesso dentro `F(n)`).
9. **Sempre qualcuno che vota l'agguato** nella Famiglia: la Prostituta non lo vota (finché c'è un altro della Famiglia che può).
10. **Neutrali** almeno uno da 9 giocatori (prima da 8), due da 11.

| n | Famiglia | F(n) | N(n) | V(n) | L3 città max |
|---|---|---|---|---|---|
| 4–6 | 1 | 0 | 0 | 3 | 1 |
| 7 | 2 | 0 | 0 | 8 | 1 |
| 8 | 2 | 0 | 2 | 8 | 2 |
| 9 | 2 | 2 | 2 | 8 | 2 |
| 10 | 2 | 2 | 2 | 7 | 2 |
| 11 | 2 | 2 | 7 | 9 | 2 |
| 12 | 3 | 4 | 7 | 10 | 2 |

### 2.3 Chi entra da quanti giocatori

| n | Ruoli che entrano da qui |
|---|---|
| 4 | Commissario |
| 5 | Dottore |
| 7 | Sarto, Compare, Cecchino |
| 8 | Cronista, Becchino, Fesso, **Carceriere** |
| 9 | Guardaspalle, Reduce, Sindaco, Portinaio, Cacciatore, **Prostituta, Pacifista** (poi Tiratore, Cupido) |
| 10 | Padrino, Pregiudicato, Messia, Strozzino (poi Artigliere, Presidente) |
| 11 | Piromane (poi Capo della setta) |
| 12 | Sicario |

### 2.4 Classificata e stanze degli amici

Decisione del proprietario: **stesso roster, stesse regole dei livelli** (2.2) in classificata e tra amici, Presidente compreso. Restano diversi solo il punteggio (OpenSkill per lingua in classificata; XP e monete in tutte e due) e, più avanti, i modi "scegli i ruoli" e "a mano" delle stanze degli amici, che devono comunque rispettare le regole rigide (Famiglia tra 1 e meno della metà del tavolo, sempre un killer, al massimo un L4, al massimo uno che vince col linciaggio, ruoli con chat solo online).

### 2.5 Simulazione del bilanciamento

`tool/balance/simulate.dart` (3000 partite per tavolo; `lib/online/game/deck_balance.dart`): mazzo automatico online, tutti bot del server (`BotBrain`). I bot da soli votano quasi a caso mentre la Famiglia si conosce, e così la Famiglia vince qualunque mazzo; per simulare un tavolo vero al voto ogni non-mafioso, con probabilità 0,3 (il "fiuto"), punta qualcuno della Famiglia. Con questo fiuto il tavolo più semplice (4 giocatori: Picciotto, Commissario, due Onesti) sta alla pari. `test/online/deck_balance_test.dart` rifà una versione corta a ogni `flutter test`.

**Con le regole di 2.2 (ruoli nuovi compresi):**

| n | Città | Famiglia | Neutrali |
|---|---|---|---|
| 4 | 53% | 47% | 0% |
| 5 | 56% | 44% | 0% |
| 6 | **75%** | 25% | 0% |
| 7 | 25% | **75%** | 0% |
| 8 | 40% | 60% | 0% |
| 9 | 45% | 44% | 10% |
| 10 | 59% | 33% | 8% |
| 11 | 52% | 22% | 26% |
| 12 | 26% | 52% | 22% |

Senza i tre ruoli nuovi i numeri cambiano di 1–3 punti al massimo (stessa tabella: 4: 52/48, 6: 76/24, 7: 25/75, 8: 39/61, 10: 60/33/7, 12: 24/55/20): i ruoli nuovi non sbilanciano.

**Prima della taratura** (regole del documento originale, stesso fiuto): 5: 67/33, 6: 80/20, 7: 26/74, 10: 61/33, **11: 17/67/16**. La taratura ha sistemato 5 (Città 67% → 56%), 8 (Famiglia 62% → 60%, Carceriere e due L3 da 8), 10 e soprattutto 11 (Famiglia 67% → 22%, due della Famiglia invece di tre).

**Vittorie per ruolo** (chi aveva quella carta ha vinto), su tutti i tavoli: Picciotto 49%, Padrino 40%, Sarto 40%, Compare 41%, **Prostituta 40%**, Onesto 50%, Commissario 50%, Dottore 37%, Cecchino 38%, Cronista 46%, Becchino 39%, Guardaspalle 42%, Reduce 50%, Pregiudicato 47%, Messia 48%, Sindaco 45%, Portinaio 43%, **Carceriere 44%**, **Pacifista 45%**, Fesso 17%, Piromane 22%, Cacciatore 39%, Strozzino 39%, Sicario 19%. Nessun ruolo domina.

**Il limite che resta: 6 e 7 giocatori.** Nella simulazione conta quasi solo quanti uccidono di notte: un mafioso su 6 perde tre volte su quattro, due su 7 vincono tre volte su quattro, qualunque potere abbia la Città (a 6 anche senza nessun ruolo speciale la Città vince il 71%; a 7 col mazzo cittadino più forte possibile, Commissario + Dottore + Cecchino, vince il 26%). Bilanci e livelli non bastano: serve una decisione sul tavolo (sezione 6).

---

## 3. Ruoli nuovi

Ordine di risoluzione della **notte** con i nuovi ruoli (si aggiunge in testa a quello di `ruoli-analisi.md`, senza toccarlo):
0. Solo la prima notte: Cupido lega gli innamorati (non bloccabile).
1. **Cella** (Carceriere).
2. **Blocco** (Prostituta), se la Prostituta non è in cella.
3. Mira del Tiratore, conversione del Capo della setta, protezioni, agguati, fuoco: come oggi.
4. **Crepacuore**: chi ha l'innamorato morto muore (non si ferma).
5. Messia, poi controllo dei vincitori.

Ordine del **giorno**: discussione (Pacifista, Artigliere, Tiratore possono agire), poi voto (Sindaco). Se il Pacifista parla, il voto salta e si va alla notte.

### 3.1 Il Carceriere — `carceriere`
- **Squadra:** Città · **Liv.:** L3 · **Da:** 8 giocatori · **Categoria:** protettore (conta nel tetto protettori).
- **Notte:** chiude in cella una persona (non sé, mai la stessa due notti di fila). Il prigioniero: azione della notte annullata; nessuna morte lo raggiunge (agguato, Cecchino, Sicario, **fuoco compreso**: la cella è l'unica cosa che ferma il fuoco; resta cosparso). Indagini, scavo e silenzio del Sarto passano: la cella ferma le azioni *del* prigioniero e le morti *su* di lui.
- **Nessuna esecuzione** (resta L3; un'esecuzione lo porterebbe a L4).
- **Interrogatorio:** chat privata tra Carceriere e prigioniero per quella notte (canale `jail:<notte>`, uno nuovo ogni notte). Il prigioniero vede solo "Il Carceriere", mai il nome: le righe del Carceriere non hanno profilo, posto né nome (chi le ha scritte resta in `internal.jail_authors`, per la moderazione). Solo testo: il prigioniero quella notte non ha voce (nemmeno quella della Famiglia).
- **Quando:** la cella si chiude appena il Carceriere sceglie, e non si cambia: la mossa già fatta dal prigioniero salta e non ne può fare altre.
- **Con chi blocca al tavolo** (Carceriere o Prostituta nel mazzo, che è pubblico) l'indagine del Commissario e lo scavo del Becchino non rispondono più subito: rispondono all'alba, e solo se chi li ha fatti non è stato fermato.
- **Interazioni:** Picciotto/Padrino/Sarto in cella non votano l'agguato e non vedono la chat della Famiglia quella notte; se il prigioniero è l'unico killer, niente agguato. Messia, Piromane, Sicario, Capo della setta, Strozzino, Prostituta in cella: azione annullata. Dottore o Guardaspalle sul prigioniero: inutili (nessun colpo da assorbire). La Prostituta che blocca il Carceriere non libera il prigioniero (la cella viene prima). Conta come visita per il Portinaio.
- **Telefono unico** (adattato): niente chat. Al suo turno, dopo aver scelto, il Carceriere può scrivere una domanda; se il prigioniero ha il turno dopo, vede «Sei in cella», la domanda, e può scrivere una risposta che il Carceriere legge al suo turno della notte dopo. Se il prigioniero aveva già giocato, la sua mossa salta e al suo turno della notte dopo legge «Ieri notte eri in cella» e la domanda. Le risposte che arrivano all'alba (indagini e scavi con chi blocca al tavolo, il blocco della Prostituta) sul telefono unico non hanno un momento privato: si leggono al proprio turno della notte dopo, in cima alla scelta. Il testo non esce mai dal telefono.
- **Chi vede cosa:** Carceriere: nome del prigioniero e chat. Prigioniero: *«Sei in cella.»* e la chat anonima. Famiglia (se il prigioniero è dei loro): *«Stanotte Tizio è in cella.»* Gli altri: niente; all'alba nessun annuncio.
- **Testi:** «Chi chiudi in cella stanotte?» · «Sei in cella. Stanotte non esci.» · «Il Carceriere vuole parlarti.» · motto: «Qui dentro si parla. Fuori si muore.»

### 3.2 Il Pacifista — `pacifista`
- **Squadra:** Città · **Liv.:** L2 · **Da:** 9 · **Categoria:** civico.
- **Giorno, una volta per partita, solo in discussione:** sceglie una persona (non sé). Tutti vedono il **ruolo esatto** di quella persona e la carta del Pacifista diventa pubblica. Il voto di quel giorno è annullato: finita la discussione si salta al verdetto («Tregua: oggi non si impicca nessuno.»). Sul telefono unico: in discussione c'è il bottone «Tregua del Pacifista» finché la tregua non è spesa (resta anche se il Pacifista è morto, sennò il tavolo lo saprebbe); il Pacifista tocca il proprio volto (il telefono controlla che lo sia), poi chi svelare, e si va al verdetto.
- **Interazioni:** batte il Padrino (ruolo esatto, non fazione apparente) e il Pregiudicato. Il Fesso svelato quel giorno non può essere linciato. Il Sindaco non può rivelarsi quel giorno (non c'è voto). Il Sarto non lo ferma (il silenzio toglie la chat, non i bottoni). Il Pacifista rivelato diventa un bersaglio della Famiglia: il prezzo del potere.
- **Chi vede cosa:** tutti: nome del Pacifista, nome e ruolo dello svelato. Nessun dato privato.
- **Voce/chat:** nessun canale nuovo.
- **Testi:** «Fermi tutti. Oggi non si impicca nessuno.» · «Il Pacifista ha parlato: Tizio è il Padrino.» · motto: «Il sangue chiama sangue. Io chiamo la tregua.»

### 3.3 Protettore che muore al posto del bersaglio
Esiste già: **Il Guardaspalle**. Nessun ruolo nuovo. Da sistemare solo la regola sul fuoco (vedi tabella 1).

### 3.4 Il Cacciatore di teste
Esiste già: **Il Cacciatore di taglie** (`cacciatore`), identico. Proposta: rinominare la carta in *Il Cacciatore di teste*, il nome che i giocatori conoscono. Unica modifica alle regole: alla taglia scaduta, nota privata *«La tua taglia è morta. Ora sei un Onesto.»* e la carta nel foglio ruoli mostra l'Onesto (al Commissario risultava già onesto).

### 3.5 L'Artigliere — `artigliere`
Differenza con il Cecchino: il Cecchino spara una volta, di notte, in segreto. L'Artigliere spara due volte, **di giorno**, e fa un rumore che tutti sentono.
- **Squadra:** Città · **Liv.:** L3 · **Da:** 10 · **Categoria:** colpo extra (mai con Cecchino, Tiratore, Piromane, Sicario).
- **Giorno, dal secondo giorno, solo in discussione:** 2 colpi in tutta la partita, uno al giorno. Il bersaglio muore subito (di giorno non ci sono protezioni: niente Dottore, Guardaspalle, Reduce). Al primo colpo la sua carta diventa pubblica per sempre.
- **Interazioni:** colpire un innamorato uccide anche l'altro. Sparare alla taglia del Cacciatore: la taglia scade. Il Pacifista non lo ferma. Il Sarto non lo ferma. Dopo il primo colpo, Dottore e Carceriere hanno un motivo per coprirlo.
- **Chi vede cosa:** tutti: chi ha sparato (dal primo colpo), chi è morto e il suo ruolo (come un linciato). Lui: colpi rimasti.
- **Testi:** «Fuoco!» (bottone) · «Un boato in piazza: l'Artigliere ha colpito Tizio.» · «Ti resta un colpo.» · motto: «Io non sussurro. Io tuono.»

### 3.6 Il Tiratore scelto — `tiratore`
- **Squadra:** Città · **Liv.:** L3 · **Da:** 9 · **Categoria:** colpo extra.
- **Notte:** mette nel mirino una persona (non conta come visita per il Portinaio). Il mirino resta finché non lo cambia.
- **Giorno, in discussione:** spara al bersaglio nel mirino, oppure non fa niente (lo cambierà la notte). 2 colpi in tutta la partita.
- **Se colpisce un cittadino** (squadra vera Città, Pregiudicato compreso): muore lui al posto del bersaglio, che resta vivo. Se colpisce Famiglia (Padrino compreso) o un neutrale, il bersaglio muore.
- **Anonimato:** lo sparo è pubblico ma il tiratore resta anonimo, finché non muore per errore (allora la sua carta è pubblica).
- **Interazioni:** si sposa con il Commissario (indaga e spara). In cella o bloccato dalla Prostituta: quella notte non cambia mira, ma il giorno dopo può sparare alla mira vecchia. Colpo di giorno: niente protezioni.
- **Chi vede cosa:** lui: mira attuale, colpi rimasti. Tutti: «Un colpo dal campanile» e il morto col suo ruolo.
- **Testi:** «Chi tieni nel mirino?» · «Spari a Tizio?» · «Il colpo ti torna indietro: era uno della Città.» · motto: «Un respiro, un colpo, un nome.»
- **Nota:** decisione del proprietario: il Cecchino resta per i tavoli piccoli, il Tiratore per quelli grandi. Meccanica qui sopra in attesa della conferma finale.

### 3.7 Cupido — `cupido`
> Decisione del proprietario (sezione 0): gli innamorati **vincono solo se sono vivi tutti e due a fine partita**, chiunque vinca (e non vincono con la loro squadra se uno dei due è morto); si conoscono e hanno la loro chat. *Nel codice:* intenzione `Link` (due nomi, una volta, non si cambia), crepacuore di notte (`DawnReport.heartbroken`, carta coperta) e sul patibolo (`LynchReport.heartbroken`, `RoundRecord.dayVictims`); il Messia che riporta un innamorato spezza il legame, e così chi lascia la città. Chat `lovers` online di notte, per i due vivi e fuori di cella (migrazione `20261122090000_lovers_chat.sql`).

- **Squadra:** Città · **Liv.:** L1 · **Da:** 9 · **Categoria:** civico.
- **Prima notte (sola azione):** lega due persone (può includere se stesso). Non bloccabile, non è una visita.
- **Innamorati:** ognuno sa il **nome** dell'altro, non il ruolo. Tengono la loro squadra e in più hanno una vittoria personale: vincono se sono **vivi tutti e due a fine partita**, chiunque vinca (come lo Strozzino). Se uno muore (notte, linciaggio, colpo di giorno) l'altro muore subito di crepacuore: niente lo ferma, e il crepacuore viene prima del controllo dei vincitori.
- **Interazioni:** Famiglia innamorata di un cittadino: se la Famiglia uccide l'amato, muore anche il suo. Messia che riporta un innamorato: torna solo lui e il legame si spezza. Becchino sul morto di crepacuore: ruolo esatto. Il Capo della setta che converte un innamorato non converte l'altro.
- **Voce/chat:** chat `innamorati` solo testo, solo di notte, solo online.
- **Chi vede cosa:** Cupido: i due nomi. Ognuno dei due: *«Sei innamorato di Tizio.»* Gli altri: niente; alla morte per crepacuore tutti leggono *«Caio è morto di crepacuore.»*
- **Testi:** «Chi fai sposare?» · «Il cuore ha scelto: sei innamorato di Tizio.» · motto: «Due cuori, una dote, nessuna via d'uscita.»

### 3.8 Il Presidente — `presidente`
> Decisione del proprietario (sezione 0): ammesso **in classificata e tra amici**; la scorta lo salva dalle prime **due notti** di attacco (più attaccanti nella stessa notte = un attacco), con un'animazione sua; alla terza notte attaccato muore, e la Città perde. Dove il testo sotto dice "variante" o "agguati", vale questo.

Diverso dal Sindaco: il Sindaco è segreto e si rivela per un voto doppio; il Presidente è pubblico da subito ed è un punto debole della Città.
- **Squadra:** Città · **Liv.:** L0 (−2: è una debolezza per la Città) · **Da:** 10 · **Solo variante** (stanze degli amici, mai in classificata).
- **Pubblico dall'inizio:** tutti sanno chi è. Non si può votare (non si lincia lo Stato).
- **Se muore, la Città perde:** vince la Famiglia (se ci sono Famiglia viva o neutrali ostili; mai insieme a Piromane o Sicario, per evitare vincitori ambigui).
- **La scorta**, sennò la Famiglia lo uccide la prima notte e la partita è finita: i primi **due** agguati contro di lui falliscono (*«La scorta ha respinto un attentato.»*, pubblico). Dottore, Guardaspalle e Carceriere lo coprono come chiunque.
- **Chi vede cosa:** tutti: nome, ruolo, colpi di scorta rimasti.
- **Testi:** motto: «Lo Stato non tratta.» · «Il Presidente è caduto. La città è perduta.»

### 3.9 Il Capo della setta — `capoSetta`
> Decisione del proprietario (sezione 0): se muore, la setta si scioglie e basta; il Commissario **non** vede i convertiti; solo il Capo vede l'elenco: i convertiti **non** sanno chi è il Capo né chi altro c'è (sanno solo che ora vincono con la setta). Dove il testo sotto dice altro (i nomi degli altri convertiti, la chat `setta`), vale questo.

- **Squadra:** Neutrale ostile (conta come Piromane e Sicario: uno solo, finché è vivo la Città non vince) · **Liv.:** L4 · **Da:** 11 (massimo del tavolo 12) · **Mai** con Piromane o Sicario.
- **Notte:** converte una persona alla setta. I convertiti tengono ruolo e poteri ma vincono solo con la setta. **Vince da solo** (con tutti i convertiti) quando tutti i vivi sono della setta.
- **Chi non si converte:** la Famiglia (tutta), Piromane, Sicario, Presidente. Su di loro la conversione fallisce e il Capo della setta legge *«Porta chiusa.»* (scopre che è uno "non convertibile", ma non chi è). Quindi la setta vince solo se la Famiglia è morta: il Capo della setta vive dei linciaggi della Città.
- **Contrasti:** il Dottore e lo Strozzino sul bersaglio fermano la conversione (la cura); il Guardaspalle no (non c'è morte da prendere). La cella e la Prostituta la fermano. Il linciaggio del Capo della setta **scioglie la setta**: i convertiti tornano alla loro squadra, nessuno muore.
- **Investigazioni:** il Capo della setta e i convertiti al Commissario risultano onesti (la setta non è la Famiglia). Il Cronista scrive «della Setta». Il Becchino legge ruolo e «(della Setta)». Il Portinaio conta la conversione come visita.
- **Voce/chat:** chat `setta` solo testo, di notte, solo online. Sul telefono unico il Capo della setta è vietato (troppe sveglie private).
- **Chi vede cosa:** Capo della setta: elenco dei convertiti. Convertito: *«Ora sei della setta.»* e i nomi degli altri. Gli altri: niente.
- **Testi:** «Chi chiami alla luce stanotte?» · «Hai visto la luce. Ora sei della setta.» · motto: «Non vi chiedo di credere. Vi chiedo di seguirmi.»

### 3.10 La Prostituta — `prostituta`
Decisione del proprietario: **della Famiglia**. Anche in locale: chi è stato bloccato lo legge al suo turno della notte dopo.
- **Squadra:** Famiglia · **Liv.:** L2 · **Da:** 9 · **Categoria:** potere di Famiglia (conta in `maxFamilyPowersFor`).
- **Notte:** passa la notte con una persona (mai la stessa due notti di fila): l'azione di quella persona è annullata (una mossa da una volta sola, come lo scoop, è spesa lo stesso). Non vota l'agguato finché nella Famiglia c'è un altro che lo vota; se resta l'unica, vota l'agguato e può ancora, al suo posto, passare la notte fuori.
- **Interazioni:** blocca Commissario, Dottore, Guardaspalle, Becchino, Portinaio, Cronista (lo scoop è speso), Messia (spesa), Tiratore (mira), Piromane, Sicario, Capo della setta, Strozzino. Non blocca Cupido (prima notte) né i poteri di giorno. Non sblocca la cella. Conta come visita per il Portinaio. In cella non agisce.
- **Chi vede cosa:** Prostituta: il nome scelto. Famiglia: chi ha scelto (nella chat). Bloccato, all'alba: *«Stanotte qualcuno ti ha tenuto occupato.»*
- **Voce/chat:** chat e voce della Famiglia, come gli altri.
- **Testi:** «Per chi canti stanotte?» · «Stanotte qualcuno ti ha tenuto occupato.» · motto: «Una canzone, un bicchiere, e la notte vola.»

### 3.11 Esclusi dal proprietario
Setacciatore (cacciatore di setta), Hacker.

---

## 4. Canali di voce e chat (con i nuovi)

| Canale | Chi scrive | Chi parla (push-to-talk) | Quando | Note |
|---|---|---|---|---|
| Piazza (`day`) | Vivi, tranne il silenziato dal Sarto | Vivi, tranne il silenziato | Giorno | Il silenzio deve spegnere anche la voce |
| Famiglia (`family`) | Famiglia viva, tranne chi è in cella | Idem | Notte (e giorno con il Compare) | Anche la Prostituta. *Nel codice.* |
| Cella (`jail:<notte>`) | Carceriere (anonimo) e prigioniero | Nessuno (il prigioniero perde anche la voce della Famiglia) | Notte | Online; in locale domanda e risposta scritte (3.1). *Nel codice.* |
| Innamorati (`lovers`, nuovo) | I due innamorati | Nessuno | Notte | Solo online |
| Setta (`sect`, nuovo) | Capo della setta e convertiti | Nessuno | Notte | Solo online |
| Eventi (`event`) | Server | — | Sempre | Righe private per seggio dove serve |

**Anti-trucco:** come oggi, ogni seggio riceve solo ciò che `viewFor` gli concede; i canali nuovi vanno filtrati dal server (il nome del Carceriere non deve mai arrivare al telefono del prigioniero, nemmeno nei dati della chat).

---

## 5. Ordine di lavoro proposto

| Batch | Contenuto | Perché prima |
|---|---|---|
| 1 (fatto) | Livelli `tier` e bilanci V/F/N nel mazzo, tarati con la simulazione; Sicario "ultimo vivo"; **Prostituta**, **Carceriere** (cella, chat anonima, voce tolta), **Pacifista** (tregua) | Richiesta del proprietario |
| 2 | Correzione testi Compare, Messia, Sindaco; Cacciatore "ora sei un Onesto"; regola unica Guardaspalle/fuoco | Solo ordine |
| 3 | **Artigliere** (se confermato) | Usa il bottone di giorno del Pacifista |
| 4 | **Tiratore scelto** | Usa mira di notte + colpo di giorno (batch 2 e 3) |
| 5 | **Cupido**: legame, crepacuore, canale `lovers` | Tocca il controllo dei vincitori |
| 6 | **Capo della setta**: conversione, setta, canale `sect`, scioglimento | Il più complesso; serve simulazione dedicata |
| 7 | **Presidente** come variante | Solo stanze degli amici |
| 8 | Stanze degli amici: "scegli i ruoli" e "a mano" con barra dei bilanci; elenco ruoli ammessi in classificata | Serve avere i ruoli |

Per ogni batch: testi IT/EN in `italian_pack.dart`/`english_pack.dart`, voci di ogni frase nuova (`tool/voice/regenerate.sh`, Kokoro im_nicola/am_adam, 0.86, effetto godfather), icone dei ruoli (`docs/ruoli-icone.md`), test in `test/rules/interactions_test.dart`, simulazione 300 partite, e aggiornamento del sito `site/oberta`. Ogni ruolo entra in classificata solo dopo un batch di prova nelle stanze degli amici.

---

## 6. Domande ancora aperte

Decise il 28 ottobre (sezione 0): Prostituta della Famiglia; cella che ferma il fuoco e senza esecuzione; Pacifista col ruolo esatto; Cupido con la vittoria a due; Presidente in classificata e tra amici con la scorta da due notti; setta sciolta alla morte del Capo e invisibile al Commissario; Cecchino per i tavoli piccoli e Tiratore per i grandi.

Restano:

1. **Tavoli da 6 e 7** (simulazione, 2.5): a 6 la Città vince il 75%, a 7 la Famiglia il 75%, e nessun bilancio di livelli lo cambia. Strade possibili: (a) accettarlo (i tavoli veri hanno più fiuto dei bot: va visto con le partite vere); (b) a 6 e 7 un solo mafioso più un neutrale che uccide (in simulazione: a 6 Città 28%, Famiglia 28%, Sicario 44%; a 7 con Commissario e Dottore Città 42%, Famiglia 16%, Sicario 42%: nessuna squadra sopra il 60%, ma il Sicario da solo vince troppo); (c) a 7 la Famiglia da 2 con un voto della piazza in più al primo giorno (da progettare).
2. **Tiratore scelto:** conferma della meccanica (sezione 0).
3. **Telefono unico:** le risposte all'alba arrivano al turno della notte dopo (vedi 3.1): il Commissario con un Carceriere o una Prostituta al tavolo gioca la piazza senza la risposta della notte. Va bene, o si preferisce un passaggio di telefono privato all'alba?
4. **Indagini all'alba:** con un Carceriere o una Prostituta nel mazzo il Commissario e il Becchino ricevono la risposta all'alba invece che subito (sennò il blocco non bloccherebbe niente). Va bene così, o la risposta resta immediata e il blocco ferma solo le mosse che si risolvono all'alba?
5. **Pacifista:** la tregua si chiede solo in discussione (non durante il voto). Va bene?
6. **Cittadini speciali:** vale il 40% del documento o i due terzi del codice? (il codice resta ai due terzi)
7. **Sindaco:** voto doppio solo quel giorno (motore) o da lì in poi (testo)?
8. **Guardaspalle e fuoco:** muore lui al posto del cosparso o il fuoco non si ferma?
9. **Stanze degli amici:** il mazzo "a mano" può infrangere i bilanci con solo un avviso?
