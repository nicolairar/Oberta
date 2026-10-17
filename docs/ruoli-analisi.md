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

## Domande aperte per il proprietario
- Sarto: vota l'agguato se gli altri sono vivi? Ultimo rimasto: sceglie tra uccidere e silenziare? Silenzio già dalla prima notte?
- Padrino da quanti giocatori? Compare solo online?
- Mafiosi per fascia di giocatori e tetto di ruoli speciali?
- Becchino e Cronista contano come investigatori? Guardaspalle come protettore?
- Cecchino e Piromane contano entrambi come colpi extra?
- Piromane: come vince, chi può cospargere?
- Fesso: con un neutrale vivo, come si conta la parità mafiosa?
- Messia: può riportare un mafioso linciato? Il ruolo resta noto?
- Sindaco: voto doppio per una giornata, rivelazione al momento del voto?
- Investigatore mafioso: cosa scopre e che prezzo paga?
- Timer da 30 s anche per la prima notte? E per i bot?
