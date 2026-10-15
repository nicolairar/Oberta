import '../narration/italian_pack.dart';
import '../narration/narration_pack.dart';
import '../roster/roster.dart';
import '../sound/cue_sounds.dart';
import '../ui/widgets/death_scene.dart';
import '../ui/widgets/verdict_scene.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// L'interfaccia in italiano.
final class ItalianStrings extends AppStrings {
  const ItalianStrings();

  @override
  AppLanguage get language => AppLanguage.it;

  @override
  NarrationPack get pack => italianPack;

  @override
  String get settings => 'Impostazioni';
  @override
  String get alleyPlaque => 'VICOLO DEL SILENZIO';
  @override
  String get tonight => 'STASERA SI GIOCA';
  @override
  String get sharedTitle => 'UN TELEFONO PER TUTTI';
  @override
  String get sharedBlurb => 'Si passa di mano in mano. Niente rete, niente testimoni.';
  @override
  String get createRoom => 'CREA STANZA';
  @override
  String get hostName => 'Tu';
  @override
  String get soon => 'PROSSIMAMENTE';
  @override
  String get ownTitle => 'UN TELEFONO\nA TESTA';
  @override
  String get ownBlurb => 'Ognuno col suo, e un codice di quattro lettere.';
  @override
  String get ownTeaser => 'Un telefono a testa: arriva con la rete. Pazienza.';
  @override
  String get rankedTitle => 'CLASSIFICATA';
  @override
  String get rankedBlurb => 'Sconosciuti, punti e una classifica da scalare.';
  @override
  String get rankedTeaser => 'La classificata apre presto. Intanto fatti un nome.';
  @override
  List<String> get homeCaptions => const [
    'Nessuno ha visto niente.',
    'Nessuno parla. Qualcuno muore.',
    'Tu non c\'eri. E se c\'eri, dormivi.',
    'In questa città anche i muri stanno zitti.',
    'Fidarsi è bene. Tacere è meglio.',
    'Chi sa, tace. Chi parla non vede l\'alba.',
    'Stanotte qualcuno non torna a casa.',
  ];

  @override
  String get settingsTitle => 'IMPOSTAZIONI';
  @override
  String get sound => 'Musica ed effetti';
  @override
  String get soundHint => 'Si sentono anche col telefono in silenzioso.';
  @override
  String get languageSetting => 'Lingua';
  @override
  String get languageAutomatic => 'Automatica (telefono)';
  @override
  String get rehearsal => 'Sala prove';
  @override
  String get rehearsalHint => 'Rivedi le scene della notte, una per una.';

  @override
  String get narratorTitle => 'NARRATORE';
  @override
  String get whoPullsTheStrings => 'Chi tiene\nle fila?';
  @override
  String get narratorIntro => 'Il narratore guida la partita e conosce tutti i ruoli.';
  @override
  String get pickedByGroup => 'Scelto dal gruppo';
  @override
  String get pickedByGroupHint => 'Decidete voi chi racconta. Non riceve un ruolo.';
  @override
  String get drawnByCylinder => 'Sorteggiato dal tamburo';
  @override
  String get drawnByCylinderHint => 'Un giro di tamburo. Chi esce racconta e non gioca.';
  @override
  String get automaticNarrator => 'Narratore automatico';
  @override
  String get automaticNarratorHint => 'Racconta il telefono: giocano tutti.';
  @override
  String needAtLeast(int players) => 'Servono almeno $players giocatori';
  @override
  String get whoNarrates => 'CHI RACCONTA?';
  @override
  String get drawTitle => 'SORTEGGIO';
  @override
  String get whoNarratesTonight => 'Chi racconta\nstanotte?';
  @override
  String get theNarratorIs => 'IL NARRATORE È';
  @override
  String get continueLabel => 'CONTINUA';

  @override
  String get cardsTitle => 'LE CARTE';
  @override
  String get automatic => 'Automatico';
  @override
  String get cardsDealt => 'Le carte sono servite';
  @override
  String get shuffling => 'Si mescola il mazzo…';
  @override
  String get checkYourCards => 'GUARDATE LE CARTE';
  @override
  String cardOf(int card, int of) => 'CARTA $card DI $of';
  @override
  String get holdTheCardHint => 'Tieni premuta la carta per guardarla.\nRilascia e torna coperta.';
  @override
  String get gotIt => 'HO VISTO';
  @override
  String get pressAndHold => 'TIENI PREMUTO';
  @override
  String get youAreFamily => 'STAI CON LA FAMIGLIA';
  @override
  String get youAreTown => 'STAI CON GLI ONESTI';
  @override
  String get youActAlone => 'AGISCI DA SOLO';
  @override
  String get yourAccomplices => 'I TUOI COMPLICI';
  @override
  String get familyBadge => 'FAMIGLIA';
  @override
  String get townBadge => 'ONESTI';

  @override
  String get passThePhoneTo => 'PASSA IL TELEFONO A';
  @override
  String get nobodyElseLooks => 'Nessun altro deve guardare lo schermo.';
  @override
  String get itsMe => 'SONO IO';
  @override
  String get youBadge => 'TU';
  @override
  String get innocentBadge => 'INNOCENTE';
  @override
  String get readAloud => 'LEGGETE AD ALTA VOCE';
  @override
  String readerReadsAloud(String reader) => 'LEGGE ${reader.toUpperCase()}, AD ALTA VOCE';
  @override
  String get narratorOnly => 'SOLO PER IL NARRATORE';
  @override
  String get holdToSeeRoles => 'Tieni premuto per vedere tutti i ruoli';

  @override
  String nightTitle(int round) => 'NOTTE $round';
  @override
  String get nightFalls => 'Cala la notte';
  @override
  String get startTheNight => 'COMINCIA LA NOTTE';
  @override
  String get dawnTitle => 'ALBA';
  @override
  String get everyoneAlive => 'Tutti vivi';
  @override
  String get crimePage => 'Cronaca nera';
  @override
  String get finale => 'FINALE';
  @override
  String get openTheFloor => 'APRI LA DISCUSSIONE';
  @override
  String dayTitle(int round) => 'GIORNO $round';
  @override
  String get verdictTitle => 'IL VERDETTO';
  @override
  String get noConviction => 'Nessuna condanna';
  @override
  String get endTitle => 'FINE';
  @override
  String get leaveQuestion => 'Abbandonare la partita?';
  @override
  String get leaveWarning => 'La partita in corso andrà persa.';
  @override
  String get stay => 'RESTA';
  @override
  String get leave => 'ESCI';
  @override
  String get leaveTooltip => 'Abbandona la partita';
  @override
  String get rolesTooltip => 'Ruoli, solo per il narratore';
  @override
  String get phoneOnTheTable => 'Telefono\nsul tavolo';
  @override
  String get phoneOnTheTableHint => 'Mettetelo al centro e guardate tutti.\nStanotte è successo qualcosa.';
  @override
  String get lightsDown => 'BUIO IN SALA';
  @override
  String get pass => 'PASSO';
  @override
  String get confirm => 'CONFERMA';
  @override
  String get doneTitle => 'Fatto.';
  @override
  String get nobodyWillKnow => 'Nessuno saprà cosa hai scelto.';
  @override
  String get yourInvestigation => 'LA TUA INDAGINE';
  @override
  String get inTheGrave => 'NELLA FOSSA';
  @override
  String wasRole(String role) => 'ERA ${role.toUpperCase()}';
  @override
  String get isFamily => 'È DELLA FAMIGLIA';
  @override
  String get isInnocent => 'È INNOCENTE';
  @override
  String get wasWithFamily => 'STAVA CON LA FAMIGLIA';
  @override
  String get wasWithTown => 'STAVA CON GLI ONESTI';
  @override
  String get done => 'FATTO';
  @override
  String get nobody => 'NESSUNO';
  @override
  String get condemn => 'CONDANNA';
  @override
  String fateNight(int round) => 'Notte $round';
  @override
  String fateGallows(int round) => 'Patibolo, giorno $round';
  @override
  String get stillStanding => 'Ancora in piedi';
  @override
  String get familyWins => 'Vince\nla famiglia';
  @override
  String get townWins => 'Vincono\ngli onesti';
  @override
  String get whoWasWho => 'CHI ERA CHI';
  @override
  String get mostSuspicious => 'LA FACCIA PIÙ SOSPETTA';
  @override
  String suspicion(String name, int fingers, {required bool rightly}) =>
      '$name, con $fingers ${fingers == 1 ? 'dito puntato' : 'dita puntate'} nel buio. '
      '${rightly ? 'A ragione.' : 'A torto.'}';
  @override
  String get backHome => 'TORNA ALLA HOME';
  @override
  String get keepReading => 'CONTINUA A LEGGERE';
  @override
  String get flipTheCard => 'GIRA LA CARTA';
  @override
  String get timeUp => 'TEMPO SCADUTO';
  @override
  String get floorIsOpen => 'LA PIAZZA DISCUTE';
  @override
  String get plusMinute => '+1 MIN';
  @override
  String get callTheVote => 'AL VOTO';

  @override
  String get willSeeDawn => 'VEDRÀ L\'ALBA';
  @override
  String get wontSeeDawn => 'NON VEDRÀ L\'ALBA';
  @override
  String get next => 'AVANTI';
  @override
  String get skip => 'SALTA';

  @override
  String verdictCaption(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'Al tramonto, giù al molo.',
    VerdictTake.cartello => 'Il confine della città. Strada polverosa, niente ritorno.',
    VerdictTake.treno => 'Stazione centrale. L\'ultimo treno della sera.',
    VerdictTake.cannone => 'Il circo è in città. Cercasi volontario.',
    VerdictTake.assoluzione => 'La piazza, al tramonto. Volano parole grosse.',
  };
  @override
  String verdictStamp(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'DORME COI PESCI',
    VerdictTake.cartello => 'FUORI CITTÀ',
    VerdictTake.treno => 'SOLA ANDATA',
    VerdictTake.cannone => 'IN ORBITA',
    VerdictTake.assoluzione => '',
  };
  @override
  String get verdictLine => 'LA PIAZZA HA DECISO';
  @override
  String get acquittalTitle => 'NESSUNA CONDANNA';
  @override
  String get acquittalLine => 'PER STASERA, TUTTI A CASA';
  @override
  String get townSign => 'CITTÀ';
  @override
  String verdictWord(VerdictWord word) => switch (word) {
    VerdictWord.thud => 'TONF!',
    VerdictWord.byeBye => 'CIAO CIAO!',
    VerdictWord.glub => 'BLUB',
    VerdictWord.getOut => 'FUORI!',
    VerdictWord.cough => 'COF COF!',
    VerdictWord.toot => 'TU-TUUU!',
    VerdictWord.sniff => 'SNIF SNIF!',
    VerdictWord.ping => 'PLING!',
    VerdictWord.bonk => 'TOC!',
    VerdictWord.shrug => 'BOH!',
  };

  @override
  String get screeningTitle => 'SALA PROVE';
  @override
  String get screeningIntro => 'Tutte le scene della notte. Toccane una per rivederla.';
  @override
  String get screeningCaption => 'Esterno, notte. Prova generale.';
  @override
  String sceneName(DeathAct act) => switch (act) {
    DeathAct.knife => 'Il pugnale',
    DeathAct.gun => 'Il silenziatore',
    DeathAct.burst => 'La custodia da violino',
    DeathAct.car => 'L\'auto nera',
    DeathAct.piano => 'Il pianoforte',
    DeathAct.safe => 'La cassaforte',
    DeathAct.chandelier => 'Il lampadario',
    DeathAct.blast => 'Il pacco regalo',
    DeathAct.poison => 'Il caffè corretto',
    DeathAct.noose => 'Il cappio',
    DeathAct.grab => 'Le scarpe di cemento',
    DeathAct.bat => 'La mazza',
    DeathAct.lupara => 'La lupara',
    DeathAct.driveBy => 'La raffica dall\'auto',
    DeathAct.garrote => 'La garrota',
    DeathAct.pot => 'Il vaso dal terzo piano',
    DeathAct.manhole => 'Il tombino',
    DeathAct.blackout => 'Il buio',
    DeathAct.kiss => 'Il bacio',
    DeathAct.sniper => 'Il Cecchino',
    DeathAct.rescue => 'Il Dottore arriva in tempo',
    DeathAct.lucky => 'La fiaschetta',
  };

  @override
  String get screeningEffects => 'EFFETTI';

  @override
  String cueName(Cue cue) => switch (cue) {
    Cue.click => 'Il tamburo che gira',
    Cue.bang => 'Lo sparo del sorteggio',
    Cue.deal => 'Una carta servita',
    Cue.flip => 'Una carta girata',
    Cue.nightfall => 'Cala la notte',
    Cue.dawn => 'L\'alba',
    Cue.tick => 'Gli ultimi secondi',
    Cue.timeUp => 'Tempo scaduto',
    Cue.drumroll => 'Il rullo di tamburi',
    Cue.caught => 'Era della famiglia',
    Cue.innocent => 'Era innocente',
    Cue.townWins => 'Vincono gli onesti',
    Cue.familyWins => 'Vince la famiglia',
  };

  @override
  String get lobbyTitle => 'IL TAVOLO';

  @override
  String get lobbyDebugAdd => '+ TEST';

  @override
  String get lobbyClearTooltip => 'Via tutti';

  @override
  String get lobbyEmptyTitle => 'CHI GIOCA STASERA?';

  @override
  String get lobbyEmptyBody => 'Passatevi il telefono: ognuno scrive il suo nome e si fa la foto segnaletica.';

  @override
  String get lobbyEmptyPlaceholder => '???';

  @override
  String get lobbyTableEmpty => 'TAVOLO VUOTO';

  @override
  String get lobbyReadyHint => 'Si può cominciare.';

  @override
  String get lobbyTableFull => 'Tavolo pieno: in più di $maxTablePlayers non si gioca.';

  @override
  String get lobbyTableFullRefusal => 'Il tavolo è pieno: prima si deve alzare qualcuno.';

  @override
  String get lobbyRosterFull => 'L\'elenco è pieno: prima togli qualcuno.';

  @override
  String get lobbyGestureHint =>
      'Tocca una faccia per farla sedere o alzare.\nTienila premuta per cambiare nome o foto.';

  @override
  String get lobbyOut => 'FUORI';

  @override
  String get lobbyPrivacy => 'Nomi e foto restano su questo telefono.';

  @override
  String get lobbyAdd => 'AGGIUNGI';

  @override
  String get lobbyStart => 'AVVIA';

  @override
  String get lobbyClearTitle => 'Via tutti?';

  @override
  String get lobbyClearBody => 'Cancello da questo telefono tutti i nomi e tutte le foto. Non si torna indietro.';

  @override
  String get lobbyClearCancel => 'ANNULLA';

  @override
  String get lobbyClearConfirm => 'CANCELLA TUTTI';

  @override
  String lobbySeated(int seated) => '$seated AL TAVOLO';

  @override
  String lobbyMissing(int missing) =>
      missing == 1 ? 'Ne manca ancora uno per cominciare.' : 'Ne mancano ancora $missing per cominciare.';

  @override
  String get personTitleNew => 'NUOVA SCHEDA';

  @override
  String get personTitleEdit => 'SCHEDA';

  @override
  String get personPlacardEmpty => 'IL TUO NOME';

  @override
  String get personNameHint => 'Come ti chiami?';

  @override
  String get personNameEmpty => 'Senza un nome non ti si può schedare.';

  @override
  String get personNameTooLong => 'Troppo lungo: al massimo $maxNameLength lettere.';

  @override
  String get personNameTaken => 'C\'è già qualcuno con questo nome.';

  @override
  String get personShoot => 'SCATTA';

  @override
  String get personReshoot => 'RIFAI';

  @override
  String get personGallery => 'GALLERIA';

  @override
  String get personNoPhoto => 'SENZA FOTO';

  @override
  String get personHintDrag => 'Trascina per centrare la faccia';

  @override
  String get personSubmitNew => 'AGGIUNGI AL TAVOLO';

  @override
  String get personSubmitEdit => 'SALVA';

  @override
  String get personPrivacy => 'La foto resta su questo telefono: il gioco non la manda da nessuna parte.';

  @override
  String get personCameraDenied =>
      'Niente permesso per la fotocamera. Puoi darlo dalle Impostazioni, o giocare senza foto.';

  @override
  String get personCameraFailed => 'La foto non è riuscita. Riprova, o gioca senza.';

  @override
  String get personStamp => 'SCHEDATO';

  @override
  String get personBookedPass => 'Passa il telefono al prossimo.';

  @override
  String get personNext => 'AVANTI IL PROSSIMO';

  @override
  String get personDone => 'ABBIAMO FINITO';

  @override
  String get personRemoveTooltip => 'Togli dall\'elenco';

  @override
  String get personRemoveCancel => 'ANNULLA';

  @override
  String get personRemoveConfirm => 'TOGLI';

  @override
  String get personRemoveBody => 'Cancello dal telefono il nome e la foto.';

  @override
  String personBookedSeated(String name) => '$name è al tavolo.';

  @override
  String personBookedWatching(String name) => 'Il tavolo è pieno: $name per ora guarda.';

  @override
  String personRemoveTitle(String name) => 'Via $name?';

  @override
  String get screeningVerdicts => 'VERDETTI';

  @override
  String verdictName(VerdictTake take) => switch (take) {
        VerdictTake.molo => 'Il molo',
        VerdictTake.cartello => 'Il cartello di fine città',
        VerdictTake.treno => 'L\'ultimo treno',
        VerdictTake.cannone => 'Il cannone del circo',
        VerdictTake.assoluzione => 'Nessuna condanna',
      };
}
