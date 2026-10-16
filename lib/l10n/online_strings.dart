import '../online/online_models.dart';

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

  // Il profilo.
  String get setupTitle;
  String get setupBody;
  String get handleLabel;
  String get handleHint;
  String get nameLabel;
  String get save;
  String get handleInvalid;
  String get nameInvalid;

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
  String get startSoon;
  String get leaveRoom;

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
    'setupTitle': setupTitle,
    'setupBody': setupBody,
    'handleLabel': handleLabel,
    'handleHint': handleHint,
    'nameLabel': nameLabel,
    'save': save,
    'handleInvalid': handleInvalid,
    'nameInvalid': nameInvalid,
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
    'startSoon': startSoon,
    'leaveRoom': leaveRoom,
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
  };
}

final class ItalianOnlineStrings extends OnlineStrings {
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
  String get setupTitle => 'IL TUO PROFILO';
  @override
  String get setupBody => 'Gli amici ti cercano col nome unico; al tavolo vedono il nome da mostrare.';
  @override
  String get handleLabel => 'Nome unico';
  @override
  String get handleHint => 'es. marco_rossi';
  @override
  String get nameLabel => 'Nome da mostrare';
  @override
  String get save => 'SALVA';
  @override
  String get handleInvalid => 'Da 3 a 20 fra lettere minuscole, cifre e _.';
  @override
  String get nameInvalid => 'Scrivi un nome, al massimo 24 caratteri.';

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
  String get startSoon => 'INIZIA · PRESTO';
  @override
  String get leaveRoom => 'ESCI DALLA STANZA';

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
        OnlineFailure.profileIncomplete => 'Prima finisci il tuo profilo.',
        OnlineFailure.handleTaken => 'Questo nome unico è già preso.',
        OnlineFailure.invalidHandle => 'Nome non valido.',
        OnlineFailure.roomNotFound => 'Nessuna stanza con questo codice.',
        OnlineFailure.roomClosed => 'In quella stanza si gioca già.',
        OnlineFailure.roomFull => 'La stanza è piena.',
        OnlineFailure.playerNotFound => 'Giocatore non trovato.',
        OnlineFailure.notAllowed => 'Non si può.',
        OnlineFailure.requestNotFound => 'La richiesta non c\'è più.',
        OnlineFailure.cancelled => 'Accesso annullato.',
        OnlineFailure.network => 'Niente rete. Riprova fra poco.',
        OnlineFailure.unknown => 'Qualcosa è andato storto. Riprova.',
      };
}

final class EnglishOnlineStrings extends OnlineStrings {
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
  String get setupTitle => 'YOUR PROFILE';
  @override
  String get setupBody => 'Friends find you by your handle; at the table they see your display name.';
  @override
  String get handleLabel => 'Handle';
  @override
  String get handleHint => 'like mark_smith';
  @override
  String get nameLabel => 'Display name';
  @override
  String get save => 'SAVE';
  @override
  String get handleInvalid => '3 to 20 lowercase letters, digits or _.';
  @override
  String get nameInvalid => 'Enter a name, 24 characters at most.';

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
  String get startSoon => 'START · SOON';
  @override
  String get leaveRoom => 'LEAVE THE ROOM';

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
        OnlineFailure.profileIncomplete => 'Finish your profile first.',
        OnlineFailure.handleTaken => 'That handle is already taken.',
        OnlineFailure.invalidHandle => 'Invalid name.',
        OnlineFailure.roomNotFound => 'No room with that code.',
        OnlineFailure.roomClosed => 'That room is already playing.',
        OnlineFailure.roomFull => 'The room is full.',
        OnlineFailure.playerNotFound => 'Player not found.',
        OnlineFailure.notAllowed => 'Not allowed.',
        OnlineFailure.requestNotFound => 'That request is gone.',
        OnlineFailure.cancelled => 'Sign-in cancelled.',
        OnlineFailure.network => 'No connection. Try again shortly.',
        OnlineFailure.unknown => 'Something went wrong. Try again.',
      };
}
