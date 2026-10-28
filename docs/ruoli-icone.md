# Icone dei ruoli: brief per le SVG

Per generare e controllare gli asset, seguire la [guida per le icone dei ruoli](guida-generazione-icone-ruoli.md). La tabella in questo file resta la fonte canonica per id, fazione e simbolo.

Stile: noir mafioso anni '20–'50, coerente con l'app (ottone #D6AD48, rosso sangue #A51D25, carta #EFDFB9, inchiostro #100B09).
Silhouette piatte, leggibili a 24 px, contorno pulito, niente sfumature complicate, viewBox 0 0 64 64, un file per ruolo (`<id>.svg`).
Colore per fazione: famiglia rosso, città ottone, neutrali verde salvia #7A9A6A.

| id | Nome | Fazione | Cosa fa | Idea per l'icona |
|---|---|---|---|---|
| mafioso | Il Picciotto | Famiglia | Uccide di notte con la famiglia | Lupara / pistola |
| padrino | Il Padrino | Famiglia | Uccide con la famiglia, al Commissario risulta innocente | Anello con sigillo / fedora con rosa |
| sarto | Il Sarto | Famiglia | Una volta toglie la parola a qualcuno per un giorno | Ago e filo che cuce una bocca / forbici |
| compare | Il Compare | Famiglia | Dà alla famiglia la chat segreta anche di giorno | Due mani che si stringono / orecchio |
| cittadino | L'Onesto | Città | Nessun potere, vota | Coppola / cappello semplice |
| detective | Il Commissario | Città | Indaga di notte da che parte sta qualcuno | Lente d'ingrandimento / distintivo |
| medico | Il Dottore | Città | Protegge qualcuno ogni notte | Valigetta medica / croce |
| cecchino | Il Cecchino | Città | Un solo colpo in tutta la partita | Mirino |
| giornalista | Il Cronista | Città | Uno scoop: rivela la fazione di qualcuno all'alba | Giornale / macchina fotografica a flash |
| becchino | Il Becchino | Città | Scopre il ruolo di chi è morto di notte | Pala / lapide |
| guardaspalle | Il Guardaspalle | Città | Fa da scudo e muore al posto di un altro | Scudo / giacca con spalle larghe |
| reduce | Il Reduce | Città | Sopravvive al primo agguato | Elmetto / medaglia |
| pregiudicato | Il Pregiudicato | Città | Onesto, ma al Commissario risulta mafioso | Manette / foto segnaletica |
| messia | Il Messia | Città | Una volta riporta in vita un onesto linciato | Aureola / candela |
| sindaco | Il Sindaco | Città | Si rivela al voto e il suo voto vale doppio | Fascia tricolore / martelletto |
| portinaio | Il Portinaio | Città | Guarda una porta: sa se qualcuno è passato | Mazzo di chiavi / porta socchiusa |
| fesso | Il Fesso | Neutrale | Vince se lo linciano | Cappello da giullare / sorriso storto |
| piromane | Il Piromane | Neutrale | Cosparge di benzina e poi brucia tutti | Fiammifero / tanica |
| cacciatore | Il Cacciatore di taglie | Neutrale | Deve far linciare il suo bersaglio | Manifesto «WANTED» / mirino su foto |
| strozzino | Lo Strozzino | Neutrale | Protegge un debitore ogni notte, vince se sopravvive | Mazzetta di banconote / registro dei debiti |
| sicario | Il Sicario | Neutrale | Uccide da solo ogni notte | Coltello / guanto nero con silenziatore |
| prostituta | La Prostituta | Famiglia | Di notte passa la notte con qualcuno: la sua mossa salta | Coppa da cocktail con ciliegia e segno di rossetto sul bordo |
| carceriere | Il Carceriere | Città | Ogni notte chiude qualcuno in cella: lo blocca e lo protegge, e lo interroga in una chat privata senza farsi riconoscere | Grata di cella con lucchetto (le chiavi sono già del Portinaio) |
| pacifista | Il Pacifista | Città | Una volta, di giorno, svela a tutti il ruolo esatto di qualcuno e annulla il voto di quel giorno | Bandiera bianca sull'asta |
| cupido | Cupido | Città | La prima notte lega due innamorati: vincono solo vivi tutti e due, se uno muore muore anche l'altro | Cuore trafitto da una freccia |

Le icone dei ruoli nuovi (prostituta, carceriere, pacifista, cupido) sono disegnate a codice (PIL, 1000 px ridotti a 250 px), sulla stessa geometria del medaglione degli altri: da rifare con ImageGen se si vuole lo stesso tratto del set.
