# Ruoli: roster, livelli di potere, ruoli nuovi (28 ottobre 2026)

Documento di progetto, nessun codice cambiato. Base: `lib/rules/role.dart`, `lib/rules/role_assignment.dart`, `lib/rules/game_engine.dart`, `lib/narration/italian_pack.dart`, `docs/ruoli-analisi.md` (regole di risoluzione già fissate). I numeri di bilanciamento sono valori iniziali, da tarare con la simulazione (`test/rules/new_neutrals_test.dart`).

Nomi dei ruoli nuovi: quelli che i giocatori conoscono dal genere (regola del proprietario, 28 ottobre 2026); l'ambientazione anni Quaranta passa solo per illustrazioni e motti.

Legenda livelli: **L0** nessun potere (o malus), **L1** base, **L2** medio, **L3** forte, **L4** super. Punti: L0 = 0, L1 = 1, L2 = 2, L3 = 3, L4 = 5 (il salto da 3 a 5 è voluto: un L4 pesa per due).

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
| Il Sicario | `sicario` | Neutrale ostile | Uccide ogni notte; risulta della Famiglia | 12 | L3 | Ok, fermabile da protezioni. |

**Altre incoerenze trovate**
- `ruoli-analisi.md` dice "cittadini speciali al massimo il 40%", il codice (`maxSpecialCitizensFor`) usa due terzi. Va deciso quale vale.
- Il mazzo oggi conta solo categorie e tetti, non la forza: a 8 giocatori può uscire Commissario + Dottore + Cronista (8 punti) contro 2 Picciotti senza poteri.

---

## 2. Sistema a livelli e bilanciamento

### 2.1 Livelli dei ruoli (esistenti + nuovi)

| Liv. | Città | Famiglia (poteri) | Neutrali |
|---|---|---|---|
| L0 | Onesto (0), Pregiudicato (−1), Presidente (−2, variante) | Picciotto (base) | — |
| L1 | Becchino, Reduce, Sindaco, Portinaio, Cupido | Compare | Fesso, Strozzino |
| L2 | Dottore, Cecchino, Cronista, Guardaspalle, Messia, Pacifista | Padrino, Sarto, Prostituta | Cacciatore di taglie |
| L3 | Commissario, Carceriere, Artigliere, Tiratore scelto | — | Sicario |
| L4 | — | — | Piromane, Capo della setta |

### 2.2 Regole del mazzo (classificata e mazzo automatico)

Restano tutte quelle di oggi (`mafiaCountFor`, `maxFamilyPowersFor`, tetti per categoria, `neutralFits`, Compare solo online). Si aggiungono:

1. **Bilancio della Città** `V(n)`: somma dei punti dei cittadini speciali ≤ `V(n)`. Con un neutrale L4 al tavolo, `V(n)` +1.
2. **Bilancio della Famiglia** `F(n)`: punti dei poteri di Famiglia ≤ `F(n)`.
3. **Bilancio neutrali** `N(n)`: punti dei neutrali ≤ `N(n)`.
4. **Al massimo un L4 per tavolo**, e solo da 11 giocatori.
5. **L3 della Città:** al massimo uno sotto i 9 giocatori, due da 9.
6. **Colpo extra** (Cecchino, Artigliere, Tiratore): uno solo, e mai con Piromane o Sicario (come oggi).
7. **Contrappeso:** da 7 giocatori, se la Città usa almeno `V(n) − 1` punti, la Famiglia riceve almeno un potere (se ce n'è uno ammesso).
8. **Sempre qualcuno che uccide** nella Famiglia: Compare e Prostituta non votano l'agguato.

### 2.3 Tabella per numero di giocatori (con i ruoli nuovi)

| n | Famiglia | Poteri fam. (F) | Neutrali (N) | Speciali città max | V(n) | Ruoli che entrano da qui | Mazzo d'esempio |
|---|---|---|---|---|---|---|---|
| 4 | 1 | 0 | 0 | 2 | 3 | Commissario | Picciotto · Commissario · 2 Onesti |
| 5 | 1 | 0 | 0 | 2 | 5 | Dottore | Picciotto · Commissario, Dottore · 2 Onesti |
| 6 | 1 | 0 | 0 | 3 | 5 | — | Picciotto · Commissario, Dottore · 3 Onesti |
| 7 | 2 | 2 | 0 | 3 | 5 | Sarto, Compare, Cecchino | Picciotto, Sarto · Commissario, Dottore · 3 Onesti |
| 8 | 2 | 2 | 1 (≤2) | 4 | 6 | Cronista, Becchino, Fesso, **Carceriere** | 2 Picciotti · Fesso · Carceriere, Dottore, Becchino · 2 Onesti |
| 9 | 2 | 2 | 1 (≤2) | 4 | 7 | Guardaspalle, Reduce, Sindaco, Portinaio, Cacciatore, **Prostituta, Pacifista, Tiratore, Cupido** | Picciotto, Prostituta · Cacciatore · Commissario, Guardaspalle, Pacifista · 3 Onesti |
| 10 | 2 | 2 | 1 (≤2) | 5 | 8 | Padrino, Pregiudicato, Messia, Strozzino, **Artigliere, Presidente (variante)** | Padrino, Picciotto · Strozzino · Carceriere, Dottore, Reduce, Sindaco · 3 Onesti |
| 11 | 3 | 4 | 2 (≤7, un solo L3/L4) | 5 | 9 | Piromane, **Capo della setta** | Picciotto ×2, Sarto · Capo della setta, Fesso · Commissario, Dottore, Tiratore · 3 Onesti |
| 12 | 3 | 4 | 2 (≤7, un solo L3/L4) | 6 | 10 | Sicario | Picciotto, Padrino, Prostituta · Sicario, Strozzino · Carceriere, Commissario, Guardaspalle, Portinaio · 3 Onesti |

Nota: a 11–12 con un L4 il bilancio città sale a 10/11. "Speciali città max" include i neutrali (come oggi `maxSpecialCitizensFor`).

### 2.4 Classificata contro stanze degli amici

| | Classificata | Stanza degli amici |
|---|---|---|
| Mazzo | Sempre automatico, con seme, regole 2.2 tutte rigide | Tre modi: **automatico**; **scegli i ruoli** (l'host spegne/accende ruoli, il generatore pesca solo da quelli rispettando i bilanci); **a mano** (l'host compone il mazzo esatto) |
| Ruoli ammessi | Solo ruoli "collaudati" (vedi batch); niente varianti (Presidente) | Tutti, varianti comprese |
| Regole rigide anche a mano | — | Famiglia tra 1 e meno della metà del tavolo; almeno un killer in Famiglia; al massimo un L4; al massimo uno che vince col linciaggio; Compare (e chat di cella, innamorati, setta) solo online |
| Bilanci | Rigidi | Solo avviso: barra "Città 9/8 · Famiglia 2/2" e la scritta *«Mazzo sbilanciato: la Città è favorita.»* L'host può giocare lo stesso |
| Punteggio | OpenSkill per lingua | Solo XP e monete (come oggi) |

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
- **Interrogatorio:** chat privata `cella` tra Carceriere e prigioniero per tutta la notte. Il prigioniero vede solo "Il Carceriere", mai il nome. Solo testo, niente voce (la voce lo tradirebbe).
- **Interazioni:** Picciotto/Padrino/Sarto in cella non votano l'agguato e non vedono la chat della Famiglia quella notte; se il prigioniero è l'unico killer, niente agguato. Messia, Piromane, Sicario, Capo della setta, Strozzino, Prostituta in cella: azione annullata. Dottore o Guardaspalle sul prigioniero: inutili (nessun colpo da assorbire). La Prostituta che blocca il Carceriere non libera il prigioniero (la cella viene prima). Conta come visita per il Portinaio.
- **Telefono unico:** cella senza chat (blocca e protegge, basta).
- **Chi vede cosa:** Carceriere: nome del prigioniero e chat. Prigioniero: *«Sei in cella.»* e la chat anonima. Famiglia (se il prigioniero è dei loro): *«Stanotte Tizio è in cella.»* Gli altri: niente; all'alba nessun annuncio.
- **Testi:** «Chi chiudi in cella stanotte?» · «Sei in cella. Stanotte non esci.» · «Il Carceriere vuole parlarti.» · motto: «Qui dentro si parla. Fuori si muore.»

### 3.2 Il Pacifista — `pacifista`
- **Squadra:** Città · **Liv.:** L2 · **Da:** 9 · **Categoria:** civico.
- **Giorno, una volta per partita, solo in discussione:** sceglie una persona (non sé). Tutti vedono il **ruolo esatto** di quella persona e la carta del Pacifista diventa pubblica. Il voto di quel giorno è annullato.
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
- **Nota:** con Artigliere e Tiratore il Cecchino diventa il colpo extra "da tavolo piccolo" (7–8 giocatori).

### 3.7 Cupido — `cupido`
- **Squadra:** Città · **Liv.:** L1 · **Da:** 9 · **Categoria:** civico.
- **Prima notte (sola azione):** lega due persone (può includere se stesso). Non bloccabile, non è una visita.
- **Innamorati:** ognuno sa il **nome** dell'altro, non il ruolo. Tengono la loro squadra e in più hanno una vittoria personale: vincono se sono **vivi tutti e due a fine partita**, chiunque vinca (come lo Strozzino). Se uno muore (notte, linciaggio, colpo di giorno) l'altro muore subito di crepacuore: niente lo ferma, e il crepacuore viene prima del controllo dei vincitori.
- **Interazioni:** Famiglia innamorata di un cittadino: se la Famiglia uccide l'amato, muore anche il suo. Messia che riporta un innamorato: torna solo lui e il legame si spezza. Becchino sul morto di crepacuore: ruolo esatto. Il Capo della setta che converte un innamorato non converte l'altro.
- **Voce/chat:** chat `innamorati` solo testo, solo di notte, solo online.
- **Chi vede cosa:** Cupido: i due nomi. Ognuno dei due: *«Sei innamorato di Tizio.»* Gli altri: niente; alla morte per crepacuore tutti leggono *«Caio è morto di crepacuore.»*
- **Testi:** «Chi fai sposare?» · «Il cuore ha scelto: sei innamorato di Tizio.» · motto: «Due cuori, una dote, nessuna via d'uscita.»

### 3.8 Il Presidente — `presidente`
Diverso dal Sindaco: il Sindaco è segreto e si rivela per un voto doppio; il Presidente è pubblico da subito ed è un punto debole della Città.
- **Squadra:** Città · **Liv.:** L0 (−2: è una debolezza per la Città) · **Da:** 10 · **Solo variante** (stanze degli amici, mai in classificata).
- **Pubblico dall'inizio:** tutti sanno chi è. Non si può votare (non si lincia lo Stato).
- **Se muore, la Città perde:** vince la Famiglia (se ci sono Famiglia viva o neutrali ostili; mai insieme a Piromane o Sicario, per evitare vincitori ambigui).
- **La scorta**, sennò la Famiglia lo uccide la prima notte e la partita è finita: i primi **due** agguati contro di lui falliscono (*«La scorta ha respinto un attentato.»*, pubblico). Dottore, Guardaspalle e Carceriere lo coprono come chiunque.
- **Chi vede cosa:** tutti: nome, ruolo, colpi di scorta rimasti.
- **Testi:** motto: «Lo Stato non tratta.» · «Il Presidente è caduto. La città è perduta.»

### 3.9 Il Capo della setta — `capoSetta`
- **Squadra:** Neutrale ostile (conta come Piromane e Sicario: uno solo, finché è vivo la Città non vince) · **Liv.:** L4 · **Da:** 11 (massimo del tavolo 12) · **Mai** con Piromane o Sicario.
- **Notte:** converte una persona alla setta. I convertiti tengono ruolo e poteri ma vincono solo con la setta. **Vince da solo** (con tutti i convertiti) quando tutti i vivi sono della setta.
- **Chi non si converte:** la Famiglia (tutta), Piromane, Sicario, Presidente. Su di loro la conversione fallisce e il Capo della setta legge *«Porta chiusa.»* (scopre che è uno "non convertibile", ma non chi è). Quindi la setta vince solo se la Famiglia è morta: il Capo della setta vive dei linciaggi della Città.
- **Contrasti:** il Dottore e lo Strozzino sul bersaglio fermano la conversione (la cura); il Guardaspalle no (non c'è morte da prendere). La cella e la Prostituta la fermano. Il linciaggio del Capo della setta **scioglie la setta**: i convertiti tornano alla loro squadra, nessuno muore.
- **Investigazioni:** il Capo della setta e i convertiti al Commissario risultano onesti (la setta non è la Famiglia). Il Cronista scrive «della Setta». Il Becchino legge ruolo e «(della Setta)». Il Portinaio conta la conversione come visita.
- **Voce/chat:** chat `setta` solo testo, di notte, solo online. Sul telefono unico il Capo della setta è vietato (troppe sveglie private).
- **Chi vede cosa:** Capo della setta: elenco dei convertiti. Convertito: *«Ora sei della setta.»* e i nomi degli altri. Gli altri: niente.
- **Testi:** «Chi chiami alla luce stanotte?» · «Hai visto la luce. Ora sei della setta.» · motto: «Non vi chiedo di credere. Vi chiedo di seguirmi.»

### 3.10 La Prostituta — `prostituta`
Proposta: **della Famiglia**, perché la Città ha già il Carceriere come bloccatore e la Famiglia ha pochi poteri contro i ruoli nuovi.
- **Squadra:** Famiglia · **Liv.:** L2 · **Da:** 9 · **Categoria:** potere di Famiglia (conta in `maxFamilyPowersFor`).
- **Notte:** passa la notte con una persona (mai la stessa due notti di fila): l'azione di quella persona è annullata. Non vota l'agguato (come il Compare: ci vuole un altro killer).
- **Interazioni:** blocca Commissario, Dottore, Guardaspalle, Becchino, Portinaio, Cronista (lo scoop è speso), Messia (spesa), Tiratore (mira), Piromane, Sicario, Capo della setta, Strozzino. Non blocca Cupido (prima notte) né i poteri di giorno. Non sblocca la cella. Conta come visita per il Portinaio. In cella non agisce.
- **Chi vede cosa:** Prostituta: il nome scelto. Famiglia: chi ha scelto (nella chat). Bloccato, all'alba: *«Stanotte qualcuno ti ha tenuto occupato.»*
- **Voce/chat:** chat e voce della Famiglia, come gli altri.
- **Testi:** «Per chi canti stanotte?» · «Stanotte qualcuno ti ha tenuto occupato.» · motto: «Una canzone, un bicchiere, e la notte è passata.»

### 3.11 Esclusi dal proprietario
Setacciatore (cacciatore di setta), Hacker.

---

## 4. Canali di voce e chat (con i nuovi)

| Canale | Chi scrive | Chi parla (push-to-talk) | Quando | Note |
|---|---|---|---|---|
| Piazza (`day`) | Vivi, tranne il silenziato dal Sarto | Vivi, tranne il silenziato | Giorno | Il silenzio deve spegnere anche la voce |
| Famiglia (`family`) | Famiglia viva, tranne chi è in cella | Idem | Notte (e giorno con il Compare) | Anche la Prostituta |
| Cella (`jail`, nuovo) | Carceriere (anonimo) e prigioniero | Nessuno | Notte | Solo online |
| Innamorati (`lovers`, nuovo) | I due innamorati | Nessuno | Notte | Solo online |
| Setta (`sect`, nuovo) | Capo della setta e convertiti | Nessuno | Notte | Solo online |
| Eventi (`event`) | Server | — | Sempre | Righe private per seggio dove serve |

**Anti-trucco:** come oggi, ogni seggio riceve solo ciò che `viewFor` gli concede; i canali nuovi vanno filtrati dal server (il nome del Carceriere non deve mai arrivare al telefono del prigioniero, nemmeno nei dati della chat).

---

## 5. Ordine di lavoro proposto

| Batch | Contenuto | Perché prima |
|---|---|---|
| 1 | Campo `tier` in `RoleRule`, bilanci V/F/N in `rolesForPlayerCount`; correzione testi Compare, Messia, Sindaco; Cacciatore "ora sei un Onesto"; regola unica Guardaspalle/fuoco; silenzio anche sulla voce | Nessun ruolo nuovo, solo ordine |
| 2 | **Prostituta + Carceriere**: passo di blocco e cella nella notte, canale `jail` | Stessa infrastruttura (azione annullata); si contrastano a vicenda |
| 3 | **Pacifista + Artigliere**: azioni di giorno in discussione | Stessa infrastruttura (bottone di giorno, effetto pubblico) |
| 4 | **Tiratore scelto** | Usa mira di notte + colpo di giorno (batch 2 e 3) |
| 5 | **Cupido**: legame, crepacuore, canale `lovers` | Tocca il controllo dei vincitori |
| 6 | **Capo della setta**: conversione, setta, canale `sect`, scioglimento | Il più complesso; serve simulazione dedicata |
| 7 | **Presidente** come variante | Solo stanze degli amici |
| 8 | Stanze degli amici: "scegli i ruoli" e "a mano" con barra dei bilanci; elenco ruoli ammessi in classificata | Serve avere i ruoli |

Per ogni batch: testi IT/EN in `italian_pack.dart`/`english_pack.dart`, voci di ogni frase nuova (`tool/voice/regenerate.sh`, Kokoro im_nicola/am_adam, 0.86, effetto godfather), icone dei ruoli (`docs/ruoli-icone.md`), test in `test/rules/interactions_test.dart`, simulazione 300 partite, e aggiornamento del sito `site/oberta`. Ogni ruolo entra in classificata solo dopo un batch di prova nelle stanze degli amici.

---

## 6. Domande aperte per il proprietario

1. **Prostituta:** della Famiglia (proposta) o della Città?
2. **Carceriere:** la cella ferma anche il fuoco (proposta: sì)? Deve poter giustiziare il prigioniero (diventerebbe L4)?
3. **Pacifista:** svela il ruolo esatto (proposta) o solo la fazione?
4. **Artigliere:** di giorno (proposta) o di notte? Primo colpo dal secondo giorno ok?
5. **Tiratore:** sparare a un neutrale è "giusto" (proposta: sì, solo i cittadini lo fanno morire)?
6. **Cupido:** gli innamorati tengono la loro squadra più una vittoria personale (proposta), o diventano una squadra a parte che vince solo se restano gli ultimi due?
7. **Presidente:** ok come variante solo tra amici, con la scorta da due agguati e non linciabile?
8. **Capo della setta:** il linciaggio scioglie la setta senza morti (proposta) o la setta muore con lui? Il Commissario deve vedere i convertiti?
9. **Cecchino:** resta per i tavoli piccoli o lo sostituiamo con il Tiratore?
10. **Cittadini speciali:** vale il 40% del documento o i due terzi del codice?
11. **Sindaco:** voto doppio solo quel giorno (motore) o da lì in poi (testo)? (domanda già aperta)
12. **Guardaspalle e fuoco:** muore lui al posto del cosparso o il fuoco non si ferma?
13. **Stanze degli amici:** il mazzo "a mano" può infrangere i bilanci con solo un avviso (proposta)?
