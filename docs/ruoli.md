# Ruoli: roster, livelli di potere, ruoli nuovi (28 ottobre 2026)

Documento di progetto. Le **decisioni del proprietario** (28 ottobre 2026) sono nella sezione 0 e valgono su tutto il resto; il batch 1 è già nel codice (sezione 5). Base: `lib/rules/role.dart`, `lib/rules/role_assignment.dart`, `lib/rules/game_engine.dart`, `lib/narration/italian_pack.dart`, `docs/ruoli-analisi.md` (regole di risoluzione già fissate). I numeri di bilanciamento sono valori iniziali, da tarare con la simulazione (`test/rules/new_neutrals_test.dart`).

Nomi dei ruoli nuovi: quelli che i giocatori conoscono dal genere (regola del proprietario, 28 ottobre 2026); l'ambientazione anni Quaranta passa solo per illustrazioni e motti.

Legenda livelli: **L0** nessun potere (o malus), **L1** base, **L2** medio, **L3** forte, **L4** super. Punti: L0 = 0, L1 = 1, L2 = 2, L3 = 3, L4 = 5 (il salto da 3 a 5 è voluto: un L4 pesa per due).

---

## 0. Decisioni del proprietario (finali, 28 ottobre 2026)

- **Sicario:** neutrale, uccide una persona ogni notte, vince **solo se resta l'ultimo vivo** (non più "con una persona" né "con la Famiglia"). *Nel codice.*
- **Prostituta:** vince con la **Famiglia** ma **non sa chi sono** (decisione del 29 ottobre): niente elenco, chat, voce o mani della Famiglia per lei, e la Famiglia non sa di lei (alleata nascosta da tutte e due le parti). Di notte passa la notte con una persona, chiunque sia (anche della Famiglia), e ne blocca la mossa. Non vota l'agguato; se resta l'ultima della Famiglia vota lei («Sei rimasta l'ultima della Famiglia: ora la notte è tua»), sempre senza sapere dei morti più di quanto è pubblico. Al Commissario risulta della Famiglia. *Nel codice.*
- **Carceriere:** Città; ogni notte chiude in cella una persona: ne blocca la mossa e la protegge (anche dal fuoco); **niente esecuzione**; può interrogarla in una chat privata per quella notte (il prigioniero non sa chi è il Carceriere); mai la stessa persona due notti di fila; il prigioniero quella notte non usa la voce. *Nel codice.*
- **Pacifista:** Città; una volta per partita, di giorno, svela a tutti il **ruolo esatto** di una persona e annulla il voto di quel giorno. *Nel codice.*
- **Cupido:** la prima notte lega due persone, qualunque ruolo abbiano; gli innamorati vincono solo se sono **vivi tutti e due a fine partita** (qualunque squadra vinca); se uno muore l'altro muore subito. Si conoscono (e hanno una chat privata). *Nel codice.* In locale niente chat: gli innamorati leggono «Il tuo cuore batte per…» al loro turno della notte dopo (e a ogni turno), Cupido «Hai legato…».
- **Presidente:** ammesso **sia in classificata sia tra amici** (nessuna differenza); tutti sanno chi è dall'inizio; la scorta lo salva dalle prime **due notti di attacco** (più attaccanti nella stessa notte contano come un attacco solo), con un'animazione dedicata; la terza notte in cui lo attaccano muore; se muore il Presidente la Città perde. *Nel codice:* pubblico dalla prima carta, non si vota e il Cecchino non gli spara; `AttackOutcome.escorted` con il film della scorta (`DeathAct.escort`); vale −2 punti, da 10 giocatori, mai con Piromane, Sicario o Capo della setta. Anche in locale, uguale (è tutto pubblico).
- **Capo della setta:** neutrale; ogni notte converte una persona; vince quando tutti i vivi sono della setta; se muore la setta si scioglie e non succede altro; il Commissario **non** vede i convertiti; solo il Capo vede l'elenco della setta: i convertiti **non** sanno chi è il Capo né chi altro è nella setta (sanno solo di essere stati convertiti e che ora vincono con la setta). *Nel codice:* compito `convert`; la conversione non passa su chi è in cella o protetto (Dottore, Strozzino), né sulla Famiglia, sul Piromane, sul Sicario o sul Presidente («porta chiusa», la vede solo il Capo), né su chi muore quella notte. Niente chat della setta (i convertiti non si conoscono). In locale il convertito legge «Hai visto la luce» al suo turno della notte dopo, il Capo l'elenco e le porte chiuse.
- **Artigliere:** Città, L3, da 10 giocatori, colpo extra (mai con Cecchino, Tiratore, Piromane, Sicario). *Nel codice:* `Fire` di giorno, solo in discussione, dal secondo giorno, due colpi in tutto, uno al giorno; il colpito muore subito (niente Dottore, Guardaspalle, Reduce: di giorno non ci sono protezioni) e la sua carta si gira come quella di un linciato; al primo colpo anche l'Artigliere diventa pubblico. Non spara al Presidente (è della Città, come il Cecchino: la scorta para solo gli attacchi di notte). La tregua del Pacifista e il silenzio del Sarto non lo fermano; l'innamorato del colpito muore di crepacuore; la taglia colpita scade. Se il colpo chiude la partita, finisce lì. Online: bottone «Fuoco!» in discussione, riga in chat (`cannon`), boato; in locale: bottone «Fuoco dell'Artigliere» in discussione accanto alla tregua (l'Artigliere tocca il suo volto, poi il bersaglio), poi il copione del boato. Build 66.
- **Cecchino** resta per i tavoli piccoli; **Tiratore scelto** per i tavoli grandi: mira di notte, il giorno dopo spara o cambia mira, 2 colpi, muore se spara a un cittadino della Città, i neutrali non lo uccidono. *Nel codice* (3.6): enum `tiratoreScelto`, da 9 giocatori; dove può entrare lui il Cecchino non esce (torna solo se al tavolo c'è un telefono troppo vecchio per il Tiratore).
- **Classificata** (29 ottobre): 12 giocatori, con un **mazzo suo a posti fissi** tarato con la simulazione (2.6). Le stanze degli amici e il gioco in locale usano il mazzo automatico (2.2).
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
| La Prostituta | `prostituta` | Famiglia | Blocca la mossa notturna di una persona (anche della Famiglia); non sa chi è della Famiglia e la Famiglia non sa di lei; non vota l'agguato (lo vota se resta l'ultima della Famiglia) | 12 | L2 | Anche in locale. Da 12 (prima da 9): con due della Famiglia lasciava un killer solo. |
| Il Carceriere | `carceriere` | Città | Chiude in cella: blocca e protegge (anche dal fuoco); chat anonima | 8 | L3 | In locale: domanda e risposta scritte. |
| Il Pacifista | `pacifista` | Città | Una volta, di giorno: ruolo esatto di uno a tutti, niente voto | 9 | L2 | Anche in locale. |
| Il Tiratore scelto | `tiratoreScelto` | Città | Di notte mira; di giorno spara (2 colpi); se colpisce la Città muore lui | 9 | L3 | Anche in locale. Prende il posto del Cecchino da 9. |

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

### 2.2 Regole del mazzo (stanze degli amici e locale; la classificata ha il suo, 2.6)

Nel codice (`lib/rules/role_assignment.dart`, campo `tier` in `RoleRule`, punti in `RoleInfo.points`). Restano quelle di prima (`maxFamilyPowersFor`, tetti per categoria, `neutralFits`, Compare e ruoli nuovi solo online). In più, con i valori tarati dalla simulazione (2.5):

1. **Famiglia** (`mafiaCountFor`): 1 fino a 6 giocatori, 2 da 7 a **11** (prima 3 a 11: la Famiglia vinceva due partite su tre), 3 a 12.
2. **Bilancio della Città** `V(n)` (`cityBudgetFor`): somma dei punti dei cittadini speciali ≤ `V(n)`; con un neutrale L4 al tavolo, +1.
3. **Bilancio della Famiglia** `F(n)` (`familyBudgetFor`): punti dei poteri di Famiglia ≤ `F(n)`.
4. **Bilancio neutrali** `N(n)` (`neutralBudgetFor`): punti dei neutrali ≤ `N(n)`, e al massimo un neutrale L3/L4.
5. **Al massimo un L4 per tavolo**, e solo da 11 giocatori.
6. **L3 della Città** (`maxStrongCitizensFor`): al massimo uno sotto gli 8 giocatori, due da 8.
7. **Colpo extra** (Cecchino, poi Artigliere e Tiratore): uno solo, mai con Piromane o Sicario.
8. **Contrappeso:** da 7 giocatori, se la Città usa almeno `V(n) − 1` punti e la Famiglia non ha poteri, un Picciotto ne riceve uno (se ce n'è uno ammesso dentro `F(n)`).
9. **Sempre qualcuno che vota l'agguato** nella Famiglia: la Prostituta non lo vota (finché c'è un altro della Famiglia che può), e non conosce la Famiglia.
10. **Neutrali** almeno uno da 9 giocatori (prima da 8), due da 11.

| n | Famiglia | F(n) | N(n) | V(n) | L3 città max |
|---|---|---|---|---|---|
| 4–6 | 1 | 0 | 0 | 3 | 1 |
| 7 | 2 | 0 | 0 | 8 | 1 |
| 8 | 2 | 0 | 2 | 8 | 2 |
| 9 | 2 | 2 | 2 | 8 | 2 |
| 10 | 2 | 2 | 2 | 6 | 2 |
| 11 | 2 | 2 | 7 | 9 | 2 |
| 12 | 3 | 4 | 7 | 10 | 2 |

### 2.3 Chi entra da quanti giocatori

| n | Ruoli che entrano da qui |
|---|---|
| 4 | Commissario |
| 5 | Dottore |
| 7 | Sarto, Compare, Cecchino |
| 8 | Cronista, Becchino, Fesso, **Carceriere** |
| 9 | Guardaspalle, Reduce, Sindaco, Portinaio, Cacciatore, **Pacifista, Tiratore scelto, Cupido** (da qui il Cecchino non esce più) |
| 10 | Padrino, Pregiudicato, Messia, Strozzino (poi Artigliere, Presidente) |
| 11 | Piromane (poi Capo della setta) |
| 12 | Sicario, **Prostituta** (prima da 9) |

### 2.4 Classificata e stanze degli amici

Prima decisione del proprietario (28 ottobre): **stesso roster, stesse regole dei livelli** (2.2) in classificata e tra amici, Presidente compreso. **Superata il 29 ottobre per la classificata**: a 12 il mazzo automatico dava Città 28%, Famiglia 48%, neutrali 23%, e la classificata ora ha un mazzo suo (2.6). Le stanze degli amici restano col mazzo automatico. Restano diversi solo il punteggio (OpenSkill per lingua in classificata; XP e monete in tutte e due) e, più avanti, i modi "scegli i ruoli" e "a mano" delle stanze degli amici, che devono comunque rispettare le regole rigide (Famiglia tra 1 e meno della metà del tavolo, sempre un killer, al massimo un L4, al massimo uno che vince col linciaggio, ruoli con chat solo online).

### 2.5 Simulazione del bilanciamento

`tool/balance/simulate.dart` (3000 partite per tavolo; `lib/online/game/deck_balance.dart`): mazzo automatico online, tutti bot del server (`BotBrain`). I bot da soli votano quasi a caso mentre la Famiglia si conosce, e così la Famiglia vince qualunque mazzo; per simulare un tavolo vero al voto ogni non-mafioso, con probabilità 0,3 (il "fiuto"), punta qualcuno della Famiglia. Con questo fiuto il tavolo più semplice (4 giocatori: Picciotto, Commissario, due Onesti) sta alla pari. `test/online/deck_balance_test.dart` rifà una versione corta a ogni `flutter test`.

**Con le regole di 2.2 (ruoli nuovi compresi, Capo della setta e Artigliere compresi):**

| n | Città | Famiglia | Neutrali |
|---|---|---|---|
| 4 | 53% | 47% | 0% |
| 5 | 56% | 44% | 0% |
| 6 | **75%** | 25% | 0% |
| 7 | 25% | **75%** | 0% |
| 8 | 40% | 60% | 0% |
| 9 | 46% | 43% | 11% |
| 10 | 61% | 33% | 7% |
| 11 | 47% | 25% | 29% |
| 12 | 24% | 56% | 20% |

Senza i ruoli nuovi i numeri cambiano di 1–3 punti al massimo (stessa tabella: 4: 50/50, 6: 76/24, 7: 26/74, 8: 39/61, 10: 58/35/7, 11: 51/24/25, 12: 24/54/22), tranne a 11 dove il Capo della setta sposta 4–5 punti dalla Città ai neutrali: i ruoli nuovi non sbilanciano. Nella simulazione l'Artigliere spara un giorno su due dal secondo, col fiuto su uno della Famiglia, se no a caso.

**Con il Tiratore scelto** (dai 9 al posto del Cecchino; 1500 partite per tavolo, con tutti i ruoli nuovi, Capo della setta e Artigliere compresi; il Tiratore di notte mira con lo stesso fiuto a uno della Famiglia, di giorno spara una volta su due): 4: 51/49, 5: 55/45, 6: 76/24, 7: 25/75, 8: 40/60, 9: 50/41/9, 10: 60/34/6, 11: 48/24/28, 12: 23/55/22. Senza nessun ruolo nuovo: 9: 45/43/11, 10: 60/33/7, 11: 52/23/25, 12: 24/57/19. Il Tiratore vince il 57% delle partite in cui c'è (l'Artigliere il 62%, il Cecchino, rimasto ai tavoli da 7 e 8, il 32%): a 9 la Città sale di qualche punto, senza passare il 60%.

**Con la Prostituta al buio** (29 ottobre: non conosce la Famiglia e la Famiglia non conosce lei; 3000 partite per tavolo, `dart run tool/balance/simulate.dart`), Città/Famiglia/Neutrali con i ruoli nuovi: 9: 53/37/11, 10: 65/28/7, 11: 49/22/29, 12: 28/48/23 (prima 9: 50/41/9, 10: 60/34/6, 11: 48/24/28, 12: 23/55/22). Senza i ruoli nuovi (quindi senza Prostituta) non cambia niente: 9: 43/45/11, 10: 60/33/7, 11: 52/23/25, 12: 24/55/21. La Prostituta vince il 24% delle partite in cui c'è (prima il 39%): i bot la fanno bloccare a caso, anche la Famiglia, e la Famiglia può colpirla senza saperlo. La Famiglia perde 4–7 punti dai 9 ai 12; a 10 la Città arriva al 65%, sopra il tetto del 60%.

**La correzione del 10** (29 ottobre, 10000 partite per tavolo). Contare la Prostituta L1 invece di L2 non cambierebbe niente: dai 9 agli 11 la Famiglia ha al massimo un potere (`maxFamilyPowersFor`), e a 12 ogni coppia di poteri sta già nei 4 punti. Il guaio è un altro: con due della Famiglia, se uno è la Prostituta resta un killer solo, che non sa di lei (a 10, con lei, la Città vinceva il 76%). Quindi: **Prostituta da 12** (dove la Famiglia è in tre) e **V(10) da 7 a 6**. Città/Famiglia/Neutrali: 9: 46/44/10 (prima 52/37/10), **10: 59/34/7 (prima 65/29/7)**, 11: 47/24/29 (prima 49/22/29), 12 invariato (29/47/23). Con V(10) a 4 o 5 la Città scende solo di un altro punto, ma il mazzo si riempie di Presidente e Pregiudicato (i ruoli coi punti negativi): non vale la pena.

**Prima della taratura** (regole del documento originale, stesso fiuto): 5: 67/33, 6: 80/20, 7: 26/74, 10: 61/33, **11: 17/67/16**. La taratura ha sistemato 5 (Città 67% → 56%), 8 (Famiglia 62% → 60%, Carceriere e due L3 da 8), 10 e soprattutto 11 (Famiglia 67% → 22%, due della Famiglia invece di tre).

**Vittorie per ruolo** (chi aveva quella carta ha vinto), su tutti i tavoli: Picciotto 49%, Padrino 41%, Sarto 42%, Compare 42%, **Prostituta 39%**, Onesto 50%, Commissario 50%, Dottore 37%, Cecchino 36%, Cronista 47%, Becchino 39%, Guardaspalle 42%, Reduce 48%, Pregiudicato 45%, Messia 47%, Sindaco 45%, Portinaio 42%, **Carceriere 43%**, **Pacifista 46%**, **Cupido 44%**, **Presidente 58%**, **Artigliere 62%**, Fesso 18%, Piromane 20%, Cacciatore 40%, Strozzino 43%, Sicario 17%, **Capo della setta 21%**. Nessun ruolo domina; l'Artigliere è il più forte (due colpi pubblici, da 10 giocatori, dove la Città vince già il 61%): sul tetto del 62% del test, da tenere d'occhio (se sale, alzarlo a 11 giocatori o togliergli un colpo).

**Il limite che resta: 6 e 7 giocatori.** Nella simulazione conta quasi solo quanti uccidono di notte: un mafioso su 6 perde tre volte su quattro, due su 7 vincono tre volte su quattro, qualunque potere abbia la Città (a 6 anche senza nessun ruolo speciale la Città vince il 71%; a 7 col mazzo cittadino più forte possibile, Commissario + Dottore + Cecchino, vince il 26%). Bilanci e livelli non bastano: serve una decisione sul tavolo (sezione 6).

### 2.6 Classificata

La classificata si gioca in **12** (`ranked_size`), ed è quella che deve essere bilanciata meglio. Dal 29 ottobre ha un **mazzo suo a posti fissi** (`rankedRoles` in `lib/rules/role_assignment.dart`). Il server lo usa quando la stanza è classificata e al tavolo sono in 12; un tavolo classificato è sempre di 12, mai più piccolo, per quanto si aspetti.

| Posti | Carte |
|---|---|
| Famiglia (3) | un **Picciotto** e **due poteri diversi** fra Padrino, Sarto, Compare |
| Neutrale (1) | uno fra **Fesso, Cacciatore di taglie, Strozzino** |
| Colpi extra (2) | **Artigliere e Tiratore scelto, sempre tutti e due** |
| Investigatore (1) | uno fra Commissario, Cronista, Becchino, Portinaio |
| Protettore (1) | uno fra Dottore, Guardaspalle, Carceriere |
| Civici (2) | due fra Reduce, Pregiudicato, Messia, Sindaco, Pacifista, Cupido, Presidente |
| Onesti (2) | |

**Fuori dalla classificata:** Piromane, Sicario e Capo della setta: con un assassino in proprio al tavolo la Città scendeva al 22–25%, e in più non potevano esserci né colpi extra né Presidente. Fuori anche la Prostituta (con lei la Città vinceva il 63%, perché non conosce la Famiglia e non vota l'agguato) e il Cecchino (a 12 il colpo extra è del Tiratore). Un ruolo che un telefono al tavolo non sa leggere (`role_builds.dart`) lascia il posto a un altro dello stesso gruppo, o a un Picciotto o a un Onesto.

**Perché così.** Nella simulazione conta quasi solo chi uccide. I poteri della Famiglia e i punti della Città spostano 1–3 punti; i colpi extra e i neutrali ne spostano 10–15. Con un solo colpo extra la Città vinceva il 46% e la Famiglia il 47% (al bordo della fascia); con tutti e due 51/43. L'Artigliere non va toccato: in classificata vince il 50% delle volte che esce. Il 62% di prima veniva dai tavoli da 10, dove la Città vinceva già il 61–65%. Quindi niente colpo in meno.

**Simulazione** (`dart run tool/balance/ranked.dart 50000`: 50000 partite, seme 1, fiuto 0,3; intervallo di confidenza al 95%). **Prima**, col mazzo automatico a 12 (`dart run tool/balance/ranked.dart 50000 1 auto`): **Città 28,4% ± 0,4, Famiglia 48,5% ± 0,4, neutrale da solo 23,1% ± 0,4**. Con la Prostituta la Città saliva al 36–37%, senza scendeva al 21–23%; con Cacciatore e Capo della setta insieme si fermava al 18%. **Adesso:**

| Squadra | vittorie (IC 95%) |
|---|---|
| Città | 50,8% ± 0,4 |
| Famiglia | 43,1% ± 0,4 |
| Neutrale da solo | 6,1% ± 0,2 |

| Ruolo | esce (per partita) | vince quando esce | vittorie sul totale |
|---|---|---|---|
| Picciotto | 1,00 carte | 42,2% ± 0,4 |  |
| Padrino | 66,1% | 42,4% ± 0,5 |  |
| Sarto | 66,8% | 42,1% ± 0,5 |  |
| Compare | 67,1% | 42,4% ± 0,5 |  |
| Onesto | 2,00 carte | 49,6% ± 0,3 |  |
| Commissario | 25,0% | 50,4% ± 0,9 |  |
| Dottore | 33,3% | 50,5% ± 0,8 |  |
| Cronista | 25,2% | 53,1% ± 0,9 |  |
| Becchino | 24,9% | 47,9% ± 0,9 |  |
| Guardaspalle | 33,2% | 47,4% ± 0,8 |  |
| Reduce | 28,4% | 51,8% ± 0,8 |  |
| Pregiudicato | 28,6% | 49,7% ± 0,8 |  |
| Messia | 28,8% | 52,3% ± 0,8 |  |
| Sindaco | 28,4% | 49,1% ± 0,8 |  |
| Portinaio | 24,8% | 47,5% ± 0,9 |  |
| Carceriere | 33,5% | 50,7% ± 0,8 |  |
| Pacifista | 28,8% | 49,6% ± 0,8 |  |
| Cupido | 28,4% | 45,2% ± 0,8 |  |
| Presidente | 28,5% | 50,2% ± 0,8 |  |
| Artigliere | 100% | 49,9% ± 0,4 |  |
| Tiratore scelto | 100% | 49,4% ± 0,4 |  |
| Fesso | 33,4% | 14,5% ± 0,5 | 4,8% ± 0,2 |
| Cacciatore | 33,3% | 36,2% ± 0,7 | 12,1% ± 0,3 |
| Strozzino | 33,3% | 42,3% ± 0,8 | 14,1% ± 0,3 |

Per i neutrali, "vittorie sul totale" è la quota di tutte le partite classificate in cui quel neutrale vince. Lo Strozzino vince con chiunque se è vivo; il Cacciatore chiude la partita con la taglia linciata. Nessun ruolo passa il 54% quando esce, e nessun neutrale il 15% sul totale.

| Composizione | partite | Città | Famiglia | Neutrale |
|---|---|---|---|---|
| Famiglia: Compare + Padrino | 16613 | 50,5% ± 0,8 | 43,6% ± 0,8 | 5,8% ± 0,4 |
| Famiglia: Compare + Sarto | 16948 | 51,0% ± 0,8 | 42,7% ± 0,7 | 6,2% ± 0,4 |
| Famiglia: Padrino + Sarto | 16439 | 50,9% ± 0,8 | 42,9% ± 0,8 | 6,2% ± 0,4 |
| Neutrale: Cacciatore | 16645 | 44,2% ± 0,8 | 37,5% ± 0,7 | 18,3% ± 0,6 |
| Neutrale: Fesso | 16716 | 52,2% ± 0,8 | 47,8% ± 0,8 | 0% |
| Neutrale: Strozzino | 16639 | 56,0% ± 0,8 | 44,0% ± 0,8 | 0% |

Le uniche composizioni fuori media sono quelle del neutrale. Col Cacciatore la Città scende al 44% (lui chiude il 18% di quelle partite); con lo Strozzino sale al 56%. Tutte e tre restano sotto il 60%. I punti della Città spostano poco: da 47/47 con 8 punti a 54/40 con 14.

`test/online/ranked_balance_test.dart` rifà a ogni `flutter test` una simulazione corta (2000 partite, seme fisso) e controlla la fascia: Città 45–55%, Famiglia 40–50%, nessun ruolo sopra il 60% quando esce, nessun neutrale sopra il 15% sul totale. Un ruolo nuovo che entra in classificata deve passarlo.


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
> *Nel codice* (vedi sezione 0). Il Presidente non si colpisce.

- **Squadra:** Città · **Liv.:** L3 · **Da:** 10 · **Categoria:** colpo extra (mai con Cecchino, Tiratore, Piromane, Sicario).
- **Giorno, dal secondo giorno, solo in discussione:** 2 colpi in tutta la partita, uno al giorno. Il bersaglio muore subito (di giorno non ci sono protezioni: niente Dottore, Guardaspalle, Reduce). Al primo colpo la sua carta diventa pubblica per sempre.
- **Interazioni:** colpire un innamorato uccide anche l'altro. Sparare alla taglia del Cacciatore: la taglia scade. Il Pacifista non lo ferma. Il Sarto non lo ferma. Dopo il primo colpo, Dottore e Carceriere hanno un motivo per coprirlo.
- **Chi vede cosa:** tutti: chi ha sparato (dal primo colpo), chi è morto e il suo ruolo (come un linciato). Lui: colpi rimasti.
- **Testi:** «Fuoco!» (bottone) · «Un boato in piazza: l'Artigliere ha colpito Tizio.» · «Ti resta un colpo.» · motto: «Io non sussurro. Io tuono.»

### 3.6 Il Tiratore scelto — `tiratoreScelto`
> Meccanica confermata dal proprietario. *Nel codice:* compito notturno `aim` (non è una visita; passare tiene la mira; il Presidente non si mira), intenzione `Shoot` di giorno (il server la accetta solo in discussione, come la tregua), `ShotReport` pubblico in `PublicView.lastShot` (il morto e il suo ruolo; il bersaglio salvato da un colpo tornato indietro non si dice), mira e colpi solo nella vista del Tiratore (`PlayerView.aim`, `shotsLeft`). Un colpo al giorno (la mira si consuma). Nel giorno della tregua non si spara. Il morto finisce tra i `dayVictims` del giro; il colpo può chiudere la partita. Build 66.
> *Telefono unico:* in discussione il bottone «Colpo del Tiratore» finché restano colpi (resta anche se il Tiratore è morto, sennò il tavolo lo saprebbe); il Tiratore tocca il proprio volto, vede chi ha nel mirino, «Fuoco!»; poi il narratore legge chi è caduto e la sua carta. Al suo turno di notte legge «Nel mirino: Tizio».

- **Squadra:** Città · **Liv.:** L3 · **Da:** 9 · **Categoria:** colpo extra.
- **Notte:** mette nel mirino una persona (non conta come visita per il Portinaio). Il mirino resta finché non lo cambia.
- **Giorno, in discussione:** spara al bersaglio nel mirino, oppure non fa niente (lo cambierà la notte). 2 colpi in tutta la partita.
- **Se colpisce un cittadino** (squadra vera Città, Pregiudicato compreso): muore lui al posto del bersaglio, che resta vivo. Se colpisce Famiglia (Padrino compreso) o un neutrale, il bersaglio muore.
- **Anonimato:** lo sparo è pubblico ma il tiratore resta anonimo, finché non muore per errore (allora la sua carta è pubblica).
- **Interazioni:** si sposa con il Commissario (indaga e spara). In cella o bloccato dalla Prostituta: quella notte non cambia mira, ma il giorno dopo può sparare alla mira vecchia. Colpo di giorno: niente protezioni.
- **Chi vede cosa:** lui: mira attuale, colpi rimasti. Tutti: «Un colpo dal campanile» e il morto col suo ruolo.
- **Testi:** «Chi tieni nel mirino?» · «Spari a Tizio?» · «Il colpo ti torna indietro: era uno della Città.» · motto: «Un respiro, un colpo, un nome.»
- **Nota:** decisione del proprietario: il Cecchino resta per i tavoli piccoli, il Tiratore per quelli grandi.

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
Decisione del proprietario: **vince con la Famiglia, ma non sa chi sono** (29 ottobre; prima si conoscevano). Anche in locale: chi è stato bloccato lo legge al suo turno della notte dopo.
- **Squadra:** Famiglia · **Liv.:** L2 · **Da:** 9 · **Categoria:** potere di Famiglia (conta in `maxFamilyPowersFor`).
- **Notte:** passa la notte con una persona (mai la stessa due notti di fila): l'azione di quella persona è annullata (una mossa da una volta sola, come lo scoop, è spesa lo stesso). Può scegliere chiunque, anche uno della Famiglia (non sa chi sono): un killer bloccato non vota l'agguato (se era l'unico, niente agguato). Non vota l'agguato finché nella Famiglia c'è un altro che lo vota; se resta l'ultima, legge «Sei rimasta l'ultima della Famiglia: ora la notte è tua», vota l'agguato e può ancora, al suo posto, passare la notte fuori. Anche allora non entra nella chat della Famiglia e dei morti sa solo quello che è pubblico (`GameEngine.isLastOfFamily`).
- **Interazioni:** blocca Commissario, Dottore, Guardaspalle, Becchino, Portinaio, Cronista (lo scoop è speso), Messia (spesa), Tiratore (mira), Piromane, Sicario, Capo della setta, Strozzino. Non blocca Cupido (prima notte) né i poteri di giorno. Non sblocca la cella. Conta come visita per il Portinaio. In cella non agisce.
- **Chi vede cosa:** Prostituta: il nome scelto, e sulla carta *«Lavori per la Famiglia, ma non sai chi sia»*; nessun complice, nessuna mano della Famiglia, non sa chi della Famiglia è in cella. Famiglia: niente su di lei (non è tra i complici, non sa se è in cella, non vede chi ha scelto). Commissario: della Famiglia, come prima. Bloccato, all'alba: *«Stanotte qualcuno ti ha tenuto occupato.»*
- **Voce/chat:** niente chat né voce della Famiglia, mai (`RoleInfo.knowsFamily`; sul server `family: false` nei diritti della chat, quindi niente stanza `family` in `voice_rules.ts`).
- **Testi:** «Per chi canti stanotte?» · «Stanotte qualcuno ti ha tenuto occupato.» · motto: «Una canzone, un bicchiere, e la notte vola.»

### 3.11 Esclusi dal proprietario
Setacciatore (cacciatore di setta), Hacker.

---

## 4. Canali di voce e chat (con i nuovi)

| Canale | Chi scrive | Chi parla (push-to-talk) | Quando | Note |
|---|---|---|---|---|
| Piazza (`day`) | Vivi, tranne il silenziato dal Sarto | Vivi, tranne il silenziato | Giorno | Il silenzio deve spegnere anche la voce |
| Famiglia (`family`) | Famiglia viva, tranne chi è in cella | Idem | Notte (e giorno con il Compare) | Mai la Prostituta (non sa chi sono). *Nel codice.* |
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
3. **Telefono unico:** le risposte all'alba arrivano al turno della notte dopo (vedi 3.1): il Commissario con un Carceriere o una Prostituta al tavolo gioca la piazza senza la risposta della notte. Va bene, o si preferisce un passaggio di telefono privato all'alba?
4. **Indagini all'alba:** con un Carceriere o una Prostituta nel mazzo il Commissario e il Becchino ricevono la risposta all'alba invece che subito (sennò il blocco non bloccherebbe niente). Va bene così, o la risposta resta immediata e il blocco ferma solo le mosse che si risolvono all'alba?
5. **Pacifista:** la tregua si chiede solo in discussione (non durante il voto). Va bene?
6. **Cittadini speciali:** vale il 40% del documento o i due terzi del codice? (il codice resta ai due terzi)
7. **Sindaco:** voto doppio solo quel giorno (motore) o da lì in poi (testo)?
8. **Guardaspalle e fuoco:** muore lui al posto del cosparso o il fuoco non si ferma?
9. **Stanze degli amici:** il mazzo "a mano" può infrangere i bilanci con solo un avviso?
