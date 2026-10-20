# Ruoli: codice attuale contro la specifica (17 ottobre 2026)

## Oggi nel codice
- Fazioni: solo cittadini e mafia; la mafia vince alla parità, i cittadini quando non c'è più mafia.
- Picciotto vota l'agguato. Padrino: risulta cittadino all'indagine; con `TieBreak.boss` vale doppio negli spareggi. Sarto: silenzia OGNI notte (mai la stessa persona due notti di fila), non vota l'agguato, fa l'agguato se è l'ultimo che può uccidere.
- Onesto, Commissario (fazione apparente), Dottore (mai stessa persona due notti), Cecchino (1 colpo), Cronista (1 scoop pubblico), Becchino (ruolo esatto di un morto, in privato), Guardaspalle (muore al posto del protetto), Reduce (sopravvive al primo agguato), Pregiudicato (risulta mafia).
- Mazzo fisso: mafia = max(1, giocatori/4); Padrino da 8, Sarto da 10; Commissario 4, Dottore 5, Cecchino 7, Cronista e Becchino 8, Reduce 9, Guardaspalle 10, Pregiudicato 11; il resto Onesti.
- Timer: telefono unico discussione 3 min (`lib/rules/game_settings.dart`); online discussione 2 min, notte 120 s (prima 180), voto 60 s (`OnlinePacing` in `lib/online/game/game_authority.dart`).

## Differenze con la specifica
- Sarto ogni notte invece che una volta per partita; silenzio non fatto rispettare (manca la chat).
- Padrino da 8 giocatori invece che solo nelle partite grandi; `TieBreak.boss` è un voto doppio vietato.
- Padrino e Sarto sempre insieme: a 10–11 giocatori la famiglia è solo loro due.
- Troppi ruoli speciali: a 10–11 giocatori un solo Onesto, a 16 solo 4.
- Due protettori (Dottore, Guardaspalle) e tre investigatori (Commissario, Cronista, Becchino) insieme.
- Mancano Compare, Fesso, Piromane, Messia, Sindaco, Portinaio, investigatore mafioso, fazioni neutrali, vittorie personali, resurrezioni.
- Voti della famiglia già calcolati solo per i mafiosi (`familyVotes`) ma non mostrati da nessuna schermata.
- Timer diversi dalla specifica (30 / 60 / 30).

## Lavoro necessario, in ordine
A. Motore: Sarto una volta per partita (nello snapshot), togliere `TieBreak.boss`, silenziato nella vista.
B. Mazzo: regole per ruolo (soglia, copie massime, categoria, modalità), mafia proporzionale, tetto ai cittadini speciali, almeno metà Onesti, pesca casuale nei vincoli, mai Padrino + Sarto + Compare.
C. Timer configurabili in `GameSettings` (30/60/30), online e telefono unico.
D. Chat online secondo le regole, permessi decisi dal motore (`viewFor`), pannello famiglia con `familyVotes`.
E. Fazioni neutrali e vittorie personali (Fesso, Piromane), Messia, Sindaco, Portinaio: lavoro grosso, dopo.
F. Testi IT/EN dei ruoli nuovi e voci (`tool/voice/regenerate.sh`).

## Fatto (18 ottobre 2026): fasi A, B, C e il Compare
- A: Sarto una volta per partita (`silenceSpent` nello snapshot), `TieBreak.boss` tolto, `silenced` e `familyChat` nella vista (`viewFor`); il server passa i permessi della chat dal motore.
- B: regole per ruolo in `Role.rule` (soglia, copie, categoria, modalità) e pesca in `rolesForPlayerCount` (`lib/rules/role_assignment.dart`).
- C: `GameSettings` con notte, discussione e voto; `OnlinePacing` usa gli stessi valori.
- Compare: ruolo mafioso solo online; migrazione `20261018123417_compare_family_day_chat.sql`.

## Decisioni provvisorie (il proprietario può cambiarle)
- Sarto: un solo silenzio a partita, usabile dalla prima notte. Ogni notte vota l'agguato come un Picciotto; la notte in cui cuce non vota (sceglie tra le due cose, che ci siano altri sicari o che sia l'ultimo). Il silenziato legge, vota e agisce, ma non scrive nella chat della piazza per quel giorno.
- Padrino: da 10 giocatori, una copia. Nessun voto doppio: gli spareggi della famiglia sono sorteggio o nessuno.
- Famiglia: 1 mafioso da 3 a 6 giocatori, 2 da 7 a 10, 3 da 11 a 14, 4 a 15–16. Ruoli di potere (Padrino, Sarto, Compare): al massimo uno sotto gli 11 giocatori, due da 11, quindi mai tutti e tre; ognuno entra con probabilità 1/2. Sempre almeno un mafioso che vota l'agguato.
- Soglie: Commissario 4, Dottore 5, Sarto 7, Compare 7, Cecchino 7, Cronista 8, Becchino 8, Guardaspalle 9, Reduce 9, Padrino 10, Pregiudicato 10. Una copia per ruolo (Picciotti e Onesti a volontà).
- Categorie: investigatori Commissario, Becchino, Cronista; protettori Dottore, Guardaspalle; colpo extra Cecchino; passivi Reduce, Pregiudicato. Al massimo un investigatore e un protettore sotto i 12 giocatori, due da 12; un solo colpo extra.
- Cittadini speciali al massimo il 40% dei cittadini (arrotondato per difetto), quindi almeno metà Onesti. Si pesca prima un investigatore, poi un protettore, poi il resto a caso; con un seme il mazzo è sempre lo stesso.
- Compare: solo online, mai nel mazzo del telefono unico. Nessun potere di notte (non vota l'agguato); finché è vivo la famiglia ha la chat privata anche di giorno, fatta rispettare dal server. Se resta l'unico mafioso la famiglia non uccide più.
- Timer: notte 30 s (anche la prima), discussione 60 s, voto 30 s, uguali online e sul telefono unico (dove si usa solo la discussione).

- Neutrali: `Team.neutral`, vittorie personali (`GameEngine.personalWins`, `hasWon`, `PublicView.personalWins`). Chi vince da solo conta come vittoria per XP e punteggio (`won` nel risultato del server). Il Commissario vede i neutrali come onesti; lo scoop scrive la fazione vera (neutrale).
- Parità con neutrali vivi: la mafia vince quando i mafiosi vivi sono almeno quanti i non mafiosi (i neutrali contano come non mafiosi). La città vince quando non c'è più mafia né un Piromane vivo.
- Fesso: da 8 giocatori, una copia. Vince da solo se la piazza lo lincia (non se muore di notte); la partita continua senza di lui. Di notte fa il compito di copertura.
- Piromane: da 13 giocatori, una copia, mai con il Cecchino. Ogni notte cosparge qualcuno (non se stesso, non chi è già cosparso) oppure accende (sceglie se stesso): bruciano tutti i cosparsi vivi. Il fuoco passa per il Dottore, il Guardaspalle e il Reduce come ogni agguato. Chi è cosparso lo sa solo il Piromane. Vince da solo solo se resta l'ultimo vivo (regola del proprietario, 19 ottobre 2026); finché è vivo la città non vince.
- Neutrali nel mazzo: entrano prima degli altri speciali, ognuno con probabilità 1/2, al posto di un cittadino speciale; al massimo due (quindi il Fesso mai con più di un altro neutrale).
- Messia: da 10 giocatori, una copia. Una volta per partita, di notte, sceglie un cittadino linciato (mai un mafioso; il ruolo è già pubblico). Se il Messia vede l'alba il prescelto torna in vita con il suo ruolo e i poteri già spesi restano spesi; se muore quella notte la resurrezione fallisce ed è comunque spesa. Si applica prima del controllo dei vincitori. Il suo compito di notte non conta come visita per il Portinaio.
- Sindaco: da 9 giocatori, una copia. Una volta per partita, durante il voto di giorno, si rivela (`RevealMayor`): il ruolo diventa pubblico e per il voto di quel giorno vale due. Sul telefono unico il narratore condanna di persona, quindi il voto doppio lo conta il tavolo.
- Portinaio: da 9 giocatori, una copia, investigatore. Ogni notte guarda una porta e all'alba sa solo se qualcuno ci è passato: contano le mosse vere su quel bersaglio (agguato, protezione, scorta, indagine, colpo, scoop, silenzio, benzina, un altro Portinaio); non contano il compito di copertura, il fiammifero, lo scavo e la resurrezione. Lo legge la notte dopo, sopra la sua scelta.
- Categorie: Messia e Sindaco sono "civici" (nessun tetto oltre la copia); Portinaio conta tra gli investigatori.

## Neutrali nuovi (19 ottobre 2026): Cacciatore di taglie, Strozzino, Sicario
Riferimento Wolvesville: nelle partite rapide a 16 ci sono 4 lupi, 1 solitario assassino, 1 solitario "da voto", 1 ruolo che cambia squadra e 9 paesani. Da lì le regole: mai due assassini in proprio, mai due che vincono col linciaggio.
- Cacciatore di taglie (Headhunter): da 9 giocatori, entrambe le modalità. All'inizio il motore tira a sorte (col seme) un cittadino come taglia; la vede solo lui (`PlayerView.bounty`, nelle note della notte). Se la taglia viene linciata mentre lui è vivo vince da solo (`LynchReport.bountyHunter`), la sua carta diventa pubblica e la partita finisce (vince anche lo Strozzino vivo). Se la taglia muore in altro modo passa con la città: vince se vince lei (`bountyLapsed`). Di notte fa il compito di copertura; il bot vota la sua taglia.
- Strozzino: da 10 giocatori, entrambe le modalità. Ogni notte presta a qualcuno (non se stesso, mai lo stesso due notti di fila): quel debitore stanotte non muore, come col Dottore (conta come visita per il Portinaio). Vince se è vivo a fine partita, chiunque vinca; non blocca nessuna vittoria. Al Commissario risulta onesto.
- Sicario (Serial Killer): da 14 giocatori, entrambe le modalità. Ogni notte uccide qualcuno (`AttackSource.assassin`, raccontato come un omicidio qualunque); Dottore, Strozzino, Guardaspalle e Reduce lo fermano come ogni agguato. Al Commissario risulta della famiglia. Ostile come il Piromane: finché è vivo la città non vince, vince lui se resta da solo o con un altro.
- Mazzo (`neutralFits`): neutrali al massimo 2 fino a 13 giocatori, 3 da 14 (`maxNeutralsFor`); al massimo un assassino in proprio (Piromane o Sicario) e mai col Cecchino; al massimo uno che vince col voto (Fesso o Cacciatore); con il Fesso al massimo un altro neutrale. Minimo invariato (`minNeutralsFor`: 1 da 8, 2 da 11). A 12: 3 famiglia, 2 neutrali, fino a 4 speciali, almeno 2 Onesti.
- Simulazione a mosse casuali (300 partite, 9–16 giocatori, test `test/rules/new_neutrals_test.dart`): mafia 215, città 64, neutrale (Piromane/Sicario) 21; vittorie personali: Strozzino 36, Fesso 29, Cacciatore 23, Sicario 11, Piromane 10. Le mosse a caso premiano la mafia (la piazza lincia alla cieca); i neutrali restano sotto il 10% delle vittorie di partita.
- Schermo finale: "Vince un cane sciolto" per qualunque assassino in proprio; il narratore ha finali e battute proprie per Sicario e Cacciatore, con le voci registrate.

## Regole di risoluzione (19 ottobre 2026)
Fissate una per una in `test/rules/interactions_test.dart`.

**La notte** si risolve tutta insieme: chi muore stanotte ha comunque agito (il Cecchino spara, il Messia no: vedi sotto).
1. Bersagli: famiglia (voto a maggioranza; pareggio a sorte o nessuno secondo `TieBreak`), Cecchino, Sicario, poi il fuoco (tutti i cosparsi vivi). Chi è nel mirino di più assassini subisce un agguato solo, attribuito al primo della lista (famiglia > Cecchino > Sicario > fuoco).
2. Protezione: Dottore e Strozzino fermano qualunque colpo, fuoco compreso. Il Dottore può proteggere se stesso, mai la stessa persona due notti di fila; lo Strozzino non presta a se stesso né allo stesso due notti di fila.
3. Guardaspalle: se il suo protetto è colpito e non è già protetto, il colpo passa a lui (anche il fuoco, anche due assassini insieme: muore solo lui, un agguato). Se il Guardaspalle è colpito lui stesso muore lui. Se il Dottore copre il Guardaspalle, vivono tutti e due.
4. Reduce: il primo colpo che lo ucciderebbe (fuoco compreso) va a vuoto; un colpo già fermato dal Dottore non consuma la pelle dura.
5. Dopo i morti: lo scoop esce solo se il Cronista è vivo (lo spende comunque); il silenzio del Sarto vale solo se il bersaglio è vivo (l'ago è speso comunque); il Messia riporta in vita il prescelto solo se lui è vivo all'alba (spesa comunque). **Fix:** il Messia che passa non spende più la resurrezione.
6. Resurrezione prima del conteggio dei vincitori. Il risorto torna senza benzina; la taglia di un Cacciatore, una volta morta, resta scaduta anche se risorge (**fix**).
7. Portinaio: vede "qualcuno è passato" per ogni mossa vera sul bersaglio. **Fix:** dei voti della famiglia conta solo quello sulla porta scelta davvero (prima un voto perdente risultava visita e svelava le scelte della famiglia).

**Il Messia** sceglie solo cittadini linciati: mai mafia, mai neutrali (il Fesso), mai chi è morto di notte o è uscito dal tavolo.

**Indagini.** Commissario: Padrino onesto; Pregiudicato e Sicario famiglia; Fesso, Piromane, Cacciatore, Strozzino onesti. Becchino: ruolo esatto di ogni morto non pubblico (bruciato, sparato, accoltellato); i linciati sono già pubblici. Cronista: fazione vera (i neutrali come neutrali).

**Il giorno.** Parità in piazza: nessuno. Il Sindaco rivelato vale due solo quel giorno; ucciso o linciato, il ruolo resta pubblico. Il cosparso linciato esce dalla lista del Piromane (**fix**: prima restava visibile fino alla notte dopo).

**Fine partita, in quest'ordine** (si controlla a ogni alba, a ogni linciaggio e a ogni abbandono):
1. Taglia linciata con il Cacciatore vivo: vince il Cacciatore (`Team.neutral`), la partita finisce. **Fix:** ora vince anche lo Strozzino vivo.
2. Sicario vivo con al massimo un altro vivo: vince il Sicario. Piromane: solo se è l'ultimo vivo. Piromane e Sicario ultimi due (mai nel mazzo, `neutralFits` lo vieta; solo un tavolo costruito a mano): vince il Sicario, che uccide in una notte.
3. Famiglia: mafiosi vivi almeno quanti gli altri (i neutrali contano come non mafiosi). Vale anche contro il Piromane (Piromane + un mafioso: vince la famiglia) e contro un Sicario in minoranza.
4. Città: nessun mafioso e nessun assassino in proprio vivo. Anche se sono morti tutti, o se restano solo neutrali innocui (Fesso, Strozzino, Cacciatore).
5. Piromane con un solo non mafioso: si va avanti (la piazza in due pareggia, lui cosparge e accende) finché resta l'ultimo o viene linciato.
Vittorie personali che si sommano: Fesso linciato (anche se il linciaggio chiude la partita), Strozzino vivo a fine partita (con chiunque vinca), Cacciatore con taglia scaduta (vince se vince la città).

## Domande aperte per il proprietario
- Sindaco: il voto doppio deve restare anche nei giorni dopo la rivelazione?
- Portinaio: deve vedere anche i compiti di copertura (più rumore, meno informazione)?
- Investigatore mafioso: cosa scopre e che prezzo paga?
- Cacciatore: alla taglia morta di notte meglio una taglia nuova invece del passaggio alla città?
- Strozzino: deve anche "comprare" il voto del debitore online?
- Timer: tempi diversi per i bot?

## Aggiornamento 20 ottobre 2026

- Il fuoco del Piromane non si ferma: Dottore, Strozzino, Guardaspalle e Reduce non salvano chi brucia.
- Il Sicario vince se resta da solo o con una sola persona, anche se è della Famiglia.
