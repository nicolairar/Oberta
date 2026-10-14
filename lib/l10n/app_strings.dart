import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../narration/narration_pack.dart';
import '../rules/role.dart';
import '../sound/cue_sounds.dart';
import '../ui/widgets/death_scene.dart';
import 'app_language.dart';

/// Tutti i testi dell'interfaccia in una lingua. Il copione del narratore e
/// i ruoli stanno nel [pack]: qui ci sono pulsanti, titoli e didascalie.
///
/// Ogni lingua è una sottoclasse che deve dire tutto: aggiungere un testo è
/// aggiungere un membro astratto qui, e il compilatore indica le lingue a
/// cui manca. Chi aggiunge un membro lo mette anche in [catalog], che i test
/// controllano in tutte e due le lingue.
abstract class AppStrings {
  const AppStrings();

  /// I testi della lingua scelta. Dove nessuno ha installato una lingua
  /// (un `MaterialApp` nudo nei test) si parla italiano.
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? AppLanguage.it.strings;

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  AppLanguage get language;

  /// Il copione e i nomi dei ruoli nella stessa lingua.
  NarrationPack get pack;

  RoleText role(Role role) => pack.role(role);

  // Il vicolo.
  String get homeTitle => 'OBERTÀ';
  String get settings;
  String get alleyPlaque;
  String get tonight;
  String get sharedTitle;
  String get sharedBlurb;
  String get createRoom;
  String get hostName;
  String get soon;
  String get ownTitle;
  String get ownBlurb;
  String get ownTeaser;
  String get rankedTitle;
  String get rankedBlurb;
  String get rankedTeaser;

  /// Le didascalie battute a macchina in fondo al vicolo.
  List<String> get homeCaptions;

  // Le impostazioni.
  String get settingsTitle;
  String get sound;
  String get soundHint;
  String get languageSetting;
  String get languageAutomatic;
  String get rehearsal;
  String get rehearsalHint;

  // Il narratore.
  String get narratorTitle;
  String get whoPullsTheStrings;
  String get narratorIntro;
  String get pickedByGroup;
  String get pickedByGroupHint;
  String get drawnByCylinder;
  String get drawnByCylinderHint;
  String get automaticNarrator;
  String get automaticNarratorHint;
  String needAtLeast(int players);
  String get whoNarrates;
  String get drawTitle;
  String get whoNarratesTonight;
  String get theNarratorIs;
  String get continueLabel;

  // Le carte.
  String get cardsTitle;
  String get automatic;
  String get cardsDealt;
  String get shuffling;
  String get checkYourCards;
  String cardOf(int card, int of);
  String get holdTheCardHint;
  String get gotIt;
  String get pressAndHold;
  String get youAreFamily;
  String get youAreTown;
  String get youActAlone;
  String get yourAccomplices;
  String get familyBadge;
  String get townBadge;

  // Il passaggio del telefono, la griglia, il copione.
  String get passThePhoneTo;
  String get nobodyElseLooks;
  String get itsMe;
  String get youBadge;
  String get innocentBadge;
  String get readAloud;
  String readerReadsAloud(String reader);
  String get narratorOnly;
  String get holdToSeeRoles;

  // La partita.
  String nightTitle(int round);
  String get nightFalls;
  String get startTheNight;
  String get dawnTitle;
  String get everyoneAlive;
  String get crimePage;
  String get finale;
  String get openTheFloor;
  String dayTitle(int round);
  String get verdictTitle;
  String get noConviction;
  String get endTitle;
  String get leaveQuestion;
  String get leaveWarning;
  String get stay;
  String get leave;
  String get leaveTooltip;
  String get rolesTooltip;
  String get phoneOnTheTable;
  String get phoneOnTheTableHint;
  String get lightsDown;
  String get pass;
  String get confirm;
  String get doneTitle;
  String get nobodyWillKnow;
  String get yourInvestigation;
  String get inTheGrave;
  String wasRole(String role);
  String get isFamily;
  String get isInnocent;
  String get wasWithFamily;
  String get wasWithTown;
  String get done;
  String get nobody;
  String get condemn;
  String fateNight(int round);
  String fateGallows(int round);
  String get stillStanding;
  String get familyWins;
  String get townWins;
  String get whoWasWho;
  String get mostSuspicious;
  String suspicion(String name, int fingers, {required bool rightly});
  String get backHome;
  String get keepReading;
  String get flipTheCard;
  String get timeUp;
  String get floorIsOpen;
  String get plusMinute;
  String get callTheVote;

  // La scena del delitto.
  String get willSeeDawn;
  String get wontSeeDawn;
  String get next;
  String get skip;

  // La sala prove.
  String get screeningTitle;
  String get screeningIntro;
  String get screeningCaption;
  String sceneName(DeathAct act);
  String get screeningEffects;
  String cueName(Cue cue);

  // Il tavolo e la scheda di chi gioca.
  String get lobbyTitle;
  String get lobbyDebugAdd;
  String get lobbyClearTooltip;
  String get lobbyEmptyTitle;
  String get lobbyEmptyBody;
  String get lobbyEmptyPlaceholder;
  String get lobbyTableEmpty;
  String get lobbyReadyHint;
  String get lobbyTableFull;
  String get lobbyTableFullRefusal;
  String get lobbyRosterFull;
  String get lobbyGestureHint;
  String get lobbyOut;
  String get lobbyPrivacy;
  String get lobbyAdd;
  String get lobbyStart;
  String get lobbyClearTitle;
  String get lobbyClearBody;
  String get lobbyClearCancel;
  String get lobbyClearConfirm;
  String lobbySeated(int seated);
  String lobbyMissing(int missing);
  String get personTitleNew;
  String get personTitleEdit;
  String get personPlacardEmpty;
  String get personNameHint;
  String get personNameEmpty;
  String get personNameTooLong;
  String get personNameTaken;
  String get personShoot;
  String get personReshoot;
  String get personGallery;
  String get personNoPhoto;
  String get personHintDrag;
  String get personSubmitNew;
  String get personSubmitEdit;
  String get personPrivacy;
  String get personCameraDenied;
  String get personCameraFailed;
  String get personStamp;
  String get personBookedPass;
  String get personNext;
  String get personDone;
  String get personRemoveTooltip;
  String get personRemoveCancel;
  String get personRemoveConfirm;
  String get personRemoveBody;
  String personBookedSeated(String name);
  String personBookedWatching(String name);
  String personRemoveTitle(String name);

  /// Ogni testo, col suo nome; quelli con parametri provati con valori
  /// d'esempio. Serve ai test: niente di vuoto, niente nella lingua sbagliata.
  Map<String, String> get catalog => {
    'homeTitle': homeTitle,
    'settings': settings,
    'alleyPlaque': alleyPlaque,
    'tonight': tonight,
    'sharedTitle': sharedTitle,
    'sharedBlurb': sharedBlurb,
    'createRoom': createRoom,
    'hostName': hostName,
    'soon': soon,
    'ownTitle': ownTitle,
    'ownBlurb': ownBlurb,
    'ownTeaser': ownTeaser,
    'rankedTitle': rankedTitle,
    'rankedBlurb': rankedBlurb,
    'rankedTeaser': rankedTeaser,
    for (final (i, caption) in homeCaptions.indexed) 'homeCaptions[$i]': caption,
    'settingsTitle': settingsTitle,
    'sound': sound,
    'soundHint': soundHint,
    'languageSetting': languageSetting,
    'languageAutomatic': languageAutomatic,
    'rehearsal': rehearsal,
    'rehearsalHint': rehearsalHint,
    'narratorTitle': narratorTitle,
    'whoPullsTheStrings': whoPullsTheStrings,
    'narratorIntro': narratorIntro,
    'pickedByGroup': pickedByGroup,
    'pickedByGroupHint': pickedByGroupHint,
    'drawnByCylinder': drawnByCylinder,
    'drawnByCylinderHint': drawnByCylinderHint,
    'automaticNarrator': automaticNarrator,
    'automaticNarratorHint': automaticNarratorHint,
    'needAtLeast': needAtLeast(4),
    'whoNarrates': whoNarrates,
    'drawTitle': drawTitle,
    'whoNarratesTonight': whoNarratesTonight,
    'theNarratorIs': theNarratorIs,
    'continueLabel': continueLabel,
    'cardsTitle': cardsTitle,
    'automatic': automatic,
    'cardsDealt': cardsDealt,
    'shuffling': shuffling,
    'checkYourCards': checkYourCards,
    'cardOf': cardOf(2, 5),
    'holdTheCardHint': holdTheCardHint,
    'gotIt': gotIt,
    'pressAndHold': pressAndHold,
    'youAreFamily': youAreFamily,
    'youAreTown': youAreTown,
    'youActAlone': youActAlone,
    'yourAccomplices': yourAccomplices,
    'familyBadge': familyBadge,
    'townBadge': townBadge,
    'passThePhoneTo': passThePhoneTo,
    'nobodyElseLooks': nobodyElseLooks,
    'itsMe': itsMe,
    'youBadge': youBadge,
    'innocentBadge': innocentBadge,
    'readAloud': readAloud,
    'readerReadsAloud': readerReadsAloud('Sara'),
    'narratorOnly': narratorOnly,
    'holdToSeeRoles': holdToSeeRoles,
    'nightTitle': nightTitle(2),
    'nightFalls': nightFalls,
    'startTheNight': startTheNight,
    'dawnTitle': dawnTitle,
    'everyoneAlive': everyoneAlive,
    'crimePage': crimePage,
    'finale': finale,
    'openTheFloor': openTheFloor,
    'dayTitle': dayTitle(2),
    'verdictTitle': verdictTitle,
    'noConviction': noConviction,
    'endTitle': endTitle,
    'leaveQuestion': leaveQuestion,
    'leaveWarning': leaveWarning,
    'stay': stay,
    'leave': leave,
    'leaveTooltip': leaveTooltip,
    'rolesTooltip': rolesTooltip,
    'phoneOnTheTable': phoneOnTheTable,
    'phoneOnTheTableHint': phoneOnTheTableHint,
    'lightsDown': lightsDown,
    'pass': pass,
    'confirm': confirm,
    'doneTitle': doneTitle,
    'nobodyWillKnow': nobodyWillKnow,
    'yourInvestigation': yourInvestigation,
    'inTheGrave': inTheGrave,
    'wasRole': wasRole(role(Role.medico).label),
    'isFamily': isFamily,
    'isInnocent': isInnocent,
    'wasWithFamily': wasWithFamily,
    'wasWithTown': wasWithTown,
    'done': done,
    'nobody': nobody,
    'condemn': condemn,
    'fateNight': fateNight(2),
    'fateGallows': fateGallows(3),
    'stillStanding': stillStanding,
    'familyWins': familyWins,
    'townWins': townWins,
    'whoWasWho': whoWasWho,
    'mostSuspicious': mostSuspicious,
    'suspicion.one.rightly': suspicion('Sara', 1, rightly: true),
    'suspicion.many.wrongly': suspicion('Sara', 3, rightly: false),
    'backHome': backHome,
    'keepReading': keepReading,
    'flipTheCard': flipTheCard,
    'timeUp': timeUp,
    'floorIsOpen': floorIsOpen,
    'plusMinute': plusMinute,
    'callTheVote': callTheVote,
    'willSeeDawn': willSeeDawn,
    'wontSeeDawn': wontSeeDawn,
    'next': next,
    'skip': skip,
    'screeningTitle': screeningTitle,
    'screeningIntro': screeningIntro,
    'screeningCaption': screeningCaption,
    for (final act in DeathAct.values) 'sceneName.${act.name}': sceneName(act),
    'screeningEffects': screeningEffects,
    'lobbyTitle': lobbyTitle,
    'lobbyDebugAdd': lobbyDebugAdd,
    'lobbyClearTooltip': lobbyClearTooltip,
    'lobbyEmptyTitle': lobbyEmptyTitle,
    'lobbyEmptyBody': lobbyEmptyBody,
    'lobbyEmptyPlaceholder': lobbyEmptyPlaceholder,
    'lobbyTableEmpty': lobbyTableEmpty,
    'lobbyReadyHint': lobbyReadyHint,
    'lobbyTableFull': lobbyTableFull,
    'lobbyTableFullRefusal': lobbyTableFullRefusal,
    'lobbyRosterFull': lobbyRosterFull,
    'lobbyGestureHint': lobbyGestureHint,
    'lobbyOut': lobbyOut,
    'lobbyPrivacy': lobbyPrivacy,
    'lobbyAdd': lobbyAdd,
    'lobbyStart': lobbyStart,
    'lobbyClearTitle': lobbyClearTitle,
    'lobbyClearBody': lobbyClearBody,
    'lobbyClearCancel': lobbyClearCancel,
    'lobbyClearConfirm': lobbyClearConfirm,
    'lobbySeated': lobbySeated(8),
    'lobbyMissing': lobbyMissing(2),
    'personTitleNew': personTitleNew,
    'personTitleEdit': personTitleEdit,
    'personPlacardEmpty': personPlacardEmpty,
    'personNameHint': personNameHint,
    'personNameEmpty': personNameEmpty,
    'personNameTooLong': personNameTooLong,
    'personNameTaken': personNameTaken,
    'personShoot': personShoot,
    'personReshoot': personReshoot,
    'personGallery': personGallery,
    'personNoPhoto': personNoPhoto,
    'personHintDrag': personHintDrag,
    'personSubmitNew': personSubmitNew,
    'personSubmitEdit': personSubmitEdit,
    'personPrivacy': personPrivacy,
    'personCameraDenied': personCameraDenied,
    'personCameraFailed': personCameraFailed,
    'personStamp': personStamp,
    'personBookedPass': personBookedPass,
    'personNext': personNext,
    'personDone': personDone,
    'personRemoveTooltip': personRemoveTooltip,
    'personRemoveCancel': personRemoveCancel,
    'personRemoveConfirm': personRemoveConfirm,
    'personRemoveBody': personRemoveBody,
    'personBookedSeated': personBookedSeated('Marco'),
    'personBookedWatching': personBookedWatching('Marco'),
    'personRemoveTitle': personRemoveTitle('Marco'),
    for (final cue in Cue.values) 'cueName.${cue.name}': cueName(cue),
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.values.any((language) => language.locale.languageCode == locale.languageCode);

  // Sincrono: i testi sono già in memoria, e il primo fotogramma non deve
  // uscire vuoto aspettando la lingua.
  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(AppLanguage.forLocale(locale).strings);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
