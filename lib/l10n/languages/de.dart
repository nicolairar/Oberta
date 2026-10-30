import 'dart:math';

import '../../narration/death_story.dart';
import '../../narration/narration_pack.dart';
import '../../online/handle_rules.dart';
import '../../online/online_models.dart';
import '../../online/ranked_models.dart';
import '../../online/shop_models.dart';
import '../../roster/roster.dart';
import '../../rules/game_engine.dart';
import '../../rules/role.dart';
import '../../ui/avatar/deep_slots.dart' show Hand;
import '../../ui/widgets/verdict_scene.dart';
import '../app_language.dart';
import '../online_strings.dart';
import '../rules_strings.dart';
import '../shop_strings.dart';
import '../strings_en.dart';

// The whole of the German translation: interface, keyed messages and the
// narrator's script. German, "du" throughout.
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.
//
// Stage names, the same everywhere: Soldat, Pate, Schneider, Komplize,
// Bürger, Detektiv, Doktor ("der Doc" in the lines), Scharfschütze, Reporter,
// Totengräber, Leibwächter, Veteran, Ex-Knacki, Messias, Bürgermeister,
// Portier, Trottel, Brandstifter, Kopfgeldjäger, Kredithai, Auftragskiller,
// Lockvogel, Schließer, Pazifist, Amor, Präsident, Sektenführer, Kanonier,
// Meisterschütze. The factions: "die Familie" and "die Stadt" (and "die Sekte").
// Roles go into sentences without an article ("{name} war Detektiv").

final class GermanStrings extends EnglishStrings {
  const GermanStrings();

  @override
  AppLanguage get language => AppLanguage.de;
  @override
  NarrationPack get pack => germanPack;
  @override
  OnlineStrings get online => const GermanOnlineStrings();
  @override
  ShopStrings get shop => const GermanShopStrings();
  @override
  List<RulesStep>? rulesSteps(RulesStyle style) => style == RulesStyle.quick ? _quickDe : _stageDe;
  @override
  Map<String, String> get messages => germanMessages;

  @override
  String get settings => 'Einstellungen';
  @override
  String get alleyPlaque => 'GASSE DES SCHWEIGENS';
  @override
  String get tonight => 'NUR HEUTE NACHT';
  @override
  String get sharedTitle => 'EIN HANDY FÜR ALLE';
  @override
  String get sharedBlurb => 'Von Hand zu Hand. Kein Netz, keine Zeugen.';
  @override
  String get createRoom => 'RAUM ERÖFFNEN';
  @override
  String get hostName => 'Du';
  @override
  String get soon => 'DEMNÄCHST';
  @override
  String get rankedTitle => 'RANGLISTE';
  @override
  String get rankedBlurb => 'Fremde, Punkte und eine Rangliste zum Hochklettern.';
  @override
  String get rankedTeaser => 'Die Rangliste öffnet bald. Mach dir solange einen Namen.';
  @override
  List<String> get homeCaptions => const [
    'Keiner hat was gesehen.',
    'Keiner redet. Einer stirbt.',
    'Du warst nicht da. Und wenn doch, hast du geschlafen.',
    'In dieser Stadt schweigen sogar die Wände.',
    'Vertrauen ist gut. Schweigen ist besser.',
    'Wer was weiß, schweigt. Wer redet, sieht den Morgen nicht.',
    'Heute Nacht kommt einer nicht nach Hause.',
  ];

  @override
  String get settingsTitle => 'EINSTELLUNGEN';
  @override
  String get sound => 'Musik und Effekte';
  @override
  String get soundHint => 'Du hörst sie auch, wenn das Handy stumm ist.';
  @override
  String get languageSetting => 'Sprache';
  @override
  String get languageAutomatic => 'Automatisch (Handy)';

  @override
  String get narratorTitle => 'ERZÄHLER';
  @override
  String get whoPullsTheStrings => 'Wer zieht\ndie Fäden?';
  @override
  String get narratorIntro => 'Der Erzähler leitet das Spiel und kennt alle Rollen.';
  @override
  String get pickedByGroup => 'Von der Runde bestimmt';
  @override
  String get pickedByGroupHint => 'Ihr entscheidet, wer erzählt. Diese Person bekommt keine Rolle.';
  @override
  String get drawnByCylinder => 'Von der Trommel gezogen';
  @override
  String get drawnByCylinderHint => 'Einmal die Trommel drehen. Wen es trifft, der erzählt und spielt nicht mit.';
  @override
  String get automaticNarrator => 'Automatischer Erzähler';
  @override
  String get automaticNarratorHint => 'Das Handy erzählt: alle spielen mit.';
  @override
  String needAtLeast(int players) => 'Ihr braucht mindestens $players Spieler';
  @override
  String get whoNarrates => 'WER ERZÄHLT?';
  @override
  String get drawTitle => 'DIE ZIEHUNG';
  @override
  String get whoNarratesTonight => 'Wer erzählt\nheute Nacht?';
  @override
  String get theNarratorIs => 'ES ERZÄHLT';
  @override
  String get continueLabel => 'WEITER';

  @override
  String get cardsTitle => 'DIE KARTEN';
  @override
  String get automatic => 'Automatisch';
  @override
  String get cardsDealt => 'Die Karten sind verteilt';
  @override
  String get shuffling => 'Das Blatt wird gemischt…';
  @override
  String get checkYourCards => 'SCHAUT EURE KARTEN AN';
  @override
  String cardOf(int card, int of) => 'KARTE $card VON $of';
  @override
  String get holdTheCardHint => 'Halt die Karte gedrückt, um sie anzusehen.\nLoslassen, und sie dreht sich zurück.';
  @override
  String get gotIt => 'GESEHEN';
  @override
  String get pressAndHold => 'GEDRÜCKT HALTEN';
  @override
  String get youAreFamily => 'DU GEHÖRST ZUR FAMILIE';
  @override
  String get youAreTown => 'DU GEHÖRST ZUR STADT';
  @override
  String get youActAlone => 'DU ARBEITEST ALLEIN';
  @override
  String get yourAccomplices => 'DEINE KOMPLIZEN';
  @override
  String get familyUnknown => 'DU ARBEITEST FÜR DIE FAMILIE, ABER DU WEISST NICHT, WER SIE SIND';
  @override
  String get familyBadge => 'FAMILIE';
  @override
  String get townBadge => 'EHRLICHE';

  @override
  String get passThePhoneTo => 'GIB DAS HANDY AN';
  @override
  String get nobodyElseLooks => 'Sonst schaut keiner aufs Display.';
  @override
  String get itsMe => 'DAS BIN ICH';
  @override
  String get youBadge => 'DU';
  @override
  String get innocentBadge => 'UNSCHULDIG';
  @override
  String get neutralBadge => 'NEUTRAL';
  @override
  String get youAreNeutral => 'DU SPIELST FÜR DICH';
  @override
  String get arsonistWins => 'Ein Einzelgänger\ngewinnt';
  @override
  String get wonAlone => 'ALLEIN GEWONNEN';
  @override
  String get revealAsMayor => 'Gib dich zu erkennen: Bürgermeister';
  @override
  String get lightTheMatch => 'Zünd das Streichholz an';
  @override
  String get dousePick => 'Übergießen';
  @override
  String get dousedBadge => 'BENZIN';
  @override
  String get bountyBadge => 'KOPFGELD';
  @override
  String get bountyLine => 'Du hast ein Kopfgeld auf {name}: Bring die Stadt dazu, {name} zu lynchen.';
  @override
  String get readAloud => 'LIES ES LAUT VOR';
  @override
  String readerReadsAloud(String reader) => '${reader.toUpperCase()} LIEST ES LAUT VOR';
  @override
  String get narratorSpeaks => 'DER ERZÄHLER SPRICHT';
  @override
  String get narratorOnly => 'NUR FÜR DEN ERZÄHLER';
  @override
  String get holdToSeeRoles => 'Gedrückt halten, um alle Rollen zu sehen';

  @override
  String nightTitle(int round) => 'NACHT $round';
  @override
  String get nightFalls => 'Die Nacht bricht herein';
  @override
  String get startTheNight => 'DIE NACHT BEGINNT';
  @override
  String get dawnTitle => 'MORGENGRAUEN';

  @override
  String get dayBreaks => 'Es wird Tag';
  @override
  String get everyoneAlive => 'Alle haben überlebt';
  @override
  String get crimePage => 'Die Polizeiberichte';
  @override
  String get finale => 'DAS FINALE';
  @override
  String get openTheFloor => 'DISKUSSION ERÖFFNEN';
  @override
  String dayTitle(int round) => 'TAG $round';
  @override
  String get verdictTitle => 'DAS URTEIL';
  @override
  String get noConviction => 'Kein Urteil';
  @override
  String get endTitle => 'ENDE';
  @override
  String get leaveQuestion => 'Das Spiel verlassen?';
  @override
  String get leaveWarning => 'Das laufende Spiel geht verloren.';
  @override
  String get stay => 'BLEIBEN';
  @override
  String get leave => 'GEHEN';
  @override
  String get leaveTooltip => 'Spiel verlassen';
  @override
  String get rolesTooltip => 'Rollen, nur für den Erzähler';
  @override
  String get phoneOnTheTable => 'Handy\nauf den Tisch';
  @override
  String get phoneOnTheTableHint => 'Legt es in die Mitte, wo alle es sehen.\nLetzte Nacht ist etwas passiert.';
  @override
  String get lightsDown => 'LICHT AUS';
  @override
  String get pass => 'PASSEN';
  @override
  String get voteTheHit => 'DER ANSCHLAG';
  @override
  String get sewAMouth => 'MUND ZUNÄHEN';
  @override
  String get confirm => 'BESTÄTIGEN';
  @override
  String get doneTitle => 'Erledigt.';
  @override
  String get nobodyWillKnow => 'Keiner wird erfahren, was du gewählt hast.';
  @override
  String get yourInvestigation => 'DEINE ERMITTLUNG';
  @override
  String get inTheGrave => 'IM GRAB';
  @override
  String wasRole(String role) => 'WAR ${role.toUpperCase()}';
  @override
  String get isFamily => 'GEHÖRT ZUR FAMILIE';
  @override
  String get isInnocent => 'IST UNSCHULDIG';
  @override
  String get wasWithFamily => 'GEHÖRTE ZUR FAMILIE';
  @override
  String get wasWithTown => 'GEHÖRTE ZUR STADT';
  @override
  String get done => 'FERTIG';
  @override
  String get nobody => 'NIEMAND';
  @override
  String get condemn => 'VERURTEILEN';
  @override
  String fateNight(int round) => 'Nacht $round';
  @override
  String fateGallows(int round) => 'Galgen, Tag $round';
  @override
  String get stillStanding => 'Noch am Leben';
  @override
  String get familyWins => 'Die Familie\ngewinnt';
  @override
  String get townWins => 'Die Stadt\ngewinnt';
  @override
  String get whoWasWho => 'WER WAR WER';
  @override
  String get mostSuspicious => 'DAS VERDÄCHTIGSTE GESICHT';
  @override
  String suspicion(String name, int fingers, {required bool rightly}) =>
      '$name. $fingers Finger ${fingers == 1 ? 'zeigte' : 'zeigten'} im Dunkeln auf diesen Namen. '
      '${rightly ? 'Zu Recht.' : 'Zu Unrecht, wie sich zeigt.'}';
  @override
  String get backHome => 'ZURÜCK IN DIE GASSE';
  @override
  String get keepReading => 'WEITERLESEN';
  @override
  String get flipTheCard => 'KARTE UMDREHEN';
  @override
  String get timeUp => 'ZEIT IST UM';
  @override
  String get floorIsOpen => 'DIE DISKUSSION LÄUFT';
  @override
  String get plusMinute => '+1 MIN';
  @override
  String get callTheVote => 'ZUR ABSTIMMUNG';
  @override
  String get accusedStamp => 'ANGEKLAGT';
  @override
  String aliveCount(int alive, int total) => '$alive von $total noch am Leben';

  @override
  String get willSeeDawn => 'SIEHT DEN MORGEN';
  @override
  String get wontSeeDawn => 'SIEHT DEN MORGEN NICHT';
  @override
  String get next => 'WEITER';
  @override
  String get skip => 'ÜBERSPRINGEN';

  @override
  String verdictCaption(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'Sonnenuntergang, unten am Hafen.',
    VerdictTake.cartello => 'Die Stadtgrenze. Eine staubige Straße, keine Rückfahrt.',
    VerdictTake.treno => 'Hauptbahnhof. Der letzte Zug heute Nacht.',
    VerdictTake.cannone => 'Der Zirkus ist in der Stadt. Freiwillige gesucht.',
    VerdictTake.assoluzione => 'Der Marktplatz bei Sonnenuntergang. Die Gemüter kochen.',
  };
  @override
  String verdictStamp(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'SCHLÄFT BEI DEN FISCHEN',
    VerdictTake.cartello => 'DAVONGEJAGT',
    VerdictTake.treno => 'NUR HINFAHRT',
    VerdictTake.cannone => 'IM ORBIT',
    VerdictTake.assoluzione => '',
  };
  @override
  String get verdictLine => 'DAS VOLK HAT GESPROCHEN';
  @override
  String get acquittalTitle => 'KEIN URTEIL';
  @override
  String get acquittalLine => 'ALLE NACH HAUSE. FÜR HEUTE.';
  @override
  String get townSign => 'STADT';
  @override
  String verdictWord(VerdictWord word) => switch (word) {
    VerdictWord.thud => 'RUMMS!',
    VerdictWord.byeBye => 'TSCHÜSSI!',
    VerdictWord.glub => 'BLUBB',
    VerdictWord.getOut => 'RAUS!',
    VerdictWord.cough => 'HUST!',
    VerdictWord.toot => 'TUT-TUUT!',
    VerdictWord.sniff => 'SCHNIEF!',
    VerdictWord.ping => 'PLING!',
    VerdictWord.bonk => 'BONK!',
    VerdictWord.shrug => 'TJA!',
  };

  @override
  String get lobbyTitle => 'DER TISCH';

  @override
  String get lobbyDebugAdd => '+ TEST';

  @override
  String get lobbyClearTooltip => 'Alle entfernen';

  @override
  String get lobbyEmptyTitle => 'WER SPIELT HEUTE NACHT?';

  @override
  String get lobbyEmptyBody => 'Gebt das Handy herum: Alle tippen ihren Namen ein und machen ein Fahndungsfoto.';

  @override
  String get lobbyEmptyPlaceholder => '???';

  @override
  String get lobbyTableEmpty => 'LEERER TISCH';

  @override
  String get lobbyReadyHint => 'Es kann losgehen.';

  @override
  String get lobbyTableFull => 'Tisch voll: höchstens $maxTablePlayers Spieler.';

  @override
  String get lobbyTableFullRefusal => 'Der Tisch ist voll: Erst muss jemand aufstehen.';

  @override
  String get lobbyRosterFull => 'Die Liste ist voll: Nimm erst jemanden raus.';

  @override
  String get lobbyGestureHint => 'Tipp ein Gesicht an, um es an den Tisch zu setzen oder aufstehen zu lassen.\nGedrückt halten, um Name oder Foto zu ändern.';

  @override
  String get lobbyOut => 'RAUS';

  @override
  String get lobbyPrivacy => 'Namen und Fotos bleiben auf diesem Handy.';

  @override
  String get lobbyAdd => 'NEU';

  @override
  String get lobbyStart => 'LOS';

  @override
  String get lobbyClearTitle => 'Alle entfernen?';

  @override
  String get lobbyClearBody => 'Damit werden alle Namen und Fotos von diesem Handy gelöscht. Das lässt sich nicht rückgängig machen.';

  @override
  String get lobbyClearCancel => 'ABBRECHEN';

  @override
  String get lobbyClearConfirm => 'ALLE LÖSCHEN';

  @override
  String lobbySeated(int seated) => '$seated AM TISCH';

  @override
  String lobbyMissing(int missing) =>
      missing == 1 ? 'Noch ein Spieler, dann geht es los.' : 'Noch $missing Spieler, dann geht es los.';

  @override
  String get personTitleNew => 'NEUE AKTE';

  @override
  String get personTitleEdit => 'AKTE';

  @override
  String get personPlacardEmpty => 'DEIN NAME';

  @override
  String get personNameHint => 'Wie heißt du?';

  @override
  String get personNameEmpty => 'Kein Name, keine Akte.';

  @override
  String get personNameTooLong => 'Zu lang: höchstens $maxNameLength Buchstaben.';

  @override
  String get personNameTaken => 'Diesen Namen hat schon jemand.';

  @override
  String get personShoot => 'KNIPSEN';

  @override
  String get personReshoot => 'NOCHMAL';

  @override
  String get personGallery => 'GALERIE';

  @override
  String get personNoPhoto => 'KEIN FOTO';

  @override
  String get personHintDrag => 'Ziehen, um das Gesicht zu zentrieren';

  @override
  String get personSubmitNew => 'AN DEN TISCH';

  @override
  String get personSubmitEdit => 'SPEICHERN';

  @override
  String get personPrivacy => 'Das Foto bleibt auf diesem Handy: Das Spiel schickt es nirgendwohin.';

  @override
  String get personCameraDenied => 'Keine Kamera-Erlaubnis. Du kannst sie in den Einstellungen erteilen oder ohne Foto spielen.';

  @override
  String get personCameraFailed => 'Das Foto hat nicht geklappt. Versuch es noch mal oder spiel ohne.';

  @override
  String get personStamp => 'ERFASST';

  @override
  String get personBookedPass => 'Gib das Handy an den Nächsten weiter.';

  @override
  String get personNext => 'DER NÄCHSTE!';

  @override
  String get personDone => 'WIR SIND FERTIG';

  @override
  String get personRemoveTooltip => 'Von der Liste nehmen';

  @override
  String get personRemoveCancel => 'ABBRECHEN';

  @override
  String get personRemoveConfirm => 'ENTFERNEN';

  @override
  String get personRemoveBody => 'Damit werden Name und Foto vom Handy gelöscht.';

  @override
  String personBookedSeated(String name) => '$name sitzt am Tisch.';

  @override
  String personBookedWatching(String name) => 'Der Tisch ist voll: $name schaut erst mal zu.';

  @override
  String personRemoveTitle(String name) => '$name entfernen?';

  @override
  String verdictName(VerdictTake take) => switch (take) {
        VerdictTake.molo => 'Der Pier',
        VerdictTake.cartello => 'Die Stadtgrenze',
        VerdictTake.treno => 'Der letzte Zug',
        VerdictTake.cannone => 'Die Zirkuskanone',
        VerdictTake.assoluzione => 'Kein Urteil',
      };

  @override
  String get someoneSaved => 'JEMAND';

  @override
  String get musicVolumeLabel => 'Musik';

  @override
  String get effectsVolumeLabel => 'Soundeffekte';

  @override
  String get memeMode => 'Meme-Modus';

  @override
  String get memeModeHint => 'Vine Booms, FAAAH und Co. in den großen Momenten.';
}

final class GermanOnlineStrings extends EnglishOnlineStrings {
  const GermanOnlineStrings();

  @override
  String get rankedQueueTitle => 'RANGLISTE';
  @override
  String get rankedStart => 'Spiel suchen';
  @override
  String get rankedSearching => 'Suche nach neuen Gesichtern in der Stadt…';
  @override
  String rankedWaiting(int people) => '$people warten';
  @override
  String rankedEstimate(String time) => 'Geschätzte Wartezeit: $time';
  @override
  String get rankedCancel => 'Abbrechen';
  @override
  String get rankedFound => 'Tisch gefunden!';
  @override
  String get rankedTestMatch => 'TEST · OHNE WERTUNG';
  @override
  String get rankedWarning => 'Wer Spiele verlässt, landet am Tisch mit anderen, die Spiele verlassen.';
  @override
  String rankedCooldown(String time) => 'Zu viele Spiele verlassen: Du kannst dich in $time wieder anstellen.';
  @override
  String get rankedLobbyTitle => 'WARTERAUM';
  @override
  String rankedSeats(int seated, int size) => '$seated/$size am Tisch';
  @override
  String rankedMissing(int missing) => missing == 1 ? 'Noch ein Spieler fehlt' : 'Noch $missing Spieler fehlen';
  @override
  String rankedStartsIn(int seconds) => 'Tisch voll: Start in $seconds';
  @override
  String get rankedLeaveLobby => 'Raum verlassen';
  @override
  String get rankedNoPenalty => 'Vor dem Start kannst du ohne Strafe gehen.';
  @override
  String get rankedTipsTitle => 'WÄHREND DU WARTEST';
  @override
  String get rankedStrangers => 'Wer mit dir am Tisch sitzt, erfährst du, wenn das Spiel beginnt.';
  @override
  String homeQueued(int n) => '$n warten auf einen Tisch';
  @override
  String get rankedSit => 'Platz nehmen';
  @override
  String get rankedTutorialsTitle => 'Zuerst die drei Übungsrunden';
  @override
  String get rankedTutorialsBody =>
      'An einen Ranglisten-Tisch kommt nur, wer die drei Übungsrunden gespielt hat: Familie, Stadt und Einzelgänger. Mit Freunden kannst du sofort spielen.';
  @override
  String rankedTutorialName(String faction) => switch (faction) {
        'family' => 'die Familie',
        'town' => 'die Stadt',
        _ => 'der Einzelgänger',
      };
  @override
  String rankedTutorialPlay(String name) => 'Übungsrunde spielen: $name';
  @override
  String get rankedSkipTutorials => 'Ich kenne das Spiel schon';
  @override
  String get rankedSkipTitle => 'Bist du sicher?';
  @override
  String get rankedSkipBody => 'Du überspringst alle Übungsrunden und gehst direkt in die Rangliste.';
  @override
  String get rankedSkipConfirm => 'Ja, überspringen';
  @override
  String get rankedSkipCancel => 'Lieber nicht';
  @override
  String get rankedPickTable => 'WÄHL DEINEN TISCH';
  @override
  String get rankedRules => '12 Spieler · Runden auf Zeit · wer abhaut, zahlt';
  @override
  String get rankedYourRank => 'DEIN RANG';
  @override
  String rankedTowards(String tier) => 'nächster Rang: $tier';
  @override
  String get rankedTopTier => 'ganz oben in der Familie';
  @override
  String rankedTableQueued(int n) => '$n in der Schlange';
  @override
  String get rankedTableIt => 'Hier wird Italienisch gesprochen';
  @override
  String get rankedTableEn => 'Hier wird Englisch gesprochen';
  @override
  String homeOnline(int n) => '$n Spieler in der Stadt unterwegs';
  @override
  List<String> get rankedTips => const [
        'Rede am Tag, aber nicht zu viel: Die Lautesten landen im Fadenkreuz.',
        'Eine Stimme in letzter Sekunde verrät viel über ihren Absender.',
        'Die Familie gewinnt, sobald sie so viele ist wie die Stadt: Zähl die Köpfe.',
        'Wer ein Spiel verlässt, lässt sein Team im Stich.',
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
  String get dossierTitle => 'PERSONALAKTE';
  @override
  String get dossierHistory => 'LETZTE FÄLLE';
  @override
  String get dossierNoHistory => 'Weiße Weste: noch keine Spiele.';
  @override
  String get dossierSettings => 'Einstellungen';
  @override
  String get dossierConfidential => 'VERTRAULICH';
  @override
  String get dossierName => 'NAME';
  @override
  String steamPersona(String persona) => 'Auf Steam: $persona';
  @override
  String get pictureLabel => 'Profilbild';
  @override
  String get pictureGame => 'Spiel-Avatar';
  @override
  String get pictureSteam => 'Steam-Bild';
  @override
  String handleFromSteam(String persona) =>
      'Von deinem Steam-Namen übernommen: „$persona“. Zufrieden? Speichern, oder ändere ihn.';
  @override
  String get handleSuggestions => 'Frei und ähnlich:';
  @override
  String get dossierRank => 'RANG';
  @override
  String get dossierExperience => 'ERFAHRUNG';
  @override
  String get resultsTitle => 'WIE ES LIEF';
  @override
  String get resultsWon => 'Sieg';
  @override
  String get resultsLost => 'Niederlage';
  @override
  String get resultsLeft => 'Du hast die Stadt verlassen';
  @override
  String resultsXp(int xp) => '+$xp EP';
  @override
  String resultsLevelUp(int level) => 'Level $level!';
  @override
  String resultsCoins(int coins) => '+$coins Münzen';
  @override
  String get resultsRatingUp => 'Dein Rang steigt';
  @override
  String get resultsRatingDown => 'Dein Rang sinkt';
  @override
  String get resultsContinue => 'Weiter';

  @override
  String get posterTitle => 'MIT FREUNDEN\nSPIELEN';
  @override
  String get posterBlurb => 'Ein Online-Raum: ein Code oder ein QR, alle am eigenen Handy.';
  @override
  String get posterStrip => 'ONLINE';

  @override
  String get unavailableTitle => 'NICHT VERFÜGBAR';
  @override
  String get unavailableBody => 'Online-Spiele gibt es in dieser Version nicht. Ein Handy für alle funktioniert wie immer.';

  @override
  String get loginTitle => 'WER BIST DU?';
  @override
  String get loginBody => 'Online brauchst du ein Konto: Profil und Freunde begleiten dich auf jedes Handy.';
  @override
  String get loginApple => 'Mit Apple anmelden';
  @override
  String get loginGoogle => 'Mit Google anmelden';
  @override
  String get loginNoProvider => 'Auf diesem Handy gibt es noch keine Möglichkeit zur Anmeldung.';
  @override
  String get loginPrivacy => 'Das Konto dient nur deinem Spielprofil. Ein Handy für alle braucht kein Konto.';

  @override
  String get signIn => 'ANMELDEN';
  @override
  String get coachSignIn => 'Melde dich an, um online zu spielen';
  @override
  String roomLinkSignIn(String code) => 'Melde dich an, um Raum $code beizutreten.';
  @override
  String get roomLinkInvalid => 'Dieser Link führt zu keinem Raum.';
  @override
  String get technicalReason => 'Technischer Grund';
  @override
  String get pickHandle => 'Wähl deinen Handle';
  @override
  String levelShort(int level) => 'LV. $level';
  @override
  String get level => 'LEVEL';
  @override
  String get coins => 'MÜNZEN';
  @override
  String xpProgress(int xp, int next) => '$xp von $next Erfahrungspunkten';

  @override
  String get loginEmail => 'Mit E-Mail anmelden';
  @override
  String get emailBody =>
      'Wir schicken dir eine E-Mail mit einem 6-stelligen Code und einem Anmeldelink. Kein Passwort.';
  @override
  String get emailBodyCodeOnly =>
      'Wir schicken dir eine E-Mail mit einem 6-stelligen Code, den du hier eingibst. Kein Passwort.';
  @override
  String get emailLabel => 'E-Mail-Adresse';
  @override
  String get emailSend => 'SCHICK MIR DEN CODE';
  @override
  String emailSentTo(String address) =>
      'Wir haben an $address geschrieben. Gib den Code aus der E-Mail ein oder tippe auf den Link: Die App öffnet sich angemeldet.';
  @override
  String emailSentToCodeOnly(String address) =>
      'Wir haben an $address geschrieben. Gib hier den Code aus der E-Mail ein.';
  @override
  String get emailCodeLabel => '6-stelliger Code';
  @override
  String get emailVerify => 'ANMELDEN';
  @override
  String get emailResend => 'Code erneut senden';
  @override
  String emailResendIn(int seconds) => 'Erneut senden in $seconds s';
  @override
  String get emailResent => 'Neuer Code unterwegs: Nur der letzte gilt.';
  @override
  String get emailChange => 'Andere Adresse';
  @override
  String get emailOtherWays => 'Andere Anmeldearten';
  @override
  String get emailSpam => 'Noch nichts da? Schau im Spam-Ordner nach.';

  @override
  String get setupTitle => 'DEIN PROFIL';
  @override
  String get setupBody => 'Dein Handle ist auch der Name, den alle sehen: im Raum, am Tisch und unter Freunden.';
  @override
  String get handleLabel => 'Handle';
  @override
  String get handleHint => 'etwa max.muster';
  @override
  String get save => 'SPEICHERN';
  @override
  String get handleInvalid => '3 bis 12 Zeichen: Kleinbuchstaben, Ziffern, Punkt und Unterstrich.';
  @override
  String get handleChecking => 'Prüfe, ob er frei ist…';
  @override
  String get handleFree => 'Frei: Er gehört dir, wenn du willst.';
  @override
  String handleProblem(HandleProblem problem) => switch (problem) {
        HandleProblem.tooShort => 'Mindestens 3 Zeichen.',
        HandleProblem.tooLong => 'Höchstens 12 Zeichen.',
        HandleProblem.characters => 'Nur Kleinbuchstaben, Ziffern, Punkt und Unterstrich.',
        HandleProblem.start => 'Er darf nicht mit Punkt oder Unterstrich beginnen.',
        HandleProblem.endsWithDot => 'Er darf nicht mit einem Punkt enden.',
        HandleProblem.doubleDot => 'Keine zwei Punkte hintereinander.',
        HandleProblem.tooManySymbols => 'Höchstens drei Symbole hintereinander.',
        HandleProblem.botName => 'Namen mit „bot“ am Anfang gehören den Bots.',
        HandleProblem.notAllowed => 'Name nicht erlaubt.',
      };

  @override
  String get hubTitle => 'MIT FREUNDEN SPIELEN';
  @override
  String signedInAs(String name) => 'Angemeldet als $name';
  @override
  String get hubCreate => 'RAUM ERÖFFNEN';
  @override
  String get hubJoin => 'MIT CODE BEITRETEN';
  @override
  String get friends => 'FREUNDE';
  @override
  String get signOut => 'Abmelden';

  @override
  String get joinTitle => 'RAUM BEITRETEN';
  @override
  String get codeLabel => 'Raumcode';
  @override
  String get joinSubmit => 'BEITRETEN';
  @override
  String get scan => 'QR scannen';
  @override
  String get codeInvalid => 'Der Code hat sechs Zeichen, ohne 0, O, 1, I oder L.';
  @override
  String get scanTitle => 'QR SCANNEN';
  @override
  String get scanHint => 'Richte die Kamera auf den QR am Handy des Gastgebers.';
  @override
  String get scanDenied => 'Ohne Kamera lässt sich der QR nicht lesen: Tipp den Code stattdessen ein.';

  @override
  String get roomTitle => 'DER RAUM';
  @override
  String get roomShareHint => 'Lass sie den QR scannen oder lies den Code vor.';
  @override
  String roomSeated(int seated, int max) => '$seated von $max am Tisch';
  @override
  String get hostBadge => 'GASTGEBER';
  @override
  String get addFriend => 'Als Freund hinzufügen';
  @override
  String friendRequestSent(String name) => 'Freundschaftsanfrage an $name geschickt.';
  @override
  String nowFriends(String name) => 'Du und $name seid jetzt befreundet.';
  @override
  String get leaveRoom => 'RAUM VERLASSEN';
  @override
  String get leaveConfirmTitle => 'Raum verlassen?';
  @override
  String get leaveConfirmBody => 'Dein Platz am Tisch wird frei.';
  @override
  String get leaveConfirm => 'GEHEN';
  @override
  String get stay => 'BLEIBEN';
  @override
  String get chooseHostTitle => 'Wer übernimmt den Raum?';
  @override
  String get chooseHostBody => 'Du bist Gastgeber: Wähl, wer deinen Platz übernimmt, dann geh.';
  @override
  String get botBadge => 'TEST-BOT';
  @override
  String get testBotsNote => 'Testbetrieb: Bots besetzen die freien Plätze.';
  @override
  String get startGame => 'SPIEL STARTEN';
  @override
  String startNeeds(int players) => 'Mindestens $players Leute am Tisch: Lass jemanden rein.';
  @override
  String get waitingForHost => 'Warte, bis der Gastgeber die Karten verteilt.';
  @override
  String get rejoin => 'ZURÜCK AN DEN TISCH';
  @override
  String get gameRunning => 'Das Spiel läuft.';
  @override
  String get reconnecting => 'Zurück an den Tisch…';

  @override
  String get gameConnecting => 'Platz nehmen…';
  @override
  String get yourCard => 'DEINE KARTE';
  @override
  String get yourCardHint => 'Behalt sie für dich: Die anderen sehen nur ihre eigene.';
  @override
  String waitingForOthers(int pending) =>
      pending == 1 ? 'Warte auf die letzte Entscheidung.' : 'Warte auf die anderen: $pending müssen noch wählen.';
  @override
  String get youAreOut => 'Du bist raus. Sieh zu, wie es ausgeht, und halt den Mund.';
  @override
  String get voteTitle => 'DIE STADT STIMMT AB';
  @override
  String get voteHint => 'Tipp an, wen du verurteilen willst. Solange die Abstimmung läuft, kannst du umentscheiden.';
  @override
  String get abstain => 'ENTHALTUNG';
  @override
  String votedFor(String name) => 'Du hast für $name gestimmt';
  @override
  String get abstained => 'Du hast dich enthalten';
  @override
  String votesCast(int votes, int alive) => '$votes von $alive Stimmen';
  @override
  String closesIn(String time) => 'Die Abstimmung endet in $time';
  @override
  String get rejected => 'Dieser Zug ist nicht erlaubt: Versuch es noch mal.';
  @override
  String get serverSilent => 'Der Server antwortet nicht: Prüf deine Verbindung.';
  @override
  String get syncLost => 'Verbindung verloren, neuer Versuch…';
  @override
  String get backToRoom => 'ZURÜCK IN DEN RAUM';
  @override
  String timeLeft(String time) => 'noch $time';
  @override
  String get startingSoon => 'Gleich geht es los…';
  @override
  String get ready => 'BEREIT';
  @override
  String get readyWaiting => 'Warte auf die anderen…';
  @override
  String get moveRegistered => 'Erledigt. Die Stadt schläft…';
  @override
  String get voteRegistered => 'gezählt ✓';
  @override
  String get sending => 'Wird gesendet…';
  @override
  String get offlineBadge => 'offline';
  @override
  String get leaveAbandonWarning =>
      'Wer jetzt geht, gilt als Abbrecher: keine Punkte, keine Münzen, auch wenn deine Seite später gewinnt.';
  @override
  String get leaveDeadWarning => 'Du kannst ohne Strafe gehen, aber gewinnt deine Seite später, bekommst du nichts.';
  @override
  String get resultsAfk => 'Du warst weg: keine Belohnung';
  @override
  String get gameClosed => 'Das Spiel wurde beendet: Keiner hat mehr gespielt.';
  @override
  String get fateLeft => 'Hat die Stadt verlassen';
  @override
  String get youLeftTown => 'Du warst zu lange weg und hast die Stadt verlassen. Sieh zu, wie es ausgeht.';
  @override
  String get youLookOffline => 'Der Server hört dich nicht: Für die anderen bist du offline.';
  @override
  String get connectionLost => 'Verbindung verloren.';
  @override
  String get abstainTag => 'enthält sich';
  @override
  String votesFor(int votes) => votes == 1 ? '1 Stimme' : '$votes Stimmen';
  @override
  String get nightTitleOnline => 'DIE NACHT';
  @override
  String get discussionTitle => 'DIE STADT REDET';
  @override
  String get discussionHint => 'Sag deine Meinung im Chat. Dann wird abgestimmt.';
  @override
  String get accusedTag => 'ANGEKLAGT';
  @override
  String get verdictWaiting => 'Die Stadt hat entschieden.';
  @override
  String get chatHint => 'Schreib…';
  @override
  String get chatLobby => 'RAUM';
  @override
  String get chatTown => 'STADT';
  @override
  String get chatFamily => 'FAMILIE';
  @override
  String get chatEmpty => 'Noch keine Nachrichten.';
  @override
  String get chatNightClosed => 'Nachts schweigt die Stadt.';
  @override
  String get chatDead => 'Aus dem Jenseits kannst du nur mitlesen.';
  @override
  String get chatSilenced =>
      'Der Schneider hat dir den Mund zugenäht: Heute liest du und stimmst ab, aber schreiben kannst du nicht.';
  @override
  String get chatSend => 'Senden';

  @override
  String get searchHint => 'Nach Handle suchen';
  @override
  String get requests => 'ANFRAGEN';
  @override
  String get yourFriends => 'DEINE FREUNDE';
  @override
  String get waiting => 'AUSSTEHEND';
  @override
  String get friendsEmpty => 'Noch keine Freunde. Such nach Handle oder füg sie aus einem Raum hinzu.';
  @override
  String get noResults => 'Keiner mit diesem Handle.';
  @override
  String get accept => 'Annehmen';
  @override
  String get decline => 'Ablehnen';
  @override
  String get add => 'Hinzufügen';
  @override
  String get remove => 'Entfernen';
  @override
  String get withdraw => 'Zurückziehen';

  @override
  String get deviceOneAtATime => 'Du kannst immer nur auf einem Gerät spielen';
  @override
  String deviceContested(String other) => 'Dein Konto ist auch hier offen: $other. Wo willst du spielen?';
  @override
  String get deviceDisplacedTitle => 'Du bist auf einem anderen Gerät verbunden';
  @override
  String deviceDisplaced(String other) => 'Du spielst jetzt auf: $other. Wenn du willst, hol es dir hierher zurück.';
  @override
  String get devicePlayHere => 'HIER SPIELEN';

  @override
  String get updateTitle => 'Update nötig';
  @override
  String updateNewRelease(String latest, String current) =>
      'Version $latest ist da, diese hier ist $current. Aktualisiere, um weiterzuspielen.';
  @override
  String get updateServer => 'Diese Version ist am Tisch nicht mehr erlaubt. Aktualisiere, um weiterzuspielen.';
  @override
  String get updateButton => 'AKTUALISIEREN';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Melde dich zuerst mit einem Konto an.',
        OnlineFailure.appleDisabled => 'Die Anmeldung mit Apple ist auf dem Server nicht aktiviert.',
        OnlineFailure.googleDisabled => 'Die Anmeldung mit Google ist auf dem Server nicht aktiviert.',
        OnlineFailure.emailDisabled => 'Die Anmeldung per E-Mail ist auf dem Server nicht aktiviert.',
        OnlineFailure.invalidEmail => 'Diese E-Mail sieht nicht gültig aus.',
        OnlineFailure.emailCodeWrong => 'Falscher Code: Schau in die letzte E-Mail, die wir dir geschickt haben.',
        OnlineFailure.emailCodeExpired => 'Der Code ist abgelaufen: Fordere einen neuen an.',
        OnlineFailure.emailLinkExpired => 'Der Link ist abgelaufen oder wurde schon benutzt: Gib den Code aus der E-Mail ein oder fordere einen neuen an.',
        OnlineFailure.emailRateLimited => 'Zu viele E-Mails hintereinander: Warte eine Minute und versuch es noch mal.',
        OnlineFailure.emailNotSent => 'Die E-Mail ging nicht raus: Versuch es gleich noch mal.',
        OnlineFailure.profileIncomplete => 'Vervollständige zuerst dein Profil.',
        OnlineFailure.handleTaken => 'Dieser Handle ist schon vergeben.',
        OnlineFailure.invalidHandle => 'Ungültiger Name.',
        OnlineFailure.handleNotAllowed => 'Name nicht erlaubt.',
        OnlineFailure.roomNotFound => 'Kein Raum mit diesem Code.',
        OnlineFailure.roomClosed => 'In diesem Raum wird schon gespielt.',
        OnlineFailure.roomFull => 'Der Raum ist voll.',
        OnlineFailure.hostMustChoose => 'Wähl zuerst, wer den Raum übernimmt.',
        OnlineFailure.playerNotFound => 'Spieler nicht gefunden.',
        OnlineFailure.notAllowed => 'Nicht erlaubt.',
        OnlineFailure.requestNotFound => 'Diese Anfrage gibt es nicht mehr.',
        OnlineFailure.messageBlocked => 'Diese Nachricht kann nicht gesendet werden.',
        OnlineFailure.tooManyMessages => 'Langsam: zu viele Nachrichten hintereinander.',
        OnlineFailure.tooManyReports => 'Du hast schon viele Meldungen geschickt. Versuch es später wieder.',
        OnlineFailure.chatClosed => 'Hier kannst du gerade nicht schreiben.',
        OnlineFailure.reactionClosed => 'Jetzt keine Gesten: nur tagsüber und nur unter den Lebenden.',
        OnlineFailure.reactionCooldown => 'Langsam mit den Gesten: Warte ein paar Sekunden.',
        OnlineFailure.reactionCap => 'Genug Gesten für dieses Spiel.',
        OnlineFailure.notEnoughCoins => 'Du hast nicht genug Münzen.',
        OnlineFailure.alreadyOwned => 'Das gehört dir schon.',
        OnlineFailure.notOwned => 'Kauf es zuerst.',
        OnlineFailure.itemNotFound => 'Dieses Stück gibt es im Laden nicht mehr.',
        OnlineFailure.cancelled => 'Anmeldung abgebrochen.',
        OnlineFailure.rankedCooldown => 'Zu viele Spiele verlassen: Warte etwas, bevor du dich anstellst.',
        OnlineFailure.alreadyInGame => 'Du bist schon in einem Spiel.',
        OnlineFailure.tutorialsRequired => 'Spiel die drei Übungsrunden, um in die Rangliste zu kommen.',
        OnlineFailure.otherDevice => 'Du bist auf einem anderen Gerät verbunden.',
        OnlineFailure.updateRequired => 'Update nötig: Lade die neue Version herunter.',
        OnlineFailure.linkSameAccount => 'Dieses Konto ist schon verknüpft.',
        OnlineFailure.linkConflict =>
          'Diese zwei Konten lassen sich nicht zusammenlegen: Sie nutzen schon dieselbe Art der Anmeldung.',
        OnlineFailure.network => 'Keine Verbindung. Versuch es gleich noch mal.',
        OnlineFailure.unknown => 'Etwas ist schiefgelaufen. Versuch es noch mal.',
      };
}

final class GermanShopStrings extends EnglishShopStrings {
  const GermanShopStrings();

  @override
  String get title => 'BEIM SCHNEIDER';
  @override
  String get subtitle => 'Schneider und Hutmacher · seit 1946';
  @override
  String get greeting => 'Nur zu, probier es an. Der Spiegel lügt nie.';
  @override
  String get coinsHint => 'Münzen gibt es mit jedem Level, und Level gibt es fürs Gewinnen.';
  @override
  String get featured => 'IM SCHAUFENSTER';
  @override
  String endsIn(int days) => days <= 1 ? 'Letzter Tag' : 'Noch $days Tage';
  @override
  String get counterTab => 'THEKE';
  @override
  String get wardrobeTab => 'GARDEROBE';
  @override
  String slot(String slot) => switch (slot) {
    'hat' => 'Hüte',
    'face' => 'Schnurrbärte',
    'glasses' => 'Brillen',
    'outfit' => 'Anzüge',
    'hairdo' => 'Frisuren',
    'tattoo' => 'Tattoos',
    'border' => 'Rahmen',
    'nameStyle' => 'Namen',
    'gesture' => 'Gesten',
    _ => 'Accessoires',
  };
  @override
  String rarity(ShopRarity rarity) => switch (rarity) {
    ShopRarity.base => 'Hausmarke',
    ShopRarity.comune => 'Gewöhnlich',
    ShopRarity.raro => 'Selten',
    ShopRarity.epico => 'Episch',
    ShopRarity.leggendario => 'Legendär',
  };
  @override
  String get owned => 'GEHÖRT DIR';
  @override
  String get worn => 'GETRAGEN';
  @override
  String get free => 'GRATIS';
  @override
  String get buy => 'KAUFEN';
  @override
  String get wear => 'ANZIEHEN';
  @override
  String get takeOff => 'AUSZIEHEN';
  @override
  String get tryingOn => 'Zur Anprobe';
  @override
  String confirmTitle(String item) => '„$item“ kaufen?';
  @override
  String confirmBody(int price, int left) => 'Kostet $price Münzen. Danach hast du noch $left.';
  @override
  String get confirmYes => 'Abgemacht';
  @override
  String get notNow => 'Nicht jetzt';
  @override
  String bought(String item) => '„$item“ gehört dir.';
  @override
  String missing(int coins) => 'Dir fehlen noch $coins Münzen.';
  @override
  String get emptyWardrobe => 'Hier hängt nur, was dir schon gehört.';
  @override
  String get unavailable => 'Der Laden ist zu: Melde dich mit deinem Konto an.';
  @override
  String get brands => 'Marken';
  @override
  String get allBrands => 'Alle';
  @override
  String get oddities => 'Kuriositäten';
  @override
  String get calcioHint => 'Die alten Kurven: Wähl dein Team.';
  @override
  String brandTagline(ShopBrand brand) => switch (brand) {
    ShopBrand.vaugirard => 'Koffer und Reisegepäck · Paris',
    ShopBrand.arminio => 'Weiche Schneiderkunst · Mailand',
    ShopBrand.cuccioli => 'Lederwaren · Florenz',
    ShopBrand.versalli => 'Gold und Barock · Reggio',
    ShopBrand.chanterelle => 'Haute Couture · Paris',
    ShopBrand.nikea => 'Laufen und Leichtathletik',
    ShopBrand.adelphi => 'Leichtathletik zweier Brüder',
  };
  @override
  String dept(ShopDept dept) => switch (dept) {
    ShopDept.window => 'Schaufenster',
    ShopDept.hats => 'Hüte',
    ShopDept.face => 'Gesicht',
    ShopDept.outfit => 'Anzüge',
    ShopDept.vice => 'Laster',
    ShopDept.scene => 'Kulisse',
    ShopDept.back => 'Schultern',
    ShopDept.hands => 'Hände',
    ShopDept.frames => 'Rahmen',
    ShopDept.gestures => 'Gesten',
  };
  @override
  String ownership(ShopOwnership ownership) => switch (ownership) {
    ShopOwnership.all => 'Alle',
    ShopOwnership.mine => 'Meine',
    ShopOwnership.toBuy => 'Zu kaufen',
  };
  @override
  String get filters => 'Filter';
  @override
  String get rarityFilter => 'Klasse';
  @override
  String get collectionFilter => 'Kollektion';
  @override
  String get clearFilters => 'Zurücksetzen';
  @override
  String get search => 'Stück suchen';
  @override
  String count(int shown, int total) => shown == total ? pieces(total) : '$shown von $total';
  @override
  String timeLeft(Duration left) => left.inDays >= 1
      ? '${left.inDays} T ${left.inHours % 24} Std'
      : left.inHours >= 1
      ? '${left.inHours} Std'
      : '${max(1, left.inMinutes)} Min';

  @override
  String get homeSign => 'SCHNEIDER';
  @override
  String get fresh => 'NEU';
  @override
  String get allRarities => 'Alle';
  @override
  String get allSlots => 'Alle';
  @override
  String get affordable => 'Kann ich mir leisten';
  @override
  String get cheapFirst => 'Preis ↑';
  @override
  String get dearFirst => 'Preis ↓';
  @override
  String pieces(int count) => count == 1 ? '1 Stück' : '$count Stück';
  @override
  String get emptyShelf => 'Nichts in diesem Regal.';
  @override
  String get changeFace => 'Gesicht ändern';
  @override
  String get viewBust => 'Figur';
  @override
  String get viewCard => 'Platzkarte';
  @override
  String hand(Hand hand) => hand == Hand.left ? 'Links' : 'Rechts';
  @override
  String get changeFaceHint => 'Gesicht, Haut, Schnurrbart: Geh zum Barbier.';
  @override
  String get back => 'Zurück';
  @override
  String save(int pct) => '$pct % SPAREN';
  @override
  String get bundlesHeading => 'KOMPLETTE LOOKS';
  @override
  String get bundlesHint => 'Zusammen kostet es weniger als Stück für Stück.';
  @override
  String get premiumHeading => 'GRAND LUXE';
  @override
  String get premium => 'GRAND LUXE';
  @override
  String get complete => 'KOMPLETT';
  @override
  String get buyBundle => 'ALLES KAUFEN';
  @override
  String get bundleContents => 'IM PAKET';
  @override
  String get singlesLabel => 'Einzeln';
  @override
  String ownedPart(int owned, int total) => 'Dir gehören $owned von $total: Du zahlst nur den Rest.';
  @override
  String bundleConfirmTitle(String bundle) => '„$bundle“ kaufen?';
  @override
  String bundleConfirmBody(int price, int saved, int left) =>
      'Kostet $price Münzen, $saved weniger als Stück für Stück. Danach hast du noch $left.';
  @override
  String bundleBought(String bundle) => '„$bundle“ gehört ganz dir.';
  @override
  String get seeAll => 'Alle Pakete';
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const germanMessages = <String, String>{
  // ---- settings
  'settings.audio': 'AUDIO',
  'settings.languageSection': 'SPRACHE',
  'settings.game': 'SPIEL',
  'settings.account': 'KONTO',
  'settings.privacy': 'DATENSCHUTZ & DATEN',
  'settings.about': 'ÜBER',
  'settings.signedInAs': 'Angemeldet als @{handle}',
  'settings.signedInNoHandle': 'Angemeldet, noch ohne Handle',
  'settings.notSignedIn': 'Du bist online nicht angemeldet.',
  'settings.privacyPolicy': 'Datenschutzerklärung',
  'settings.terms': 'Nutzungsbedingungen',
  'settings.openOnWeb': 'Im Web öffnen',
  'settings.exportData': 'Meine Daten herunterladen',
  'settings.exportHint': 'Alles, was der Server über dich speichert, als JSON-Datei.',
  'settings.exportFailed': 'Deine Daten ließen sich nicht herunterladen. Versuch es noch mal.',
  'settings.deleteAccount': 'Konto löschen',
  'settings.deleteHint': 'Für immer: Profil, Freunde, Garderobe und Münzen.',
  'settings.deleteTitle': 'Dein Konto löschen?',
  'settings.deleteBody': 'Profil, Look, Freunde, Garderobe, Münzen, Aufträge, Räume und Nachrichten: alles weg, für immer.',
  'settings.deleteContinue': 'Weiter',
  'settings.cancel': 'Abbrechen',
  'settings.deleteTypePrompt': 'Letztes Wort: Tipp „{word}“ zur Bestätigung.',
  'settings.deleteConfirmWord': 'LÖSCHEN',
  'settings.deleteForever': 'Für immer löschen',
  'settings.deleteDone': 'Konto gelöscht. Leb wohl, und danke.',
  'settings.deleteFailed': 'Das Konto ließ sich nicht löschen. Versuch es noch mal.',
  'settings.version': 'Version',
  'settings.credits': 'Credits',
  'settings.creditsBody': 'Sounds und Grafiken von Kenney (kenney.nl) und Freesound (freesound.org), unter der Lizenz CC0. Danke!',
  'settings.yourLook': 'DEIN LOOK',
  'settings.barberSign': 'BARBIER',
  'settings.changeLook': 'Look ändern',
  'settings.lobbyHint': 'Deine Tische: Italienisch, Englisch und {language}.',
  'settings.lobbyHintShared': 'Deine Tische: Italienisch und Englisch.',
  // ---- desktop
  'desktop.loginSteam': 'Mit Steam anmelden',
  'desktop.steamWaiting': 'Schließ die Anmeldung im Browser ab und komm dann zurück.',
  'desktop.screen': 'ANZEIGE',
  'desktop.windowMode': 'Fenster',
  'desktop.windowed': 'Im Fenster',
  'desktop.fullscreen': 'Vollbild',
  'desktop.borderless': 'Rahmenlos',
  'desktop.resolution': 'Auflösung',
  'desktop.resolutionHint': 'Breitere Bildschirme spielen in 16:9, mit Balken an den Seiten.',
  'desktop.orientation': 'Ausrichtung',
  'desktop.landscape': 'Quer',
  'desktop.portrait': 'Hoch',
  'desktop.linkAccount': 'Konto verknüpfen',
  'desktop.linkHint': 'Spiel mit demselben Profil am Handy und am PC.',
  'desktop.linkBody': 'Melde dich mit deinem anderen Konto an: Aus zwei Profilen wird eins.',
  'desktop.linkWith': '{provider} verknüpfen',
  'desktop.linkRule': 'Das ältere Profil gewinnt: Es behält Namen, Münzen, Erfahrung, Garderobe und Wertung. Das andere wird für immer geschlossen.',
  'desktop.linkWaiting': 'Schließ die Anmeldung im Browser ab und komm dann zurück.',
  'desktop.linkDone': 'Konten verknüpft.',
  'desktop.linkSwitched': 'Konten verknüpft: Du bist jetzt im älteren Profil.',
  'desktop.linkAlready': 'Dieses Konto ist schon verknüpft.',
  'desktop.close': 'Schließen',
  'desktop.quit': 'Beenden',
  'desktop.quitTitle': 'Du verlässt die Gasse?',
  'desktop.quitBody': 'Das Spiel wird geschlossen. Keiner hat was gesehen.',
  'desktop.quitConfirm': 'Spiel beenden',
  'desktop.stay': 'Bleiben',
  'desktop.enterHint': 'ENTER zum Bestätigen',
  'desktop.posterEnter': 'Rein',
  // ---- desktopOnline
  'desktopOnline.hubCreateBody': 'Eröffne deinen eigenen Tisch und setz deine Freunde per Code dazu.',
  'desktopOnline.hubJoinBody': 'Jemand hat dir einen Code gegeben? Eintippen, und du bist drin.',
  'desktopOnline.hubFriendsBody': 'Nach Handle suchen, Freundschaftsanfragen beantworten.',
  'desktopOnline.hubDoors': 'Wohin',
  'desktopOnline.profile': 'Dein Profil',
  'desktopOnline.joinHint': 'Tipp den Code ein und drück ENTER.',
  'desktopOnline.invite': 'An den Tisch einladen',
  'desktopOnline.table': 'Am Tisch',
  'desktopOnline.search': 'Suchen',
  'desktopOnline.results': 'Gefunden',
  'desktopOnline.searchEmpty': 'Tipp einen Handle ein, um jemanden zu finden.',
  'desktopOnline.rankedHow': 'So funktioniert es',
  'desktopOnline.freeSeat': 'Freier Platz',
  // ---- desktopGame
  'desktopGame.menu': 'Menü',
  'desktopGame.menuTitle': 'Der Tisch wartet nicht',
  'desktopGame.menuBody': 'Das Spiel läuft weiter, während dieses Menü offen ist: Die Uhr tickt für alle.',
  'desktopGame.resume': 'Zurück an den Tisch',
  'desktopGame.roles': 'Rollen im Spiel',
  'desktopGame.settings': 'Einstellungen',
  'desktopGame.leave': 'Spiel verlassen',
  'desktopGame.stay': 'Am Tisch bleiben',
  'desktopGame.leaveConfirm': 'Gehen',
  'desktopGame.keyEnter': 'Enter',
  'desktopGame.chatKeys': 'ENTER zum Chatten',
  'desktopGame.rightClick': 'Rechtsklick auf einen Spieler: melden oder blockieren',
  'desktopGame.timeLeft': 'Zeit',
  'desktopGame.table': 'Der Tisch',
  'desktopGame.you': 'Du',
  // ---- gameEvent
  'gameEvent.onlyYou': 'NUR DU',
  'gameEvent._team.mafia': 'bei der Familie',
  'gameEvent._team.neutral': 'auf eigene Rechnung unterwegs',
  'gameEvent._team': 'sauber',
  'gameEvent._winner.citizens': 'Die Stadt gewinnt',
  'gameEvent._winner.mafia': 'Die Familie gewinnt',
  'gameEvent._winner.neutral': 'Ein Einzelgänger gewinnt',
  'gameEvent._winner': 'kein Sieger',
  'gameEvent.text.night': 'Nacht {round} bricht herein. Die Stadt schläft.',
  'gameEvent.text.dawn': 'Tag {round} bricht an.',
  'gameEvent.text.dawn.nobodyDiedTonight': 'Heute Nacht ist niemand gestorben.',
  'gameEvent.text.dawn.foundDead': 'Tot aufgefunden: {names}.',
  'gameEvent.text.dawn.theEscortFended': 'Die Eskorte hat einen Anschlag auf den Präsidenten abgewehrt.',
  'gameEvent.text.dawn.someoneWasSaved': 'Jemand wurde gerettet.',
  'gameEvent.text.dawn.attacksFoiled': '{saved} Anschläge vereitelt.',
  'gameEvent.text.dawn.diedOfA': '{broken} ist an gebrochenem Herzen gestorben.',
  'gameEvent.text.scoop': 'Der Knüller der Zeitung: {name} ist {role}.',
  'gameEvent.text.scoop.thePaperS': 'Der Knüller der Zeitung: {name} ist {team}.',
  'gameEvent.text.silenced': 'Der Schneider hat {name} den Mund zugenäht: heute stumm.',
  'gameEvent.text.lynch': 'Enthaltungen: {abstained}',
  'gameEvent.text.lynch.theSquareCondemns': 'Der Platz verurteilt niemanden.',
  'gameEvent.text.lynch.theSquareCondemns.2': 'Der Platz verurteilt {name}: {role}.',
  'gameEvent.text.lynch.collectsTheBounty': ' {bountyHunter} kassiert das Kopfgeld.',
  'gameEvent.text.lynch.diedOfA': ' {heartbroken} ist an gebrochenem Herzen gestorben.',
  'gameEvent.text.mayor': '{name} gibt sich als Bürgermeister zu erkennen: Die Stimme zählt doppelt.',
  'gameEvent.text.truce': '{name}, der Pazifist, ruft Waffenstillstand aus: {target} ist {role}. Heute keine Abstimmung.',
  'gameEvent.text.cannon': ' {heartbroken} ist an gebrochenem Herzen gestorben.',
  'gameEvent.text.cannon.aRoarIn': 'Ein Donnern auf dem Platz: {name}, der Kanonier, hat {target} getroffen, Rolle {role}.',
  'gameEvent.text.shot': ' {heartbroken} ist an gebrochenem Herzen gestorben.',
  'gameEvent.text.shot.aShotFrom': 'Ein Schuss vom Glockenturm geht nach hinten los: {name}, {role}, zielte auf die Stadt.',
  'gameEvent.text.shot.aShotFrom.2': 'Ein Schuss vom Glockenturm: {name} liegt am Boden. Rolle {role}.',
  'gameEvent.text.aim': 'Du hast {name} im Visier.',
  'gameEvent.text.cell': 'Du sitzt in der Zelle. Heute Nacht gehst du nirgendwohin.',
  'gameEvent.text.cell.tonightIsIn': 'Heute Nacht sitzt {name} in der Zelle.',
  'gameEvent.text.converted': 'Du hast das Licht gesehen: Jetzt gehörst du zur Sekte und gewinnst nur mit ihr.',
  'gameEvent.text.door': '{name} gehört jetzt zu dir.',
  'gameEvent.text.door.doorShutDid': 'Tür zu: {name} ist nicht übergetreten.',
  'gameEvent.text.busy': 'Letzte Nacht hat dich jemand beschäftigt.',
  'gameEvent.text.left': '{name} hat die Stadt verlassen.',
  'gameEvent.text.end': 'Spiel beendet: Keiner hat mehr gespielt.',
  'gameEvent.text.end.thePresidentHas': ' Der Präsident ist gefallen.',
  'gameEvent.text.end.gameOver': 'Spiel vorbei: {winner}.',
  'gameEvent.text.end.wonAlone': ' Allein gewonnen: {alone}.',
  'gameEvent.text.found': '{name} war {role}.',
  'gameEvent.text.found.comesUp': 'Ermittlung zu {name}: {team}.',
  'gameEvent.text.watch': 'Jemand war an der Tür von {name}.',
  'gameEvent.text.watch.nobodyCameTo': 'Niemand war an der Tür von {name}.',
  'gameEvent.text.bounty': 'Dein Kopfgeld: Sorg dafür, dass {name} gelyncht wird.',
  'gameEvent.text.doused': 'Mit Benzin übergossen: {names}.',
  'gameEvent.text.familyTarget': 'Die Familie konnte sich nicht einigen.',
  'gameEvent.text.familyTarget.theFamilyChose': 'Die Familie hat {name} gewählt.',
  'gameEvent.text.guard': 'Heute Nacht hast du {name} bewacht.',
  'gameEvent.text.lend': 'Heute Nacht hast du {name} Geld geliehen.',
  'gameEvent.text.protected': 'Heute Nacht hast du über {name} gewacht.',
  'gameEvent.text.dawn.foundOne': 'Tot aufgefunden: {name}.',
  'gameEvent.text.dawn.backAmongLiving': '{name} ist zurück unter den Lebenden.',
  'gameEvent.text.lovers.bound': 'Du hast {first} und {second} aneinander gebunden.',
  'gameEvent.text.lovers.self': 'Das Herz hat gewählt: {first} und {second} lieben sich. Ihr gewinnt nur, wenn ihr beide lebt.',
  // ---- progress
  'progress.missions': 'Aufträge',
  'progress.achievements': 'Erfolge',
  'progress.leaderboard': 'Bestenliste',
  'progress.daily': 'TÄGLICH',
  'progress.weekly': 'WÖCHENTLICH',
  'progress.goals': 'ZIELE',
  'progress.tabDaily': 'HEUTE',
  'progress.tabWeekly': 'WOCHE',
  'progress.tabGoals': 'ZIELE',
  'progress.missionsHint': 'Sie erledigen sich beim Spielen, dann holst du sie ab. Münzen gibt es nur so: Für echtes Geld wird nichts verkauft. Abgebrochene oder untätige Spiele zählen nie.',
  'progress.goalsHint': 'Ziele bleiben, bis du sie erreichst. Manche bringen Stücke, die der Laden nie verkauft.',
  'progress.claim': 'ABHOLEN',
  'progress.claimed': 'ABGEHOLT',
  'progress.late': 'FRÜHER',
  'progress.reputation': 'RESPEKT',
  'progress.reputationGain': '+{n} Respekt',
  'progress.claimDone': 'Abgeholt: {coins} Münzen, +{reputation} Respekt',
  'progress.itemWon': 'Jetzt deins: {name}',
  'progress.reward': 'Belohnung: {name}',
  'progress.unlocksWith': 'Freischalten mit: {mission}',
  'progress.missionOnly': 'Nur über Aufträge',
  'progress.done': 'ERLEDIGT',
  'progress.endsIn': 'endet in {inDays} Tagen',
  'progress.endsIn.endsInH': 'endet in {h} Std',
  'progress.endsIn.endsInMin': 'endet in {d} Min',
  'progress.loadFailed': 'Konnte nicht geladen werden. Versuch es noch mal.',
  'progress.retry': 'Nochmal',
  'progress.unlockedCount': '{n} von {of}',
  'progress.locked': 'Gesperrt',
  'progress.rewardTitle': 'Titel: „{title}“',
  'progress.rewardFrame': 'Gratis-Rahmen',
  'progress.title': 'TITEL',
  'progress.leaderboardEmpty': 'Noch niemand auf der Liste.',
  'progress.leaderboardHint': 'Die besten Hundert der Rangliste, nach Sprache.',
  'progress.yourPlace': 'Du bist auf Platz {rank}',
  'progress.notRanked': 'Spiel ein Ranglistenspiel, um auf die Liste zu kommen.',
  'progress.missionDone': 'Auftrag erledigt: {name}. Hol ihn ab!',
  'progress.achievementDone': 'Erfolg: {name}',
  'progress.mission.daily_play_3': 'Spiel 3 Partien',
  'progress.mission.daily_win_1': 'Gewinn eine Partie',
  'progress.mission.daily_friends_win_2': 'Gewinn 2 Partien mit Freunden',
  'progress.mission.daily_lynch_hits_3': 'Stimm 3-mal gegen den richtigen Mafioso',
  'progress.mission.daily_nights_2': 'Überleb 2 Nächte',
  'progress.mission.daily_ranked_1': 'Spiel 1 Ranglistenpartie',
  'progress.mission.daily_survive_1': 'Sei am Ende einer Partie noch am Leben',
  'progress.mission.daily_town_win_1': 'Gewinn mit der Stadt',
  'progress.mission.daily_mafia_win_1': 'Gewinn mit der Familie',
  'progress.mission.weekly_neutral_win_1': 'Gewinn als Neutraler',
  'progress.mission.weekly_wins_7': 'Gewinn 7 Partien',
  'progress.mission.weekly_play_15': 'Spiel 15 Partien',
  'progress.mission.weekly_lynch_hits_10': 'Stimm 10-mal gegen den richtigen Mafioso',
  'progress.mission.weekly_ranked_5': 'Spiel 5 Ranglistenpartien',
  'progress.mission.weekly_ranked_wins_3': 'Gewinn 3 Ranglistenpartien',
  'progress.mission.weekly_saves_2': 'Rette als Doktor 2 Leben',
  'progress.mission.weekly_finds_3': 'Entlarve als Detektiv 3 Mafiosi',
  'progress.mission.weekly_kills_5': 'Zieh mit der Familie 5 Anschläge durch',
  'progress.mission.weekly_nights_12': 'Überleb 12 Nächte',
  'progress.mission.daily_friends_play_2': 'Spiel 2 Partien mit Freunden',
  'progress.mission.daily_win_alive_1': 'Gewinn und überleb bis zum Ende',
  'progress.mission.daily_survive_2': 'Sei am Ende von 2 Partien noch am Leben',
  'progress.mission.weekly_play_10': 'Spiel 10 Partien',
  'progress.mission.weekly_wins_4': 'Gewinn 4 Partien',
  'progress.mission.weekly_town_wins_3': 'Gewinn 3-mal mit der Stadt',
  'progress.mission.weekly_mafia_wins_2': 'Gewinn 2-mal mit der Familie',
  'progress.mission.weekly_detective_win_1': 'Gewinn eine Partie als Detektiv',
  'progress.mission.weekly_doctor_win_1': 'Gewinn eine Partie als Doktor',
  'progress.mission.long_nights_10': 'Überleb 10 Nächte',
  'progress.mission.long_lynch_hits_3': 'Schick 3 Mafiosi an den Galgen',
  'progress.mission.long_detective_wins_5': 'Gewinn 5 Partien als Detektiv',
  'progress.mission.long_finds_5': 'Entlarve als Detektiv 5 Mafiosi',
  'progress.mission.long_mafia_wins_10': 'Gewinn 10-mal mit der Familie',
  'progress.mission.long_town_wins_10': 'Gewinn 10-mal mit der Stadt',
  'progress.mission.long_wins_50': 'Gewinn 50 Partien',
  'progress.mission.long_games_25': 'Spiel 25 Partien',
  'progress.mission.long_friends_games_20': 'Spiel 20 Partien mit Freunden',
  'progress.mission.long_ranked_games_20': 'Spiel 20 Ranglistenpartien',
  'progress.mission.long_saves_5': 'Rette als Doktor 5 Leben',
  'progress.mission.long_survived_25': 'Sei am Ende von 25 Partien noch am Leben',
  'progress.mission.long_neutral_wins_3': 'Gewinn 3-mal als Einzelgänger',
  'progress.mission': 'Ziel: {target}',
  'progress.achievement.wins_10': 'Glückspilz',
  'progress.achievement': 'Gewinn 10 Partien',
  'progress.achievement.wins_50': 'Ehrenmann',
  'progress.achievement.winGames': 'Gewinn 50 Partien',
  'progress.achievement.wins_200': 'Legende',
  'progress.achievement.winGames.2': 'Gewinn 200 Partien',
  'progress.achievement.games_25': 'Stammgast',
  'progress.achievement.playGames': 'Spiel 25 Partien',
  'progress.achievement.games_100': 'Gehört zum Inventar',
  'progress.achievement.playGames.2': 'Spiel 100 Partien',
  'progress.achievement.games_500': 'Veteran',
  'progress.achievement.playGames.3': 'Spiel 500 Partien',
  'progress.achievement.ranked_wins_10': 'Am grünen Tisch',
  'progress.achievement.winRankedGames': 'Gewinn 10 Ranglistenpartien',
  'progress.achievement.ranked_wins_50': 'Boss',
  'progress.achievement.winRankedGames.2': 'Gewinn 50 Ranglistenpartien',
  'progress.achievement.friends_wins_25': 'Unter Freunden',
  'progress.achievement.winGamesWith': 'Gewinn 25 Partien mit Freunden',
  'progress.achievement.town_wins_25': 'Musterbürger',
  'progress.achievement.winTimesWith': 'Gewinn 25-mal mit der Stadt',
  'progress.achievement.mafia_wins_25': 'Ein gemachter Mann',
  'progress.achievement.winTimesWith.2': 'Gewinn 25-mal mit der Familie',
  'progress.achievement.neutral_wins_1': 'Auf eigene Faust',
  'progress.achievement.winAsA': 'Gewinn als Neutraler',
  'progress.achievement.neutral_wins_10': 'Einsamer Wolf',
  'progress.achievement.winTimesAs': 'Gewinn 10-mal als Neutraler',
  'progress.achievement.roles_won_5': 'Viele Gesichter',
  'progress.achievement.winWithDifferent': 'Gewinn mit 5 verschiedenen Rollen',
  'progress.achievement.roles_won_12': 'Alter Bühnenhase',
  'progress.achievement.winWithDifferent.2': 'Gewinn mit 12 verschiedenen Rollen',
  'progress.achievement.roles_won_all': 'Chamäleon',
  'progress.achievement.winWithEvery': 'Gewinn mit jeder Rolle',
  'progress.achievement.roles_town_all': 'Die ganze Stadt',
  'progress.achievement.winWithEvery.2': 'Gewinn mit jeder Rolle der Stadt',
  'progress.achievement.roles_mafia_all': 'Die ganze Familie',
  'progress.achievement.winWithEvery.3': 'Gewinn mit jeder Rolle der Familie',
  'progress.achievement.roles_lone_all': 'Alle Einzelgänger',
  'progress.achievement.winWithEvery.4': 'Gewinn mit jeder Einzelgänger-Rolle',
  'progress.achievement.wins_alive_25': 'Dickes Fell',
  'progress.achievement.winTimesStill': 'Gewinn 25-mal und bleib dabei am Leben',
  'progress.achievement.lynch_hits_10': 'Gute Nase',
  'progress.achievement.voteCondemnedMafiosi': 'Stimm gegen 10 verurteilte Mafiosi',
  'progress.achievement.lynch_hits_50': 'Spürhund',
  'progress.achievement.voteCondemnedMafiosi.2': 'Stimm gegen 50 verurteilte Mafiosi',
  'progress.achievement.lynch_hits_200': 'Rächer',
  'progress.achievement.voteCondemnedMafiosi.3': 'Stimm gegen 200 verurteilte Mafiosi',
  'progress.achievement.nights_25': 'Schlaflos',
  'progress.achievement.surviveNights': 'Überleb 25 Nächte',
  'progress.achievement.nights_100': 'Nachteule',
  'progress.achievement.surviveNights.2': 'Überleb 100 Nächte',
  'progress.achievement.saves_1': 'Erste Hilfe',
  'progress.achievement.saveALife': 'Rette als Doktor ein Leben',
  'progress.achievement.saves_10': 'Schutzengel',
  'progress.achievement.saveLivesAs': 'Rette als Doktor 10 Leben',
  'progress.achievement.countryDoctor': 'Landarzt',
  'progress.achievement.asTheDoctor': 'Rette als Doktor jemanden und überleb bis zum Schluss',
  'progress.achievement.finds_10': 'Bullenriecher',
  'progress.achievement.unmaskMafiosiAs': 'Entlarve als Detektiv 10 Mafiosi',
  'progress.achievement.theInspector': 'Der Inspektor',
  'progress.achievement.asTheDetective': 'Bring als Detektiv den Paten an den Galgen',
  'progress.achievement.snipes_1': 'Sauberer Schuss',
  'progress.achievement.asTheSniper': 'Erledige als Scharfschütze einen Mafioso',
  'progress.achievement.kills_25': 'Harte Hand',
  'progress.achievement.successfulHitsWith': '25 gelungene Anschläge mit der Familie',
  'progress.achievement.framed_5': 'Intrigant',
  'progress.achievement.asAMafioso': 'Bring als Mafioso 5 Unschuldige an den Galgen',
  'progress.achievement.fool_win': 'Wer zuletzt lacht',
  'progress.achievement.winAsThe': 'Gewinn als Trottel',
  'progress.achievement.winAGame': 'Gewinn eine Partie mit dieser Rolle',
  'progress.titleName.man_of_honor': 'Ehrenmann',
  'progress.titleName.legend': 'Legende',
  'progress.titleName.veteran': 'Veteran',
  'progress.titleName.boss': 'Boss',
  'progress.titleName.model_citizen': 'Musterbürger',
  'progress.titleName.made_man': 'Ein gemachter Mann',
  'progress.titleName.lone_wolf': 'Einsamer Wolf',
  'progress.titleName.chameleon': 'Chamäleon',
  'progress.titleName.bloodhound': 'Spürhund',
  'progress.titleName.night_owl': 'Nachteule',
  'progress.titleName.guardian_angel': 'Schutzengel',
  'progress.titleName.inspector': 'Der Inspektor',
  'progress.titleName.schemer': 'Intrigant',
  'progress.toClaim': '{n} zum Abholen',
  // ---- recap
  'recap.open': 'DER GANZE BERICHT',
  'recap.masthead': 'Der ganze Bericht',
  'recap.dateLine': 'Sonderausgabe · alle Karten auf dem Tisch',
  'recap.cast': 'Wer war wer',
  'recap.timeline': 'Nacht für Nacht, Tag für Tag',
  'recap.night': 'Nacht {round}',
  'recap.day': 'Tag {round}',
  'recap.won': 'GEWONNEN',
  'recap.wonAlone': 'ALLEIN GEWONNEN',
  'recap.survived': 'am Leben',
  'recap.fell': 'gefallen',
  'recap.left': 'abgehauen',
  'recap.close': 'SCHLIESSEN',
  'recap.you': 'du',
  'recap.quietNight': 'Eine Nacht ohne Zug.',
  'recap.team.citizens': 'Stadt',
  'recap.team.mafia': 'Familie',
  'recap.team.neutral': 'auf eigene Rechnung',
  'recap.winner.citizens': 'Die Stadt gewinnt',
  'recap.winner.mafia': 'Die Familie gewinnt',
  'recap.winner.neutral': 'Der Brandstifter gewinnt',
  'recap.winner.null': 'Kein Sieger',
  'recap.familyAimed': 'Die Familie hatte es auf {target} abgesehen ({voters}).',
  'recap.familyNobody': 'Die Familie konnte sich nicht einigen.',
  'recap.move.silence': 'hat {target} den Mund zugenäht.',
  'recap.move.protect': 'hat über {target} gewacht.',
  'recap.move.guard': 'hat {target} bewacht.',
  'recap.move.snipe': 'hat auf {target} geschossen.',
  'recap.move.scoop': 'hat den Knüller über {target} gebracht.',
  'recap.move.douse': 'hat {target} mit Benzin übergossen.',
  'recap.move.ignite': 'hat das Streichholz angezündet.',
  'recap.move.resurrect': 'hat {target} ins Leben zurückgeholt.',
  'recap.move.lend': 'hat {target} Geld geliehen.',
  'recap.move.stab': 'hat {target} abgestochen.',
  'recap.move.jail': 'hat {target} eingesperrt.',
  'recap.move.block': 'hat die Nacht mit {target} verbracht.',
  'recap.move.link': 'hat {target} verliebt gemacht.',
  'recap.move.convert': 'hat {target} zur Sekte gerufen.',
  'recap.move.aim': 'hat {target} ins Visier genommen.',
  'recap.attack.family': 'von der Familie',
  'recap.attack.sniper': 'vom Scharfschützen',
  'recap.attack.fire': 'vom Feuer',
  'recap.attack.assassin': 'vom Auftragskiller',
  'recap.attack.shrugged': '{target} hat den Schlag {by} eingesteckt und lebt.',
  'recap.attack.escorted': 'Die Eskorte hat den Anschlag {by} auf {target} abgewehrt.',
  'recap.scoopOut.mafia': 'Die Zeitung ist raus: {target} gehört zur Familie.',
  'recap.scoopOut.citizens': 'Die Zeitung ist raus: {target} ist sauber.',
  'recap.scoopOut.neutral': 'Die Zeitung ist raus: {target} spielt allein.',
  'recap.mayor': '{name} gibt sich als Bürgermeister zu erkennen: Die Stimme zählt doppelt.',
  'recap.votes': 'Die Abstimmung',
  'recap.abstained': 'enthält sich',
  'recap.noCondemned': 'Der Platz verurteilt niemanden.',
  'recap.foolWins': '{name} wollte genau das: gewinnt allein.',
  'recap.bounty': '{hunter} kassiert das Kopfgeld.',
  'recap.exit': '{name} hat die Stadt verlassen.',
  'recap.leftTown': '{name} hat die Bühne verlassen.',
  'recap.wentAway': '{name} ist vom Tisch aufgestanden.',
  'recap.cameBack': '{name} ist zurück am Tisch.',
  'recap.calledOut': '{name} nimmt dich ins Visier.',
  'recap.move.investigate': 'hat {target} überprüft: {seen, select, mafia{Familie} other{sauber}}.',
  'recap.move.dig': 'hat {target} ausgegraben: Rolle {role}.',
  'recap.move.watch': 'hat die Tür von {target} beobachtet: {visited, select, yes{jemand kam vorbei} other{niemand kam vorbei}}.',
  'recap.attack.killed': '{target} wurde {by} getötet.',
  'recap.attack.healed': '{target}, {by} getroffen, wurde gerettet.',
  'recap.risen': '{target} ist zurück unter den Lebenden.',
  'recap.condemned': 'Der Platz verurteilt {name}. Rolle: {role}.',
  // ---- rolesSheet
  'rolesSheet.button': 'ROLLEN',
  'rolesSheet.title': 'Rollen im Spiel',
  'rolesSheet.subtitle': 'Die Karten dieses Spiels. Wer sie hält, bleibt geheim.',
  'rolesSheet.deckEmpty': 'Das Blatt ist noch nicht bekannt.',
  'rolesSheet.legendTitle': 'Was die Symbole bedeuten',
  'rolesSheet.revealedBy': 'enthüllt: {name}',
  'rolesSheet.silenced': 'stumm',
  'rolesSheet.silencedLegend': 'vom Schneider zum Schweigen gebracht: darf heute nicht schreiben, aber abstimmen',
  'rolesSheet.offline': 'weg',
  'rolesSheet.offlineLegend': 'grauer Punkt: Die Verbindung ist abgerissen',
  'rolesSheet.dead': 'tot',
  'rolesSheet.deadLegend': 'Nelke oder Dolch: tot',
  'rolesSheet.accused': 'angeklagt',
  'rolesSheet.accusedLegend': 'Band ANGEKLAGT: gerade die meisten Stimmen',
  'rolesSheet.votes': 'erhaltene Stimmen',
  'rolesSheet.votesLegend': 'roter Kreis mit Zahl: erhaltene Stimmen',
  'rolesSheet.voteNote': 'gestimmt für',
  'rolesSheet.voteNoteLegend': 'Notiz „→ Name“: für wen gestimmt wurde',
  'rolesSheet.revealedRole': 'Rolle enthüllt',
  'rolesSheet.revealedRoleLegend': 'Rollensymbol oder -name auf einem Platz: eine Rolle, die du kennst',
  'rolesSheet.selected': 'gewählt',
  'rolesSheet.meLegend': 'goldenes Namensschild: Das bist du',
  'rolesSheet.teamLabel': 'Seite',
  'rolesSheet.nightLabel': 'Nachts',
  'rolesSheet.winLabel': 'Du gewinnst, wenn',
  'rolesSheet.twistLabel': 'Achtung',
  'rolesSheet.teamFamily': 'die Familie',
  'rolesSheet.teamTown': 'die Stadt',
  'rolesSheet.teamAlone': 'auf eigene Faust',
  // ---- safety
  'safety.report': 'Melden',
  'safety.block': 'Blockieren',
  'safety.unblock': 'Freigeben',
  'safety.cancel': 'Abbrechen',
  'safety.send': 'Senden',
  'safety.reportTitle': '{name} melden',
  'safety.reportWhy': 'Was ist passiert?',
  'safety.reason.language': 'Beleidigende Sprache',
  'safety.reason.cheating': 'Schummeln oder Spiele verlassen',
  'safety.reason.identity': 'Unpassender Name oder Look',
  'safety.reason.spam': 'Spam',
  'safety.reason.other': 'Sonstiges',
  'safety.noteHint': 'Details (optional)',
  'safety.reportPrivate': 'Das bleibt unter uns: Niemand erfährt, wer gemeldet hat.',
  'safety.reportSent': 'Meldung erhalten. Wir kümmern uns darum.',
  'safety.reportedMessage': 'Gemeldete Nachricht',
  'safety.blockTitle': '{name} blockieren?',
  'safety.blockBody': 'Aus den Augen: keine Nachrichten, keine Freundschaft, kein Platz in deinen Räumen. In der Rangliste sitzt ihr an verschiedenen Tischen. Du kannst es in den Einstellungen rückgängig machen.',
  'safety.muteChat': 'Chat stummschalten',
  'safety.unmuteChat': 'Chat wieder an',
  'safety.chatMuted': 'Du siehst die Nachrichten von {name} nicht mehr (nur hier).',
  'safety.chatUnmuted': 'Du siehst die Nachrichten von {name} wieder.',
  'safety.seat': 'Platz {number}',
  'safety.atTable': 'Am Tisch',
  'safety.outOfGame': 'Aus dem Spiel',
  'safety.inRoom': 'Im Raum',
  'safety.blocked': 'Du hast {name} blockiert.',
  'safety.unblocked': 'Du hast {name} freigegeben.',
  'safety.blockedPlayers': 'Blockierte Spieler',
  'safety.blockedHint': 'Wen du blockiert hast, und wie du die Blockade aufhebst.',
  'safety.noneBlocked': 'Du hast niemanden blockiert.',
  'safety.rulesTitle': 'Regeln der Gemeinschaft',
  'safety.rulesHint': 'Wie wir uns am Tisch benehmen.',
  'safety.rulesEnforcement': 'Du kannst einen Spieler melden, indem du am Tisch das Gesicht antippst oder eine Nachricht lange gedrückt hältst. Jede Meldung wird geprüft: Wer gegen die Regeln verstößt, kann Chat, Rangliste oder Konto verlieren. Beleidigende Nachrichten und Namen werden automatisch blockiert.',
  'safety.rulesContact': 'Für dringende Meldungen, E-Mail an',
  'safety.rules.1': 'Lüg im Spiel, nicht die Menschen an. Bluffen gehört zu Obertà; Beleidigungen, Drohungen und Belästigung nicht.',
  'safety.rules.2': 'Keine Hassrede, keine Schimpfwörter, keine sexuellen Inhalte und keine Angriffe auf Herkunft, Religion, Geschlecht, Orientierung oder Behinderung.',
  'safety.rules.3': 'Namen und Looks müssen anständig sein: keine beleidigenden Namen, kein Auftreten als Team-Mitglied oder als anderer Spieler.',
  'safety.rules.4': 'Spiel deine Partie zu Ende. Abhauen, absichtlich verlieren oder Absprachen außerhalb des Spiels verderben allen den Spaß.',
  'safety.rules.5': 'Kein Spam, keine Werbung, keine Links und keine persönlichen Daten: Teil nie Telefonnummern, Adressen oder Social-Media-Konten.',
  'safety.rules.6': 'Sei nett zu Neuen. Jeder war mal neu.',
  // ---- stats
  'stats.tabFile': 'AKTE',
  'stats.tabStats': 'STATISTIK',
  'stats.title': 'PERSÖNLICHE STATISTIK',
  'stats.includeTests': 'Testspiele einbeziehen',
  'stats.games': 'Partien',
  'stats.wins': 'Gewonnen',
  'stats.losses': 'Verloren',
  'stats.winRate': 'Siegquote',
  'stats.atTheTable': 'AM TISCH',
  'stats.timePlayed': 'Zeit am Tisch',
  'stats.timeMeasured': 'gemessen über {timed} von {games} Partien',
  'stats.favouriteRole': 'Lieblingsrolle',
  'stats.longestStreak': 'Längste Siegesserie',
  'stats.survived': 'Am Ende am Leben',
  'stats.byTable': 'NACH TISCH',
  'stats.friends': 'Mit Freunden',
  'stats.ranked': 'Rangliste',
  'stats.byFaction': 'NACH SEITE',
  'stats.family': 'Familie',
  'stats.town': 'Stadt',
  'stats.alone': 'Auf eigene Faust',
  'stats.byRole': 'NACH ROLLE',
  'stats.neverPlayed': 'nie gespielt',
  'stats.feats': 'TATEN',
  'stats.featsHint': 'Seit jeher, nur aus Partien, die zu Ende gespielt wurden.',
  'stats.counter.nights': 'Überlebte Nächte',
  'stats.counter.lynch_hits': 'Richtige Lynch-Stimmen',
  'stats.counter.saves': 'Rettungen als Doktor',
  'stats.counter.finds': 'Gefundene Täter',
  'stats.counter.snipes': 'Schüsse als Scharfschütze',
  'stats.counter.kills': 'Anschläge der Familie',
  'stats.counter.framed': 'Reingelegte Ehrliche',
  'stats.counter.godfather_lynch': 'Gelynchte Paten',
  'stats.counter.wins_alive': 'Lebend gewonnen',
  'stats.private': 'NUR FÜR DICH',
  'stats.privateHint': 'Diese Zahlen sieht sonst keiner.',
  'stats.abandoned': 'Verlassen',
  'stats.afk': 'Abwesend (AFK)',
  'stats.reserved': 'GESPERRT',
  'stats.empty': 'Noch keine Online-Partien. Die Statistik schreibt sich beim Spielen von selbst.',
  'stats.loadFailed': 'Konnte nicht geladen werden. Versuch es noch mal.',
  'stats.retry': 'Nochmal',
  'stats.profile': 'Profil',
  'stats.publicTitle': 'ÖFFENTLICHE AKTE',
  'stats.onRecord': 'AKTENKUNDIG',
  'stats.featured': 'MEDAILLEN IN DER VITRINE',
  'stats.noMedals': 'Noch keine Medaillen.',
  'stats.topRoles': 'MEISTGESPIELTE ROLLEN',
  'stats.closedFile': 'Gesperrte Akte: Diese Statistik bleibt privat.',
  'stats.unavailable': 'Profil nicht verfügbar.',
  'stats.publicSwitch': 'Öffentliches Profil',
  'stats.publicSwitchHint': 'Andere sehen deine Statistik, deinen Rang und deine Medaillen. Aus: nur Name, Level und Porträt.',
  'stats.gamesWins': '{games, plural, one{# Partie} other{# Partien}} · {wins} gewonnen',
  // ---- table
  'table.holdTheCard': 'Halt die Karte gedrückt, um sie anzusehen.',
  'table.picked': 'Du hast {name} gewählt. Du kannst bis zum Ablauf der Zeit umentscheiden.',
  'table.passed': 'Du hast gepasst. Du kannst noch jemanden wählen.',
  'table.familyPicks': 'Familie: {picks}',
  'table.nightRunsOut': 'Die Nacht endet, wenn die Zeit abläuft.',
  'table.investigate': '{name} überprüfen?',
  'table.dig': '{name} ausgraben?',
  'table.instantAnswer': 'Die Antwort kommt sofort, danach kannst du nichts mehr ändern.',
  'table.cancel': 'Abbrechen',
  'table.jail': '{name} einsperren?',
  'table.jailBody': 'Die Zelle schließt sofort: Wer drin sitzt, kann heute Nacht nichts tun, und keiner kommt ran. Du kannst es nicht ändern.',
  'table.youAreJailed': 'Du sitzt in der Zelle. Heute Nacht gehst du nirgendwohin.',
  'table.jailerWantsYou': 'Der Schließer will ein Wörtchen reden.',
  'table.inYourCell': 'In deiner Zelle: {name}. Verhör im Chat.',
  'table.lastOfFamily': 'Von der Familie bist nur noch du übrig: Jetzt gehört die Nacht dir.',
  'table.mateInCell': 'Heute Nacht sitzt {name} in der Zelle.',
  'table.jailChat': 'Die Zelle',
  'table.jailer': 'Der Schließer',
  'table.converted': 'Du hast das Licht gesehen: Jetzt gehörst du zur Sekte und gewinnst nur mit ihr.',
  'table.sectLine': 'Deine Sekte: {names}.',
  'table.doorClosed': 'Tür zu: {name} ist nicht übergetreten.',
  'table.linkFirst': 'Tipp das erste Herz an.',
  'table.linkSecond': '{name} und wer noch? Tipp das zweite Herz an.',
  'table.link': '{a} und {b} verkuppeln?',
  'table.linkBody': 'Sie erfahren es im Morgengrauen und gewinnen nur, wenn beide leben. Du kannst es nicht ändern.',
  'table.loversLine': 'Verliebt: {a} und {b}.',
  'table.inLoveWith': 'Dein Herz schlägt für {name}.',
  'table.loversChat': 'Die Verliebten',
  'table.answerAtDawn': 'Jemand an diesem Tisch blockiert: Die Antwort kommt im Morgengrauen.',
  'table.readTheNews': 'Lies die Nachrichten, dann „Bereit“.',
  'table.votedFor': 'Du hast für {name} gestimmt. Du kannst umentscheiden.',
  'table.revealMayor': 'Enthüllen',
  'table.revealMayorTitle': 'Dich als Bürgermeister zu erkennen geben?',
  'table.revealMayorBody': 'Alle wissen dann, wer du bist, und ab heute zählt deine Stimme doppelt.',
  'table.shootTitle': 'Auf {name} schießen?',
  'table.shotLine': 'Der Schuss ging nach hinten los: {name} war {role}.',
  'table.shotLine.aShotFrom': 'Ein Schuss vom Glockenturm: {name} war {role}.',
  'table.aimLine': 'Im Visier: {name}. Schüsse: {left}.',
  'table.truce': 'Waffenstillstand',
  'table.truceHint': 'Tipp an, wen du vor allen enthüllst.',
  'table.truceTitle': 'Alles stopp: {name} enthüllen?',
  'table.truceBody': 'Alle sehen die genaue Rolle, und deine. Heute keine Abstimmung. Nur einmal.',
  'table.truceLine': '{pacifist} hat Waffenstillstand ausgerufen: {name} ist {role}.',
  'table.truceVerdict': 'Waffenstillstand: Heute hängt keiner.',
  'table.fire': 'Feuer!',
  'table.fireHint': 'Tipp an, wen du triffst.',
  'table.fireTitle': 'Feuer auf {name}?',
  'table.fireBody': 'Die Person stirbt sofort, und ihre Rolle wird öffentlich. Alle hören das Donnern: Dann wissen sie, wer die Kanone hat.',
  'table.shotsLeft': 'Du hast noch einen Schuss.',
  'table.shotsLeft.youHaveShots': 'Du hast noch {count} Schüsse.',
  'table.gunnerShotsLeft': 'Der Kanonier hat keine Schüsse mehr.',
  'table.gunnerShotsLeft.theGunnerHas': 'Der Kanonier hat noch einen Schuss.',
  'table.gunnerShotsLeft.theGunnerHas.2': 'Der Kanonier hat noch {count} Schüsse.',
  'table.cannonLine': 'Ein Donnern auf dem Platz: Der Kanonier hat {name} getroffen, Rolle {role}.',
  'table.noLynch': 'Niemand wurde gelyncht.',
  'table.chatOpensLater': 'Der Platz öffnet wieder zur Diskussion.',
  'table.chatOver': 'Das Spiel ist vorbei.',
  'table.rejoin': 'Zurück',
  'table.leave': 'Gehen',
  'table.abstained': 'Du hast dich enthalten. Du kannst noch abstimmen.',
  'table.silenced': 'stumm',
  'table.lynched': 'Gelyncht',
  'table.lynchedLine': '{name} wurde gelyncht.',
  'table.lynchedLine.role': '{name} wurde gelyncht. Rolle: {role}.',
  'table.abstainedVotes': '{n, plural, one{# Enthaltung} other{# Enthaltungen}}',
  'table.shootBody': 'Alle hören es, keiner weiß, wer geschossen hat. Gehört die Person zur Stadt, geht der Schuss nach hinten los und du stirbst. {left, plural, one{Es ist dein letzter Schuss.} other{Du hast noch # Schüsse.}}',
  // ---- tutorial
  'tutorial.you': 'Du',
  'tutorial.skip': 'Überspringen',
  'tutorial.exit': 'Gehen',
  'tutorial.exitTitle': 'Übungsrunde verlassen?',
  'tutorial.exitBody': 'Sie zählt dann nicht als erledigt: Du kannst sie jederzeit wieder spielen.',
  'tutorial.stay': 'Bleiben',
  'tutorial.hint': 'Zum ersten Mal hier? Drei Übungsrunden, eine pro Farbe.',
  'tutorial.hintGo': 'Probieren',
  'tutorial.replay': 'Tutorial',
  'tutorial.replayHint': 'Drei Übungsrunden gegen die Bots.',
  'tutorial.deskButton': 'Tutorial',
  'tutorial.choose': 'Wähl eine Seite zum Lernen',
  'tutorial.chooseSub': 'Eine Runde gegen fünf Bots, am echten Tisch.',
  'tutorial.faction.family': 'Familie',
  'tutorial.faction.city': 'Stadt',
  'tutorial.faction.solo': 'Auf eigene Faust',
  'tutorial.pitch.family': 'Nachts töten, tagsüber lügen.',
  'tutorial.pitch.city': 'Ermitteln, die Familie entlarven.',
  'tutorial.pitch.solo': 'Lass dich lynchen und gewinn allein.',
  'tutorial.done': 'Erledigt',
  'tutorial.ready': 'Jetzt bist du bereit',
  'tutorial.toTheTable': 'An den Tisch',
  'tutorial.nextHand': 'Noch eine Runde',
  // ---- tutorialScript
  'tutorialScript.whenYouHave': 'Wenn du es gelesen hast: „Bereit“.',
  'tutorialScript.atDawnYou': 'Im Morgengrauen siehst du, wie die Nacht gelaufen ist.',
  'tutorialScript.theTownWins.city': 'Die Stadt gewinnt, wenn keiner von der Familie mehr übrig ist. Beweise schlagen Gerede.',
  'tutorialScript.youAreThe.city': 'Du bist Detektiv. Halt die Karte gedrückt, dann „Bereit“.',
  'tutorialScript.atNightYou.city': 'Nachts ermittelst du. Tipp Vito an, Platz 2, und bestätige.',
  'tutorialScript.vitoIsFamily.city': 'Vito gehört zur Familie. Das weißt erst mal nur du.',
  'tutorialScript.brunoNeverHurt.city': 'Bruno hat nie jemandem was getan. Wer wollte ihn tot sehen?',
  'tutorialScript.iWasAt.city': 'Ich war die ganze Nacht in der Bar. Frag die 4.',
  'tutorialScript.trueLookAt.city': 'Stimmt. Schaut lieber auf die 6: viel zu ruhig.',
  'tutorialScript.meDetectiveWhat.city': 'Ich?? Detektiv, was weißt du?',
  'tutorialScript.iCheckedVito.city': 'Ich habe Vito überprüft: Familie.',
  'tutorialScript.isLyingI.city': 'Die 2 lügt. Ich habe ihn heute Nacht gesehen.',
  'tutorialScript.liarHeJust.city': 'Lügner! Er will euch nur verwirren.',
  'tutorialScript.ifTheDetective.city': 'Wenn der Detektiv das sagt, bin ich dabei.',
  'tutorialScript.meTooWe.city': 'Ich auch. Wir stimmen für die 2.',
  'tutorialScript.theSquareTalks.city': 'Der Platz redet. Sag, was du über Vito weißt.',
  'tutorialScript.theyBelieveYou.city': 'Sie glauben dir. „Bereit“, und wir stimmen ab.',
  'tutorialScript.onSecondThought.city': 'Wenn ich es mir recht überlege … die 2.',
  'tutorialScript.watchTheHands.city': 'Achte auf die Hände: Meinungen ändern sich. Zeig auf Vito.',
  'tutorialScript.theLynchedShows.city': 'Wer gelyncht wird, zeigt die Karte. Der Platz lag richtig.',
  'tutorialScript.anotherNightCheck.city': 'Noch eine Nacht. Überprüf Carmela, Platz 4.',
  'tutorialScript.carmelaIsFamily.city': 'Carmela gehört auch zur Familie.',
  'tutorialScript.tonightTheyCame.city': 'Heute Nacht sind sie dich holen gekommen …',
  'tutorialScript.theDoctorSaved.city': 'Der Doktor hat dich gerettet. Jetzt bist du dran.',
  'tutorialScript.iWatchedOver.city': 'Ich habe heute Nacht über den Detektiv gewacht. Sie haben es versucht.',
  'tutorialScript.luckyYouBut.city': 'Glück gehabt … aber Vito hat allein gehandelt.',
  'tutorialScript.detectiveWhoDid.city': 'Detektiv, wen hast du heute Nacht überprüft?',
  'tutorialScript.carmelaFamily.city': 'Carmela: Familie.',
  'tutorialScript.isTheLast.city': 'Die 4 ist die Letzte. Stimmt gegen sie.',
  'tutorialScript.ohPleaseIs.city': 'Ach bitte! Die 1 fantasiert.',
  'tutorialScript.iSavedYou.city': 'Ich habe dich gerettet: Ich vertraue dir.',
  'tutorialScript.weVote.city': 'Wir stimmen für die 4.',
  'tutorialScript.lastDayTell.city': 'Letzter Tag. Erzähl dem Platz von Carmela.',
  'tutorialScript.goodReadyAnd.city': 'Gut. „Bereit“, und wir stimmen ab.',
  'tutorialScript.noWait.city': 'Nein, warte: die 4.',
  'tutorialScript.voteCarmela.city': 'Stimm gegen Carmela.',
  'tutorialScript.noFamilyLeft.city': 'Keiner von der Familie mehr übrig: Die Stadt gewinnt.',
  'tutorialScript.theFamilyWins.family': 'Die Familie gewinnt, sobald sie so viele ist wie die Stadt. Tagsüber: gut lügen.',
  'tutorialScript.thisTimeYou.family': 'Diesmal gehörst du zur Familie. Halt die Karte gedrückt, dann „Bereit“.',
  'tutorialScript.justTheTwo.family': 'Nur wir zwei. Keiner darf es wissen.',
  'tutorialScript.iSayEnzo.family': 'Ich sage die 6, Enzo: zu viele Fragen. Und du?',
  'tutorialScript.ok.family': 'Okay, die 6.',
  'tutorialScript.fineEnzoTonight.family': 'Gut, heute Nacht Enzo.',
  'tutorialScript.perfectTap.family': 'Perfekt. Tipp die 6 an.',
  'tutorialScript.atNightThe.family': 'Nachts redet die Familie im Geheimen. Antworte Vito.',
  'tutorialScript.nowTapEnzo.family': 'Jetzt tipp Enzo an, Platz 6: Das ist deine Stimme.',
  'tutorialScript.twoVotesOn.family': 'Zwei Stimmen für Enzo: Die Familie ist sich einig.',
  'tutorialScript.enzoLivesThe.family': 'Enzo lebt: Der Doktor hat ihn gerettet. Später noch mal.',
  'tutorialScript.someoneWentTo.family': 'Heute Nacht war jemand bei Enzo.',
  'tutorialScript.aliveByA.family': 'Wie durch ein Wunder am Leben. Wer war das?',
  'tutorialScript.wasOutOn.family': 'Die 1 war letzte Nacht auf der Straße. Ich habe ihn gesehen.',
  'tutorialScript.wellTalk.family': 'Na, 1? Rede.',
  'tutorialScript.easyWasAt.family': 'Ruhig, die 1 war mit mir in der Bar.',
  'tutorialScript.brunoAccusesFirst.family': 'Bruno klagt als Erster an: Wer zuerst anklagt, hat was zu verbergen.',
  'tutorialScript.iWasAsleep.family': 'Ich habe geschlafen. Aber die 3 weiß ziemlich viel, oder?',
  'tutorialScript.brunoIsIn.family': 'Bruno hat es tatsächlich eilig.',
  'tutorialScript.toldYouIs.family': 'Hab ich doch gesagt. Die 3 ist komisch.',
  'tutorialScript.whatIAm.family': 'Was?! Ich bin sauber!',
  'tutorialScript.theyAccuseYou.family': 'Sie klagen dich an. Verteidige dich nicht: Schieb es auf Bruno, Platz 3.',
  'tutorialScript.itWorkedReady.family': 'Hat geklappt. „Bereit“, und wir stimmen ab.',
  'tutorialScript.changedMyMind.family': 'Ich hab es mir anders überlegt: die 3.',
  'tutorialScript.handsAreMoving.family': 'Die Hände bewegen sich. Stimm mit ihnen gegen Bruno, Platz 3.',
  'tutorialScript.brunoWasInnocent.family': 'Bruno war unschuldig. Du bist sicher, für heute.',
  'tutorialScript.theDoctorSaved.family': 'Der Doktor hat Enzo gerettet. Ich wette, es ist die 4.',
  'tutorialScript.herTonightYou.family': 'Heute Nacht sie. Bist du dabei?',
  'tutorialScript.iAmIn.family': 'Bin dabei: die 4.',
  'tutorialScript.fineCarmela.family': 'Gut, Carmela.',
  'tutorialScript.letSGo.family': 'Los geht es.',
  'tutorialScript.vitoHasAn.family': 'Vito hat eine Idee. Antworte ihm.',
  'tutorialScript.tapCarmelaSeat.family': 'Tipp Carmela an, Platz 4.',
  'tutorialScript.twoAgainstTwo.family': 'Zwei gegen zwei: Die Stadt kann nicht mehr gewinnen.',
  'tutorialScript.soloPlayersHave.solo': 'Einzelgänger haben ihr eigenes Ziel: Der Trottel gewinnt, wenn er gelyncht wird, und das Spiel geht ohne ihn weiter.',
  'tutorialScript.youPlayAlone.solo': 'Du spielst allein: Der Trottel gewinnt, wenn er gelyncht wird. Halt die Karte gedrückt.',
  'tutorialScript.theFoolHas.solo': 'Der Trottel hat keine Kraft: Tipp irgendwen an, nur zum Schein.',
  'tutorialScript.atNightYou.solo': 'Nachts tust du nichts. Deine Arbeit ist am Tag.',
  'tutorialScript.brunoIsGone.solo': 'Bruno ist weg. Jetzt reden wir.',
  'tutorialScript.brunoIsDead.solo': 'Bruno ist tot. Hat jemand was gesehen?',
  'tutorialScript.iWasAsleep.solo': 'Ich habe geschlafen. Aber die 1 war die ganze Nacht wach.',
  'tutorialScript.yeahDoesNot.solo': 'Ja, die 1 überzeugt mich nicht.',
  'tutorialScript.giveHimA.solo': 'Gebt ihm eine Chance. Also, 1?',
  'tutorialScript.brunoOneLess.solo': 'Bruno? Einer weniger. Ich weine nicht.',
  'tutorialScript.iSayNothing.solo': 'Ich sage nichts. Stimmt gegen mich, wenn ihr euch traut.',
  'tutorialScript.youHeardThat.solo': 'Habt ihr das gehört? Fast ein Geständnis!',
  'tutorialScript.isSeriouslyWeird.solo': 'Die 1 ist echt komisch. Ich stimme gegen ihn.',
  'tutorialScript.sorryYouDid.solo': 'Tut mir leid, 1: Das hast du dir selbst eingebrockt.',
  'tutorialScript.actShadySay.solo': 'Benimm dich verdächtig: Sag etwas, das kein Unschuldiger sagen würde.',
  'tutorialScript.theyFellFor.solo': 'Sie sind drauf reingefallen. „Bereit“, und wir stimmen ab.',
  'tutorialScript.fineMeToo.solo': 'Gut, ich auch: die 1.',
  'tutorialScript.everyonePointsAt.solo': 'Alle zeigen auf dich. Stimm für irgendwen: Es ist egal.',
  'tutorialScript.theyLynchedYou.solo': 'Sie haben dich gelyncht: genau, was du wolltest.',
  // ---- voice
  'voice.title': 'Sprache',
  'voice.mode.off': 'Aus',
  'voice.mode.listen': 'Nur zuhören',
  'voice.mode.mic': 'Mikrofon',
  'voice.modeFull': 'Mikrofon (Push-to-Talk)',
  'voice.pushToTalk': 'Push-to-Talk',
  'voice.pushToTalkPhone': 'Halt das Mikrofon gedrückt, um zu sprechen.',
  'voice.pushToTalkDesk': 'Halt V (oder das Mikrofon) gedrückt, um zu sprechen.',
  'voice.holdToTalk': 'Halten zum Sprechen',
  'voice.holdV': 'V halten',
  'voice.offline': 'Sprache offline, neuer Versuch',
  'voice.nightFamily': 'Nachts redet nur die Familie',
  'voice.deadListen': 'Die Toten hören nur zu',
  'voice.sewn': 'Der Schneider hat dir den Mund zugenäht',
  'voice.jailed': 'In der Zelle wird nicht geredet',
  'voice.voteSilence': 'Während der Abstimmung wird nicht geredet',
  'voice.nobodyNow': 'Gerade redet keiner',
  'voice.opensSoon': 'Sprache geht gleich los',
  'voice.muteVoice': 'Stimme stummschalten',
  'voice.unmuteVoice': 'Stimme wieder an',
  'voice.mutedHere': 'Stumm: Nur du hörst diese Stimme nicht.',
  'voice.micDeniedTitle': 'Mikrofon verweigert',
  'voice.micDenied': 'Ohne Zugriff aufs Mikrofon kannst du nur zuhören. Du kannst ihn in den Systemeinstellungen erlauben und dann wieder „Mikrofon“ wählen.',
  'voice.openSettings': 'Einstellungen öffnen',
  'voice.notNow': 'Nicht jetzt',
  'voice.settings': 'Sprache am Tisch',
  'voice.settingsHint': 'In Freundesräumen. Tagsüber reden die Lebenden, nachts nur die Familie. Nur live: Nichts wird aufgezeichnet.',
  'voice.people': 'Am Tisch',
  'voice.nobody': 'Sonst hört keiner zu.',
  'voice.mute': 'Stumm',
  'voice.reportOrBlock': 'Melden oder blockieren',
  'voice.unmute': 'Ton an',
  'voice.blocked': 'Blockiert: Ihr hört euch nicht.',
  'voice.closed': 'Sprache ist gerade geschlossen.',
  'voice.listening': 'Nur zuhören.',
  'voice.silencedNow': 'Du kannst gerade nicht reden.',
  'voice.connecting': 'Verbinde…',
  'voice.live': 'Man hört dich',
  'voice.button': 'Sprache',
  'voice.micAskTitle': 'Das Mikrofon',
  'voice.micAsk': 'Zum Reden am Tisch nutzt Obertà das Mikrofon, nur wenn das Spiel dir das Wort gibt. Deine Stimme geht live raus und wird nie aufgezeichnet oder transkribiert.',
  'voice.micAllow': 'Mikrofon nutzen',
  'voice.cancel': 'Abbrechen',
  // ---- results
  'results.familyWins': 'DIE FAMILIE GEWINNT',
  'results.townWins': 'DIE STADT GEWINNT',
  'results.loneWolfWins': 'EIN EINZELGÄNGER GEWINNT',
  'results.youLost': 'DU HAST VERLOREN',
  'results.bountyPaid': 'DAS KOPFGELD IST BEZAHLT',
  'results.loanSharkCashesIn': 'DER KREDITHAI KASSIERT',
  'results.foolLastLaugh': 'DER TROTTEL LACHT ZULETZT',
  'results.hitmanStandsAlone': 'DER AUFTRAGSKILLER STEHT ALLEIN',
  'results.cityBurns': 'DIE STADT BRENNT',
  'results.back': 'ZURÜCK',
  'results.backToRoom': 'ZURÜCK IN DEN RAUM',
  'results.playAgain': 'NOCH MAL',
  'results.keysPlayAgainOrBack': 'ENTER  noch mal   ·   ESC  zurück',
  'results.keysBackToRoom': 'ENTER oder ESC  zurück in den Raum',
  'results.level': 'LEVEL {level}',
  // ---- mirror
  'mirror.takeHatOff': 'Hut abnehmen',
  'mirror.putHatOn': 'Hut aufsetzen',
  'mirror.hatOff': 'Ohne Hut',
  'mirror.hatOn': 'Mit Hut',
  'mirror.title': 'Der Spiegel des Barbiers',
  'mirror.later': 'Später',
  'mirror.whoSits': 'Wer sitzt im Stuhl?',
  'mirror.presentationHint': 'Der Barbier schlägt passende Schnitte, Make-up und Kleidung vor. Mit „Alles zeigen“ kannst du trotzdem alles wählen.',
  'mirror.man': 'Mann',
  'mirror.woman': 'Frau',
  'mirror.other': 'Divers',
  'mirror.preferNotToSay': 'Keine Angabe',
  'mirror.showAll': 'Alles zeigen',
  'mirror.saveFace': 'Dieses Gesicht speichern',
  'mirror.backToBefore': 'Zurück wie vorher',
  'mirror.randomFace': 'Zufallsgesicht',
  'mirror.readyMadeFaces': 'Fertige Gesichter',
  'mirror.freeClothes': 'Gratis-Kleidung',
  'mirror.randomShort': 'Zufall',
  'mirror.asItWas': 'Wie vorher',
  'mirror.cancel': 'Abbrechen',
  'mirror.tab.skin': 'Haut',
  'mirror.tab.hair': 'Haare',
  'mirror.tab.colour': 'Farbe',
  'mirror.tab.eyes': 'Augen',
  'mirror.tab.eyeSize': 'Augengröße',
  'mirror.tab.iris': 'Iris',
  'mirror.tab.brows': 'Brauen',
  'mirror.tab.nose': 'Nase',
  'mirror.tab.mouth': 'Mund',
  'mirror.tab.lipstick': 'Lippenstift',
  'mirror.tab.makeUp': 'Make-up',
  'mirror.tab.marks': 'Male',
  'mirror.tab.age': 'Alter',
  'mirror.tab.head': 'Kopf',
  // ---- chronicle
  'chronicle.deadJoiner': ' UND ',
  'chronicle.listJoiner': ' und ',
  'chronicle.fire': 'Feuer in der Nacht: {burned} verbrannt',
  'chronicle.fireWithOthers': 'Feuer in der Nacht: {burned} verbrannt, außerdem tot: {others}',
  'chronicle.risen': '{name} ist zurück aus dem Grab',
  'chronicle.foundDead': '{names} tot aufgefunden',
  'chronicle.squareUndecided': 'Der Platz kann sich nicht entscheiden',
  'chronicle.lynched': '{name} gelyncht',
  'chronicle.lynchedFool': '{name} gelyncht: Der Trottel gewinnt',
  'chronicle.lynchedBounty': '{name} gelyncht: {hunter} kassiert das Kopfgeld',
  'chronicle.lynchedNeutral': '{name} gelyncht: {role}',
  'chronicle.lynchedFamily': '{name} gelyncht: einer von der Familie',
  'chronicle.lynchedInnocent': '{name} gelyncht: unschuldig',
  // ---- courier
  'courier.masthead': 'Der {city}-Kurier',
  'courier.dateLine': 'Jahrgang XIX  ·  Tag {round}  ·  {edition}',
  'courier.dawnEdition': 'Morgenausgabe',
  // ---- gesture
  'gesture.title': 'Eine Geste für {name}',
  'gesture.hint': 'Der ganze Tisch sieht sie.',
  'gesture.locked': 'Im Laden',
  'gesture.wait': 'Nächste in {seconds} s',
  'gesture.report': 'Melden oder blockieren',
  'gesture.settingTitle': 'Gesten am Tisch',
  'gesture.settingHint': 'Aus: Keiner kann dir Zigarren, Rosen oder Fische zuwerfen.',
  'gesture.button': 'Gesten',
  'gesture.pickTarget': 'Wer bekommt eine Geste?',
  'gesture.pickHint': 'Oder halt einen Platz gedrückt.',
  'gesture.firstHint': 'Wirf jemandem eine Geste zu: Tipp auf „Gesten“.',
  // ---- collection
  'collection.title': 'Die Rollen',
  'collection.settingsHint': 'Die Sammlung: Jede Karte wird aufgedeckt, wenn du mit ihr gewinnst.',
  'collection.count': '{n} von {of} Karten',
  'collection.hint': 'Jede Karte bleibt verdeckt, bis du eine Partie mit dieser Rolle gewinnst.',
  'collection.signedOut': 'Melde dich an, um die Karten aufzudecken und über deine Partien Buch zu führen.',
  'collection.signIn': 'Anmelden',
  'collection.team.citizens': 'Stadt',
  'collection.team.mafia': 'Familie',
  'collection.team.neutral': 'Einzelgänger',
  'collection.locked': 'Verdeckt',
  'collection.lockedBody': 'Verdeckte Karte. Gewinn eine Partie mit dieser Rolle, um zu erfahren, was sie kann, und deine Zahlen zu sehen.',
  'collection.playedNoWin': 'Einmal gespielt, nie gewonnen.',
  'collection.playedNoWin.playedTimesNever': '{n}-mal gespielt, nie gewonnen.',
  'collection.neverPlayed': 'Nie gespielt.',
  'collection.played': 'Partien',
  'collection.wins': 'Gewonnen',
  'collection.losses': 'Verloren',
  'collection.winRate': 'Siegquote',
  'collection.bestStreak': 'Beste Serie',
  'collection.lastPlayed': 'Letzte Partie',
  'collection.short': '{wins} S · {played} P',
  'collection.close': 'Schließen',
  'collection.publicCount': 'Aufgedeckte Rollen',
  // ---- localRole
  'localRole.wasBusy': 'Letzte Nacht hat dich jemand beschäftigt: Dein Zug ist verloren.',
  'localRole.wasJailed': 'Letzte Nacht warst du in der Zelle: Dein Zug ist verloren.',
  'localRole.jailerAsked': 'Der Schließer fragte: „{question}“',
  'localRole.prisonerAnswered': 'Aus der Zelle antwortete {name}: „{answer}“',
  'localRole.foundFamily': 'Im Morgengrauen: {name} gehört zur Familie.',
  'localRole.foundClean': 'Im Morgengrauen: {name} ist sauber.',
  'localRole.foundRole': 'Im Morgengrauen: {name} war {role}.',
  'localRole.jailedTitle': 'Du bist in der Zelle',
  'localRole.jailedBody': 'Heute Nacht gehst du nicht raus, und keiner rührt dich an.',
  'localRole.jailerAsks': 'Der Schließer fragt dich:',
  'localRole.answerHint': 'Deine Antwort (nur der Schließer liest sie)',
  'localRole.questionHint': 'Eine Frage an den Gefangenen (optional)',
  'localRole.jailed': '{name} sitzt in deiner Zelle.',
  'localRole.converted': 'Du hast das Licht gesehen: Jetzt gehörst du zur Sekte und gewinnst nur mit ihr.',
  'localRole.sect': 'Deine Sekte: {names}.',
  'localRole.doorClosed': 'Letzte Nacht eine verschlossene Tür: {name}.',
  'localRole.sectWins': 'Die Sekte gewinnt',
  'localRole.linkSecond': 'Und wer noch? Tipp das zweite Herz an.',
  'localRole.linked': 'Du hast {a} und {b} aneinander gebunden.',
  'localRole.inLoveWith': 'Dein Herz schlägt für {name}: Ihr gewinnt nur, wenn ihr beide lebt.',
  'localRole.fateCannon': 'Kanone, Tag {round}',
  'localRole.fateDay': 'Tagsüber, Tag {round}',
  'localRole.whoToReveal': 'Wen enthüllst du vor allen?',
  'localRole.whoToHit': 'Wen triffst du?',
  'localRole.aimed': 'Im Visier: {name}. Übrige Schüsse: {left}.',
  'localRole.noAim': 'Niemand im Visier: Wähl heute Nacht jemanden.',
  'localRole.fire': 'Feuer!',
  'localRole.carryOn': 'Weiter',
  'localRole.cancel': 'Abbrechen',
  'localRole.confirm': 'Bestätigen',
  'localRole.usePower': 'Macht einsetzen',
  'localRole.powerWho': 'Wer bist du? Tipp auf dein eigenes Gesicht.',
  'localRole.noPower': 'Gerade hast du nichts einzusetzen.',
  'localRole.truceHow': 'Einmal pro Spiel: Du enthüllst allen die genaue Rolle einer Person, und deine eigene. Heute wird nicht abgestimmt.',
  'localRole.cannonHow': 'Wen du triffst, stirbt sofort, vor allen. Ein Schuss pro Tag; ab dem ersten wissen alle, wer du bist.',
  'localRole.marksmanHow': 'Du schießt auf die Person in deinem Visier. Gehört sie zur Stadt, geht der Schuss nach hinten los.',
  'localRole.mayorHow': 'Einmal pro Spiel: Du gibst dich allen zu erkennen, und heute zählt deine Stimme doppelt.',
  'localRole.shotsLeft': 'Schüsse übrig: {left}.',
  'localRole.askTruce': 'Waffenruhe',
  'localRole.dayPowerHint': 'Am Tag: Nimm das Handy und tipp auf „Macht einsetzen“.',
  // ---- localTable
  'localTable.pickedConfirm': 'Du hast {name} gewählt. Bestätige, oder tipp auf einen anderen Platz.',
  'localTable.familyNote': 'Familie',
  'localTable.cleanNote': 'sauber',
  'localTable.discuss': 'Redet laut darüber. Dann wird abgestimmt.',
  'localTable.undo': 'Zurück',
  'localTable.voteTitle': 'Die Abstimmung',
  'localTable.voteHeadline': 'Wie stimmt der Platz ab?',
  'localTable.voteIntro': 'Am Tag, wenn die Diskussion vorbei ist, verurteilt der Platz jemanden. Wählt, wie, für dieses Spiel.',
  'localTable.secretVote': 'Geheime Wahl auf dem Handy',
  'localTable.voiceVoteHint': 'Ihr stimmt laut ab, alle zusammen: Jeder sagt vor allen, wen er beschuldigt. Dann tippt einer auf dem Handy den Verurteilten an, oder „Gleichstand · niemand“: Bei Gleichstand kommt niemand an den Galgen und die Nacht kehrt zurück. Mehr Gerede, und jeder zeigt Farbe.',
  'localTable.secretVoteHint': 'Das Handy geht reihum und jeder stimmt allein ab, einmal, ohne gesehen zu werden. Am Ende erfährt man nur, wer verurteilt ist und wie viele Stimmen jeder bekam, nie, wer wen gewählt hat. Langsamer, und man versteckt sich leichter.',
  'localTable.voteNext': 'Weiter',
  'localTable.voiceVoteTitle': 'Stimmt laut ab',
  'localTable.voiceVote': 'Stimmt laut ab. Dann tippt an, wen ihr verurteilt.',
  'localTable.tieRule': 'Gleichstand: Niemand kommt an den Galgen, die Nacht kehrt zurück.',
  'localTable.condemnConfirm': '{name} verurteilen? Bestätige, oder tipp auf einen anderen Platz.',
  'localTable.tieNobody': 'Gleichstand · niemand',
  'localTable.condemn': '{name} verurteilen',
  'localTable.backToTalk': 'Zurück zur Diskussion',
  'localTable.mustVote': '{name} muss abstimmen',
  'localTable.secretBallot': 'Geheime Wahl: Niemand sieht deinen Zettel. Tipp an, wen du ausschalten willst, nur einmal.',
  'localTable.votePicked': 'Du hast {name} markiert. Wirf ihn in die Urne, oder tipp auf einen anderen Namen.',
  'localTable.castVote': 'In die Urne',
  'localTable.ballotPad': 'STEMPELKISSEN',
  'localTable.ballotSerial': 'Nr. {n}',
  'localTable.ballotRule': 'Wahl des Verurteilten · nur einen Namen stempeln',
  'localTable.ballotTitle': 'GEHEIMER STIMMZETTEL',
  'localTable.ballotHint': 'Tipp auf einen Namen auf dem Zettel, oder enthalte dich.',
  'localTable.ballotAbstain': 'Enthalten',
  // ---- rules
  'rules.sign': 'Regeln',
  'rules.title': 'So wird gespielt',
  'rules.banner': 'Zum Vorlesen',
  'rules.pitch': 'Lies diese Seite laut vor: In einer Minute können deine Freunde spielen.',
  'rules.style.quick': 'Kurz',
  'rules.style.stage': 'Theatralisch',
  'rules.styleHint.quick': 'Das ganze Spiel in einer Minute.',
  'rules.styleHint.stage': 'Ein schwarzes Märchen, zum Vortragen.',
  'rules.readToMe': 'Lies sie mir vor',
  'rules.stopReading': 'Das reicht',
  'rules.commonRoles': 'Die häufigsten Rollen',
  'rules.commonRolesHint': 'Eine Zeile pro Rolle, für Neugierige.',
  'rules.playLocal': 'Spielen wir an einem Handy',
  'rules.playLocalHint': 'Ein Handy, von Hand zu Hand gereicht.',
  'rules.playFriends': 'Mit Freunden spielen',
  'rules.playFriendsHint': 'Das Ein-Handy-Spiel läuft auf dem Handy: Von hier geht es in einen Online-Raum.',
  'rules.back': 'Zurück',
  'rules.team.citizens': 'Stadt',
  'rules.team.mafia': 'Familie',
  'rules.team.neutral': 'Auf eigene Faust',
  // ---- chat
  'chat.fresh': '{n} neu',
  // ---- nightNotes
  'nightNotes.spendTheNight': 'Die Nacht verbringen',
  // ---- ranked
  'ranked.yourTable': 'Deine Sprache',
};

/// The narrator's script, read on screen (no recorded voice yet).
// Same rules as the English pack: short lines, never a player's gender (the
// name, "die Person", or turn the sentence), real cities and places, nobody
// closes their eyes, the factions are always "die Familie" and "die Stadt".
const germanPack = NarrationPack(
  roles: {
    Role.mafioso: RoleText(
      'Soldat',
      '„Nichts Persönliches.“',
      'Du gehörst zur Familie. Jede Nacht wählt ihr gemeinsam, wer stirbt. Ihr gewinnt, sobald ihr so viele seid wie alle anderen.',
    ),
    Role.padrino: RoleText(
      'Pate',
      '„Ich tue nur Gefallen. Hör dich um.“',
      'Du führst die Familie und wählst nachts mit ihr, wer stirbt. Achtung: Für den Detektiv wirkst du unschuldig. Du gewinnst mit der Familie.',
    ),
    Role.sarto: RoleText(
      'Schneider',
      '„Tagsüber Anzüge. Nachts Münder.“',
      'Du gehörst zur Familie und tötest nachts mit ihr. Einmal pro Spiel lässt du jemanden einen ganzen Tag verstummen. Du gewinnst mit der Familie.',
    ),
    Role.compare: RoleText(
      'Komplize',
      '„Ich war nur auf der Durchreise.“',
      'Du gehörst zur Familie und tötest nachts mit ihr. Solange du lebst, kann die Familie auch tagsüber heimlich reden.',
    ),
    Role.cittadino: RoleText(
      'Bürger',
      '„Ich hab nichts gesehen. Leider stimmt das.“',
      'Du hast keine Kräfte. Hör tagsüber zu, klag an und stimm ab, um die Mörder zu finden. Du gewinnst mit der Stadt, wenn alle Mörder raus sind.',
    ),
    Role.detective: RoleText(
      'Detektiv',
      '„Alle lügen. Manche besser.“',
      'Wähl jede Nacht jemanden und erfahre, ob die Person zur Familie gehört. Achtung: Manche Karten lügen, der Pate etwa wirkt unschuldig.',
    ),
    Role.medico: RoleText(
      'Doktor',
      '„Ich flicke, was andere aufreißen.“',
      'Wähl jede Nacht jemanden, auch dich selbst: Wird die Person angegriffen, rettest du sie. Nie zwei Nächte hintereinander dieselbe.',
    ),
    Role.cecchino: RoleText(
      'Scharfschütze',
      '„Ein Schuss. Nicht zwei.“',
      'Du hast eine Kugel für das ganze Spiel: In einer Nacht bestimmst du, wer stirbt. Ziel gut, du kannst danebenliegen. Du gewinnst mit der Stadt.',
    ),
    Role.giornalista: RoleText(
      'Reporter',
      '„Um sechs liegt die Wahrheit am Kiosk.“',
      'Einmal pro Spiel wählst du nachts jemanden: Im Morgengrauen erfahren alle, zu welcher Seite die Person gehört. Stirbst du in der Nacht, erscheint nichts.',
    ),
    Role.becchino: RoleText(
      'Totengräber',
      '„Meine Kunden lügen nie.“',
      'Jede Nacht kannst du eine nachts gestorbene Person wählen und ihre Rolle erfahren. Nur du kennst sie. Du gewinnst mit der Stadt.',
    ),
    Role.guardaspalle: RoleText(
      'Leibwächter',
      '„Erst müssen sie an mir vorbei.“',
      'Bewach jede Nacht jemanden: Wird die Person angegriffen, stirbst du an ihrer Stelle. Du gewinnst mit der Stadt.',
    ),
    Role.reduce: RoleText(
      'Veteran',
      '„Auf mich wurde schon besser geschossen.“',
      'Nachts tust du nichts, aber du bist zäh: Der erste nächtliche Angriff auf dich geht schief. Du gewinnst mit der Stadt.',
    ),
    Role.pregiudicato: RoleText(
      'Ex-Knacki',
      '„Ich hab gesessen. Meine Akte sitzt noch.“',
      'Du gehörst zur Stadt, aber Achtung: Für den Detektiv wirkst du wie Familie. Du musst die anderen überzeugen, dass du sauber bist.',
    ),
    Role.messia: RoleText(
      'Messias',
      '„Steh auf. Du bist noch nicht fertig.“',
      'Einmal pro Spiel kannst du nachts eine beliebige tote Person zurückholen. Du gewinnst mit der Stadt.',
    ),
    Role.sindaco: RoleText(
      'Bürgermeister',
      '„Gewählt bin ich nicht, um zu schweigen.“',
      'Einmal pro Spiel kannst du dich bei der Abstimmung zu erkennen geben: Ab dann zählt deine Stimme doppelt. Du gewinnst mit der Stadt.',
    ),
    Role.portinaio: RoleText(
      'Portier',
      '„Ich frage nicht, wer. Ich sehe die Tür.“',
      'Beobachte jede Nacht eine Tür: Im Morgengrauen weißt du, ob jemand zu Besuch kam, aber nicht, wer. Du gewinnst mit der Stadt.',
    ),
    Role.fesso: RoleText(
      'Trottel',
      '„Ich? Schuldig? Aber sowas von.“',
      'Du spielst allein und gewinnst, wenn der Platz dich lyncht: Wirk verdächtig! Nachts zu sterben zählt nicht.',
    ),
    Role.piromane: RoleText(
      'Brandstifter',
      '„Jeder liebt ein Lagerfeuer.“',
      'Du spielst allein. Übergieß jede Nacht jemanden mit Benzin oder zünde alle Übergossenen auf einmal an. Du gewinnst, wenn sonst keiner mehr lebt.',
    ),
    Role.cacciatore: RoleText(
      'Kopfgeldjäger',
      '„Nichts Persönliches. Nur Geschäft.“',
      'Du spielst allein, mit Kopfgeld auf jemanden aus der Stadt, den du beim Namen kennst. Lyncht der Platz diese Person, gewinnst du und das Spiel endet.',
    ),
    Role.strozzino: RoleText(
      'Kredithai',
      '„Ein toter Schuldner zahlt nicht.“',
      'Du spielst allein. Schütz jede Nacht jemanden, nie zweimal hintereinander dieselbe Person. Du gewinnst, wenn du am Ende lebst, egal wer gewinnt.',
    ),
    Role.sicario: RoleText(
      'Auftragskiller',
      '„Ich arbeite allein. Der Kaffee geht auf mich.“',
      'Du spielst allein und tötest jede Nacht jemanden. Achtung: Für den Detektiv wirkst du wie Familie. Du gewinnst nur, wenn sonst keiner überlebt.',
    ),
    Role.prostituta: RoleText(
      'Lockvogel',
      '„Ein Lied, ein Drink, und die Nacht ist weg.“',
      'Du spielst für die Familie, aber ihr kennt euch nicht. Jede Nacht blockierst du einen Zug, nie zweimal dieselbe Person. Bleibst nur du übrig, wählst du.',
    ),
    Role.carceriere: RoleText(
      'Schließer',
      '„Hier drin wird geredet. Draußen gestorben.“',
      'Jede Nacht sperrst du jemanden ein, nie zweimal hintereinander: Die Person kann nichts tun und nicht sterben. Verhör sie im Chat, ohne dich zu zeigen.',
    ),
    Role.pacifista: RoleText(
      'Pazifist',
      '„Blut ruft nach Blut. Ich rufe Waffenruhe.“',
      'Einmal pro Spiel enthüllst du tagsüber vor allen die genaue Rolle einer Person, und deine: Dann wird nicht abgestimmt. Du gewinnst mit der Stadt.',
    ),
    Role.cupido: RoleText(
      'Amor',
      '„Zwei Herzen, eine Mitgift, kein Ausweg.“',
      'In der ersten Nacht verbindest du zwei Personen, gern auch dich. Sie gewinnen nur, wenn beide leben; stirbt eine, folgt die andere. Du gewinnst mit der Stadt.',
    ),
    Role.presidente: RoleText(
      'Präsident',
      '„Der Staat verhandelt nicht.“',
      'Alle wissen, wer du bist, und keiner kann gegen dich stimmen. Die Eskorte rettet dich bei den ersten zwei Anschlägen, beim dritten stirbst du. Dann verliert die Stadt.',
    ),
    Role.capoSetta: RoleText(
      'Sektenführer',
      '„Ich will keinen Glauben. Nur Gefolgschaft.“',
      'Du spielst allein: Jede Nacht bekehrst du jemanden, der ab dann nur mit dir gewinnt und die anderen nicht kennt. Du gewinnst, wenn alle Lebenden zur Sekte gehören.',
    ),
    Role.artigliere: RoleText(
      'Kanonier',
      '„Ich flüstere nicht. Ich donnere.“',
      'Zwei Schüsse, einer pro Tag, ab dem zweiten Tag: Wen du in der Diskussion triffst, stirbt sofort. Ab dem ersten Schuss kennen dich alle. Du gewinnst mit der Stadt.',
    ),
    Role.tiratoreScelto: RoleText(
      'Meisterschütze',
      '„Ein Atemzug, ein Schuss, ein Name.“',
      'Nachts nimmst du jemanden ins Visier, tagsüber darfst du schießen. Zwei Schüsse. Gehört die Person zur Stadt, geht der Schuss nach hinten los und du stirbst.',
    ),
  },
  cities: [
    CitySetting(
      id: 'chicago',
      name: 'Chicago',
      title: 'Chicago, 1929',
      openings: [
        'Chicago, 1929. Die Prohibition hat die Bars geschlossen und alles andere geöffnet.',
        'Chicago, 1929. Die Windy City. Sie nimmt dir den Hut, und manchmal den, der drunter steckt.',
      ],
      scenes: [
        StoryPiece('chicago-loop', 'Außen, Nacht. Unter den Gleisen der L im Loop. Oben rattert ein Zug vorbei.'),
        StoryPiece('chicago-station', 'Innen, Nacht. Union Station. Der Wartesaal ist leer.'),
        StoryPiece('chicago-pier', 'Außen, Nacht. Navy Pier. Nebel über dem Lake Michigan.'),
        StoryPiece('chicago-jazz', 'Innen, Nacht. Das Green Mill: Rauch und ein Saxofon.'),
        StoryPiece('chicago-bridge', 'Außen, Nacht. Eine Klappbrücke über dem Chicago River.'),
        StoryPiece('chicago-market', 'Außen, Nacht. Der Markt in der Maxwell Street, alle Stände zu.'),
        StoryPiece('chicago-speakeasy', 'Innen, Nacht. Eine Flüsterkneipe in der South Side.'),
        StoryPiece('chicago-hotel', 'Innen, Nacht. Die Lobby des Lexington Hotel. Keiner an der Rezeption.'),
      ],
    ),
    CitySetting(
      id: 'new-york',
      name: 'New York',
      title: 'New York, 1947',
      openings: [
        'New York, 1947. Acht Millionen Menschen, und keiner hat was gesehen.',
        'New York, 1947. Die Stadt, die niemals schläft. Heute Nacht sollte sie es wirklich mal versuchen.',
      ],
      scenes: [
        StoryPiece('ny-mulberry', 'Außen, Nacht. Mulberry Street, Little Italy, unter den Leuchtreklamen.'),
        StoryPiece('ny-bridge', 'Außen, Nacht. Unter der Brooklyn Bridge. Nebel über dem East River.'),
        StoryPiece('ny-station', 'Innen, Nacht. Grand Central. Die Uhr zeigt drei.'),
        StoryPiece('ny-market', 'Außen, Nacht. Der Fulton Fish Market, zwischen den Kisten.'),
        StoryPiece('ny-coney', 'Außen, Nacht. Coney Island, Nebensaison. Das Wonder Wheel steht still.'),
        StoryPiece('ny-pier', 'Außen, Nacht. Ein Pier am Hudson. Ein Frachter ohne Namen.'),
        StoryPiece('ny-diner', 'Innen, Nacht. Ein Diner, einen Block vom Times Square.'),
        StoryPiece('ny-park', 'Außen, Nacht. Central Park. Eine einzige Laterne brennt noch.'),
      ],
    ),
    CitySetting(
      id: 'palermo',
      name: 'Palermo',
      title: 'Palermo, 1955',
      openings: [
        'Palermo, 1955. Die schönste Sonne der Welt, und ein paar sehr lange Schatten.',
        'Palermo, 1955. Hier weiß jeder alles. Darum sagt keiner ein Wort.',
      ],
      scenes: [
        StoryPiece('palermo-vucciria', 'Außen, Nacht. Der Markt der Vucciria, für die Nacht verrammelt.'),
        StoryPiece('palermo-teatro', 'Außen, Nacht. Die Stufen des Teatro Massimo, zwischen den zwei Löwen.'),
        StoryPiece('palermo-canti', 'Außen, Nacht. Die Quattro Canti, menschenleer. Nur die Statuen.'),
        StoryPiece('palermo-cala', 'Außen, Nacht. La Cala, der alte Hafen. Die Boote schaukeln.'),
        StoryPiece('palermo-ballaro', 'Außen, Nacht. Eine Gasse in Ballarò, Wäsche auf den Leinen.'),
        StoryPiece('palermo-mondello', 'Außen, Nacht. Der Strand von Mondello, Nebensaison.'),
        StoryPiece('palermo-foro', 'Außen, Nacht. Der Foro Italico am Meer, zwischen den Palmen.'),
        StoryPiece('palermo-pasticceria', 'Innen, Nacht. Eine Konditorei in der Altstadt, die Rollläden unten.'),
      ],
    ),
    CitySetting(
      id: 'napoli',
      name: 'Neapel',
      title: 'Neapel, 1950',
      openings: [
        'Neapel, 1950. Der Vesuv raucht, der Kaffee brennt, und jemand schläft heute Nacht nicht.',
        'Neapel, 1950. Hier singen alle. Nur nie für die Polizei.',
      ],
      scenes: [
        StoryPiece('napoli-quartieri', 'Außen, Nacht. Eine Gasse in den Quartieri Spagnoli.'),
        StoryPiece('napoli-galleria', 'Innen, Nacht. Die Galleria Umberto, leer. Jeder Schritt hallt.'),
        StoryPiece('napoli-molo', 'Außen, Nacht. Der Molo Beverello. Die Fähren fahren nicht.'),
        StoryPiece('napoli-spaccanapoli', 'Außen, Nacht. Spaccanapoli, gerade wie eine Klinge.'),
        StoryPiece('napoli-sancarlo', 'Innen, Nacht. Das Teatro San Carlo, jeder Platz leer.'),
        StoryPiece('napoli-lungomare', 'Außen, Nacht. Die Uferpromenade unter dem Castel dell\'Ovo.'),
        StoryPiece('napoli-funicolare', 'Innen, Nacht. Die Standseilbahn von Chiaia, letzte Fahrt der Nacht.'),
        StoryPiece('napoli-pizzeria', 'Innen, Nacht. Eine Pizzeria in der Via dei Tribunali, der Ofen kalt.'),
      ],
    ),
    CitySetting(
      id: 'las-vegas',
      name: 'Las Vegas',
      title: 'Las Vegas, 1955',
      openings: [
        'Las Vegas, 1955. Eine Million Glühbirnen in der Wüste, damit man den Rest nicht sieht.',
        'Las Vegas, 1955. Die Bank gewinnt immer. Heute Nacht erfährst du, wer die Bank ist.',
      ],
      scenes: [
        StoryPiece('vegas-fremont', 'Außen, Nacht. Fremont Street: tausend Lichter, kein einziger Zeuge.'),
        StoryPiece('vegas-flamingo', 'Innen, Nacht. Der Spielsaal des Flamingo, in den frühen Morgenstunden.'),
        StoryPiece('vegas-desert', 'Außen, Nacht. Die Mojave-Wüste. Zwei Scheinwerfer, eine Schaufel.'),
        StoryPiece('vegas-nugget', 'Innen, Nacht. Das Hinterzimmer des Golden Nugget. Ein Pokertisch.'),
        StoryPiece('vegas-motel', 'Außen, Nacht. Der Parkplatz eines Motels am Strip.'),
        StoryPiece('vegas-dam', 'Außen, Nacht. Der Hoover Dam. Darunter zweihundert Meter Nichts.'),
        StoryPiece('vegas-dressing', 'Innen, Nacht. Die Garderobe einer Sängerin, nach der Show.'),
        StoryPiece('vegas-chapel', 'Innen, Nacht. Eine Hochzeitskapelle, die die ganze Nacht offen hat.'),
      ],
    ),
  ],
  howToPlay:
      'Nachts schaltet die Familie eine Person aus. Tagsüber stimmen alle ab, wer ausgeschaltet wird. '
      'Die Stadt gewinnt, wenn die ganze Familie weg ist; die Familie gewinnt, sobald sie nicht mehr in der Unterzahl ist.',
  firstNights: [
    'Die erste Nacht bricht über {city} herein.',
    'Dunkelheit legt sich über {city}. Es ist die erste Nacht.',
    'Erste Nacht. Schlaft gut, wenn das Gewissen euch lässt.',
  ],
  nights: [
    'Wieder bricht die Nacht über {city} herein.',
    'Die Laternen gehen aus. Jemand hat Arbeit zu erledigen.',
    'Es ist Nacht. Jemand hat ein Rendezvous. Die Blumen kommen später.',
    'Noch eine Nacht. In {city} schlafen die Leute inzwischen mit Schuhen.',
    'Die Dunkelheit kommt. Sogar die Hunde haben aufgehört zu bellen.',
    'Tiefe Nacht. Das Bestattungsinstitut macht Überstunden.',
  ],
  nightInstruction: 'Gebt das Handy herum. Alle machen ihren Zug im Geheimen und reichen es weiter.',
  nobodyDied: 'Letzte Nacht ist niemand gestorben.',
  quietDawns: [
    'Das Bestattungsinstitut zeigt sich zutiefst besorgt.',
    'Schaut euch am Tisch um: Hier ist jemand enttäuscht.',
    'Macht es euch nicht bequem. So fängt es meistens an.',
    'Der Nachtwächter vom Friedhof hat acht Stunden durchgeschlafen, und traut der Sache nicht.',
  ],
  secondVictims: ['Und das ist noch nicht alles.', 'Szenenwechsel.', 'Aber es war eine lange Nacht.'],
  victimFact: 'Unter den Toten der Nacht: {name}. Die Rolle bleibt geheim.',
  sniperShots: {
    DeathStory.sniperId: [
      'Ein einziger Schuss, aus einem fernen Fenster. {name} hat nichts gehört.',
      'Ein Blitzen auf einem Dach, dann ein Schuss. {name} fällt vor dem Echo.',
      'Irgendwer hat sich in der Ferne Zeit zum Zielen gelassen. {name} bleibt auf dem Pflaster.',
      'Diesmal keiner um die Ecke. Nur ein Fadenkreuz, und {name} mittendrin.',
    ],
    DeathStory.belfryId: [
      'Ein Blitzen oben im Glockenturm. Dann ein Glockenschlag, und {name} steht nicht mehr auf.',
      'Die Glocke schlägt die Stunde und verschluckt den Schuss. {name} bleibt auf dem Kopfsteinpflaster.',
      'Ein Schwarm Tauben schießt aus dem Glockenturm. {name} liegt schon am Boden.',
    ],
    DeathStory.phoneBoothId: [
      'Das Telefon in der Zelle klingelt. {name} hebt ab. Das Glas springt zu einem Stern.',
      'Ein Loch im Glas der Zelle, ein Netz aus Rissen. {name} rutscht zu Boden.',
      '{name} hebt den Hörer ab. Am anderen Ende spricht keiner: nur der Schuss.',
    ],
    DeathStory.carDoorId: [
      '{name} öffnet die Autotür. Ein Schuss aus der Ferne: Diese Fahrt beginnt nie.',
      'Schlüssel in der Hand, ein Fuß auf dem Trittbrett. Dann der Schuss, und {name} fällt.',
      '{name} wollte gerade losfahren. Der Motor bleibt kalt, die Tür steht offen.',
    ],
  },
  rescues: {
    DeathStory.rescueId: [
      'Der Anschlag sitzt, {name} liegt am Boden. Dann rennende Schritte: der Doc.',
      'Sie kamen, um die Rechnung mit {name} zu begleichen. Der Doc war vor dem Pfarrer da.',
      '{name} lag schon am Boden. Aber der Doc kam zufällig vorbei.',
      '{name} geht zu Boden. Dann schnappt eine Ledertasche auf: Es ist noch nicht vorbei.',
    ],
    DeathStory.defibrillatorId: [
      '{name} am Boden, Herzstillstand. Der Doc reibt die Paddles aneinander: Weg da!',
      'Ein Stromstoß, nichts. Noch ein Stromstoß: Das Herz von {name} schlägt wieder.',
      'Der Doc öffnet einen Kasten voller Kabel. Ein Funke, und {name} atmet wieder.',
    ],
    DeathStory.pliersId: [
      'Der Doc bohrt mit einer Zange in der Wunde von {name}. Heraus kommt das Blei.',
      'Eine Kugel in der Zange, ein Verband auf der Brust. {name} atmet noch.',
      '{name} am Boden, der Doc auf beiden Knien. „Pling“: Die Kugel landet in der Schale.',
    ],
    DeathStory.ambulanceId: [
      'Eine Sirene die Straße runter. Der Krankenwagen bremst scharf: {name} kommt auf die Trage.',
      '{name} am Boden, dann die Sirenen. Trage, Decke, und ab geht die Fahrt.',
      'Der Krankenwagen hält mit Blaulicht. Von der Trage winkt {name}.',
    ],
    DeathStory.stitchesId: [
      'Unter der Laterne, Nadel und Faden. Der Doc näht {name} zusammen, Stich für Stich.',
      'Drei Stiche, ein Knoten, ein Schnipp mit der Schere. {name} steht wieder auf.',
      'Der Doc fädelt im Laternenlicht ein. {name} spürt nichts.',
    ],
  },
  someone: 'jemand',
  savedFact: 'Letzte Nacht wäre fast jemand gestorben, aber jemand kam rechtzeitig zur Rettung. Wer, bleibt geheim.',
  shrugs: {
    DeathStory.luckyId: [
      '{name} taumelt, dann ein Griff an die Brusttasche: ein Flachmann, schwer verbeult.',
      'Der Schlag sitzt, und macht „ding“. {name} zieht einen verbeulten Flachmann hervor.',
      '{name} bleibt stehen: Der Schlag ist am Flachmann hängen geblieben.',
      '{name} spürt einen Stoß gegen die Brust. Unter dem Jackett ein Flachmann, glatt geknickt.',
    ],
    DeathStory.bibleId: [
      '{name} zieht eine Bibel aus der Brusttasche: Genau dort ist der Schlag stecken geblieben.',
      'Der Schlag bleibt in einer Taschenbibel stecken. {name} blickt nach oben und sagt danke.',
      '{name} spürt einen Stoß gegen die Brust. In der Tasche eine Bibel, halb durchlöchert.',
    ],
    DeathStory.jamId: [
      'Die Waffe zielt auf {name}. „Klick.“ Noch mal „klick“. Der Killer nimmt Reißaus.',
      'Der Abzug schnappt ins Leere: Ladehemmung. {name} dreht sich um, der Killer rennt.',
      '„Klick, klick.“ {name} krempelt die Ärmel hoch, und die Gasse leert sich.',
    ],
    DeathStory.bananaId: [
      'Der Killer tritt auf eine Bananenschale und fliegt rückwärts. {name} geht davon.',
      'Eine Bananenschale, ein Rückwärtssalto. Der Killer landet flach auf der Straße: {name} lacht.',
      'Der Killer stürmt auf {name} los, dann kommt eine Bananenschale. Der Rest ist Slapstick.',
    ],
    DeathStory.blackCatId: [
      'Eine schwarze Katze springt dem Killer auf den Arm. Der Schuss geht daneben, {name} bleibt stehen.',
      'Der Killer zielt auf {name}. Eine schwarze Katze schlägt die Waffe weg.',
      'Bringt Unglück, heißt es. Aber heute Nacht hat eine schwarze Katze {name} gerettet.',
    ],
  },
  shruggedFact: 'Letzte Nacht wäre fast jemand gestorben, aber der Schlag ging daneben. Wer, bleibt geheim.',
  methods: [
    StoryPiece('auto', 'Zwei Scheinwerfer im Dunkeln. Eine schwarze Limousine bremst nicht. {name} dreht sich um: zu spät.'),
    StoryPiece('pianoforte', 'Ein Seil reißt. Ein Flügel stürzt herab. {name} schaut nach oben.'),
    StoryPiece('veleno', '{name} nimmt den letzten Schluck Kaffee. Verzieht das Gesicht. Gift.'),
    StoryPiece('pugnale', 'Ein Schatten hinter {name}. Eine Klinge. Einmal reicht.'),
    StoryPiece('cemento', 'Zwei Schläger halten {name} fest. Ein dritter rührt den Zement an.'),
    StoryPiece('cappio', 'Aus dem Dunkel hinter {name} fällt eine Schlinge. Sie zieht sich zu.'),
    StoryPiece('silenziatore', 'Ein Revolverschuss, trocken wie ein Fingerschnippen. {name} sackt zu Boden.'),
    StoryPiece('pacco', '{name} packt ein Geschenk aus. Drinnen tickt etwas. Dann kracht etwas.'),
    StoryPiece('lampadario', 'Ein Knarren. Ein Kristallleuchter löst sich, genau über {name}.'),
    StoryPiece('violino', 'Ein Geigenkasten geht auf. Drin ist keine Geige. {name} fällt.'),
    StoryPiece('cassaforte', 'Von oben ein Tresor. {name} hat gerade noch Zeit, die Marke zu lesen.'),
    StoryPiece('sigaro', '{name} zündet eine geschenkte Zigarre an. Die Zigarre macht „bumm“.'),
    StoryPiece('mazza', 'Um die Ecke ein Baseballschläger. Ein Schwung. {name} sieht Sterne, dann nichts mehr.'),
    StoryPiece('lupara', 'Zwei abgesägte Läufe ragen aus dem Dunkel. Ein Donnern. {name} fliegt nach hinten.'),
    StoryPiece('raffica', 'Ein Auto wird langsamer. Aus dem Fenster eine Tommy Gun. {name} dreht sich nicht rechtzeitig um.'),
    StoryPiece('garrota', 'Ein Stahldraht, zwei Hände in Handschuhen. {name} zappelt, dann nicht mehr.'),
    StoryPiece('vaso', 'Ein Geranientopf fällt aus dem dritten Stock. Kein Zufall. {name} sieht ihn nie kommen.'),
    StoryPiece('tombino', 'Unter den Füßen von {name} öffnet sich ein Gully. Dann schließt er sich wieder, ganz sorgfältig.'),
    StoryPiece('buio', 'Die Laterne geht aus. Ein dumpfer Schlag. Als sie wieder angeht, liegt {name} am Boden.'),
    StoryPiece('bacio', 'Ein Fremder, ein Kuss, ein Lippenstift zum Sterben schön. {name} lächelt, und stirbt.'),
    StoryPiece('boccia', 'Eine Bowlingkugel rollt aus dem Dunkel. {name} fliegt wie ein Kegel. Strike.'),
    StoryPiece(
      'pescespada',
      'Ein Schwertfisch lugt um die Ecke. En garde, Ausfall. {name} schläft jetzt bei den Fischen.',
    ),
    StoryPiece(
      'arpione',
      'Eine Harpune pfeift durch die Nacht, das Seil spannt sich. {name} verschwindet um die Ecke.',
    ),
    StoryPiece('torta', 'Eine Sahnetorte, mitten ins Gesicht von {name}. Alle lachen. In der Sahne steckt eine Granate.'),
    StoryPiece('trombone', 'In der Gasse spielt eine Posaune. Aus dem Schalltrichter kommt ein Schuss. {name} trifft einen falschen Ton.'),
    StoryPiece('tango', 'Jemand Fremdes bittet {name} zum Tango. Eine Drehung, ein Beugen, ein Dolch.'),
    StoryPiece('rose', 'Ein Strauß roter Rosen für {name}. Zwischen den Rosen ein Pistolenlauf. Überall Blütenblätter.'),
    StoryPiece('lavanderia', 'Ein Wäschereiwagen hält. Eine Schiebetür, zwei Arme. {name} kommt nie zurück.'),
  ],
  epilogues: [
    StoryPiece('gatto', 'Eine Katze hat alles gesehen. Sie redet nicht.'),
    StoryPiece('mambo', 'Irgendwo spielt ein Radio einen Mambo.'),
    StoryPiece('tetti', '{city} schläft. Oder tut so.'),
    StoryPiece('carta', 'Am Boden eine Spielkarte. Abspann.'),
    StoryPiece('finestra', 'Ein Fenster leuchtet auf, dann wird es dunkel.'),
    StoryPiece('sipario', 'Der Vorhang fällt. Keiner klatscht.'),
    StoryPiece('voce', 'Eine Stimme aus dem Off: „Nichts Persönliches.“'),
    StoryPiece('sirene', 'Sirenen in der Ferne. Sie kommen immer zu spät.'),
    StoryPiece('cappello', 'Ein Hut rollt über den Boden. Schnitt.'),
    StoryPiece('continua', 'Auf der Leinwand drei Wörter: „Fortsetzung folgt.“'),
  ],
  scoops: [
    'Extrablatt! Extrablatt! {name} ist auf der Titelseite.',
    'Am Kiosk steht eine Schlange: Die Zeitung schreibt nur über {name}.',
    'Die Zeitungsjungen rufen alle denselben Namen: {name}.',
  ],
  scoopMafia: 'Die Zeitung schreibt es schwarz auf weiß: {name} gehört zur Familie.',
  scoopClean: 'Die Zeitung schreibt es schwarz auf weiß: {name} ist unschuldig.',
  silences: [
    'Nadel, Faden, feine Handarbeit: Heute Morgen sind die Lippen von {name} zugenäht.',
    'Letzte Nacht hat jemand {name} besucht. Mit einer Nadel und einem guten Rat.',
    'Auf dem Kissen von {name} eine Spule schwarzer Faden. Botschaft angekommen.',
  ],
  silencedFact:
      'Heute darf {name} in der Diskussion nicht reden. {name} stimmt mit Gesten ab und kann trotzdem ausgeschaltet werden.',
  silencedFactOnline: 'Heute darf {name} im Stadt-Chat nicht schreiben. {name} stimmt trotzdem ab und kann ausgeschaltet werden.',
  dayInstruction: 'Ihr habt {minutes} zum Diskutieren. Dann stimmt ab, wer ausgeschaltet wird.',
  oneMinute: 'eine Minute',
  manyMinutes: '{minutes} Minuten',
  voteCalls: [
    'Die Zeit ist um. Die Menge will einen Schuldigen.',
    'Genug geredet. {city} will einen Namen.',
    'Die Menge wird unruhig. Der Henker lockert sich schon die Schultern.',
    'Zeit zum Abstimmen. Versucht, nicht falschzuliegen. Schon wieder.',
  ],
  voteInstruction: 'Stimmt laut ab, alle zusammen. Dann tippt einer den Verurteilten an. Bei Gleichstand: niemand.',
  secretVoteInstruction: 'Geheime Wahl: Das Handy geht reihum, jeder stimmt allein ab, die anderen schauen weg.',
  tieFact: 'Gleichstand: Heute wird niemand verurteilt. Zurück in die Nacht.',
  powerCurtainHint: 'Nimm das Handy in die Hand und lass niemanden draufschauen.',
  dayPowersHint: 'Wer eine Macht am Tag hat, setzt sie mit dem Knopf „Macht einsetzen“ ein.',
  lynchScenes: [
    '{name} steigt die Stufen zum Schafott hinauf. Die Guillotine glänzt in der Sonne.',
    '{name} geht erhobenen Hauptes zur Schlinge. Trommelwirbel.',
    'Ein Güterzug, eine einfache Fahrt. {name} verlässt {city}.',
    'Die Falltür am Rathaus knarrt. {name} wirft einen letzten Blick auf die Menge.',
    '{name} bittet um eine letzte Zigarette. Der Henker gibt Feuer.',
    'Großaufnahme der gefesselten Hände von {name}. Ganz {city} schaut zu.',
  ],
  cardTurns: 'Die Karte dreht sich. {name} war … {role}.',
  wasMafia: 'Auf der Seite der Familie.',
  wasCitizen: 'Auf der Seite der Stadt.',
  wasNeutral: 'Auf eigene Rechnung.',
  lynchedInnocent: [
    'Gute Arbeit, alle zusammen. Wirklich.',
    'Jemand an diesem Tisch versucht gerade, nicht zu grinsen.',
    'Die Familie dankt für die Zusammenarbeit.',
    'Der Henker entschuldigt sich, und berechnet trotzdem den vollen Preis.',
  ],
  lynchedMafioso: [
    'Einer weniger. Aber der hatte Freunde, und Freunde haben ein langes Gedächtnis.',
    'Jemand hat gerade einen Partner verloren, und kann nicht mal zur Beerdigung.',
    'Guter Schuss. Heute Nacht hat die Familie miese Laune.',
  ],
  lynchedLastMafioso: [
    'Und das war der Letzte von ihnen. Alle Glocken der Stadt läuten.',
    'Das war der Letzte. In {city} hat endlich mal jemand geredet.',
  ],
  noLynch: [
    'Der Henker ist ausnahmsweise früh zu Hause.',
    'Jemand atmet erleichtert auf. Wer wohl?',
    'In {city} ist es ganz normal, sich auf nichts zu einigen.',
  ],
  noLynchFact: 'Heute wird niemand ausgeschaltet.',
  truces: [
    'Halt, alle zusammen. Heute hängt keiner.',
    'Der Platz lässt die Stricke sinken: Waffenstillstand, für heute.',
  ],
  truceFact: 'Der Pazifist hat Waffenstillstand ausgerufen: Heute wird nicht abgestimmt.',
  citizensWin: [
    '{city} ist frei. Ab morgen schlafen die Leute bei offenem Fenster. Abspann.',
    'Auf der Straße sehen sich die Leute wieder in die Augen. Auf der Leinwand: „Ende“.',
  ],
  citizensWinFact: 'Die Stadt gewinnt: Die ganze Familie ist ausgeschaltet.',
  mafiaWins: [
    '{city} hat neue Bosse, und sie saßen genau an diesem Tisch. Abspann.',
    'In {city} hat keiner was gesehen. Wie immer. Abblende.',
  ],
  mafiaWinsFact: 'Die Familie gewinnt: Die Stadt ist nicht mehr in der Überzahl.',
  fires: [
    'Ein Geruch nach Benzin, ein Streichholz, und die Nacht wird orange.',
    'Jemand hat ein Streichholz angezündet. Als die Feuerwehr kam, war nichts mehr übrig.',
  ],
  burnedFact: '{name} ist in der Nacht verbrannt und aus dem Spiel.',
  resurrections: [
    'Eine Hand drückt den Sargdeckel auf. Die Stadt hat vergessen, ihn zuzunageln.',
    'Im Morgengrauen kommt ein Gespenst in die Bar und bestellt einen Kaffee. Es ist kein Gespenst.',
  ],
  resurrectedFact: '{name} ist zurück im Spiel, mit derselben Karte wie vorher.',
  foolWins: [
    'Der Strick schwingt, und wer da hängt, lächelt. Genau das war der Plan.',
    'Die Menge jubelt, und der Trottel verbeugt sich.',
  ],
  foolWinsFact: '{name} war der Trottel und gewinnt allein. Das Spiel geht weiter.',
  arsonistWins: [
    '{city} liegt in Asche. Eine Gestalt geht pfeifend davon, eine Schachtel Streichhölzer in der Hand. Abspann.',
    'In {city} gibt es nichts mehr zu verbrennen. Abblende in Orange.',
  ],
  arsonistWinsFact: 'Der Brandstifter gewinnt allein: Es ist keiner mehr da, der ihn aufhält.',
  bountyWins: [
    'Hinten auf dem Platz zählt jemand Geldscheine. Das Kopfgeld ist bezahlt.',
    'In der Menge tippt sich jemand an den Hut, als Dank. Angenehme Geschäfte.',
  ],
  loanSharkWinsFact: '{name} war der Kredithai: Am Ende noch am Leben, kassiert {name} mit.',
  bountyWinsFact: '{name} war der Kopfgeldjäger: kassiert und gewinnt allein. Das Spiel endet hier.',
  assassinWins: [
    'In {city} sind nur noch leere Stühle übrig. Der Auftragskiller zahlt den Kaffee und geht.',
    'In {city} geht das letzte Licht aus. Jemand wischt eine Klinge ab und pfeift. Abspann.',
  ],
  assassinWinsFact: 'Der Auftragskiller gewinnt allein: reiner Tisch.',
  mayorRevealed: '{name} ist der Bürgermeister: Heute zählt diese Stimme doppelt.',
  watchVisited: 'Letzte Nacht kam jemand an die Tür von {name}.',
  watchQuiet: 'Letzte Nacht kam niemand an die Tür von {name}.',
  taskPrompts: {
    NightTaskKind.kill: 'Wen schaltet die Familie heute Nacht aus?',
    NightTaskKind.silence: 'Wem nähst du heute Nacht die Lippen zu?',
    NightTaskKind.protect: 'Wen beschützt du heute Nacht?',
    NightTaskKind.guard: 'Für wen hältst du heute Nacht den Kopf hin?',
    NightTaskKind.investigate: 'Wen willst du überprüfen?',
    NightTaskKind.dig: 'Wessen Grab gräbst du heute Nacht auf?',
    NightTaskKind.snipe: 'Willst du auf jemanden schießen?',
    NightTaskKind.scoop: 'Über wen geht dein Knüller?',
    NightTaskKind.douse: 'Wen übergießt du heute Nacht mit Benzin?',
    NightTaskKind.ignite: 'Zündest du heute Nacht das Streichholz an?',
    NightTaskKind.resurrect: 'Wen holst du heute Nacht zurück?',
    NightTaskKind.watch: 'Wessen Tür beobachtest du heute Nacht?',
    NightTaskKind.lend: 'Wen schützt du heute Nacht mit einem Kredit?',
    NightTaskKind.stab: 'Wen schaltest du heute Nacht aus?',
    NightTaskKind.jail: 'Wen sperrst du heute Nacht ein?',
    NightTaskKind.link: 'Wer verliebt sich?',
    NightTaskKind.convert: 'Wen rufst du heute Nacht ins Licht?',
    NightTaskKind.block: 'Für wen singst du heute Nacht?',
    NightTaskKind.aim: 'Wen behältst du im Visier?',
  },
  taskHints: {
    NightTaskKind.kill: 'Tipp einen Namen an: Das ist deine Stimme, wer stirbt. Die Mehrheit der Familie entscheidet.',
    NightTaskKind.silence: 'Tipp einen Namen an: Diese Person kann morgen nicht reden. Nur einmal, statt deiner Stimme.',
    NightTaskKind.protect: 'Tipp einen Namen an, auch deinen: Die Person kann heute Nacht nicht sterben. Nie zwei Nächte hintereinander.',
    NightTaskKind.guard: 'Tipp einen Namen an: Wird die Person heute Nacht angegriffen, stirbst du an ihrer Stelle.',
    NightTaskKind.investigate: 'Tipp einen Namen an: Du erfährst sofort, ob die Person zur Familie oder zur Stadt gehört.',
    NightTaskKind.dig: 'Tipp eine tote Person an: Du, und nur du, erfährst sofort ihre Rolle.',
    NightTaskKind.snipe: 'Tipp einen Namen an: Du schießt, die Person stirbt. Du hast eine Kugel. Passen spart sie auf.',
    NightTaskKind.scoop: 'Tipp einen Namen an: Im Morgengrauen erfahren alle die Seite. Nur ein Knüller. Passen spart ihn auf.',
    NightTaskKind.douse: 'Tipp einen Namen an, um heimlich Benzin zu verteilen. Oder zünd das Streichholz an: Alle Übergossenen brennen.',
    NightTaskKind.ignite: 'Tipp deinen eigenen Namen an: Alle, die du übergossen hast, brennen heute Nacht.',
    NightTaskKind.resurrect: 'Tipp eine tote Person an: Im Morgengrauen zurück, wenn du lebst. Nur einmal; Passen spart es auf.',
    NightTaskKind.watch: 'Tipp einen Namen an: Im Morgengrauen weißt du, ob jemand zu Besuch kam. Nicht, wer.',
    NightTaskKind.lend: 'Tipp einen Namen an: Die Person kann heute Nacht nicht sterben. Nie zweimal hintereinander dieselbe.',
    NightTaskKind.stab: 'Tipp einen Namen an: Die Person stirbt heute Nacht, außer jemand beschützt sie.',
    NightTaskKind.jail: 'Tipp einen Namen an: Die Person kann heute Nacht nichts tun und keiner kommt ran. Die Zelle schließt sofort.',
    NightTaskKind.link: 'Tipp zwei Namen an, auch deinen: Ab heute Nacht lieben sie sich. Nur einmal.',
    NightTaskKind.convert: 'Tipp einen Namen an: Geht die Tür auf, gehört die Person ab morgen zur Sekte.',
    NightTaskKind.block: 'Tipp einen Namen an: Der Zug dieser Person geht heute Nacht verloren. Nie zwei Nächte hintereinander dieselbe Person.',
    NightTaskKind.aim: 'Tipp einen Namen an: Morgen darfst du schießen. Gehört die Person zur Stadt, stirbst du.',
    NightTaskKind.decoy: 'Heute Nacht kein Zug: Tipp irgendeinen Namen an, es passiert nichts. So bleibt deine Rolle verborgen.',
  },
  backfires: [
    'Der Schuss hallt, aber es fällt, wer abgedrückt hat.',
    'Das Gewehr klemmt und platzt. Vom Glockenturm kommt nur noch Stille.',
  ],
  backfireFact: 'Der Schuss ging nach hinten los: Der Meisterschütze zielte auf die Stadt und stirbt selbst.',
  cannonShots: [
    'Ein Donnern erschüttert den Platz. Die Fenster klirren, die Tauben fliegen alle auf einmal auf.',
    'Die Kanone donnert einmal. Als sich der Rauch verzieht, steht jemand nicht mehr.',
    'Feuer! Der Boden bebt, die Tassen springen auf den Cafétischen. Dann Stille.',
  ],
  cannonFact: 'Ein Donnern auf dem Platz: Der Kanonier hat {name} getroffen.',
  cardCurtainHint: 'Gleich siehst du deine Karte: Sonst darf keiner hinschauen.',
  curtainHint: 'Alle anderen schauen weg. Tipp erst, wenn du das Handy in der Hand hast.',
  escorts: [
    'Ein Schuss im Dunkeln. Aber ein Mann in Schwarz steht schon vor dem Präsidenten, den Koffer erhoben.',
    'Ein Schuss, ein Funke, ein Klirren von Stahl. Die Eskorte schläft nie.',
  ],
  escortFact: 'Die Eskorte hat einen Anschlag auf den Präsidenten abgewehrt.',
  heartbreaks: [
    'Ein Herz bleibt lautlos stehen. Wen es liebte, ist schon fort.',
    'Manche können nicht allein auf der Welt bleiben.',
  ],
  heartbreakFact: '{name} ist an gebrochenem Herzen gestorben und folgt der großen Liebe.',
  loversWinFact: 'Die Verliebten leben beide: Sie gewinnen zusammen.',
  marksmanShots: [
    'Ein Schuss vom Glockenturm. {name} bricht mitten auf dem Platz zusammen.',
    'Ein trockener Knall, von weit her. {name} bringt den Satz nicht mehr zu Ende.',
  ],
  marksmanShotFact: 'Ein Schuss vom Glockenturm: {name} ist aus dem Spiel.',
  passPhone: 'Gib das Handy an {name} weiter.',
  presidentFallsFact: 'Der Präsident ist gefallen. Die Stadt ist verloren.',
  putPhoneDown: 'Erledigt. Leg das Handy hin und gib es weiter.',
  sectWins: [
    'In jedem Fenster brennen Kerzen. In {city} ist keiner mehr übrig, den man bekehren könnte.',
    'Ein leiser Gesang steigt aus den Straßen von {city}. Alle haben das Licht gesehen.',
  ],
  sectWinsFact: 'Die Sekte gewinnt: Alle Lebenden folgen dem Sektenführer.',
  voterTurn: '{name} muss abstimmen. Die Wahl ist geheim.',
  decoyPrompts: [
    'Wer kommt dir am verdächtigsten vor?',
    'Wem würdest du nie trauen?',
    'Wer hat das Gesicht von jemandem, der was zu verbergen hat?',
    'Wenn du mit dem Finger zeigen müsstest, auf wen?',
    'Wer spielt an diesem Tisch das beste Theater?',
  ],
);

const _quickDe = [
  RulesStep('Zwei Seiten', [
    RulesBeat('Stell dir eine Großstadt in den Vierzigern vor. Fast alle sind anständige Leute: die Stadt.'),
    RulesBeat('Manche nicht. Das ist die Familie, und heute Nacht hat sie zu tun.'),
    RulesBeat('Die Gangster kennen sich untereinander. Die Ehrlichen kennen niemanden. Genau das ist das Problem.'),
  ]),
  RulesStep('Deine Karte ist geheim', [
    RulesBeat('Das Handy geht reihum. Alle sehen sich ihre Rolle allein an und verraten sie niemandem.'),
    RulesBeat('Tagsüber darfst du über dich sagen, was du willst. Auch Lügen. Vor allem Lügen.'),
  ]),
  RulesStep('Die Nacht', [
    RulesBeat(
      'Nachts geht das Handy von Hand zu Hand. Wer es hält, macht heimlich einen Zug; alle anderen schauen weg.',
    ),
    RulesBeat('Die Familie wählt, wen sie aus dem Weg räumt. Der Detektiv ermittelt, der Doktor rettet.'),
    RulesBeat('Keine Kräfte? Tipp auf PASSEN, mit demselben Pokerface wie alle. Keiner soll wissen, wer was getan hat.'),
  ]),
  RulesStep('Der Tag', [
    RulesBeat('Im Morgengrauen erfahrt ihr, wer es nicht geschafft hat. Wer nachts stirbt, nimmt die Rolle mit ins Grab.'),
    RulesBeat('Dann wird geredet: Anklagen, Alibis, schiefe Blicke.'),
    RulesBeat(
      'Wer eine Macht am Tag hat, tippt auf „Macht einsetzen“, dann auf das eigene Gesicht, und setzt sie mit dem Handy in der Hand ein.',
    ),
    RulesBeat(
      'Zum Schluss wird laut abgestimmt, alle zusammen, und einer tippt auf dem Handy den Verurteilten an. Die Karte wird aufgedeckt. Gleichstand? Heute hängt keiner.',
    ),
    RulesBeat('Lieber eine geheime Wahl? Wählt sie vor den Karten: Das Handy geht reihum und jeder stimmt allein ab.'),
  ]),
  RulesStep('Wer gewinnt', [
    RulesBeat('Die Stadt gewinnt, wenn die ganze Familie raus ist.'),
    RulesBeat('Die Familie gewinnt, wenn sie so viele sind wie alle anderen.'),
    RulesBeat('Ein paar seltsame Gestalten spielen auf eigene Rechnung: Ihre Karte sagt ihnen, wie sie gewinnen.'),
  ]),
  RulesStep('Die goldenen Regeln', [
    RulesBeat('Schiel nicht auf fremde Handys.'),
    RulesBeat('Zeig deinen Bildschirm niemandem.'),
    RulesBeat('Tote reden nicht. Nicht mal mit den Augen.'),
    RulesBeat('Und keiner nimmt es persönlich: Es ist nur ein Spiel. Mehr oder weniger.'),
  ]),
];

const _stageDe = [
  RulesStep('Es war einmal', [
    RulesBeat.cue('Dimm das Licht. Warte auf Stille.'),
    RulesBeat(
      'Es war einmal, in einer Stadt, die niemals schläft, ein Platz voller guter Leute. Man nannte sie die Stadt.',
    ),
    RulesBeat(
      'Doch unter diesen guten Leuten versteckte sich die Familie. Wenige, elegant, bewaffnet. Sie kannten sich alle… und niemand kannte sie.',
    ),
    RulesBeat.cue('Schau allen ins Gesicht, langsam.'),
    RulesBeat('Vielleicht sitzt einer von ihnen an diesem Tisch. Vielleicht zwei.'),
  ]),
  RulesStep('Der versiegelte Umschlag', [
    RulesBeat('Jeder von euch bekommt einen versiegelten Umschlag: Darin steht, wer ihr wirklich seid.'),
    RulesBeat.cue('Gib das Handy nach rechts weiter, als wäre es ein Umschlag.'),
    RulesBeat('Lest ihn allein. Dann schließt ihn ins Herz und verratet ihn niemandem.'),
    RulesBeat('Ab morgen dürft ihr über euch erzählen, was ihr wollt. Die Wahrheit… oder auch nicht.'),
  ]),
  RulesStep('Wenn die Nacht hereinbricht', [
    RulesBeat.cue('Senk die Stimme.'),
    RulesBeat('Wenn die Nacht hereinbricht, geht das Handy von Hand zu Hand, wie ein Geheimnis, das brennt.'),
    RulesBeat('Wer es hält, macht ungesehen den Zug. Die anderen starren an die Wand, an die Decke, auf die eigenen Schuhe.'),
    RulesBeat(
      'Die Familie wählt, wer das Morgengrauen nicht erlebt. Der Detektiv schnüffelt in fremden Geschäften. Der Doktor wacht über jemanden.',
    ),
    RulesBeat(
      'Und wer keine Kräfte hat? Spielt Theater. Tippt mit Verschwörermiene auf den Bildschirm, damit keiner irgendwen verdächtigt.',
    ),
  ]),
  RulesStep('Im Morgengrauen, der Platz', [
    RulesBeat.cue('Heb die Stimme, wie ein Ausrufer.'),
    RulesBeat('Im Morgengrauen erwacht die Stadt und zählt ihre Toten. Wer nachts fällt, geht mit seinem Geheimnis.'),
    RulesBeat('Dann versammelt sich der Platz: Man klagt an, man schwört, man lügt.'),
    RulesBeat.cue('Zeig plötzlich auf jemanden.'),
    RulesBeat('Du! Wo warst du letzte Nacht?'),
    RulesBeat(
      'Wenn die Stimmen verstummen, wird abgestimmt: laut, mit ausgestrecktem Finger. Wer die meisten Stimmen bekommt, wird verurteilt, und die Karte wird vor allen aufgedeckt.',
    ),
    RulesBeat('Bei Gleichstand steht der Platz still: Heute wird niemand verurteilt.'),
  ]),
  RulesStep('Wie die Geschichte endet', [
    RulesBeat('Die Geschichte endet gut für die Stadt, wenn der Letzte der Familie den Platz verlassen hat.'),
    RulesBeat(
      'Sie endet gut für die Familie, wenn ihre Leute so viele sind wie alle anderen: Von da an gehört die Stadt ihnen.',
    ),
    RulesBeat('Und ein paar einsame Seelen spielen ihr ganz eigenes Spiel: Ihr Umschlag sagt ihnen, wie sie gewinnen.'),
  ]),
  RulesStep('Die drei Gesetze der Straße', [
    RulesBeat.cue('Langsam, an den Fingern abgezählt.'),
    RulesBeat('Erstes Gesetz: Man schielt nicht auf fremde Handys.'),
    RulesBeat('Zweites Gesetz: Den eigenen Bildschirm zeigt man niemandem.'),
    RulesBeat('Drittes Gesetz: Tote reden nicht. Nicht mit dem Mund, nicht mit den Augen.'),
    RulesBeat.cue('Pause. Dann, im Flüsterton.'),
    RulesBeat('Und jetzt… soll die Nacht beginnen.'),
  ]),
];
