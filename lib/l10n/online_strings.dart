import '../online/handle_rules.dart';
import '../online/online_models.dart';
import '../online/ranked_models.dart';

/// I testi del gioco online: il manifesto, l'ingresso, il profilo, le
/// stanze e gli amici. Stanno da parte rispetto ad [AppStrings], che li
/// raggiunge con `online`; le regole sono le stesse: ogni lingua dice tutto,
/// e ogni testo finisce nel [catalog].
abstract class OnlineStrings {
  const OnlineStrings();

  // Il manifesto nel vicolo.
  String get posterTitle;
  String get posterBlurb;
  String get posterStrip;

  // Quando l'app non ha l'online.
  String get unavailableTitle;
  String get unavailableBody;

  // L'ingresso.
  String get loginTitle;
  String get loginBody;
  String get loginApple;
  String get loginGoogle;
  String get loginNoProvider;
  String get loginPrivacy;

  // L'account nel vicolo: la targhetta, il suggerimento, il cartellino.
  String get signIn;
  String get coachSignIn;
  String roomLinkSignIn(String code);
  String get roomLinkInvalid;
  String get technicalReason;
  String get pickHandle;
  String levelShort(int level);
  String get level;
  String get coins;
  String xpProgress(int xp, int next);

  // L'account di prova, nascosto.
  String get testAccount;
  String get testAccountBody;
  String get emailLabel;
  String get passwordLabel;
  String get testAccountSubmit;

  // Il profilo.
  String get setupTitle;
  String get setupBody;
  String get handleLabel;
  String get handleHint;
  String get save;
  String get handleInvalid;
  String get handleChecking;
  String get handleFree;

  /// Che cosa non va nel nome unico, regola per regola.
  String handleProblem(HandleProblem problem);

  // La sala d'ingresso.
  String get hubTitle;
  String signedInAs(String name);
  String get hubCreate;
  String get hubJoin;
  String get friends;
  String get signOut;

  // Entrare in una stanza.
  String get joinTitle;
  String get codeLabel;
  String get joinSubmit;
  String get scan;
  String get codeInvalid;
  String get scanTitle;
  String get scanHint;
  String get scanDenied;

  // La stanza.
  String get roomTitle;
  String get roomShareHint;
  String roomSeated(int seated, int max);
  String get hostBadge;
  String get addFriend;
  String friendRequestSent(String name);
  String nowFriends(String name);
  String get leaveRoom;
  String get leaveConfirmTitle;
  String get leaveConfirmBody;
  String get leaveConfirm;
  String get stay;
  String get chooseHostTitle;
  String get chooseHostBody;
  String get addBot;
  String get removeBot;
  String get botBadge;
  String get startGame;
  String startNeeds(int players);
  String get waitingForHost;
  String get rejoin;
  String get reconnecting;

  // La partita online.
  String get gameConnecting;
  String get yourCard;
  String get yourCardHint;
  String waitingForOthers(int pending);
  String get youAreOut;
  String get voteTitle;
  String get voteHint;
  String get abstain;
  String votedFor(String name);
  String get abstained;
  String votesCast(int votes, int alive);
  String closesIn(String time);
  String get rejected;
  String get serverSilent;
  String get backToRoom;
  String timeLeft(String time);
  String get startingSoon;
  String get ready;
  String get readyWaiting;
  String get moveRegistered;
  String get voteRegistered;
  String get sending;
  String get offlineBadge;
  String leftTown(String name, String role);
  String get gameClosed;
  String get fateLeft;
  String get youLeftTown;
  String get youLookOffline;
  String get connectionLost;
  String get abstainTag;
  String votesFor(int votes);
  String get nightTitleOnline;
  String get discussionTitle;
  String get discussionHint;
  String get verdictWaiting;
  String get accusedTag;


  // La classificata e i risultati.
  String get rankedQueueTitle;
  String get rankedStart;
  String get rankedSearching;
  String rankedWaiting(int people);
  String rankedEstimate(String time);
  String get rankedCancel;
  String get rankedFound;
  String get rankedTestMatch;
  String get rankedWarning;
  String rankedCooldown(String time);
  String get rankedLobbyTitle;
  String rankedSeats(int seated, int size);
  String rankedMissing(int missing);
  String rankedStartsIn(int seconds);
  String get rankedLeaveLobby;
  String get rankedNoPenalty;
  String get rankedTipsTitle;
  List<String> get rankedTips;
  String tierName(RankTier tier);
  String get resultsTitle;
  String get resultsWon;
  String get resultsLost;
  String get resultsLeft;
  String resultsXp(int xp);
  String resultsLevelUp(int level);
  String resultsCoins(int coins);
  String get resultsRatingUp;
  String get resultsRatingDown;
  String get resultsContinue;

  // Il fascicolo del profilo.
  String get dossierTitle;
  String get dossierHistory;
  String get dossierNoHistory;
  String get dossierSettings;

  // La chat.
  String get chatHint;
  String get chatLobby;
  String get chatTown;
  String get chatFamily;
  String get chatEmpty;
  String get chatNightClosed;
  String get chatDead;
  String get chatSilenced;
  String get chatSend;

  // Gli amici.
  String get searchHint;
  String get requests;
  String get yourFriends;
  String get waiting;
  String get friendsEmpty;
  String get noResults;
  String get accept;
  String get decline;
  String get add;
  String get remove;
  String get withdraw;

  String failure(OnlineFailure failure);

  Map<String, String> get catalog => {
    'posterTitle': posterTitle,
    'posterBlurb': posterBlurb,
    'posterStrip': posterStrip,
    'unavailableTitle': unavailableTitle,
    'unavailableBody': unavailableBody,
    'loginTitle': loginTitle,
    'loginBody': loginBody,
    'loginApple': loginApple,
    'loginGoogle': loginGoogle,
    'loginNoProvider': loginNoProvider,
    'loginPrivacy': loginPrivacy,
    'signIn': signIn,
    'coachSignIn': coachSignIn,
    'roomLinkSignIn': roomLinkSignIn('ABC234'),
    'roomLinkInvalid': roomLinkInvalid,
    'technicalReason': technicalReason,
    'pickHandle': pickHandle,
    'levelShort': levelShort(3),
    'level': level,
    'coins': coins,
    'xpProgress': xpProgress(40, 300),
    'testAccount': testAccount,
    'testAccountBody': testAccountBody,
    'emailLabel': emailLabel,
    'passwordLabel': passwordLabel,
    'testAccountSubmit': testAccountSubmit,
    'setupTitle': setupTitle,
    'setupBody': setupBody,
    'handleLabel': handleLabel,
    'handleHint': handleHint,
    'save': save,
    'handleInvalid': handleInvalid,
    'handleChecking': handleChecking,
    'handleFree': handleFree,
    for (final value in HandleProblem.values) 'handleProblem.${value.name}': handleProblem(value),
    'hubTitle': hubTitle,
    'signedInAs': signedInAs('Sara'),
    'hubCreate': hubCreate,
    'hubJoin': hubJoin,
    'friends': friends,
    'signOut': signOut,
    'joinTitle': joinTitle,
    'codeLabel': codeLabel,
    'joinSubmit': joinSubmit,
    'scan': scan,
    'codeInvalid': codeInvalid,
    'scanTitle': scanTitle,
    'scanHint': scanHint,
    'scanDenied': scanDenied,
    'roomTitle': roomTitle,
    'roomShareHint': roomShareHint,
    'roomSeated': roomSeated(3, 16),
    'hostBadge': hostBadge,
    'addFriend': addFriend,
    'friendRequestSent': friendRequestSent('Sara'),
    'nowFriends': nowFriends('Sara'),
    'leaveRoom': leaveRoom,
    'leaveConfirmTitle': leaveConfirmTitle,
    'leaveConfirmBody': leaveConfirmBody,
    'leaveConfirm': leaveConfirm,
    'stay': stay,
    'chooseHostTitle': chooseHostTitle,
    'chooseHostBody': chooseHostBody,
    'addBot': addBot,
    'removeBot': removeBot,
    'botBadge': botBadge,
    'startGame': startGame,
    'startNeeds': startNeeds(4),
    'waitingForHost': waitingForHost,
    'rejoin': rejoin,
    'reconnecting': reconnecting,
    'gameConnecting': gameConnecting,
    'yourCard': yourCard,
    'yourCardHint': yourCardHint,
    'waitingForOthers': waitingForOthers(3),
    'youAreOut': youAreOut,
    'voteTitle': voteTitle,
    'voteHint': voteHint,
    'abstain': abstain,
    'votedFor': votedFor('sara'),
    'abstained': abstained,
    'votesCast': votesCast(3, 7),
    'closesIn': closesIn('1:30'),
    'rejected': rejected,
    'serverSilent': serverSilent,
    'backToRoom': backToRoom,
    'timeLeft': timeLeft('0:30'),
    'startingSoon': startingSoon,
    'ready': ready,
    'readyWaiting': readyWaiting,
    'moveRegistered': moveRegistered,
    'voteRegistered': voteRegistered,
    'sending': sending,
    'offlineBadge': offlineBadge,
    'leftTown': leftTown('sara', 'Medico'),
    'gameClosed': gameClosed,
    'fateLeft': fateLeft,
    'youLeftTown': youLeftTown,
    'youLookOffline': youLookOffline,
    'connectionLost': connectionLost,
    'abstainTag': abstainTag,
    'votesFor': votesFor(2),
    'nightTitleOnline': nightTitleOnline,
    'discussionTitle': discussionTitle,
    'discussionHint': discussionHint,
    'accusedTag': accusedTag,
    'verdictWaiting': verdictWaiting,
    'chatHint': chatHint,
    'chatLobby': chatLobby,
    'chatTown': chatTown,
    'chatFamily': chatFamily,
    'chatEmpty': chatEmpty,
    'chatNightClosed': chatNightClosed,
    'chatDead': chatDead,
    'chatSilenced': chatSilenced,
    'chatSend': chatSend,
    'searchHint': searchHint,
    'requests': requests,
    'yourFriends': yourFriends,
    'waiting': waiting,
    'friendsEmpty': friendsEmpty,
    'noResults': noResults,
    'accept': accept,
    'decline': decline,
    'add': add,
    'remove': remove,
    'withdraw': withdraw,
    for (final value in OnlineFailure.values) 'failure.${value.name}': failure(value),
    'rankedQueueTitle': rankedQueueTitle,
    'rankedStart': rankedStart,
    'rankedSearching': rankedSearching,
    'rankedWaiting': rankedWaiting(3),
    'rankedEstimate': rankedEstimate('1:30'),
    'rankedCancel': rankedCancel,
    'rankedFound': rankedFound,
    'rankedTestMatch': rankedTestMatch,
    'rankedWarning': rankedWarning,
    'rankedCooldown': rankedCooldown('5:00'),
    'rankedLobbyTitle': rankedLobbyTitle,
    'rankedSeats': rankedSeats(6, 12),
    'rankedMissing': rankedMissing(3),
    'rankedStartsIn': rankedStartsIn(10),
    'rankedLeaveLobby': rankedLeaveLobby,
    'rankedNoPenalty': rankedNoPenalty,
    'rankedTipsTitle': rankedTipsTitle,
    for (final (i, tip) in rankedTips.indexed) 'rankedTip$i': tip,
    for (final tier in RankTier.values) 'tier.${tier.name}': tierName(tier),
    'resultsTitle': resultsTitle,
    'resultsWon': resultsWon,
    'resultsLost': resultsLost,
    'resultsLeft': resultsLeft,
    'resultsXp': resultsXp(100),
    'resultsLevelUp': resultsLevelUp(2),
    'resultsCoins': resultsCoins(150),
    'resultsRatingUp': resultsRatingUp,
    'resultsRatingDown': resultsRatingDown,
    'resultsContinue': resultsContinue,
    'dossierTitle': dossierTitle,
    'dossierHistory': dossierHistory,
    'dossierNoHistory': dossierNoHistory,
    'dossierSettings': dossierSettings,
  };
}

final class ItalianOnlineStrings extends OnlineStrings {
  @override
  String get rankedQueueTitle => 'CLASSIFICATA';
  @override
  String get rankedStart => 'Cerca partita';
  @override
  String get rankedSearching => 'Si cercano facce nuove in città…';
  @override
  String rankedWaiting(int people) => people == 1 ? '1 in attesa' : '$people in attesa';
  @override
  String rankedEstimate(String time) => 'Attesa stimata: $time';
  @override
  String get rankedCancel => 'Annulla';
  @override
  String get rankedFound => 'Tavolo trovato!';
  @override
  String get rankedTestMatch => 'PROVA · NON CLASSIFICATA';
  @override
  String get rankedWarning => 'Chi abbandona le partite finisce a giocare con chi abbandona.';
  @override
  String rankedCooldown(String time) => 'Troppi abbandoni: puoi rientrare tra $time.';
  @override
  String get rankedLobbyTitle => 'SALA D\'ATTESA';
  @override
  String rankedSeats(int seated, int size) => '$seated/$size al tavolo';
  @override
  String rankedMissing(int missing) => missing == 1 ? 'Manca una persona' : 'Mancano $missing persone';
  @override
  String rankedStartsIn(int seconds) => 'Tavolo pieno: si comincia tra $seconds';
  @override
  String get rankedLeaveLobby => 'Esci dalla sala';
  @override
  String get rankedNoPenalty => 'Prima che cominci si può uscire senza penalità.';
  @override
  String get rankedTipsTitle => 'MENTRE ASPETTI';
  @override
  List<String> get rankedTips => const [
        'Di giorno parla, ma non troppo: chi parla troppo finisce nel mirino.',
        'Un voto deciso all\'ultimo secondo dice molto di chi l\'ha dato.',
        'La famiglia vince quando è tanta quanto la città: contate le teste.',
        'Chi abbandona la partita lascia la squadra in minoranza.',
      ];
  @override
  String tierName(RankTier tier) => switch (tier) {
        RankTier.picciotto => 'Picciotto',
        RankTier.capodecina => 'Capodecina',
        RankTier.caporegime => 'Caporegime',
        RankTier.consigliere => 'Consigliere',
        RankTier.don => 'Don',
      };
  @override
  String get dossierTitle => 'IL TUO FASCICOLO';
  @override
  String get dossierHistory => 'GLI ULTIMI CASI';
  @override
  String get dossierNoHistory => 'Fedina pulita: nessuna partita ancora.';
  @override
  String get dossierSettings => 'Le impostazioni';
  @override
  String get resultsTitle => 'COM\'È ANDATA';
  @override
  String get resultsWon => 'Vittoria';
  @override
  String get resultsLost => 'Sconfitta';
  @override
  String get resultsLeft => 'Hai lasciato la città';
  @override
  String resultsXp(int xp) => '+$xp esperienza';
  @override
  String resultsLevelUp(int level) => 'Livello $level!';
  @override
  String resultsCoins(int coins) => '+$coins monete';
  @override
  String get resultsRatingUp => 'Il tuo grado sale';
  @override
  String get resultsRatingDown => 'Il tuo grado scende';
  @override
  String get resultsContinue => 'Continua';

  const ItalianOnlineStrings();

  @override
  String get posterTitle => 'GIOCA\nCON AMICI';
  @override
  String get posterBlurb => 'Una stanza online: un codice o un QR, e ognuno col suo telefono.';
  @override
  String get posterStrip => 'ONLINE';

  @override
  String get unavailableTitle => 'NON DISPONIBILE';
  @override
  String get unavailableBody =>
      'Il gioco online non è disponibile in questa versione. Un telefono per tutti funziona come sempre.';

  @override
  String get loginTitle => 'CHI SEI?';
  @override
  String get loginBody =>
      'Per giocare online serve un account: il tuo profilo e i tuoi amici ti seguono su ogni telefono.';
  @override
  String get loginApple => 'Entra con Apple';
  @override
  String get loginGoogle => 'Entra con Google';
  @override
  String get loginNoProvider => 'Su questo telefono non c\'è ancora un modo per entrare.';
  @override
  String get loginPrivacy => 'L\'account serve solo al tuo profilo di gioco. Un telefono per tutti resta senza account.';

  @override
  String get signIn => 'ACCEDI';
  @override
  String get coachSignIn => 'Accedi per giocare online';
  @override
  String roomLinkSignIn(String code) => 'Accedi per entrare nella stanza $code.';
  @override
  String get roomLinkInvalid => 'Questo link non porta a nessuna stanza.';
  @override
  String get technicalReason => 'Motivo tecnico';
  @override
  String get pickHandle => 'Scegli il tuo nome';
  @override
  String levelShort(int level) => 'LIV. $level';
  @override
  String get level => 'LIVELLO';
  @override
  String get coins => 'MONETE';
  @override
  String xpProgress(int xp, int next) => '$xp su $next punti esperienza';

  @override
  String get testAccount => 'Account di prova';
  @override
  String get testAccountBody =>
      'Solo per provare l\'app da un altro telefono: entra con email e password, o crea l\'account se non c\'è.';
  @override
  String get emailLabel => 'Indirizzo email';
  @override
  String get passwordLabel => 'Password (almeno 6 caratteri)';
  @override
  String get testAccountSubmit => 'ENTRA O CREA';

  @override
  String get setupTitle => 'IL TUO PROFILO';
  @override
  String get setupBody => 'Il tuo nome unico è anche il nome che tutti vedono: nella stanza, al tavolo e tra gli amici.';
  @override
  String get handleLabel => 'Nome unico';
  @override
  String get handleHint => 'es. marco.rossi';
  @override
  String get save => 'SALVA';
  @override
  String get handleInvalid => 'Da 3 a 12 caratteri: lettere minuscole, cifre, punto e trattino basso.';
  @override
  String get handleChecking => 'Controllo se è libero…';
  @override
  String get handleFree => 'Libero: è tuo, se lo vuoi.';
  @override
  String handleProblem(HandleProblem problem) => switch (problem) {
        HandleProblem.tooShort => 'Almeno 3 caratteri.',
        HandleProblem.tooLong => 'Al massimo 12 caratteri.',
        HandleProblem.characters => 'Solo lettere minuscole, cifre, punto e trattino basso.',
        HandleProblem.start => 'Non può iniziare con un punto o un trattino basso.',
        HandleProblem.endsWithDot => 'Non può finire con un punto.',
        HandleProblem.doubleDot => 'Niente due punti di fila.',
        HandleProblem.tooManySymbols => 'Al massimo tre segni di fila.',
        HandleProblem.botName => 'I nomi che cominciano con «bot» sono dei bot.',
        HandleProblem.notAllowed => 'Nome non consentito.',
      };

  @override
  String get hubTitle => 'GIOCA CON AMICI';
  @override
  String signedInAs(String name) => 'Sei dentro come $name';
  @override
  String get hubCreate => 'APRI UNA STANZA';
  @override
  String get hubJoin => 'ENTRA CON UN CODICE';
  @override
  String get friends => 'AMICI';
  @override
  String get signOut => 'Esci dall\'account';

  @override
  String get joinTitle => 'ENTRA NELLA STANZA';
  @override
  String get codeLabel => 'Codice della stanza';
  @override
  String get joinSubmit => 'ENTRA';
  @override
  String get scan => 'Inquadra il QR';
  @override
  String get codeInvalid => 'Il codice ha sei caratteri, senza 0, O, 1, I e L.';
  @override
  String get scanTitle => 'INQUADRA IL QR';
  @override
  String get scanHint => 'Inquadra il QR sul telefono di chi ha aperto la stanza.';
  @override
  String get scanDenied => 'Senza fotocamera il QR non si legge: scrivi il codice.';

  @override
  String get roomTitle => 'LA STANZA';
  @override
  String get roomShareHint => 'Fai inquadrare il QR, o detta il codice.';
  @override
  String roomSeated(int seated, int max) => '$seated su $max al tavolo';
  @override
  String get hostBadge => 'PADRONE DI CASA';
  @override
  String get addFriend => 'Chiedi l\'amicizia';
  @override
  String friendRequestSent(String name) => 'Richiesta mandata a $name.';
  @override
  String nowFriends(String name) => 'Tu e $name ora siete amici.';
  @override
  @override
  String get leaveRoom => 'ESCI DALLA STANZA';
  @override
  String get leaveConfirmTitle => 'Esci dalla stanza?';
  @override
  String get leaveConfirmBody => 'Il tuo posto al tavolo si libera.';
  @override
  String get leaveConfirm => 'ESCI';
  @override
  String get stay => 'RESTA';
  @override
  String get chooseHostTitle => 'A chi lasci la stanza?';
  @override
  String get chooseHostBody => 'Sei il padrone di casa: scegli chi prende il tuo posto, poi esci.';
  @override
  String get addBot => '+ BOT';
  @override
  String get removeBot => 'Togli il bot';
  @override
  String get botBadge => 'BOT DI PROVA';
  @override
  String get startGame => 'INIZIA LA PARTITA';
  @override
  String startNeeds(int players) => 'Servono almeno $players al tavolo: fai entrare qualcuno o aggiungi un bot.';
  @override
  String get waitingForHost => 'Aspettiamo che il padrone di casa dia le carte.';
  @override
  String get rejoin => 'RIENTRA AL TAVOLO';
  @override
  String get reconnecting => 'Rientro al tavolo…';

  @override
  String get gameConnecting => 'Ci si siede al tavolo…';
  @override
  String get yourCard => 'LA TUA CARTA';
  @override
  String get yourCardHint => 'Tienila per te: gli altri vedono solo la loro.';
  @override
  String waitingForOthers(int pending) =>
      pending == 1 ? 'Aspettiamo l\'ultimo che deve ancora scegliere.' : 'Aspettiamo gli altri: ne mancano $pending.';
  @override
  String get youAreOut => 'Sei fuori dal gioco. Guarda come va a finire, e zitto.';
  @override
  String get voteTitle => 'IL VOTO DELLA PIAZZA';
  @override
  String get voteHint => 'Tocca chi vuoi condannare. Puoi cambiare idea finché il voto è aperto.';
  @override
  String get abstain => 'MI ASTENGO';
  @override
  String votedFor(String name) => 'Hai votato $name';
  @override
  String get abstained => 'Ti sei astenuto';
  @override
  String votesCast(int votes, int alive) => '$votes voti su $alive';
  @override
  String closesIn(String time) => 'Il voto si chiude tra $time';
  @override
  String get rejected => 'Mossa non valida: riprova.';
  @override
  String get serverSilent => 'Il server non risponde: controlla la connessione.';
  @override
  String get backToRoom => 'TORNA ALLA STANZA';
  @override
  String timeLeft(String time) => 'Mancano $time';
  @override
  String get startingSoon => 'Si parte tutti insieme…';
  @override
  String get ready => 'PRONTO';
  @override
  String get readyWaiting => 'Registrato ✓ Aspettiamo gli altri.';
  @override
  String get moveRegistered => 'Registrato ✓';
  @override
  String get voteRegistered => 'registrato ✓';
  @override
  String get sending => 'Invio…';
  @override
  String get offlineBadge => 'assente';
  @override
  String leftTown(String name, String role) => '$name ha lasciato la città. Era $role.';
  @override
  String get gameClosed => 'La partita è stata chiusa: non giocava più nessuno.';
  @override
  String get fateLeft => 'Ha lasciato la città';
  @override
  String get youLeftTown => 'Sei rimasto via troppo: hai lasciato la città. Guarda come va a finire.';
  @override
  String get youLookOffline => 'Il server non ti sente: per gli altri sei assente.';
  @override
  String get connectionLost => 'Connessione persa.';
  @override
  String get abstainTag => 'astenuto';
  @override
  String votesFor(int votes) => votes == 1 ? '1 voto' : '$votes voti';
  @override
  String get nightTitleOnline => 'LA NOTTE';
  @override
  String get discussionTitle => 'SI DISCUTE IN PIAZZA';
  @override
  String get discussionHint => 'Dite la vostra in chat. Poi si vota.';
  @override
  String get accusedTag => 'ACCUSATO';
  @override
  String get verdictWaiting => 'La piazza ha deciso.';
  @override
  String get chatHint => 'Scrivi…';
  @override
  String get chatLobby => 'STANZA';
  @override
  String get chatTown => 'PIAZZA';
  @override
  String get chatFamily => 'FAMIGLIA';
  @override
  String get chatEmpty => 'Ancora nessun messaggio.';
  @override
  String get chatNightClosed => 'Di notte la piazza tace.';
  @override
  String get chatDead => 'Dall\'aldilà si legge soltanto.';
  @override
  String get chatSilenced => 'Il Sarto ti ha cucito la bocca: oggi leggi e voti, ma non scrivi.';
  @override
  String get chatSend => 'Invia';

  @override
  String get searchHint => 'Cerca per nome unico';
  @override
  String get requests => 'RICHIESTE';
  @override
  String get yourFriends => 'I TUOI AMICI';
  @override
  String get waiting => 'IN ATTESA';
  @override
  String get friendsEmpty => 'Nessun amico, per ora. Cercali per nome unico o aggiungili da una stanza.';
  @override
  String get noResults => 'Nessuno con questo nome.';
  @override
  String get accept => 'Accetta';
  @override
  String get decline => 'Rifiuta';
  @override
  String get add => 'Aggiungi';
  @override
  String get remove => 'Togli';
  @override
  String get withdraw => 'Ritira';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Prima bisogna entrare con un account.',
        OnlineFailure.appleDisabled => 'Accesso con Apple non attivo sul server.',
        OnlineFailure.googleDisabled => 'Accesso con Google non attivo sul server.',
        OnlineFailure.emailDisabled => 'Accesso con email non attivo sul server.',
        OnlineFailure.wrongPassword => 'Password sbagliata per questa email.',
        OnlineFailure.weakPassword => 'Password troppo debole: almeno 6 caratteri.',
        OnlineFailure.invalidEmail => 'Questa email non sembra valida.',
        OnlineFailure.emailNotConfirmed => 'Il server chiede di confermare l\'email: per le prove va spento.',
        OnlineFailure.profileIncomplete => 'Prima finisci il tuo profilo.',
        OnlineFailure.handleTaken => 'Questo nome unico è già preso.',
        OnlineFailure.invalidHandle => 'Nome non valido.',
        OnlineFailure.handleNotAllowed => 'Nome non consentito.',
        OnlineFailure.roomNotFound => 'Nessuna stanza con questo codice.',
        OnlineFailure.roomClosed => 'In quella stanza si gioca già.',
        OnlineFailure.roomFull => 'La stanza è piena.',
        OnlineFailure.hostMustChoose => 'Prima scegli a chi lasciare la stanza.',
        OnlineFailure.playerNotFound => 'Giocatore non trovato.',
        OnlineFailure.notAllowed => 'Non si può.',
        OnlineFailure.requestNotFound => 'La richiesta non c\'è più.',
        OnlineFailure.messageBlocked => 'Questo messaggio non si può mandare.',
        OnlineFailure.tooManyMessages => 'Piano: troppi messaggi di fila.',
        OnlineFailure.chatClosed => 'Adesso non puoi scrivere qui.',
        OnlineFailure.notEnoughCoins => 'Non hai abbastanza monete.',
        OnlineFailure.alreadyOwned => 'Questo pezzo è già tuo.',
        OnlineFailure.notOwned => 'Prima devi comprarlo.',
        OnlineFailure.itemNotFound => 'Questo pezzo non è più in bottega.',
        OnlineFailure.cancelled => 'Accesso annullato.',
        OnlineFailure.rankedCooldown => 'Troppi abbandoni: aspetta un po\' prima di rientrare.',
        OnlineFailure.alreadyInGame => 'Sei già in una partita.',
        OnlineFailure.network => 'Niente rete. Riprova fra poco.',
        OnlineFailure.unknown => 'Qualcosa è andato storto. Riprova.',
      };
}

final class EnglishOnlineStrings extends OnlineStrings {
  @override
  String get rankedQueueTitle => 'RANKED';
  @override
  String get rankedStart => 'Find a game';
  @override
  String get rankedSearching => 'Looking for new faces in town…';
  @override
  String rankedWaiting(int people) => '$people waiting';
  @override
  String rankedEstimate(String time) => 'Estimated wait: $time';
  @override
  String get rankedCancel => 'Cancel';
  @override
  String get rankedFound => 'Table found!';
  @override
  String get rankedTestMatch => 'TEST · UNRANKED';
  @override
  String get rankedWarning => 'Players who leave games end up playing with players who leave.';
  @override
  String rankedCooldown(String time) => 'Too many games left: you can queue again in $time.';
  @override
  String get rankedLobbyTitle => 'WAITING ROOM';
  @override
  String rankedSeats(int seated, int size) => '$seated/$size at the table';
  @override
  String rankedMissing(int missing) => missing == 1 ? 'One more player needed' : '$missing more players needed';
  @override
  String rankedStartsIn(int seconds) => 'Table full: starting in $seconds';
  @override
  String get rankedLeaveLobby => 'Leave the room';
  @override
  String get rankedNoPenalty => 'Before the start you can leave with no penalty.';
  @override
  String get rankedTipsTitle => 'WHILE YOU WAIT';
  @override
  List<String> get rankedTips => const [
        'Talk during the day, but not too much: the loudest end up in the crosshairs.',
        'A vote cast at the last second says a lot about who cast it.',
        'The family wins once it matches the town in number: count heads.',
        'Leaving a game leaves your team short-handed.',
      ];
  @override
  String tierName(RankTier tier) => switch (tier) {
        RankTier.picciotto => 'Picciotto',
        RankTier.capodecina => 'Capodecina',
        RankTier.caporegime => 'Caporegime',
        RankTier.consigliere => 'Consigliere',
        RankTier.don => 'Don',
      };
  @override
  String get dossierTitle => 'PERSONAL FILE';
  @override
  String get dossierHistory => 'RECENT CASES';
  @override
  String get dossierNoHistory => 'Clean record: no games yet.';
  @override
  String get dossierSettings => 'Settings';
  @override
  String get resultsTitle => 'HOW IT WENT';
  @override
  String get resultsWon => 'Victory';
  @override
  String get resultsLost => 'Defeat';
  @override
  String get resultsLeft => 'You left town';
  @override
  String resultsXp(int xp) => '+$xp XP';
  @override
  String resultsLevelUp(int level) => 'Level $level!';
  @override
  String resultsCoins(int coins) => '+$coins coins';
  @override
  String get resultsRatingUp => 'Your rank goes up';
  @override
  String get resultsRatingDown => 'Your rank goes down';
  @override
  String get resultsContinue => 'Continue';

  const EnglishOnlineStrings();

  @override
  String get posterTitle => 'PLAY WITH\nFRIENDS';
  @override
  String get posterBlurb => 'An online room: a code or a QR, everyone on their own phone.';
  @override
  String get posterStrip => 'ONLINE';

  @override
  String get unavailableTitle => 'UNAVAILABLE';
  @override
  String get unavailableBody => 'Online play is unavailable in this version. One phone for all works as always.';

  @override
  String get loginTitle => 'WHO ARE YOU?';
  @override
  String get loginBody => 'Online play needs an account: your profile and your friends follow you to every phone.';
  @override
  String get loginApple => 'Sign in with Apple';
  @override
  String get loginGoogle => 'Sign in with Google';
  @override
  String get loginNoProvider => 'There is no way to sign in on this phone yet.';
  @override
  String get loginPrivacy => 'The account is only for your game profile. One phone for all needs no account.';

  @override
  String get signIn => 'SIGN IN';
  @override
  String get coachSignIn => 'Sign in to play online';
  @override
  String roomLinkSignIn(String code) => 'Sign in to join room $code.';
  @override
  String get roomLinkInvalid => 'This link does not lead to any room.';
  @override
  String get technicalReason => 'Technical reason';
  @override
  String get pickHandle => 'Pick your handle';
  @override
  String levelShort(int level) => 'LV. $level';
  @override
  String get level => 'LEVEL';
  @override
  String get coins => 'COINS';
  @override
  String xpProgress(int xp, int next) => '$xp of $next experience points';

  @override
  String get testAccount => 'Test account';
  @override
  String get testAccountBody =>
      'Only for trying the app from another phone: sign in with email and password, or create the account if missing.';
  @override
  String get emailLabel => 'Email address';
  @override
  String get passwordLabel => 'Password (at least 6 characters)';
  @override
  String get testAccountSubmit => 'SIGN IN OR CREATE';

  @override
  String get setupTitle => 'YOUR PROFILE';
  @override
  String get setupBody => 'Your handle is also the name everyone sees: in the room, at the table and among friends.';
  @override
  String get handleLabel => 'Handle';
  @override
  String get handleHint => 'like mark.smith';
  @override
  String get save => 'SAVE';
  @override
  String get handleInvalid => '3 to 12 characters: lowercase letters, digits, dot and underscore.';
  @override
  String get handleChecking => 'Checking if it is free…';
  @override
  String get handleFree => 'Free: it is yours if you want it.';
  @override
  String handleProblem(HandleProblem problem) => switch (problem) {
        HandleProblem.tooShort => 'At least 3 characters.',
        HandleProblem.tooLong => '12 characters at most.',
        HandleProblem.characters => 'Only lowercase letters, digits, dot and underscore.',
        HandleProblem.start => 'It cannot start with a dot or an underscore.',
        HandleProblem.endsWithDot => 'It cannot end with a dot.',
        HandleProblem.doubleDot => 'No two dots in a row.',
        HandleProblem.tooManySymbols => 'At most three symbols in a row.',
        HandleProblem.botName => 'Names starting with "bot" belong to bots.',
        HandleProblem.notAllowed => 'Name not allowed.',
      };

  @override
  String get hubTitle => 'PLAY WITH FRIENDS';
  @override
  String signedInAs(String name) => 'Signed in as $name';
  @override
  String get hubCreate => 'OPEN A ROOM';
  @override
  String get hubJoin => 'JOIN WITH A CODE';
  @override
  String get friends => 'FRIENDS';
  @override
  String get signOut => 'Sign out';

  @override
  String get joinTitle => 'JOIN A ROOM';
  @override
  String get codeLabel => 'Room code';
  @override
  String get joinSubmit => 'JOIN';
  @override
  String get scan => 'Scan the QR';
  @override
  String get codeInvalid => 'The code has six characters, without 0, O, 1, I or L.';
  @override
  String get scanTitle => 'SCAN THE QR';
  @override
  String get scanHint => 'Point the camera at the QR on the host\'s phone.';
  @override
  String get scanDenied => 'Without the camera the QR cannot be read: type the code instead.';

  @override
  String get roomTitle => 'THE ROOM';
  @override
  String get roomShareHint => 'Let them scan the QR, or read out the code.';
  @override
  String roomSeated(int seated, int max) => '$seated of $max at the table';
  @override
  String get hostBadge => 'HOST';
  @override
  String get addFriend => 'Add friend';
  @override
  String friendRequestSent(String name) => 'Friend request sent to $name.';
  @override
  String nowFriends(String name) => 'You and $name are now friends.';
  @override
  @override
  String get leaveRoom => 'LEAVE THE ROOM';
  @override
  String get leaveConfirmTitle => 'Leave the room?';
  @override
  String get leaveConfirmBody => 'Your seat at the table opens up.';
  @override
  String get leaveConfirm => 'LEAVE';
  @override
  String get stay => 'STAY';
  @override
  String get chooseHostTitle => 'Who takes over the room?';
  @override
  String get chooseHostBody => 'You are the host: pick who takes your place, then leave.';
  @override
  String get addBot => '+ BOT';
  @override
  String get removeBot => 'Remove the bot';
  @override
  String get botBadge => 'TEST BOT';
  @override
  String get startGame => 'START THE GAME';
  @override
  String startNeeds(int players) => 'At least $players at the table: let someone in or add a bot.';
  @override
  String get waitingForHost => 'Waiting for the host to deal the cards.';
  @override
  String get rejoin => 'BACK TO THE TABLE';
  @override
  String get reconnecting => 'Getting back to the table…';

  @override
  String get gameConnecting => 'Taking a seat…';
  @override
  String get yourCard => 'YOUR CARD';
  @override
  String get yourCardHint => 'Keep it to yourself: the others only see theirs.';
  @override
  String waitingForOthers(int pending) =>
      pending == 1 ? 'Waiting for the last one to choose.' : 'Waiting for the others: $pending still to choose.';
  @override
  String get youAreOut => 'You are out of the game. Watch how it ends, and keep quiet.';
  @override
  String get voteTitle => 'THE TOWN VOTES';
  @override
  String get voteHint => 'Tap who you want to condemn. You can change your mind while the vote is open.';
  @override
  String get abstain => 'I ABSTAIN';
  @override
  String votedFor(String name) => 'You voted for $name';
  @override
  String get abstained => 'You abstained';
  @override
  String votesCast(int votes, int alive) => '$votes votes of $alive';
  @override
  String closesIn(String time) => 'The vote closes in $time';
  @override
  String get rejected => 'That move is not allowed: try again.';
  @override
  String get serverSilent => 'The server is not answering: check your connection.';
  @override
  String get backToRoom => 'BACK TO THE ROOM';
  @override
  String timeLeft(String time) => '$time left';
  @override
  String get startingSoon => 'Starting together…';
  @override
  String get ready => 'READY';
  @override
  String get readyWaiting => 'Registered ✓ Waiting for the others.';
  @override
  String get moveRegistered => 'Registered ✓';
  @override
  String get voteRegistered => 'registered ✓';
  @override
  String get sending => 'Sending…';
  @override
  String get offlineBadge => 'offline';
  @override
  String leftTown(String name, String role) => '$name left town. They were $role.';
  @override
  String get gameClosed => 'The game was closed: nobody was playing any more.';
  @override
  String get fateLeft => 'Left town';
  @override
  String get youLeftTown => 'You were away too long and left town. Watch how it ends.';
  @override
  String get youLookOffline => 'The server cannot hear you: the others see you as offline.';
  @override
  String get connectionLost => 'Connection lost.';
  @override
  String get abstainTag => 'abstains';
  @override
  String votesFor(int votes) => votes == 1 ? '1 vote' : '$votes votes';
  @override
  String get nightTitleOnline => 'THE NIGHT';
  @override
  String get discussionTitle => 'THE TOWN TALKS';
  @override
  String get discussionHint => 'Have your say in the chat. Then you vote.';
  @override
  String get accusedTag => 'ACCUSED';
  @override
  String get verdictWaiting => 'The town has decided.';
  @override
  String get chatHint => 'Write…';
  @override
  String get chatLobby => 'ROOM';
  @override
  String get chatTown => 'TOWN';
  @override
  String get chatFamily => 'FAMILY';
  @override
  String get chatEmpty => 'No messages yet.';
  @override
  String get chatNightClosed => 'At night the town is silent.';
  @override
  String get chatDead => 'From the afterlife you can only read.';
  @override
  String get chatSilenced => 'The Tailor sewed your lips: today you read and vote, but you cannot write.';
  @override
  String get chatSend => 'Send';

  @override
  String get searchHint => 'Search by handle';
  @override
  String get requests => 'REQUESTS';
  @override
  String get yourFriends => 'YOUR FRIENDS';
  @override
  String get waiting => 'WAITING';
  @override
  String get friendsEmpty => 'No friends yet. Search by handle or add them from a room.';
  @override
  String get noResults => 'Nobody by that handle.';
  @override
  String get accept => 'Accept';
  @override
  String get decline => 'Decline';
  @override
  String get add => 'Add';
  @override
  String get remove => 'Remove';
  @override
  String get withdraw => 'Withdraw';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Sign in with an account first.',
        OnlineFailure.appleDisabled => 'Sign in with Apple is not enabled on the server.',
        OnlineFailure.googleDisabled => 'Sign in with Google is not enabled on the server.',
        OnlineFailure.emailDisabled => 'Email sign-in is not enabled on the server.',
        OnlineFailure.wrongPassword => 'Wrong password for this email.',
        OnlineFailure.weakPassword => 'Password too weak: at least 6 characters.',
        OnlineFailure.invalidEmail => 'That email does not look valid.',
        OnlineFailure.emailNotConfirmed => 'The server wants the email confirmed: turn that off for testing.',
        OnlineFailure.profileIncomplete => 'Finish your profile first.',
        OnlineFailure.handleTaken => 'That handle is already taken.',
        OnlineFailure.invalidHandle => 'Invalid name.',
        OnlineFailure.handleNotAllowed => 'Name not allowed.',
        OnlineFailure.roomNotFound => 'No room with that code.',
        OnlineFailure.roomClosed => 'That room is already playing.',
        OnlineFailure.roomFull => 'The room is full.',
        OnlineFailure.hostMustChoose => 'First pick who takes over the room.',
        OnlineFailure.playerNotFound => 'Player not found.',
        OnlineFailure.notAllowed => 'Not allowed.',
        OnlineFailure.requestNotFound => 'That request is gone.',
        OnlineFailure.messageBlocked => 'That message can\'t be sent.',
        OnlineFailure.tooManyMessages => 'Easy: too many messages in a row.',
        OnlineFailure.chatClosed => 'You can\'t write here right now.',
        OnlineFailure.notEnoughCoins => 'You don\'t have enough coins.',
        OnlineFailure.alreadyOwned => 'You already own this.',
        OnlineFailure.notOwned => 'Buy it first.',
        OnlineFailure.itemNotFound => 'This item is no longer in the shop.',
        OnlineFailure.cancelled => 'Sign-in cancelled.',
        OnlineFailure.rankedCooldown => 'Too many games left: wait a little before queueing.',
        OnlineFailure.alreadyInGame => 'You are already in a game.',
        OnlineFailure.network => 'No connection. Try again shortly.',
        OnlineFailure.unknown => 'Something went wrong. Try again.',
      };
}
