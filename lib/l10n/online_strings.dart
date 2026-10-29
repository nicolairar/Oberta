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

  // «Entra con email», senza password: il codice e il link della mail.
  String get loginEmail;
  String get emailBody;
  String get emailBodyCodeOnly;
  String get emailLabel;
  String get emailSend;
  String emailSentTo(String address);
  String emailSentToCodeOnly(String address);
  String get emailCodeLabel;
  String get emailVerify;
  String get emailResend;
  String emailResendIn(int seconds);
  String get emailResent;
  String get emailChange;
  String get emailOtherWays;
  String get emailSpam;

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
  String get botBadge;
  String get testBotsNote;
  String get startGame;
  String startNeeds(int players);
  String get waitingForHost;
  String get rejoin;

  /// Nella stanza, mentre la partita va avanti senza di noi.
  String get gameRunning;
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

  /// I ping falliscono da qualche secondo: si riprova da soli.
  String get syncLost;
  String get backToRoom;
  String timeLeft(String time);
  String get startingSoon;
  String get ready;
  String get readyWaiting;
  String get moveRegistered;
  String get voteRegistered;
  String get sending;
  String get offlineBadge;

  /// Uscire da vivi da una partita in corso.
  String get leaveAbandonWarning;

  /// Uscire da morti: nessuna penalità, ma niente premi.
  String get leaveDeadWarning;

  /// Nei risultati, a chi è rimasto senza giocare.
  String get resultsAfk;
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
  String get rankedStrangers;
  String homeQueued(int n);
  String get rankedSit;
  String get rankedTutorialsTitle;
  String get rankedTutorialsBody;
  String rankedTutorialName(String faction);
  String rankedTutorialPlay(String name);
  String get rankedSkipTutorials;
  String get rankedSkipTitle;
  String get rankedSkipBody;
  String get rankedSkipConfirm;
  String get rankedSkipCancel;
  String get rankedPickTable;
  String get rankedRules;
  String get rankedYourRank;
  String rankedTowards(String tier);
  String get rankedTopTier;
  String rankedTableQueued(int n);
  String get rankedTableIt;
  String get rankedTableEn;
  String homeOnline(int n);
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
  String get dossierConfidential;
  String get dossierName;
  String get dossierRank;
  String get dossierExperience;

  // Steam: il nome Steam, l'immagine del profilo, i nomi proposti.
  String steamPersona(String persona);
  String get pictureLabel;
  String get pictureGame;
  String get pictureSteam;
  String handleFromSteam(String persona);
  String get handleSuggestions;

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

  // Un dispositivo alla volta.
  String get deviceOneAtATime;
  String deviceContested(String other);
  String get deviceDisplacedTitle;
  String deviceDisplaced(String other);
  String get devicePlayHere;

  // Aggiornamento obbligatorio.
  String get updateTitle;
  String updateNewRelease(String latest, String current);
  String get updateServer;
  String get updateButton;

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
    'deviceOneAtATime': deviceOneAtATime,
    'deviceContested': deviceContested('Mac'),
    'deviceDisplacedTitle': deviceDisplacedTitle,
    'deviceDisplaced': deviceDisplaced('iPhone'),
    'devicePlayHere': devicePlayHere,
    'updateTitle': updateTitle,
    'updateNewRelease': updateNewRelease('1.2.0', '1.1.0'),
    'updateServer': updateServer,
    'updateButton': updateButton,
    'roomLinkInvalid': roomLinkInvalid,
    'technicalReason': technicalReason,
    'pickHandle': pickHandle,
    'levelShort': levelShort(3),
    'level': level,
    'coins': coins,
    'xpProgress': xpProgress(40, 300),
    'loginEmail': loginEmail,
    'emailBody': emailBody,
    'emailBodyCodeOnly': emailBodyCodeOnly,
    'emailLabel': emailLabel,
    'emailSend': emailSend,
    'emailSentTo': emailSentTo('anna@example.com'),
    'emailSentToCodeOnly': emailSentToCodeOnly('anna@example.com'),
    'emailCodeLabel': emailCodeLabel,
    'emailVerify': emailVerify,
    'emailResend': emailResend,
    'emailResendIn': emailResendIn(42),
    'emailResent': emailResent,
    'emailChange': emailChange,
    'emailOtherWays': emailOtherWays,
    'emailSpam': emailSpam,
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
    'roomSeated': roomSeated(3, 12),
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
    'botBadge': botBadge,
    'testBotsNote': testBotsNote,
    'startGame': startGame,
    'startNeeds': startNeeds(4),
    'waitingForHost': waitingForHost,
    'rejoin': rejoin,
    'gameRunning': gameRunning,
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
    'syncLost': syncLost,
    'backToRoom': backToRoom,
    'timeLeft': timeLeft('0:30'),
    'startingSoon': startingSoon,
    'ready': ready,
    'readyWaiting': readyWaiting,
    'moveRegistered': moveRegistered,
    'voteRegistered': voteRegistered,
    'sending': sending,
    'offlineBadge': offlineBadge,
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
    'rankedStrangers': rankedStrangers,
    'homeQueued': homeQueued(24),
    'rankedSit': rankedSit,
    'rankedTutorialsTitle': rankedTutorialsTitle,
    'rankedTutorialsBody': rankedTutorialsBody,
    for (final f in ['family', 'town', 'solo']) 'rankedTutorialName.$f': rankedTutorialName(f),
    'rankedTutorialPlay': rankedTutorialPlay(rankedTutorialName('family')),
    'rankedSkipTutorials': rankedSkipTutorials,
    'rankedSkipTitle': rankedSkipTitle,
    'rankedSkipBody': rankedSkipBody,
    'rankedSkipConfirm': rankedSkipConfirm,
    'rankedSkipCancel': rankedSkipCancel,
    'rankedPickTable': rankedPickTable,
    'rankedRules': rankedRules,
    'rankedYourRank': rankedYourRank,
    'rankedTowards': rankedTowards('Don'),
    'rankedTopTier': rankedTopTier,
    'rankedTableQueued': rankedTableQueued(24),
    'rankedTableIt': rankedTableIt,
    'rankedTableEn': rankedTableEn,
    'homeOnline': homeOnline(31),
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
    'dossierConfidential': dossierConfidential,
    'dossierName': dossierName,
    'dossierRank': dossierRank,
    'dossierExperience': dossierExperience,
    'steamPersona': steamPersona('Don Vito'),
    'pictureLabel': pictureLabel,
    'pictureGame': pictureGame,
    'pictureSteam': pictureSteam,
    'handleFromSteam': handleFromSteam('Don Vito'),
    'handleSuggestions': handleSuggestions,
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
  String get rankedStrangers => 'Chi siede con te lo scopri quando si gioca.';
  @override
  String homeQueued(int n) => '$n in coda per un tavolo';
  @override
  String get rankedSit => 'Siediti al tavolo';
  @override
  String get rankedTutorialsTitle => 'Prima, le tre mani di prova';
  @override
  String get rankedTutorialsBody =>
      'In classificata si siede solo chi ha giocato le tre mani di prova: la Famiglia, la Città e chi gioca da solo. Con gli amici, invece, si gioca subito.';
  @override
  String rankedTutorialName(String faction) => switch (faction) {
        'family' => 'la Famiglia',
        'town' => 'la Città',
        _ => 'chi gioca da solo',
      };
  @override
  String rankedTutorialPlay(String name) => 'Gioca la mano: $name';
  @override
  String get rankedSkipTutorials => 'Conosco già il gioco';
  @override
  String get rankedSkipTitle => 'Sicuro?';
  @override
  String get rankedSkipBody => 'Salti tutti i tutorial e vai dritto in classificata.';
  @override
  String get rankedSkipConfirm => 'Sì, salto i tutorial';
  @override
  String get rankedSkipCancel => 'Ci ripenso';
  @override
  String get rankedPickTable => 'SCEGLI IL TAVOLO';
  @override
  String get rankedRules => '12 giocatori · turni a tempo · chi abbandona paga';
  @override
  String get rankedYourRank => 'IL TUO GRADO';
  @override
  String rankedTowards(String tier) => 'verso $tier';
  @override
  String get rankedTopTier => 'in cima alla famiglia';
  @override
  String rankedTableQueued(int n) => '$n in coda';
  @override
  String get rankedTableIt => 'Si parla italiano';
  @override
  String get rankedTableEn => 'Si parla inglese';
  @override
  String homeOnline(int n) => '$n giocatori in giro per la città';
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
  String get dossierConfidential => 'RISERVATO';
  @override
  String get dossierName => 'NOMINATIVO';
  @override
  String steamPersona(String persona) => 'Su Steam: $persona';
  @override
  String get pictureLabel => 'Immagine del profilo';
  @override
  String get pictureGame => 'Avatar del gioco';
  @override
  String get pictureSteam => 'Immagine di Steam';
  @override
  String handleFromSteam(String persona) => 'Preso dal tuo nome Steam, «$persona». Va bene? Salva, o cambialo.';
  @override
  String get handleSuggestions => 'Liberi qui vicino:';
  @override
  String get dossierRank => 'GRADO';
  @override
  String get dossierExperience => 'ESPERIENZA';
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
  String get loginEmail => 'Entra con email';
  @override
  String get emailBody => 'Ti mandiamo una mail con un codice di 6 cifre e un link per entrare. Niente password.';
  @override
  String get emailBodyCodeOnly => 'Ti mandiamo una mail con un codice di 6 cifre da scrivere qui. Niente password.';
  @override
  String get emailLabel => 'Indirizzo email';
  @override
  String get emailSend => 'MANDAMI IL CODICE';
  @override
  String emailSentTo(String address) =>
      'Abbiamo scritto a $address. Scrivi il codice della mail, oppure tocca il link: l\'app si apre già dentro.';
  @override
  String emailSentToCodeOnly(String address) => 'Abbiamo scritto a $address. Scrivi qui il codice della mail.';
  @override
  String get emailCodeLabel => 'Codice di 6 cifre';
  @override
  String get emailVerify => 'ENTRA';
  @override
  String get emailResend => 'Rimanda il codice';
  @override
  String emailResendIn(int seconds) => 'Rimanda il codice tra $seconds s';
  @override
  String get emailResent => 'Codice nuovo in arrivo: vale solo l\'ultimo.';
  @override
  String get emailChange => 'Cambia indirizzo';
  @override
  String get emailOtherWays => 'Altri modi per entrare';
  @override
  String get emailSpam => 'Non arriva? Guarda nella posta indesiderata.';

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
  String get botBadge => 'BOT DI PROVA';
  @override
  String get testBotsNote => 'In prova: i posti vuoti li prendono i bot.';
  @override
  String get startGame => 'INIZIA LA PARTITA';
  @override
  String startNeeds(int players) => 'Servono almeno $players persone al tavolo: fai entrare qualcuno.';
  @override
  String get waitingForHost => 'Aspettiamo che il padrone di casa dia le carte.';
  @override
  String get rejoin => 'RIENTRA AL TAVOLO';
  @override
  String get gameRunning => 'La partita è in corso.';
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
  String get syncLost => 'Connessione persa, riprovo…';
  @override
  String get backToRoom => 'TORNA ALLA STANZA';
  @override
  String timeLeft(String time) => 'Mancano $time';
  @override
  String get startingSoon => 'Si parte tutti insieme…';
  @override
  String get ready => 'PRONTO';
  @override
  String get readyWaiting => 'Aspettiamo gli altri…';
  @override
  String get moveRegistered => 'Fatto. La città dorme…';
  @override
  String get voteRegistered => 'registrato ✓';
  @override
  String get sending => 'Invio…';
  @override
  String get offlineBadge => 'assente';
  @override
  String get leaveAbandonWarning =>
      'Se esci adesso conta come abbandono: niente punti e niente monete, anche se poi la tua squadra vince.';
  @override
  String get leaveDeadWarning => 'Puoi uscire senza penalità, ma se poi la tua squadra vince non prendi premi.';
  @override
  String get resultsAfk => 'Eri assente: niente premi';
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
  String get deviceOneAtATime => 'Puoi giocare su un solo dispositivo alla volta';
  @override
  String deviceContested(String other) => 'Il tuo account è aperto anche su: $other. Dove vuoi giocare?';
  @override
  String get deviceDisplacedTitle => 'Sei connesso su un altro dispositivo';
  @override
  String deviceDisplaced(String other) => 'Adesso giochi su: $other. Se vuoi, riprendi da qui.';
  @override
  String get devicePlayHere => 'GIOCO QUA';

  @override
  String get updateTitle => 'Aggiornamento obbligatorio';
  @override
  String updateNewRelease(String latest, String current) =>
      'È uscita la versione $latest e questa è la $current. Aggiorna per continuare a giocare.';
  @override
  String get updateServer => 'Questa versione non è più ammessa al tavolo. Aggiorna per continuare a giocare.';
  @override
  String get updateButton => 'AGGIORNA';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Prima bisogna entrare con un account.',
        OnlineFailure.appleDisabled => 'Accesso con Apple non attivo sul server.',
        OnlineFailure.googleDisabled => 'Accesso con Google non attivo sul server.',
        OnlineFailure.emailDisabled => 'Accesso con email non attivo sul server.',
        OnlineFailure.invalidEmail => 'Questa email non sembra valida.',
        OnlineFailure.emailCodeWrong => 'Codice sbagliato: controlla l\'ultima mail che ti abbiamo mandato.',
        OnlineFailure.emailCodeExpired => 'Il codice è scaduto: chiedine uno nuovo.',
        OnlineFailure.emailLinkExpired => 'Il link è scaduto o è già stato usato: scrivi il codice della mail, o chiedine uno nuovo.',
        OnlineFailure.emailRateLimited => 'Troppe mail di fila: aspetta un minuto e riprova.',
        OnlineFailure.emailNotSent => 'La mail non è partita: riprova tra poco.',
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
        OnlineFailure.tooManyReports => 'Hai già mandato molte segnalazioni. Riprova più tardi.',
        OnlineFailure.chatClosed => 'Adesso non puoi scrivere qui.',
        OnlineFailure.reactionClosed => 'Adesso niente gesti: solo di giorno, e solo fra i vivi.',
        OnlineFailure.reactionCooldown => 'Piano con i gesti: aspetta qualche secondo.',
        OnlineFailure.reactionCap => 'Basta gesti per questa partita.',
        OnlineFailure.notEnoughCoins => 'Non hai abbastanza monete.',
        OnlineFailure.alreadyOwned => 'Questo pezzo è già tuo.',
        OnlineFailure.notOwned => 'Prima devi comprarlo.',
        OnlineFailure.itemNotFound => 'Questo pezzo non è più in bottega.',
        OnlineFailure.cancelled => 'Accesso annullato.',
        OnlineFailure.rankedCooldown => 'Troppi abbandoni: aspetta un po\' prima di rientrare.',
        OnlineFailure.alreadyInGame => 'Sei già in una partita.',
        OnlineFailure.tutorialsRequired => 'Per la classificata gioca prima le tre mani di prova.',
        OnlineFailure.otherDevice => 'Sei connesso su un altro dispositivo.',
        OnlineFailure.updateRequired => 'Aggiornamento obbligatorio: scarica la nuova versione.',
        OnlineFailure.linkSameAccount => 'Questo account è già collegato.',
        OnlineFailure.linkConflict => 'Questi due account non si possono unire: hanno già lo stesso tipo di accesso.',
        OnlineFailure.network => 'Niente rete. Riprova fra poco.',
        OnlineFailure.unknown => 'Qualcosa è andato storto. Riprova.',
      };
}

class EnglishOnlineStrings extends OnlineStrings {
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
  String get rankedStrangers => 'You find out who sits with you when the game starts.';
  @override
  String homeQueued(int n) => '$n waiting for a table';
  @override
  String get rankedSit => 'Take a seat';
  @override
  String get rankedTutorialsTitle => 'First, the three practice hands';
  @override
  String get rankedTutorialsBody =>
      'Only players who have finished the three practice hands sit at a ranked table: the Family, the Town and the lone players. With friends, you can play right away.';
  @override
  String rankedTutorialName(String faction) => switch (faction) {
        'family' => 'the Family',
        'town' => 'the Town',
        _ => 'the loner',
      };
  @override
  String rankedTutorialPlay(String name) => 'Play the hand: $name';
  @override
  String get rankedSkipTutorials => 'I already know the game';
  @override
  String get rankedSkipTitle => 'Are you sure?';
  @override
  String get rankedSkipBody => 'You skip every tutorial and go straight to ranked.';
  @override
  String get rankedSkipConfirm => 'Yes, skip the tutorials';
  @override
  String get rankedSkipCancel => 'Never mind';
  @override
  String get rankedPickTable => 'PICK YOUR TABLE';
  @override
  String get rankedRules => '12 players · timed rounds · quitters pay';
  @override
  String get rankedYourRank => 'YOUR RANK';
  @override
  String rankedTowards(String tier) => 'towards $tier';
  @override
  String get rankedTopTier => 'top of the family';
  @override
  String rankedTableQueued(int n) => '$n queued';
  @override
  String get rankedTableIt => 'Italian spoken';
  @override
  String get rankedTableEn => 'English spoken';
  @override
  String homeOnline(int n) => '$n players around town';
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
  String get dossierConfidential => 'CONFIDENTIAL';
  @override
  String get dossierName => 'NAME';
  @override
  String steamPersona(String persona) => 'On Steam: $persona';
  @override
  String get pictureLabel => 'Profile picture';
  @override
  String get pictureGame => 'Game avatar';
  @override
  String get pictureSteam => 'Steam picture';
  @override
  String handleFromSteam(String persona) => 'Taken from your Steam name, “$persona”. Happy with it? Save, or change it.';
  @override
  String get handleSuggestions => 'Free nearby:';
  @override
  String get dossierRank => 'RANK';
  @override
  String get dossierExperience => 'EXPERIENCE';
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
  String get loginEmail => 'Sign in with email';
  @override
  String get emailBody => 'We send you an email with a 6-digit code and a sign-in link. No password.';
  @override
  String get emailBodyCodeOnly => 'We send you an email with a 6-digit code to type here. No password.';
  @override
  String get emailLabel => 'Email address';
  @override
  String get emailSend => 'SEND ME THE CODE';
  @override
  String emailSentTo(String address) =>
      'We wrote to $address. Type the code from the email, or tap the link: the app opens signed in.';
  @override
  String emailSentToCodeOnly(String address) => 'We wrote to $address. Type the code from the email here.';
  @override
  String get emailCodeLabel => '6-digit code';
  @override
  String get emailVerify => 'SIGN IN';
  @override
  String get emailResend => 'Send the code again';
  @override
  String emailResendIn(int seconds) => 'Send again in $seconds s';
  @override
  String get emailResent => 'New code on its way: only the latest one works.';
  @override
  String get emailChange => 'Use another address';
  @override
  String get emailOtherWays => 'Other ways to sign in';
  @override
  String get emailSpam => 'Nothing yet? Check your spam folder.';

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
  String get botBadge => 'TEST BOT';
  @override
  String get testBotsNote => 'Testing: bots take the empty seats.';
  @override
  String get startGame => 'START THE GAME';
  @override
  String startNeeds(int players) => 'At least $players people at the table: let someone in.';
  @override
  String get waitingForHost => 'Waiting for the host to deal the cards.';
  @override
  String get rejoin => 'BACK TO THE TABLE';
  @override
  String get gameRunning => 'The game is on.';
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
  String get syncLost => 'Connection lost, retrying…';
  @override
  String get backToRoom => 'BACK TO THE ROOM';
  @override
  String timeLeft(String time) => '$time left';
  @override
  String get startingSoon => 'Starting together…';
  @override
  String get ready => 'READY';
  @override
  String get readyWaiting => 'Waiting for the others…';
  @override
  String get moveRegistered => 'Done. The city sleeps…';
  @override
  String get voteRegistered => 'registered ✓';
  @override
  String get sending => 'Sending…';
  @override
  String get offlineBadge => 'offline';
  @override
  String get leaveAbandonWarning =>
      'Leaving now counts as quitting: no points and no coins, even if your side wins later.';
  @override
  String get leaveDeadWarning => 'You can leave with no penalty, but if your side wins later you get no rewards.';
  @override
  String get resultsAfk => 'You were away: no rewards';
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
  String get deviceOneAtATime => 'You can play on one device at a time';
  @override
  String deviceContested(String other) => 'Your account is also open on: $other. Where do you want to play?';
  @override
  String get deviceDisplacedTitle => 'You are connected on another device';
  @override
  String deviceDisplaced(String other) => 'You are now playing on: $other. Take it back from here if you like.';
  @override
  String get devicePlayHere => 'PLAY HERE';

  @override
  String get updateTitle => 'Update required';
  @override
  String updateNewRelease(String latest, String current) =>
      'Version $latest is out and this one is $current. Update to keep playing.';
  @override
  String get updateServer => 'This version is no longer allowed at the table. Update to keep playing.';
  @override
  String get updateButton => 'UPDATE';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Sign in with an account first.',
        OnlineFailure.appleDisabled => 'Sign in with Apple is not enabled on the server.',
        OnlineFailure.googleDisabled => 'Sign in with Google is not enabled on the server.',
        OnlineFailure.emailDisabled => 'Email sign-in is not enabled on the server.',
        OnlineFailure.invalidEmail => 'That email does not look valid.',
        OnlineFailure.emailCodeWrong => 'Wrong code: check the latest email we sent you.',
        OnlineFailure.emailCodeExpired => 'The code has expired: ask for a new one.',
        OnlineFailure.emailLinkExpired => 'The link has expired or was already used: type the code from the email, or ask for a new one.',
        OnlineFailure.emailRateLimited => 'Too many emails in a row: wait a minute and try again.',
        OnlineFailure.emailNotSent => 'The email did not go out: try again in a moment.',
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
        OnlineFailure.tooManyReports => 'You have sent many reports already. Try again later.',
        OnlineFailure.chatClosed => 'You can\'t write here right now.',
        OnlineFailure.reactionClosed => 'No gestures now: daytime only, and only among the living.',
        OnlineFailure.reactionCooldown => 'Easy with the gestures: wait a few seconds.',
        OnlineFailure.reactionCap => 'That is enough gestures for this game.',
        OnlineFailure.notEnoughCoins => 'You don\'t have enough coins.',
        OnlineFailure.alreadyOwned => 'You already own this.',
        OnlineFailure.notOwned => 'Buy it first.',
        OnlineFailure.itemNotFound => 'This item is no longer in the shop.',
        OnlineFailure.cancelled => 'Sign-in cancelled.',
        OnlineFailure.rankedCooldown => 'Too many games left: wait a little before queueing.',
        OnlineFailure.alreadyInGame => 'You are already in a game.',
        OnlineFailure.tutorialsRequired => 'Finish the three practice hands to play ranked.',
        OnlineFailure.otherDevice => 'You are connected on another device.',
        OnlineFailure.updateRequired => 'Update required: download the new version.',
        OnlineFailure.linkSameAccount => 'This account is already linked.',
        OnlineFailure.linkConflict => 'These two accounts cannot be merged: they already use the same kind of sign-in.',
        OnlineFailure.network => 'No connection. Try again shortly.',
        OnlineFailure.unknown => 'Something went wrong. Try again.',
      };
}
