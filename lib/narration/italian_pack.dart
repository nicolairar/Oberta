import '../rules/game_engine.dart';
import '../rules/role.dart';
import 'narration_pack.dart';

// Regole per chi scrive:
// - breve: una riga o due per battuta, sennò al tavolo nessuno la legge;
// - nessun aggettivo o participio accordato al nome di un giocatore: il gioco
//   non sa se chi muore è un uomo o una donna;
// - le città e i luoghi sono veri; persone e fatti no;
// - azioni e stacchi devono funzionare in qualsiasi luogo;
// - si gioca passandosi il telefono: nessuno chiude gli occhi.
const italianPack = NarrationPack(
  roles: {
    Role.mafioso: RoleText(
      'Il Picciotto',
      '«Niente di personale.»',
      'Ogni notte, insieme alla famiglia, scegli chi non vedrà l\'alba.',
    ),
    Role.padrino: RoleText(
      'Il Padrino',
      '«Io faccio solo favori. Chiedete in giro.»',
      'Scegli con la famiglia chi non vedrà l\'alba. Al Commissario risulti innocente.',
    ),
    Role.sarto: RoleText(
      'Il Sarto',
      '«Cucio abiti di giorno e bocche di notte.»',
      'Ogni notte togli la parola a qualcuno per un giorno. Se la famiglia resta senza sicari, uccidi tu.',
    ),
    Role.cittadino: RoleText(
      'L\'Onesto',
      '«Io non ho visto niente. Purtroppo è vero.»',
      'Nessun potere, solo occhi e lingua. Osserva, accusa, vota.',
    ),
    Role.detective: RoleText(
      'Il Commissario',
      '«Mentono tutti. Qualcuno meglio.»',
      'Ogni notte indaghi su qualcuno e scopri da che parte sta.',
    ),
    Role.medico: RoleText(
      'Il Dottore',
      '«Ricucio quello che gli altri strappano.»',
      'Ogni notte proteggi qualcuno. Mai la stessa persona due notti di fila.',
    ),
    Role.cecchino: RoleText(
      'Il Cecchino',
      '«Un colpo. Non due.»',
      'Hai un solo proiettile per tutta la partita. Scegli bene la notte.',
    ),
    Role.giornalista: RoleText(
      'Il Cronista',
      '«La verità esce in edicola alle sei.»',
      'Hai un solo scoop: all\'alba tutti sapranno da che parte sta chi hai scelto. Se all\'alba ci arrivi.',
    ),
    Role.becchino: RoleText(
      'Il Becchino',
      '«I miei clienti non mentono mai.»',
      'Ogni notte puoi scavare nella fossa di chi è morto di notte: scopri, solo tu, che ruolo aveva.',
    ),
    Role.guardaspalle: RoleText(
      'Il Guardaspalle',
      '«Prima devono passare da me.»',
      'Ogni notte fai da scudo a qualcuno. Se quella notte finisce nel mirino, muori tu al suo posto.',
    ),
    Role.reduce: RoleText(
      'Il Reduce',
      '«Mi hanno già sparato. Gente migliore di voi.»',
      'Hai la pelle dura: il primo agguato notturno contro di te va a vuoto. Il secondo no.',
    ),
    Role.pregiudicato: RoleText(
      'Il Pregiudicato',
      '«Ho pagato tutto. La fedina non lo sa.»',
      'Stai con gli onesti, ma la fedina è sporca: al Commissario risulti della famiglia.',
    ),
  },
  cities: [
    CitySetting(
      id: 'chicago',
      name: 'Chicago',
      title: 'Chicago, 1929',
      openings: [
        'Chicago, 1929. Il proibizionismo ha chiuso i bar, e ha aperto tutto il resto.',
        'Chicago, 1929. La città del vento: porta via i cappelli, e a volte chi li indossa.',
      ],
      scenes: [
        StoryPiece('chicago-loop', 'Esterno, notte. Sotto la sopraelevata del Loop passa un treno.'),
        StoryPiece('chicago-station', 'Interno, notte. Union Station, la sala d\'attesa deserta.'),
        StoryPiece('chicago-pier', 'Esterno, notte. Il Navy Pier, nebbia sul lago Michigan.'),
        StoryPiece('chicago-jazz', 'Interno, notte. Il Green Mill: fumo, e un sassofono.'),
        StoryPiece('chicago-bridge', 'Esterno, notte. Un ponte levatoio sul fiume Chicago.'),
        StoryPiece('chicago-market', 'Esterno, notte. Il mercato di Maxwell Street, a banchi chiusi.'),
        StoryPiece('chicago-speakeasy', 'Interno, notte. Un bar clandestino del South Side.'),
        StoryPiece('chicago-hotel', 'Interno, notte. L\'atrio del Lexington Hotel, nessuno alla reception.'),
      ],
    ),
    CitySetting(
      id: 'new-york',
      name: 'New York',
      title: 'New York, 1947',
      openings: [
        'New York, 1947. Otto milioni di persone, e nessuna ha visto niente.',
        'New York, 1947. La città che non dorme mai. Stanotte farebbe meglio a provarci.',
      ],
      scenes: [
        StoryPiece('ny-mulberry', 'Esterno, notte. Mulberry Street, Little Italy, sotto le insegne al neon.'),
        StoryPiece('ny-bridge', 'Esterno, notte. Sotto il ponte di Brooklyn, nebbia sull\'East River.'),
        StoryPiece('ny-station', 'Interno, notte. Grand Central: l\'orologio segna le tre.'),
        StoryPiece('ny-market', 'Esterno, notte. Il mercato del pesce di Fulton, tra le casse.'),
        StoryPiece('ny-coney', 'Esterno, notte. Coney Island fuori stagione, la ruota ferma.'),
        StoryPiece('ny-pier', 'Esterno, notte. Un molo sull\'Hudson, un mercantile senza nome.'),
        StoryPiece('ny-diner', 'Interno, notte. Una tavola calda a due passi da Times Square.'),
        StoryPiece('ny-park', 'Esterno, notte. Central Park, un solo lampione acceso.'),
      ],
    ),
    CitySetting(
      id: 'palermo',
      name: 'Palermo',
      title: 'Palermo, 1955',
      openings: [
        'Palermo, 1955. Il sole più bello del mondo, e certe ombre lunghissime.',
        'Palermo, 1955. Qui tutti sanno tutto. Per questo nessuno dice niente.',
      ],
      scenes: [
        StoryPiece('palermo-vucciria', 'Esterno, notte. Il mercato della Vucciria, a banchi chiusi.'),
        StoryPiece('palermo-teatro', 'Esterno, notte. La scalinata del Teatro Massimo, tra i due leoni.'),
        StoryPiece('palermo-canti', 'Esterno, notte. I Quattro Canti, deserti. Solo le statue.'),
        StoryPiece('palermo-cala', 'Esterno, notte. La Cala, il porto vecchio. Barche che dondolano.'),
        StoryPiece('palermo-ballaro', 'Esterno, notte. Un vicolo di Ballarò, panni stesi.'),
        StoryPiece('palermo-mondello', 'Esterno, notte. La spiaggia di Mondello, fuori stagione.'),
        StoryPiece('palermo-foro', 'Esterno, notte. Il Foro Italico, sul lungomare, tra le palme.'),
        StoryPiece('palermo-pasticceria', 'Interno, notte. Una pasticceria del centro, a saracinesca abbassata.'),
      ],
    ),
    CitySetting(
      id: 'napoli',
      name: 'Napoli',
      title: 'Napoli, 1950',
      openings: [
        'Napoli, 1950. Il Vesuvio fuma, il caffè scotta, e qualcuno stanotte non dorme.',
        'Napoli, 1950. Qui si canta sempre. Parlare, è un altro discorso.',
      ],
      scenes: [
        StoryPiece('napoli-quartieri', 'Esterno, notte. Un vicolo dei Quartieri Spagnoli.'),
        StoryPiece('napoli-galleria', 'Interno, notte. La Galleria Umberto I, vuota. I passi rimbombano.'),
        StoryPiece('napoli-molo', 'Esterno, notte. Il Molo Beverello, i traghetti fermi.'),
        StoryPiece('napoli-spaccanapoli', 'Esterno, notte. Spaccanapoli, dritta come una lama.'),
        StoryPiece('napoli-sancarlo', 'Interno, notte. Il Teatro San Carlo, a sala vuota.'),
        StoryPiece('napoli-lungomare', 'Esterno, notte. Il lungomare, sotto Castel dell\'Ovo.'),
        StoryPiece('napoli-funicolare', 'Interno, notte. La funicolare di Chiaia, ultima corsa.'),
        StoryPiece('napoli-pizzeria', 'Interno, notte. Una pizzeria di via dei Tribunali, a forno spento.'),
      ],
    ),
    CitySetting(
      id: 'las-vegas',
      name: 'Las Vegas',
      title: 'Las Vegas, 1955',
      openings: [
        'Las Vegas, 1955. Un milione di lampadine nel deserto, per nascondere il resto.',
        'Las Vegas, 1955. Qui il banco vince sempre. Stanotte scoprirete chi è il banco.',
      ],
      scenes: [
        StoryPiece('vegas-fremont', 'Esterno, notte. Fremont Street: mille luci, nessun testimone.'),
        StoryPiece('vegas-flamingo', 'Interno, notte. Il casinò del Flamingo, all\'ora di chiusura.'),
        StoryPiece('vegas-desert', 'Esterno, notte. Il deserto del Mojave. Due fari, una pala.'),
        StoryPiece('vegas-nugget', 'Interno, notte. Il retro del Golden Nugget, un tavolo da poker.'),
        StoryPiece('vegas-motel', 'Esterno, notte. Il parcheggio di un motel sulla Strip.'),
        StoryPiece('vegas-dam', 'Esterno, notte. La diga di Hoover. Sotto, duecento metri di vuoto.'),
        StoryPiece('vegas-dressing', 'Interno, notte. Il camerino di un cantante, dopo lo spettacolo.'),
        StoryPiece('vegas-chapel', 'Interno, notte. Una cappella per matrimoni aperta tutta la notte.'),
      ],
    ),
  ],
  howToPlay:
      'Di notte la famiglia elimina una persona. Di giorno votate tutti chi eliminare. '
      'Gli onesti vincono se eliminano tutta la famiglia; la famiglia vince se li pareggia.',
  firstNights: [
    'Cala la prima notte su {city}.',
    'Su {city} scende il buio. È la prima notte.',
    'Prima notte. Chi ha la coscienza pulita dorma pure.',
  ],
  nights: [
    'Scende di nuovo la notte su {city}.',
    'Si spengono i lampioni. Qualcuno ha da fare.',
    'È notte. Qualcuno ha un appuntamento, e non è galante.',
    'Un\'altra notte. A {city} ormai si dorme vestiti.',
    'Cala il buio. I cani hanno smesso di abbaiare.',
    'Notte fonda. Le pompe funebri fanno gli straordinari.',
  ],
  nightInstruction: 'Passatevi il telefono. Ognuno fa la sua mossa in segreto, poi lo passa.',
  nobodyDied: 'Stanotte non è morto nessuno.',
  // Per le albe in cui nessuno è stato nemmeno preso di mira. Se il Dottore
  // ha salvato qualcuno lo si vede in scena, e parlano i `rescues`.
  quietDawns: [
    'Le pompe funebri esprimono viva preoccupazione.',
    'Guardatevi in faccia: qualcuno, qui, è deluso.',
    'Non rilassatevi. Di solito è così che comincia.',
    'Il custode del cimitero ha dormito otto ore, e non sa cosa pensare.',
  ],
  secondVictims: [
    'E non è finita.',
    'Cambio di scena.',
    'Ma la notte è stata lunga.',
  ],
  victimFact: 'Stanotte è morta una persona: {name}. Il suo ruolo resta segreto.',
  sniperShots: [
    'Un colpo solo, da una finestra lontana. {name} non ha sentito niente.',
    'Un riflesso su un tetto, poi uno sparo. {name} cade prima dell\'eco.',
    'Qualcuno, da lontano, ha preso la mira con calma. {name} resta sull\'asfalto.',
    'Nessuno dietro l\'angolo, stavolta. Solo un mirino, e {name} al centro.',
  ],
  rescues: [
    'Uno sparo dal vicolo, {name} a terra. Poi dei passi di corsa: il Dottore.',
    'Volevano chiudere il conto di {name}. Il Dottore è arrivato prima del prete.',
    '{name} era già a terra. Ma il Dottore, stanotte, passava proprio di lì.',
    'Un colpo, e {name} va giù. Una borsa di cuoio si apre: non è finita.',
  ],
  someone: 'qualcuno',
  savedFact: 'Stanotte hanno sparato a qualcuno, ma il Dottore ha fatto in tempo. Chi fosse, resta un segreto.',
  // Il colpo fermato dalla fiaschetta: in scena si vede proprio quella. Il
  // fatto non nomina nessun ruolo: al tavolo resta il dubbio su chi sia.
  shrugs: [
    'Uno sparo. {name} barcolla, poi si tocca il taschino: una fiaschetta, ammaccata.',
    'Il colpo parte, e fa «ding». {name} tira fuori una fiaschetta col buco.',
    'Uno sparo dal vicolo. {name} resta in piedi: il proiettile è nella fiaschetta.',
    '{name} sente un colpo al petto. Sotto la giacca, una fiaschetta piegata in due.',
  ],
  shruggedFact: 'Stanotte hanno sparato a qualcuno, ma il colpo è andato a vuoto. Chi fosse, resta un segreto.',
  methods: [
    StoryPiece('auto', 'Due fari nel buio. Un\'auto nera non frena. {name} si volta: troppo tardi.'),
    StoryPiece('pianoforte', 'Una corda si spezza. Un pianoforte precipita. {name} alza gli occhi.'),
    StoryPiece('veleno', '{name} beve l\'ultimo sorso di caffè. Una smorfia. Veleno.'),
    StoryPiece('pugnale', 'Un\'ombra alle spalle di {name}. Una lama. Un colpo solo.'),
    StoryPiece('cemento', 'Due uomini bloccano {name}. Un terzo mescola il cemento.'),
    StoryPiece('cappio', 'Un cappio cala dal buio alle spalle di {name}. Si stringe.'),
    StoryPiece('silenziatore', 'Un colpo attutito, come un tappo di spumante. {name} scivola a terra.'),
    StoryPiece('pacco', '{name} apre un pacco regalo. Dentro, un ticchettio. Poi un boato.'),
    StoryPiece('lampadario', 'Un cigolio. Un lampadario di cristallo si stacca sopra {name}.'),
    StoryPiece('violino', 'Una custodia di violino si apre. Non c\'è un violino. {name} cade.'),
    StoryPiece('cassaforte', 'Dall\'alto, una cassaforte. {name} fa in tempo a leggere la marca.'),
    StoryPiece('sigaro', '{name} accende un sigaro avuto in regalo. Il sigaro fa «bum».'),
    StoryPiece('mazza', 'Dall\'angolo, una mazza da baseball. Un colpo secco. {name} vede le stelle.'),
    StoryPiece('lupara', 'Due canne mozze spuntano dal buio. Un boato. {name} vola all\'indietro.'),
    StoryPiece('raffica', 'Un\'auto rallenta. Dal finestrino, un mitra. {name} non fa in tempo a voltarsi.'),
    StoryPiece('garrota', 'Un filo d\'acciaio, due mani guantate. {name} scalcia, poi smette.'),
    StoryPiece('vaso', 'Dal terzo piano cade un vaso di gerani. Non per caso. {name} non lo vede.'),
    StoryPiece('tombino', 'Il tombino si apre sotto i piedi di {name}. Poi si richiude, con cura.'),
    StoryPiece('buio', 'Il lampione si spegne. Un rumore. Quando si riaccende, {name} è a terra.'),
    StoryPiece('bacio', 'Una sconosciuta, un bacio, un rossetto che non perdona. {name} sorride, poi cade.'),
  ],
  epilogues: [
    StoryPiece('gatto', 'Un gatto ha visto tutto. Non parlerà.'),
    StoryPiece('mambo', 'Da qualche parte, una radio suona un mambo.'),
    StoryPiece('tetti', '{city} dorme. O fa finta.'),
    StoryPiece('carta', 'A terra, una carta da gioco. Titoli di coda.'),
    StoryPiece('finestra', 'Una finestra si accende, poi si spegne.'),
    StoryPiece('sipario', 'Cala il sipario. Nessuno applaude.'),
    StoryPiece('voce', 'Una voce fuori campo: «Niente di personale».'),
    StoryPiece('sirene', 'Sirene in lontananza. Arrivano sempre tardi.'),
    StoryPiece('cappello', 'Un cappello rotola per terra. Stacco.'),
    StoryPiece('continua', 'Sullo schermo, una scritta: «Continua».'),
  ],
  scoops: [
    'Edizione straordinaria! In prima pagina c\'è {name}.',
    'In edicola c\'è la fila: il giornale parla di {name}.',
    'Gli strilloni gridano un nome solo: {name}.',
  ],
  scoopMafia: 'Il giornale lo scrive chiaro: {name} sta con la famiglia.',
  scoopClean: 'Il giornale lo scrive chiaro: {name} è innocente.',
  silences: [
    'Ago, filo, e un lavoro di fino: stamattina {name} ha la bocca cucita.',
    'Qualcuno ha fatto visita a {name}, stanotte. Con un ago e un consiglio.',
    'Sul cuscino di {name}, un rocchetto di filo nero. Il messaggio è arrivato.',
  ],
  silencedFact:
      'Oggi {name} non può parlare durante la discussione. Vota a gesti, e resta tra chi potete eliminare.',
  dayInstruction: 'Avete {minutes} per discutere. Poi votate chi eliminare.',
  oneMinute: 'un minuto',
  manyMinutes: '{minutes} minuti',
  voteCalls: [
    'Tempo scaduto. La piazza vuole un colpevole.',
    'Basta chiacchiere. {city} vuole un nome.',
    'La folla rumoreggia. Il boia si scalda le mani.',
    'Si vota. Cercate di non sbagliare. Di nuovo.',
  ],
  voteInstruction: 'Decidete a voce chi eliminare. Potete anche non eliminare nessuno.',
  lynchScenes: [
    '{name} sale i gradini del patibolo. La ghigliottina brilla al sole.',
    '{name} cammina verso il cappio, a testa alta. Rullo di tamburi.',
    'Un treno merci, un biglietto di sola andata. {name} lascia {city}.',
    'La botola del municipio cigola. {name} guarda la folla un\'ultima volta.',
    '{name} chiede un\'ultima sigaretta. Il boia gliela accende.',
    'Primo piano sulle mani legate di {name}. Tutta {city} guarda.',
  ],
  cardTurns: 'La carta si gira. {name} era… {role}.',
  wasMafia: 'Stava con la famiglia.',
  wasCitizen: 'Stava con gli onesti.',
  lynchedInnocent: [
    'Complimenti a tutti. Davvero.',
    'Qualcuno, tra voi, trattiene un sorriso.',
    'La famiglia ringrazia per la collaborazione.',
    'Il boia chiede scusa. Ma si fa pagare lo stesso.',
  ],
  lynchedMafioso: [
    'Uno in meno. Ma gli amici degli amici hanno buona memoria.',
    'Qualcuno ha perso un socio, e non può andare al funerale.',
    'Bel colpo. Stanotte la famiglia sarà di pessimo umore.',
  ],
  lynchedLastMafioso: [
    'Ed era l\'ultimo. Le campane suonano a festa.',
    'Era l\'ultimo. A {city}, finalmente, qualcuno ha parlato.',
  ],
  noLynch: [
    'Il boia torna a casa presto, per una volta.',
    'Qualcuno tira un sospiro di sollievo. Chissà chi.',
    'A {city} non mettersi d\'accordo è la normalità.',
  ],
  noLynchFact: 'Oggi non viene eliminato nessuno.',
  citizensWin: [
    '{city} è libera. Da domani si dorme con le finestre aperte. Titoli di coda.',
    'In piazza ci si guarda di nuovo in faccia. Sullo schermo: «Fine».',
  ],
  citizensWinFact: 'Vincono gli onesti: tutta la famiglia è stata eliminata.',
  mafiaWins: [
    '{city} ha dei nuovi padroni: erano seduti a questo tavolo. Titoli di coda.',
    'A {city} nessuno ha visto niente. Come sempre. Dissolvenza in nero.',
  ],
  mafiaWinsFact: 'Vince la famiglia: gli onesti non sono più in maggioranza.',
  taskPrompts: {
    NightTaskKind.kill: 'Chi eliminate stanotte?',
    NightTaskKind.silence: 'A chi cuci la bocca stanotte?',
    NightTaskKind.protect: 'Chi proteggi stanotte?',
    NightTaskKind.guard: 'A chi fai da scudo stanotte?',
    NightTaskKind.investigate: 'Su chi vuoi indagare?',
    NightTaskKind.dig: 'Quale fossa scavi stanotte?',
    NightTaskKind.snipe: 'Vuoi sparare a qualcuno?',
    NightTaskKind.scoop: 'Su chi pubblichi lo scoop?',
  },
  taskHints: {
    NightTaskKind.kill: 'Chi scegli non vedrà l\'alba. Se siete in più d\'uno, vince la maggioranza.',
    NightTaskKind.silence: 'Chi scegli domani non potrà parlare. Mai la stessa persona due notti di fila.',
    NightTaskKind.protect: 'Chi scegli stanotte non può morire. Mai la stessa persona due notti di fila.',
    NightTaskKind.guard: 'Se stanotte provano a uccidere chi scegli, muori tu al suo posto.',
    NightTaskKind.investigate: 'Scoprirai subito se sta con la famiglia o con gli onesti.',
    NightTaskKind.dig: 'Scegli tra chi è morto di notte: scoprirai subito, solo tu, che ruolo aveva.',
    NightTaskKind.snipe: 'Hai un solo proiettile in tutta la partita. Se passi, ti resta.',
    NightTaskKind.scoop: 'Hai un solo scoop: all\'alba tutti sapranno da che parte sta. Se passi, ti resta.',
    NightTaskKind.decoy: 'Stanotte non hai una mossa: rispondi lo stesso, così nessuno capisce chi sei.',
  },
  decoyPrompts: [
    'Chi ti sembra più sospetto?',
    'Di chi non ti fideresti mai?',
    'Chi ha la faccia di chi nasconde qualcosa?',
    'Se dovessi puntare il dito, su chi?',
    'Chi sta recitando meglio, a questo tavolo?',
  ],
);
