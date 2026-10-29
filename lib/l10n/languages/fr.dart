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

// The whole of the French translation: interface, keyed messages and the
// narrator's script. French, tutoiement, polar tone.
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.
//
// Stage names (with their article, as in Italian; mid-sentence the article
// drops its capital): le Porte-flingue, le Parrain, le Tailleur, le Complice,
// l'Honnête Citoyen, le Commissaire, le Docteur ("le Doc" in the script), le
// Tireur, le Reporter, le Fossoyeur, le Garde du corps, le Vétéran, le Repris
// de justice, le Messie, le Maire, le Concierge, le Bouffon, le Pyromane, le
// Chasseur de primes, l'Usurier, le Tueur à gages, l'Entraîneuse, le Geôlier,
// le Pacifiste, Cupidon, le Président, le Gourou, l'Artilleur, le Tireur
// d'élite. The factions: "la Famille" and "la ville".

final class FrenchStrings extends EnglishStrings {
  const FrenchStrings();

  @override
  AppLanguage get language => AppLanguage.fr;
  @override
  NarrationPack get pack => frenchPack;
  @override
  OnlineStrings get online => const FrenchOnlineStrings();
  @override
  ShopStrings get shop => const FrenchShopStrings();
  @override
  Map<String, String> get messages => frenchMessages;
  @override
  List<RulesStep>? rulesSteps(RulesStyle style) => style == RulesStyle.quick ? _quickFr : _stageFr;

  @override
  String get settings => 'Réglages';
  @override
  String get alleyPlaque => 'IMPASSE DU SILENCE';
  @override
  String get tonight => 'CE SOIR, ON JOUE';
  @override
  String get sharedTitle => 'UN TÉLÉPHONE POUR TOUS';
  @override
  String get sharedBlurb => 'Il passe de main en main. Pas de réseau, pas de témoins.';
  @override
  String get createRoom => 'CRÉER UNE SALLE';
  @override
  String get hostName => 'Toi';
  @override
  String get soon => 'BIENTÔT';
  @override
  String get rankedTitle => 'CLASSÉ';
  @override
  String get rankedBlurb => 'Des inconnus, des points et un classement à grimper.';
  @override
  String get rankedTeaser => 'Le classé ouvre bientôt. En attendant, fais-toi un nom.';
  @override
  List<String> get homeCaptions => const [
    'Personne n’a rien vu.',
    'Personne ne parle. Quelqu’un meurt.',
    'Tu n’étais pas là. Et si tu y étais, tu dormais.',
    'Dans cette ville, même les murs se taisent.',
    'La confiance, c’est bien. Le silence, c’est mieux.',
    'Qui sait se tait. Qui parle ne voit pas l’aube.',
    'Cette nuit, quelqu’un ne rentre pas chez lui.',
  ];

  @override
  String get settingsTitle => 'RÉGLAGES';
  @override
  String get sound => 'Musique et effets sonores';
  @override
  String get soundHint => 'Tu les entends même téléphone en silencieux.';
  @override
  String get languageSetting => 'Langue';
  @override
  String get languageAutomatic => 'Automatique (téléphone)';

  @override
  String get narratorTitle => 'NARRATEUR';
  @override
  String get whoPullsTheStrings => 'Qui tire\nles ficelles ?';
  @override
  String get narratorIntro => 'Le narrateur mène la partie et connaît tous les rôles.';
  @override
  String get pickedByGroup => 'Choisi par le groupe';
  @override
  String get pickedByGroupHint => 'Vous décidez qui raconte. Pas de rôle pour cette personne.';
  @override
  String get drawnByCylinder => 'Tiré au barillet';
  @override
  String get drawnByCylinderHint => 'Un tour de barillet. Qui sort raconte et ne joue pas.';
  @override
  String get automaticNarrator => 'Narrateur automatique';
  @override
  String get automaticNarratorHint => 'Le téléphone raconte : tout le monde joue.';
  @override
  String needAtLeast(int players) => 'Il faut au moins $players joueurs';
  @override
  String get whoNarrates => 'QUI RACONTE ?';
  @override
  String get drawTitle => 'LE TIRAGE';
  @override
  String get whoNarratesTonight => 'Qui raconte\nce soir ?';
  @override
  String get theNarratorIs => 'LE NARRATEUR, C’EST';
  @override
  String get continueLabel => 'CONTINUER';

  @override
  String get cardsTitle => 'LES CARTES';
  @override
  String get automatic => 'Automatique';
  @override
  String get cardsDealt => 'Les cartes sont distribuées';
  @override
  String get shuffling => 'On bat le paquet…';
  @override
  String get checkYourCards => 'REGARDEZ VOS CARTES';
  @override
  String cardOf(int card, int of) => 'CARTE $card SUR $of';
  @override
  String get holdTheCardHint => 'Garde le doigt sur la carte pour la voir.\nLâche, et elle se retourne.';
  @override
  String get gotIt => 'J’AI VU';
  @override
  String get pressAndHold => 'GARDE LE DOIGT';
  @override
  String get youAreFamily => 'TU ES AVEC LA FAMILLE';
  @override
  String get youAreTown => 'TU ES AVEC LA VILLE';
  @override
  String get youActAlone => 'TU AGIS EN SOLO';
  @override
  String get yourAccomplices => 'TES COMPLICES';
  @override
  String get familyUnknown => 'TU SERS LA FAMILLE, SANS SAVOIR QUI EN EST';
  @override
  String get familyBadge => 'FAMILLE';
  @override
  String get townBadge => 'VILLE';

  @override
  String get passThePhoneTo => 'PASSE LE TÉLÉPHONE À';
  @override
  String get nobodyElseLooks => 'Personne d’autre ne regarde l’écran.';
  @override
  String get itsMe => 'C’EST MOI';
  @override
  String get youBadge => 'TOI';
  @override
  String get innocentBadge => 'INNOCENT';
  @override
  String get neutralBadge => 'NEUTRE';
  @override
  String get youAreNeutral => 'TU JOUES POUR TOI';
  @override
  String get arsonistWins => 'Un loup solitaire\ngagne';
  @override
  String get wonAlone => 'VICTOIRE EN SOLO';
  @override
  String get revealAsMayor => 'Révèle-toi : le Maire';
  @override
  String get lightTheMatch => 'Craque l’allumette';
  @override
  String get dousePick => 'Arroser';
  @override
  String get dousedBadge => 'ESSENCE';
  @override
  String get bountyBadge => 'PRIME';
  @override
  String get bountyLine => 'Tu as une prime sur {name} : fais-le lyncher par la ville.';
  @override
  String get readAloud => 'LISEZ À VOIX HAUTE';
  @override
  String readerReadsAloud(String reader) => '${reader.toUpperCase()} LIT À VOIX HAUTE';
  @override
  String get narratorSpeaks => 'LE NARRATEUR PARLE';
  @override
  String get narratorOnly => 'RÉSERVÉ AU NARRATEUR';
  @override
  String get holdToSeeRoles => 'Garde le doigt appuyé pour voir tous les rôles';

  @override
  String nightTitle(int round) => 'NUIT $round';
  @override
  String get nightFalls => 'La nuit tombe';
  @override
  String get startTheNight => 'LANCER LA NUIT';
  @override
  String get dawnTitle => 'AUBE';

  @override
  String get dayBreaks => 'Le jour se lève';
  @override
  String get everyoneAlive => 'Tout le monde s’en sort';
  @override
  String get crimePage => 'Les faits divers';
  @override
  String get finale => 'LE FINAL';
  @override
  String get openTheFloor => 'OUVRIR LE DÉBAT';
  @override
  String dayTitle(int round) => 'JOUR $round';
  @override
  String get verdictTitle => 'LE VERDICT';
  @override
  String get noConviction => 'Aucune condamnation';
  @override
  String get endTitle => 'FIN';
  @override
  String get leaveQuestion => 'Quitter la partie ?';
  @override
  String get leaveWarning => 'La partie en cours sera perdue.';
  @override
  String get stay => 'RESTER';
  @override
  String get leave => 'QUITTER';
  @override
  String get leaveTooltip => 'Quitter la partie';
  @override
  String get rolesTooltip => 'Les rôles, pour le narrateur seulement';
  @override
  String get phoneOnTheTable => 'Téléphone\nsur la table';
  @override
  String get phoneOnTheTableHint => 'Posez-le au milieu, que tout le monde voie.\nIl s’est passé quelque chose cette nuit.';
  @override
  String get lightsDown => 'ON ÉTEINT';
  @override
  String get pass => 'JE PASSE';
  @override
  String get voteTheHit => 'LE CONTRAT';
  @override
  String get sewAMouth => 'COUDRE UNE BOUCHE';
  @override
  String get confirm => 'CONFIRMER';
  @override
  String get doneTitle => 'C’est fait.';
  @override
  String get nobodyWillKnow => 'Personne ne saura ce que tu as choisi.';
  @override
  String get yourInvestigation => 'TON ENQUÊTE';
  @override
  String get inTheGrave => 'DANS LA TOMBE';
  @override
  String wasRole(String role) => 'C’ÉTAIT ${role.toUpperCase()}';
  @override
  String get isFamily => 'EST DE LA FAMILLE';
  @override
  String get isInnocent => 'EST HONNÊTE';
  @override
  String get wasWithFamily => 'ÉTAIT AVEC LA FAMILLE';
  @override
  String get wasWithTown => 'ÉTAIT AVEC LA VILLE';
  @override
  String get done => 'TERMINÉ';
  @override
  String get nobody => 'PERSONNE';
  @override
  String get condemn => 'CONDAMNER';
  @override
  String fateNight(int round) => 'Nuit $round';
  @override
  String fateGallows(int round) => 'Potence, jour $round';
  @override
  String get stillStanding => 'Toujours debout';
  @override
  String get familyWins => 'La Famille\ngagne';
  @override
  String get townWins => 'La ville\ngagne';
  @override
  String get whoWasWho => 'QUI ÉTAIT QUI';
  @override
  String get mostSuspicious => 'LA TÊTE LA PLUS LOUCHE';
  @override
  String suspicion(String name, int fingers, {required bool rightly}) =>
      '$name, avec $fingers ${fingers <= 1 ? 'doigt pointé' : 'doigts pointés'} dans le noir. '
      '${rightly ? 'À raison.' : 'À tort, comme on le sait maintenant.'}';
  @override
  String get backHome => 'RETOUR À L’IMPASSE';
  @override
  String get keepReading => 'LIRE LA SUITE';
  @override
  String get flipTheCard => 'RETOURNER LA CARTE';
  @override
  String get timeUp => 'C’EST L’HEURE';
  @override
  String get floorIsOpen => 'LE DÉBAT EST OUVERT';
  @override
  String get plusMinute => '+1 MIN';
  @override
  String get callTheVote => 'PASSER AU VOTE';
  @override
  String get accusedStamp => 'ACCUSÉ';
  @override
  String aliveCount(int alive, int total) => '$alive debout sur $total';

  @override
  String get willSeeDawn => 'VERRA L’AUBE';
  @override
  String get wontSeeDawn => 'NE VERRA PAS L’AUBE';
  @override
  String get next => 'SUIVANT';
  @override
  String get skip => 'PASSER';

  @override
  String verdictCaption(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'Au coucher du soleil, sur les quais.',
    VerdictTake.cartello => 'Les faubourgs. Une route poussiéreuse, sans retour.',
    VerdictTake.treno => 'La gare centrale. Le dernier train de la nuit.',
    VerdictTake.cannone => 'Le cirque est arrivé. On cherche un volontaire.',
    VerdictTake.assoluzione => 'La grand-place au crépuscule. Le ton monte.',
  };
  @override
  String verdictStamp(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'DORT AVEC LES POISSONS',
    VerdictTake.cartello => 'EXIL SANS RETOUR',
    VerdictTake.treno => 'ALLER SIMPLE',
    VerdictTake.cannone => 'EN ORBITE',
    VerdictTake.assoluzione => '',
  };
  @override
  String get verdictLine => 'LE PEUPLE A PARLÉ';
  @override
  String get acquittalTitle => 'AUCUNE CONDAMNATION';
  @override
  String get acquittalLine => 'TOUT LE MONDE RENTRE. POUR CE SOIR.';
  @override
  String get townSign => 'CITÉ';
  @override
  String verdictWord(VerdictWord word) => switch (word) {
    VerdictWord.thud => 'BOUM !',
    VerdictWord.byeBye => 'BYE BYE !',
    VerdictWord.glub => 'GLOUB',
    VerdictWord.getOut => 'DEHORS !',
    VerdictWord.cough => 'KOF KOF !',
    VerdictWord.toot => 'TCHOU-TCHOU !',
    VerdictWord.sniff => 'SNIF !',
    VerdictWord.ping => 'PLING !',
    VerdictWord.bonk => 'TOC !',
    VerdictWord.shrug => 'BOF !',
  };

  @override
  String get lobbyTitle => 'LA TABLE';

  @override
  String get lobbyDebugAdd => '+ TEST';

  @override
  String get lobbyClearTooltip => 'Tout le monde dehors';

  @override
  String get lobbyEmptyTitle => 'QUI JOUE CE SOIR ?';

  @override
  String get lobbyEmptyBody => 'Faites tourner le téléphone : chacun tape son nom et pose pour sa photo d’identité judiciaire.';

  @override
  String get lobbyEmptyPlaceholder => '???';

  @override
  String get lobbyTableEmpty => 'TABLE VIDE';

  @override
  String get lobbyReadyHint => 'Quand vous voulez.';

  @override
  String get lobbyTableFull => 'Table pleine : pas plus de $maxTablePlayers joueurs.';

  @override
  String get lobbyTableFullRefusal => 'La table est pleine : quelqu’un doit d’abord se lever.';

  @override
  String get lobbyRosterFull => 'La liste est pleine : retire d’abord quelqu’un.';

  @override
  String get lobbyGestureHint =>
      'Touche un visage pour l’asseoir ou le lever.\nGarde le doigt dessus pour changer le nom ou la photo.';

  @override
  String get lobbyOut => 'DEHORS';

  @override
  String get lobbyPrivacy => 'Les noms et les photos restent sur ce téléphone.';

  @override
  String get lobbyAdd => 'AJOUTER';

  @override
  String get lobbyStart => 'COMMENCER';

  @override
  String get lobbyClearTitle => 'Tout le monde dehors ?';

  @override
  String get lobbyClearBody => 'Ça efface tous les noms et toutes les photos de ce téléphone. Pas de retour en arrière.';

  @override
  String get lobbyClearCancel => 'ANNULER';

  @override
  String get lobbyClearConfirm => 'TOUT EFFACER';

  @override
  String lobbySeated(int seated) => '$seated À TABLE';

  @override
  String lobbyMissing(int missing) =>
      missing == 1 ? 'Encore un joueur pour commencer.' : 'Encore $missing joueurs pour commencer.';

  @override
  String get personTitleNew => 'NOUVELLE FICHE';

  @override
  String get personTitleEdit => 'FICHE';

  @override
  String get personPlacardEmpty => 'TON NOM';

  @override
  String get personNameHint => 'Comment tu t’appelles ?';

  @override
  String get personNameEmpty => 'Pas de nom, pas de fiche.';

  @override
  String get personNameTooLong => 'Trop long : $maxNameLength lettres maximum.';

  @override
  String get personNameTaken => 'Quelqu’un porte déjà ce nom.';

  @override
  String get personShoot => 'CLIC';

  @override
  String get personReshoot => 'REFAIRE';

  @override
  String get personGallery => 'GALERIE';

  @override
  String get personNoPhoto => 'SANS PHOTO';

  @override
  String get personHintDrag => 'Fais glisser pour centrer le visage';

  @override
  String get personSubmitNew => 'AJOUTER À LA TABLE';

  @override
  String get personSubmitEdit => 'ENREGISTRER';

  @override
  String get personPrivacy => 'La photo reste sur ce téléphone : le jeu ne l’envoie nulle part.';

  @override
  String get personCameraDenied =>
      'Pas d’accès à l’appareil photo. Tu peux l’autoriser dans les Réglages, ou jouer sans photo.';

  @override
  String get personCameraFailed => 'La photo n’a pas marché. Réessaie, ou joue sans.';

  @override
  String get personStamp => 'FICHÉ';

  @override
  String get personBookedPass => 'Passe le téléphone au suivant.';

  @override
  String get personNext => 'AU SUIVANT !';

  @override
  String get personDone => 'ON A FINI';

  @override
  String get personRemoveTooltip => 'Retirer de la liste';

  @override
  String get personRemoveCancel => 'ANNULER';

  @override
  String get personRemoveConfirm => 'RETIRER';

  @override
  String get personRemoveBody => 'Ça efface le nom et la photo du téléphone.';

  @override
  String personBookedSeated(String name) => '$name est à table.';

  @override
  String personBookedWatching(String name) => 'La table est pleine : $name regarde pour l’instant.';

  @override
  String personRemoveTitle(String name) => 'Retirer $name ?';

  @override
  String verdictName(VerdictTake take) => switch (take) {
        VerdictTake.molo => 'Le quai',
        VerdictTake.cartello => 'Le panneau de sortie de ville',
        VerdictTake.treno => 'Le dernier train',
        VerdictTake.cannone => 'Le canon du cirque',
        VerdictTake.assoluzione => 'Aucune condamnation',
      };

  @override
  String get someoneSaved => 'QUELQU’UN';

  @override
  String get musicVolumeLabel => 'Musique';

  @override
  String get effectsVolumeLabel => 'Effets sonores';

  @override
  String get memeMode => 'Mode mème';

  @override
  String get memeModeHint => 'Vine boom, FAAAH et compagnie aux grands moments.';
}

final class FrenchOnlineStrings extends EnglishOnlineStrings {
  const FrenchOnlineStrings();

  @override
  String get rankedQueueTitle => 'CLASSÉ';
  @override
  String get rankedStart => 'Trouver une partie';
  @override
  String get rankedSearching => 'On cherche des têtes nouvelles en ville…';
  @override
  String rankedWaiting(int people) => '$people en attente';
  @override
  String rankedEstimate(String time) => 'Attente estimée : $time';
  @override
  String get rankedCancel => 'Annuler';
  @override
  String get rankedFound => 'Table trouvée !';
  @override
  String get rankedTestMatch => 'TEST · NON CLASSÉ';
  @override
  String get rankedWarning => 'Qui quitte les parties finit par jouer avec ceux qui les quittent.';
  @override
  String rankedCooldown(String time) => 'Trop de parties abandonnées : retour dans la file dans $time.';
  @override
  String get rankedLobbyTitle => 'SALLE D’ATTENTE';
  @override
  String rankedSeats(int seated, int size) => '$seated/$size à table';
  @override
  String rankedMissing(int missing) => missing == 1 ? 'Il manque un joueur' : 'Il manque $missing joueurs';
  @override
  String rankedStartsIn(int seconds) => 'Table pleine : départ dans $seconds';
  @override
  String get rankedLeaveLobby => 'Quitter la salle';
  @override
  String get rankedNoPenalty => 'Avant le départ, tu peux partir sans pénalité.';
  @override
  String get rankedTipsTitle => 'EN ATTENDANT';
  @override
  String get rankedStrangers => 'Tu découvres qui est à ta table au début de la partie.';
  @override
  String homeQueued(int n) => '$n en attente d’une table';
  @override
  String get rankedSit => 'Prendre place';
  @override
  String get rankedTutorialsTitle => 'D’abord, les trois mains d’essai';
  @override
  String get rankedTutorialsBody =>
      'Seuls ceux qui ont fini les trois mains d’essai s’assoient à une table classée : la Famille, la ville et les solitaires. Entre amis, tu peux jouer tout de suite.';
  @override
  String rankedTutorialName(String faction) => switch (faction) {
        'family' => 'la Famille',
        'town' => 'la ville',
        _ => 'le solitaire',
      };
  @override
  String rankedTutorialPlay(String name) => 'Jouer la main : $name';
  @override
  String get rankedSkipTutorials => 'Je connais déjà le jeu';
  @override
  String get rankedSkipTitle => 'Vraiment ?';
  @override
  String get rankedSkipBody => 'Tu sautes tous les tutoriels et tu passes direct au classé.';
  @override
  String get rankedSkipConfirm => 'Oui, sauter les tutoriels';
  @override
  String get rankedSkipCancel => 'Laisse tomber';
  @override
  String get rankedPickTable => 'CHOISIS TA TABLE';
  @override
  String get rankedRules => '12 joueurs · tours chronométrés · les déserteurs paient';
  @override
  String get rankedYourRank => 'TON RANG';
  @override
  String rankedTowards(String tier) => 'vers $tier';
  @override
  String get rankedTopTier => 'au sommet de la famille';
  @override
  String rankedTableQueued(int n) => '$n dans la file';
  @override
  String get rankedTableIt => 'On parle italien';
  @override
  String get rankedTableEn => 'On parle anglais';
  @override
  String homeOnline(int n) => '$n joueurs en ville';
  @override
  List<String> get rankedTips => const [
        'Parle le jour, mais pas trop : les plus bavards finissent dans le viseur.',
        'Un vote à la dernière seconde en dit long sur qui le donne.',
        'La Famille gagne dès qu’elle est aussi nombreuse que la ville : compte les têtes.',
        'Quitter une partie, c’est laisser ton camp en sous-effectif.',
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
  String get dossierTitle => 'DOSSIER PERSONNEL';
  @override
  String get dossierHistory => 'AFFAIRES RÉCENTES';
  @override
  String get dossierNoHistory => 'Casier vierge : pas encore de partie.';
  @override
  String get dossierSettings => 'Réglages';
  @override
  String get dossierConfidential => 'CONFIDENTIEL';
  @override
  String get dossierName => 'NOM';
  @override
  String steamPersona(String persona) => 'Sur Steam : $persona';
  @override
  String get pictureLabel => 'Photo de profil';
  @override
  String get pictureGame => 'Avatar du jeu';
  @override
  String get pictureSteam => 'Photo Steam';
  @override
  String handleFromSteam(String persona) =>
      'Tiré de ton nom Steam, « $persona ». Ça te va ? Enregistre, ou change-le.';
  @override
  String get handleSuggestions => 'Libres, tout près :';
  @override
  String get dossierRank => 'RANG';
  @override
  String get dossierExperience => 'EXPÉRIENCE';
  @override
  String get resultsTitle => 'LE BILAN';
  @override
  String get resultsWon => 'Victoire';
  @override
  String get resultsLost => 'Défaite';
  @override
  String get resultsLeft => 'Tu as quitté la ville';
  @override
  String resultsXp(int xp) => '+$xp XP';
  @override
  String resultsLevelUp(int level) => 'Niveau $level !';
  @override
  String resultsCoins(int coins) => '+$coins ${coins <= 1 ? 'pièce' : 'pièces'}';
  @override
  String get resultsRatingUp => 'Ton rang monte';
  @override
  String get resultsRatingDown => 'Ton rang baisse';
  @override
  String get resultsContinue => 'Continuer';

  @override
  String get posterTitle => 'JOUER ENTRE\nAMIS';
  @override
  String get posterBlurb => 'Une salle en ligne : un code ou un QR, chacun sur son téléphone.';
  @override
  String get posterStrip => 'EN LIGNE';

  @override
  String get unavailableTitle => 'INDISPONIBLE';
  @override
  String get unavailableBody =>
      'Le jeu en ligne n’est pas disponible dans cette version. Un téléphone pour tous marche comme toujours.';

  @override
  String get loginTitle => 'QUI ES-TU ?';
  @override
  String get loginBody =>
      'Le jeu en ligne demande un compte : ton profil et tes amis te suivent sur tous les téléphones.';
  @override
  String get loginApple => 'Se connecter avec Apple';
  @override
  String get loginGoogle => 'Se connecter avec Google';
  @override
  String get loginNoProvider => 'Pas encore moyen de se connecter sur ce téléphone.';
  @override
  String get loginPrivacy =>
      'Le compte sert seulement à ton profil de jeu. Un téléphone pour tous n’en demande aucun.';

  @override
  String get signIn => 'CONNEXION';
  @override
  String get coachSignIn => 'Connecte-toi pour jouer en ligne';
  @override
  String roomLinkSignIn(String code) => 'Connecte-toi pour rejoindre la salle $code.';
  @override
  String get roomLinkInvalid => 'Ce lien ne mène à aucune salle.';
  @override
  String get technicalReason => 'Raison technique';
  @override
  String get pickHandle => 'Choisis ton pseudo';
  @override
  String levelShort(int level) => 'NIV. $level';
  @override
  String get level => 'NIVEAU';
  @override
  String get coins => 'PIÈCES';
  @override
  String xpProgress(int xp, int next) => '$xp sur $next points d’expérience';

  @override
  String get testAccount => 'Compte de test';
  @override
  String get testAccountBody =>
      'Seulement pour essayer l’appli depuis un autre téléphone : connecte-toi avec e-mail et mot de passe, ou crée le compte s’il n’existe pas.';
  @override
  String get emailLabel => 'Adresse e-mail';
  @override
  String get passwordLabel => 'Mot de passe (6 caractères minimum)';
  @override
  String get testAccountSubmit => 'SE CONNECTER OU CRÉER';

  @override
  String get setupTitle => 'TON PROFIL';
  @override
  String get setupBody =>
      'Ton pseudo est aussi le nom que tout le monde voit : dans la salle, à table et entre amis.';
  @override
  String get handleLabel => 'Pseudo';
  @override
  String get handleHint => 'comme jean.dupont';
  @override
  String get save => 'ENREGISTRER';
  @override
  String get handleInvalid => 'De 3 à 12 caractères : minuscules, chiffres, point et tiret bas.';
  @override
  String get handleChecking => 'On vérifie s’il est libre…';
  @override
  String get handleFree => 'Libre : il est à toi si tu le veux.';
  @override
  String handleProblem(HandleProblem problem) => switch (problem) {
        HandleProblem.tooShort => 'Au moins 3 caractères.',
        HandleProblem.tooLong => '12 caractères maximum.',
        HandleProblem.characters => 'Seulement des minuscules, des chiffres, le point et le tiret bas.',
        HandleProblem.start => 'Il ne peut pas commencer par un point ou un tiret bas.',
        HandleProblem.endsWithDot => 'Il ne peut pas finir par un point.',
        HandleProblem.doubleDot => 'Pas deux points d’affilée.',
        HandleProblem.tooManySymbols => 'Trois symboles d’affilée, pas plus.',
        HandleProblem.botName => 'Les noms qui commencent par « bot » sont réservés aux bots.',
        HandleProblem.notAllowed => 'Nom interdit.',
      };

  @override
  String get hubTitle => 'JOUER ENTRE AMIS';
  @override
  String signedInAs(String name) => 'Connexion : $name';
  @override
  String get hubCreate => 'OUVRIR UNE SALLE';
  @override
  String get hubJoin => 'REJOINDRE AVEC UN CODE';
  @override
  String get friends => 'AMIS';
  @override
  String get signOut => 'Se déconnecter';

  @override
  String get joinTitle => 'REJOINDRE UNE SALLE';
  @override
  String get codeLabel => 'Code de la salle';
  @override
  String get joinSubmit => 'ENTRER';
  @override
  String get scan => 'Scanner le QR';
  @override
  String get codeInvalid => 'Le code fait six caractères, sans 0, O, 1, I ni L.';
  @override
  String get scanTitle => 'SCANNE LE QR';
  @override
  String get scanHint => 'Vise le QR sur le téléphone de l’hôte.';
  @override
  String get scanDenied => 'Sans l’appareil photo, impossible de lire le QR : tape plutôt le code.';

  @override
  String get roomTitle => 'LA SALLE';
  @override
  String get roomShareHint => 'Fais-leur scanner le QR, ou lis-leur le code.';
  @override
  String roomSeated(int seated, int max) => '$seated sur $max à table';
  @override
  String get hostBadge => 'HÔTE';
  @override
  String get addFriend => 'Ajouter en ami';
  @override
  String friendRequestSent(String name) => 'Demande d’ami envoyée à $name.';
  @override
  String nowFriends(String name) => 'Toi et $name, vous êtes amis maintenant.';
  @override
  String get leaveRoom => 'QUITTER LA SALLE';
  @override
  String get leaveConfirmTitle => 'Quitter la salle ?';
  @override
  String get leaveConfirmBody => 'Ta place à table se libère.';
  @override
  String get leaveConfirm => 'PARTIR';
  @override
  String get stay => 'RESTER';
  @override
  String get chooseHostTitle => 'Qui reprend la salle ?';
  @override
  String get chooseHostBody => 'C’est toi l’hôte : choisis qui prend ta place, puis pars.';
  @override
  String get botBadge => 'BOT DE TEST';
  @override
  String get testBotsNote => 'Test : des bots prennent les places vides.';
  @override
  String get startGame => 'LANCER LA PARTIE';
  @override
  String startNeeds(int players) => 'Au moins $players personnes à table : fais entrer du monde.';
  @override
  String get waitingForHost => 'On attend que l’hôte distribue les cartes.';
  @override
  String get rejoin => 'RETOUR À LA TABLE';
  @override
  String get gameRunning => 'La partie est lancée.';
  @override
  String get reconnecting => 'Retour à la table…';

  @override
  String get gameConnecting => 'On prend place…';
  @override
  String get yourCard => 'TA CARTE';
  @override
  String get yourCardHint => 'Garde-la pour toi : les autres ne voient que la leur.';
  @override
  String waitingForOthers(int pending) =>
      pending == 1 ? 'On attend le dernier choix.' : 'On attend les autres : encore $pending choix.';
  @override
  String get youAreOut => 'Tu es hors jeu. Regarde comment ça finit, et tais-toi.';
  @override
  String get voteTitle => 'LA VILLE VOTE';
  @override
  String get voteHint => 'Touche qui tu veux condamner. Tu peux changer d’avis tant que le vote est ouvert.';
  @override
  String get abstain => 'JE M’ABSTIENS';
  @override
  String votedFor(String name) => 'Tu as voté pour $name';
  @override
  String get abstained => 'Abstention enregistrée';
  @override
  String votesCast(int votes, int alive) => '$votes ${votes <= 1 ? 'vote' : 'votes'} sur $alive';
  @override
  String closesIn(String time) => 'Le vote ferme dans $time';
  @override
  String get rejected => 'Ce coup n’est pas permis : réessaie.';
  @override
  String get serverSilent => 'Le serveur ne répond pas : vérifie ta connexion.';
  @override
  String get backToRoom => 'RETOUR À LA SALLE';
  @override
  String timeLeft(String time) => 'Encore $time';
  @override
  String get startingSoon => 'On commence ensemble…';
  @override
  String get ready => 'PRÊT';
  @override
  String get readyWaiting => 'On attend les autres…';
  @override
  String get moveRegistered => 'C’est fait. La ville dort…';
  @override
  String get voteRegistered => 'enregistré ✓';
  @override
  String get sending => 'Envoi…';
  @override
  String get offlineBadge => 'hors ligne';
  @override
  String get leaveAbandonWarning =>
      'Partir maintenant compte comme un abandon : ni points ni pièces, même si ton camp gagne ensuite.';
  @override
  String get leaveDeadWarning =>
      'Tu peux partir sans pénalité, mais si ton camp gagne ensuite, tu n’auras aucune récompense.';
  @override
  String get resultsAfk => 'Absence : aucune récompense';
  @override
  String get gameClosed => 'La partie a été fermée : plus personne ne jouait.';
  @override
  String get fateLeft => 'A quitté la ville';
  @override
  String get youLeftTown => 'Trop longtemps loin de la table, tu as quitté la ville. Regarde comment ça finit.';
  @override
  String get youLookOffline => 'Le serveur ne t’entend pas : les autres te voient hors ligne.';
  @override
  String get connectionLost => 'Connexion perdue.';
  @override
  String get abstainTag => 's’abstient';
  @override
  String votesFor(int votes) => votes <= 1 ? '$votes vote' : '$votes votes';
  @override
  String get nightTitleOnline => 'LA NUIT';
  @override
  String get discussionTitle => 'LA VILLE DISCUTE';
  @override
  String get discussionHint => 'Dis ce que tu as à dire dans le chat. Ensuite, on vote.';
  @override
  String get accusedTag => 'ACCUSÉ';
  @override
  String get verdictWaiting => 'La ville a décidé.';
  @override
  String get chatHint => 'Écris…';
  @override
  String get chatLobby => 'SALLE';
  @override
  String get chatTown => 'VILLE';
  @override
  String get chatFamily => 'FAMILLE';
  @override
  String get chatEmpty => 'Pas encore de messages.';
  @override
  String get chatNightClosed => 'La nuit, la ville se tait.';
  @override
  String get chatDead => 'De l’au-delà, tu peux seulement lire.';
  @override
  String get chatSilenced =>
      'Le Tailleur t’a cousu les lèvres : aujourd’hui tu lis et tu votes, mais tu n’écris pas.';
  @override
  String get chatSend => 'Envoyer';

  @override
  String get searchHint => 'Chercher par pseudo';
  @override
  String get requests => 'DEMANDES';
  @override
  String get yourFriends => 'TES AMIS';
  @override
  String get waiting => 'EN ATTENTE';
  @override
  String get friendsEmpty => 'Pas encore d’amis. Cherche par pseudo, ou ajoute-les depuis une salle.';
  @override
  String get noResults => 'Personne avec ce pseudo.';
  @override
  String get accept => 'Accepter';
  @override
  String get decline => 'Refuser';
  @override
  String get add => 'Ajouter';
  @override
  String get remove => 'Retirer';
  @override
  String get withdraw => 'Retirer la demande';

  @override
  String get deviceOneAtATime => 'Tu peux jouer sur un seul appareil à la fois';
  @override
  String deviceContested(String other) => 'Ton compte est aussi ouvert sur : $other. Où veux-tu jouer ?';
  @override
  String get deviceDisplacedTitle => 'Ta session est ouverte sur un autre appareil';
  @override
  String deviceDisplaced(String other) => 'Tu joues maintenant sur : $other. Reprends la main ici si tu veux.';
  @override
  String get devicePlayHere => 'JOUER ICI';

  @override
  String get updateTitle => 'Mise à jour nécessaire';
  @override
  String updateNewRelease(String latest, String current) =>
      'La version $latest est sortie, celle-ci est la $current. Mets à jour pour continuer à jouer.';
  @override
  String get updateServer => 'Cette version n’est plus admise à table. Mets à jour pour continuer à jouer.';
  @override
  String get updateButton => 'METTRE À JOUR';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Connecte-toi d’abord avec un compte.',
        OnlineFailure.appleDisabled => 'La connexion avec Apple n’est pas activée sur le serveur.',
        OnlineFailure.googleDisabled => 'La connexion avec Google n’est pas activée sur le serveur.',
        OnlineFailure.emailDisabled => 'La connexion par e-mail n’est pas activée sur le serveur.',
        OnlineFailure.wrongPassword => 'Mauvais mot de passe pour cet e-mail.',
        OnlineFailure.weakPassword => 'Mot de passe trop faible : 6 caractères minimum.',
        OnlineFailure.invalidEmail => 'Cet e-mail n’a pas l’air valide.',
        OnlineFailure.emailNotConfirmed => 'Le serveur veut un e-mail confirmé : désactive ça pour les tests.',
        OnlineFailure.profileIncomplete => 'Termine d’abord ton profil.',
        OnlineFailure.handleTaken => 'Ce pseudo est déjà pris.',
        OnlineFailure.invalidHandle => 'Nom invalide.',
        OnlineFailure.handleNotAllowed => 'Nom interdit.',
        OnlineFailure.roomNotFound => 'Aucune salle avec ce code.',
        OnlineFailure.roomClosed => 'Cette salle est déjà en partie.',
        OnlineFailure.roomFull => 'La salle est pleine.',
        OnlineFailure.hostMustChoose => 'Choisis d’abord qui reprend la salle.',
        OnlineFailure.playerNotFound => 'Joueur introuvable.',
        OnlineFailure.notAllowed => 'Pas permis.',
        OnlineFailure.requestNotFound => 'Cette demande n’existe plus.',
        OnlineFailure.messageBlocked => 'Ce message ne peut pas être envoyé.',
        OnlineFailure.tooManyMessages => 'Doucement : trop de messages d’affilée.',
        OnlineFailure.tooManyReports => 'Tu as déjà envoyé beaucoup de signalements. Réessaie plus tard.',
        OnlineFailure.chatClosed => 'Tu ne peux pas écrire ici pour l’instant.',
        OnlineFailure.reactionClosed => 'Pas de gestes maintenant : seulement le jour, et seulement entre vivants.',
        OnlineFailure.reactionCooldown => 'Doucement avec les gestes : attends quelques secondes.',
        OnlineFailure.reactionCap => 'Assez de gestes pour cette partie.',
        OnlineFailure.notEnoughCoins => 'Tu n’as pas assez de pièces.',
        OnlineFailure.alreadyOwned => 'C’est déjà à toi.',
        OnlineFailure.notOwned => 'Achète-le d’abord.',
        OnlineFailure.itemNotFound => 'Cet article n’est plus en boutique.',
        OnlineFailure.cancelled => 'Connexion annulée.',
        OnlineFailure.rankedCooldown => 'Trop de parties abandonnées : attends un peu avant de reprendre la file.',
        OnlineFailure.alreadyInGame => 'Tu es déjà dans une partie.',
        OnlineFailure.tutorialsRequired => 'Termine les trois mains d’essai pour jouer en classé.',
        OnlineFailure.otherDevice => 'Ta session est ouverte sur un autre appareil.',
        OnlineFailure.updateRequired => 'Mise à jour nécessaire : télécharge la nouvelle version.',
        OnlineFailure.linkSameAccount => 'Ce compte est déjà lié.',
        OnlineFailure.linkConflict =>
          'Impossible de fusionner ces deux comptes : ils utilisent déjà le même type de connexion.',
        OnlineFailure.network => 'Pas de connexion. Réessaie dans un instant.',
        OnlineFailure.unknown => 'Quelque chose a raté. Réessaie.',
      };
}

final class FrenchShopStrings extends EnglishShopStrings {
  const FrenchShopStrings();

  @override
  String get title => 'CHEZ LE TAILLEUR';
  @override
  String get subtitle => 'Tailleur et chapelier · depuis 1946';
  @override
  String get greeting => 'Vas-y, essaie. Le miroir ne ment jamais.';
  @override
  String get coinsHint => 'Les pièces viennent avec chaque niveau, et les niveaux avec les victoires.';
  @override
  String get featured => 'EN VITRINE';
  @override
  String endsIn(int days) => days <= 1 ? 'Dernier jour' : 'Encore $days jours';
  @override
  String get counterTab => 'COMPTOIR';
  @override
  String get wardrobeTab => 'GARDE-ROBE';
  @override
  String slot(String slot) => switch (slot) {
    'hat' => 'Chapeaux',
    'face' => 'Moustaches',
    'glasses' => 'Lunettes',
    'outfit' => 'Costumes',
    'hairdo' => 'Coiffures',
    'tattoo' => 'Tatouages',
    'border' => 'Cadres',
    'nameStyle' => 'Noms',
    'gesture' => 'Gestes',
    _ => 'Accessoires',
  };
  @override
  String rarity(ShopRarity rarity) => switch (rarity) {
    ShopRarity.base => 'Maison',
    ShopRarity.comune => 'Commun',
    ShopRarity.raro => 'Rare',
    ShopRarity.epico => 'Épique',
    ShopRarity.leggendario => 'Légendaire',
  };
  @override
  String get owned => 'À TOI';
  @override
  String get worn => 'PORTÉ';
  @override
  String get free => 'GRATUIT';
  @override
  String get buy => 'ACHETER';
  @override
  String get wear => 'PORTER';
  @override
  String get takeOff => 'ENLEVER';
  @override
  String get tryingOn => 'Essayage';
  @override
  String confirmTitle(String item) => 'Acheter « $item » ?';
  @override
  String confirmBody(int price, int left) => 'Ça coûte $price pièces. Il t’en restera $left.';
  @override
  String get confirmYes => 'Marché conclu';
  @override
  String get notNow => 'Pas maintenant';
  @override
  String bought(String item) => '« $item » est à toi.';
  @override
  String missing(int coins) => 'Il te manque $coins ${coins <= 1 ? 'pièce' : 'pièces'}.';
  @override
  String get emptyWardrobe => 'Ici ne pend que ce que tu possèdes déjà.';
  @override
  String get unavailable => 'La boutique est fermée : connecte-toi avec ton compte.';
  @override
  String get brands => 'Griffes';
  @override
  String get allBrands => 'Toutes';
  @override
  String get oddities => 'Curiosités';
  @override
  String get calcioHint => 'Les vieilles tribunes : choisis ton équipe.';
  @override
  String brandTagline(ShopBrand brand) => switch (brand) {
    ShopBrand.vaugirard => 'Malles et bagages · Paris',
    ShopBrand.arminio => 'Tailleur souple · Milan',
    ShopBrand.cuccioli => 'Maroquinerie · Florence',
    ShopBrand.versalli => 'Or et baroque · Reggio',
    ShopBrand.chanterelle => 'Haute couture · Paris',
    ShopBrand.nikea => 'Course et athlétisme',
    ShopBrand.adelphi => 'L’athlétisme de deux frères',
  };
  @override
  String dept(ShopDept dept) => switch (dept) {
    ShopDept.window => 'Vitrine',
    ShopDept.hats => 'Chapeaux',
    ShopDept.face => 'Visage',
    ShopDept.outfit => 'Costumes',
    ShopDept.vice => 'Vices',
    ShopDept.scene => 'Décor',
    ShopDept.back => 'Épaules',
    ShopDept.hands => 'Mains',
    ShopDept.frames => 'Cadres',
    ShopDept.gestures => 'Gestes',
  };
  @override
  String ownership(ShopOwnership ownership) => switch (ownership) {
    ShopOwnership.all => 'Tout',
    ShopOwnership.mine => 'À moi',
    ShopOwnership.toBuy => 'À acheter',
  };
  @override
  String get filters => 'Filtres';
  @override
  String get rarityFilter => 'Classe';
  @override
  String get collectionFilter => 'Collection';
  @override
  String get clearFilters => 'Effacer';
  @override
  String get search => 'Chercher une pièce';
  @override
  String count(int shown, int total) => shown == total ? pieces(total) : '$shown sur $total';
  @override
  String timeLeft(Duration left) => left.inDays >= 1
      ? '${left.inDays} j ${left.inHours % 24} h'
      : left.inHours >= 1
      ? '${left.inHours} h'
      : '${max(1, left.inMinutes)} min';

  @override
  String get homeSign => 'TAILLEUR';
  @override
  String get fresh => 'NOUVEAU';
  @override
  String get allRarities => 'Toutes';
  @override
  String get allSlots => 'Tout';
  @override
  String get affordable => 'Dans mes moyens';
  @override
  String get cheapFirst => 'Prix ↑';
  @override
  String get dearFirst => 'Prix ↓';
  @override
  String pieces(int count) => count <= 1 ? '$count pièce' : '$count pièces';
  @override
  String get emptyShelf => 'Rien sur cette étagère.';
  @override
  String get changeFace => 'Changer de tête';
  @override
  String get viewBust => 'Personnage';
  @override
  String get viewCard => 'Carton de table';
  @override
  String hand(Hand hand) => hand == Hand.left ? 'Gauche' : 'Droite';
  @override
  String get changeFaceHint => 'Visage, peau, moustache : va voir le barbier.';
  @override
  String get back => 'Retour';
  @override
  String save(int pct) => '−$pct %';
  @override
  String get bundlesHeading => 'TENUES COMPLÈTES';
  @override
  String get bundlesHint => 'Ensemble, ça coûte moins cher que pièce par pièce.';
  @override
  String get premiumHeading => 'GRAND LUXE';
  @override
  String get premium => 'GRAND LUXE';
  @override
  String get complete => 'COMPLET';
  @override
  String get buyBundle => 'TOUT ACHETER';
  @override
  String get bundleContents => 'DANS LE LOT';
  @override
  String get singlesLabel => 'À l’unité';
  @override
  String ownedPart(int owned, int total) => 'Tu en as $owned sur $total : tu ne paies que le reste.';
  @override
  String bundleConfirmTitle(String bundle) => 'Acheter « $bundle » ?';
  @override
  String bundleConfirmBody(int price, int saved, int left) =>
      'Ça coûte $price pièces, $saved de moins qu’à l’unité. Il t’en restera $left.';
  @override
  String bundleBought(String bundle) => '« $bundle » est tout à toi.';
  @override
  String get seeAll => 'Tous les lots';
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const frenchMessages = <String, String>{
  // ---- settings
  'settings.audio': 'AUDIO',
  'settings.languageSection': 'LANGUE',
  'settings.game': 'JEU',
  'settings.account': 'COMPTE',
  'settings.privacy': 'CONFIDENTIALITÉ ET DONNÉES',
  'settings.about': 'À PROPOS',
  'settings.signedInAs': 'Connexion : @{handle}',
  'settings.signedInNoHandle': 'Connexion ouverte, pas encore de pseudo',
  'settings.notSignedIn': 'Pas de connexion en ligne.',
  'settings.privacyPolicy': 'Politique de confidentialité',
  'settings.terms': 'Conditions d’utilisation',
  'settings.openOnWeb': 'Ouvrir sur le web',
  'settings.exportData': 'Télécharger mes données',
  'settings.exportHint': 'Tout ce que le serveur garde sur toi, dans un fichier JSON.',
  'settings.exportFailed': 'Impossible de télécharger tes données. Réessaie.',
  'settings.deleteAccount': 'Supprimer le compte',
  'settings.deleteHint': 'Pour toujours : profil, amis, garde-robe et pièces.',
  'settings.deleteTitle': 'Supprimer ton compte ?',
  'settings.deleteBody': 'Profil, look, amis, garde-robe, pièces, missions, salles et messages : tout part, pour de bon.',
  'settings.deleteContinue': 'Continuer',
  'settings.cancel': 'Annuler',
  'settings.deleteTypePrompt': 'Dernier mot : tape « {word} » pour confirmer.',
  'settings.deleteConfirmWord': 'SUPPRIMER',
  'settings.deleteForever': 'Supprimer pour toujours',
  'settings.deleteDone': 'Compte supprimé. Adieu, et merci.',
  'settings.deleteFailed': 'Impossible de supprimer le compte. Réessaie.',
  'settings.version': 'Version',
  'settings.credits': 'Crédits',
  'settings.creditsBody': 'Sons et graphismes de Kenney (kenney.nl) et Freesound (freesound.org), sous licence CC0. Merci !',
  'settings.yourLook': 'TON LOOK',
  'settings.barberSign': 'BARBIER',
  'settings.changeLook': 'Changer de look',
  // ---- desktop
  'desktop.loginSteam': 'Se connecter avec Steam',
  'desktop.steamWaiting': 'Termine la connexion dans ton navigateur, puis reviens.',
  'desktop.screen': 'AFFICHAGE',
  'desktop.windowMode': 'Fenêtre',
  'desktop.windowed': 'Fenêtré',
  'desktop.fullscreen': 'Plein écran',
  'desktop.borderless': 'Sans bordure',
  'desktop.resolution': 'Résolution',
  'desktop.resolutionHint': 'Les écrans plus larges jouent en 16:9, avec des bandes sur les côtés.',
  'desktop.orientation': 'Orientation',
  'desktop.landscape': 'Paysage',
  'desktop.portrait': 'Portrait',
  'desktop.linkAccount': 'Lier un compte',
  'desktop.linkHint': 'Joue avec le même profil sur ton téléphone et sur PC.',
  'desktop.linkBody': 'Connecte-toi avec ton autre compte : les deux profils n’en font plus qu’un.',
  'desktop.linkWith': 'Lier {provider}',
  'desktop.linkRule': 'Le profil le plus ancien l’emporte : il garde son nom, ses pièces, son expérience, sa garde-robe et son classement. L’autre ferme pour de bon.',
  'desktop.linkWaiting': 'Termine la connexion dans ton navigateur, puis reviens.',
  'desktop.linkDone': 'Comptes liés.',
  'desktop.linkSwitched': 'Comptes liés : tu es maintenant sur le profil le plus ancien.',
  'desktop.linkAlready': 'Ce compte est déjà lié.',
  'desktop.close': 'Fermer',
  'desktop.quit': 'Quitter',
  'desktop.quitTitle': 'Tu quittes l’impasse ?',
  'desktop.quitBody': 'Le jeu va se fermer. Personne n’a rien vu.',
  'desktop.quitConfirm': 'Quitter le jeu',
  'desktop.stay': 'Rester',
  'desktop.enterHint': 'ENTRÉE pour confirmer',
  'desktop.posterEnter': 'Entrer',
  // ---- desktopOnline
  'desktopOnline.hubCreateBody': 'Ouvre ta propre table et fais asseoir tes amis avec le code.',
  'desktopOnline.hubJoinBody': 'On t’a filé un code ? Tape-le et tu es dedans.',
  'desktopOnline.hubFriendsBody': 'Cherche par pseudo, réponds aux demandes d’ami.',
  'desktopOnline.hubDoors': 'Où aller',
  'desktopOnline.profile': 'Ton profil',
  'desktopOnline.joinHint': 'Tape le code et appuie sur ENTRÉE.',
  'desktopOnline.invite': 'Inviter à la table',
  'desktopOnline.table': 'À table',
  'desktopOnline.search': 'Chercher',
  'desktopOnline.results': 'Trouvés',
  'desktopOnline.searchEmpty': 'Tape un pseudo pour trouver quelqu’un.',
  'desktopOnline.rankedHow': 'Comment ça marche',
  'desktopOnline.freeSeat': 'Place libre',
  // ---- desktopGame
  'desktopGame.menu': 'Menu',
  'desktopGame.menuTitle': 'La table n’attend pas',
  'desktopGame.menuBody': 'La partie continue tant que ce menu est ouvert : l’horloge tourne pour tout le monde.',
  'desktopGame.resume': 'Retour à la table',
  'desktopGame.roles': 'Rôles en jeu',
  'desktopGame.settings': 'Réglages',
  'desktopGame.leave': 'Quitter la partie',
  'desktopGame.stay': 'Rester à table',
  'desktopGame.leaveConfirm': 'Quitter',
  'desktopGame.keyEnter': 'Entrée',
  'desktopGame.chatKeys': 'ENTRÉE pour le chat',
  'desktopGame.rightClick': 'Clic droit sur un joueur : signaler ou bloquer',
  'desktopGame.timeLeft': 'Temps',
  'desktopGame.table': 'La table',
  'desktopGame.you': 'Toi',
  // ---- gameEvent
  'gameEvent.onlyYou': 'RIEN QUE TOI',
  'gameEvent._team.mafia': 'de la Famille',
  'gameEvent._team.neutral': 'en solo',
  'gameEvent._team': 'réglo',
  'gameEvent._winner.citizens': 'la ville gagne',
  'gameEvent._winner.mafia': 'la Famille gagne',
  'gameEvent._winner.neutral': 'un solitaire gagne',
  'gameEvent._winner': 'pas de vainqueur',
  'gameEvent.text.night': 'La nuit {round} tombe. La ville dort.',
  'gameEvent.text.dawn': 'Le jour {round} se lève.',
  'gameEvent.text.dawn.nobodyDiedTonight': 'Personne n’est mort cette nuit.',
  'gameEvent.text.dawn.foundDead': 'Victimes de la nuit : {names}.',
  'gameEvent.text.dawn.theEscortFended': 'L’escorte a repoussé un attentat contre le Président.',
  'gameEvent.text.dawn.someoneWasSaved': 'Quelqu’un a été sauvé.',
  'gameEvent.text.dawn.attacksFoiled': 'Attaques déjouées : {saved}.',
  'gameEvent.text.dawn.diedOfA': 'Le cœur de {broken} s’est brisé.',
  'gameEvent.text.scoop': 'Le scoop du journal : {name} est {role}.',
  'gameEvent.text.scoop.thePaperS': 'Le scoop du journal : {name} est {team}.',
  'gameEvent.text.silenced': 'Le Tailleur a cousu la bouche de {name} : silence aujourd’hui.',
  'gameEvent.text.lynch': 'abstentions {abstained}',
  'gameEvent.text.lynch.theSquareCondemns': 'La place ne condamne personne.',
  'gameEvent.text.lynch.theSquareCondemns.2': 'La place condamne {name} : c’était {role}.',
  'gameEvent.text.lynch.collectsTheBounty': ' {bountyHunter} empoche la prime.',
  'gameEvent.text.lynch.diedOfA': ' Le cœur de {heartbroken} s’est brisé.',
  'gameEvent.text.mayor': '{name} se révèle Maire : son vote compte double.',
  'gameEvent.text.truce': '{name}, le Pacifiste, impose une trêve : {target} est {role}. Pas de vote aujourd’hui.',
  'gameEvent.text.cannon': ' Le cœur de {heartbroken} s’est brisé.',
  'gameEvent.text.cannon.aRoarIn': 'Un grondement sur la place : {name}, l’Artilleur, a touché {target}, qui était {role}.',
  'gameEvent.text.shot': ' Le cœur de {heartbroken} s’est brisé.',
  'gameEvent.text.shot.aShotFrom': 'Un coup de feu du clocher revient en arrière : {name}, {role}, visait quelqu’un de la ville.',
  'gameEvent.text.shot.aShotFrom.2': 'Un coup de feu du clocher : {name} est à terre. C’était {role}.',
  'gameEvent.text.aim': 'Tu tiens {name} en joue.',
  'gameEvent.text.cell': 'Tu es en cellule. Tu ne sors pas cette nuit.',
  'gameEvent.text.cell.tonightIsIn': 'Cette nuit, {name} est en cellule.',
  'gameEvent.text.converted': 'Tu as vu la lumière : te voilà dans la secte, et tu ne gagnes plus qu’avec elle.',
  'gameEvent.text.door': '{name} est des tiens, maintenant.',
  'gameEvent.text.door.doorShutDid': 'Porte close : {name} n’a pas suivi.',
  'gameEvent.text.busy': 'La nuit dernière, quelqu’un a accaparé ta nuit.',
  'gameEvent.text.left': '{name} a quitté la ville.',
  'gameEvent.text.end': 'Partie fermée : plus personne ne jouait.',
  'gameEvent.text.end.thePresidentHas': ' Le Président est tombé.',
  'gameEvent.text.end.gameOver': 'Partie terminée : {winner}.',
  'gameEvent.text.end.wonAlone': ' Victoire en solo : {alone}.',
  'gameEvent.text.found': '{name} était {role}.',
  'gameEvent.text.found.comesUp': '{name} ressort {team}.',
  'gameEvent.text.watch': 'Quelqu’un est venu à la porte de {name}.',
  'gameEvent.text.watch.nobodyCameTo': 'Personne n’est venu à la porte de {name}.',
  'gameEvent.text.bounty': 'Ta prime : fais lyncher {name}.',
  'gameEvent.text.doused': 'Odeur d’essence sur : {names}.',
  'gameEvent.text.familyTarget': 'La Famille n’a pas réussi à se mettre d’accord.',
  'gameEvent.text.familyTarget.theFamilyChose': 'La Famille a choisi {name}.',
  'gameEvent.text.guard': 'Cette nuit, tu as monté la garde pour {name}.',
  'gameEvent.text.lend': 'Cette nuit, tu as prêté de l’argent à {name}.',
  'gameEvent.text.protected': 'Cette nuit, tu as veillé sur {name}.',
  'gameEvent.text.dawn.foundOne': '{gender, select, masculine{Retrouvé mort : {name}.} feminine{Retrouvée morte : {name}.} other{Victime de la nuit : {name}.}}',
  'gameEvent.text.dawn.backAmongLiving': '{gender, select, masculine{{name} est revenu parmi les vivants.} feminine{{name} est revenue parmi les vivants.} other{{name} revient parmi les vivants.}}',
  'gameEvent.text.lovers.bound': 'Tu as lié {first} et {second}.',
  'gameEvent.text.lovers.self': 'Le cœur a choisi : {first} et {second} s’aiment. Vous ne gagnez que si aucun de vous deux ne meurt.',
  // ---- progress
  'progress.missions': 'Missions',
  'progress.achievements': 'Succès',
  'progress.leaderboard': 'Classement',
  'progress.daily': 'DU JOUR',
  'progress.weekly': 'DE LA SEMAINE',
  'progress.goals': 'OBJECTIFS',
  'progress.tabDaily': 'AUJOURD’HUI',
  'progress.tabWeekly': 'SEMAINE',
  'progress.tabGoals': 'OBJECTIFS',
  'progress.missionsHint': 'Elles se remplissent en jouant, puis tu les encaisses. Les pièces ne se gagnent qu’ainsi : rien ne s’achète avec de l’argent réel. Les parties abandonnées ou passées à ne rien faire ne comptent jamais.',
  'progress.goalsHint': 'Les objectifs restent là jusqu’à ce que tu les atteignes. Certains offrent des articles que la boutique ne vend pas.',
  'progress.claim': 'ENCAISSER',
  'progress.claimed': 'ENCAISSÉ',
  'progress.late': 'D’HIER',
  'progress.reputation': 'RESPECT',
  'progress.reputationGain': '+{n} de respect',
  'progress.claimDone': 'Encaissé : {coins} pièces, +{reputation} de respect',
  'progress.itemWon': 'Offert : {name}',
  'progress.reward': 'Récompense : {name}',
  'progress.unlocksWith': 'Se débloque avec : {mission}',
  'progress.missionOnly': 'Seulement par les missions',
  'progress.done': 'FAIT',
  'progress.endsIn': 'finit dans {inDays} jours',
  'progress.endsIn.endsInH': 'finit dans {h} h',
  'progress.endsIn.endsInMin': 'finit dans {d} min',
  'progress.loadFailed': 'Chargement impossible. Réessaie.',
  'progress.retry': 'Réessayer',
  'progress.unlockedCount': '{n} sur {of}',
  'progress.locked': 'Verrouillé',
  'progress.rewardTitle': 'Titre : « {title} »',
  'progress.rewardFrame': 'Cadre offert',
  'progress.title': 'TITRE',
  'progress.leaderboardEmpty': 'Personne au tableau pour l’instant.',
  'progress.leaderboardHint': 'Les cent meilleurs en classé, par langue.',
  'progress.yourPlace': 'Tu es n°{rank}',
  'progress.notRanked': 'Joue une partie classée pour entrer au tableau.',
  'progress.missionDone': 'Mission accomplie : {name}. Encaisse-la !',
  'progress.achievementDone': 'Succès : {name}',
  'progress.mission.daily_play_3': 'Joue 3 parties',
  'progress.mission.daily_win_1': 'Gagne une partie',
  'progress.mission.daily_friends_win_2': 'Gagne 2 parties entre amis',
  'progress.mission.daily_lynch_hits_3': 'Vote 3 fois pour le bon mafieux',
  'progress.mission.daily_nights_2': 'Survis à 2 nuits',
  'progress.mission.daily_ranked_1': 'Joue 1 partie classée',
  'progress.mission.daily_survive_1': 'Sois en vie à la fin d’une partie',
  'progress.mission.daily_town_win_1': 'Gagne avec la ville',
  'progress.mission.daily_mafia_win_1': 'Gagne avec la Famille',
  'progress.mission.weekly_neutral_win_1': 'Gagne en neutre',
  'progress.mission.weekly_wins_7': 'Gagne 7 parties',
  'progress.mission.weekly_play_15': 'Joue 15 parties',
  'progress.mission.weekly_lynch_hits_10': 'Vote 10 fois pour le bon mafieux',
  'progress.mission.weekly_ranked_5': 'Joue 5 parties classées',
  'progress.mission.weekly_ranked_wins_3': 'Gagne 3 parties classées',
  'progress.mission.weekly_saves_2': 'Sauve 2 vies en Docteur',
  'progress.mission.weekly_finds_3': 'Démasque 3 mafieux en Commissaire',
  'progress.mission.weekly_kills_5': 'Réussis 5 contrats avec la Famille',
  'progress.mission.weekly_nights_12': 'Survis à 12 nuits',
  'progress.mission.daily_friends_play_2': 'Joue 2 parties entre amis',
  'progress.mission.daily_win_alive_1': 'Gagne et sois en vie à la fin',
  'progress.mission.daily_survive_2': 'Sois en vie à la fin de 2 parties',
  'progress.mission.weekly_play_10': 'Joue 10 parties',
  'progress.mission.weekly_wins_4': 'Gagne 4 parties',
  'progress.mission.weekly_town_wins_3': 'Gagne 3 fois avec la ville',
  'progress.mission.weekly_mafia_wins_2': 'Gagne 2 fois avec la Famille',
  'progress.mission.weekly_detective_win_1': 'Gagne une partie en Commissaire',
  'progress.mission.weekly_doctor_win_1': 'Gagne une partie en Docteur',
  'progress.mission.long_nights_10': 'Survis à 10 nuits',
  'progress.mission.long_lynch_hits_3': 'Envoie 3 mafieux à l’échafaud',
  'progress.mission.long_detective_wins_5': 'Gagne 5 parties en Commissaire',
  'progress.mission.long_finds_5': 'Démasque 5 mafieux en Commissaire',
  'progress.mission.long_mafia_wins_10': 'Gagne 10 fois avec la Famille',
  'progress.mission.long_town_wins_10': 'Gagne 10 fois avec la ville',
  'progress.mission.long_wins_50': 'Gagne 50 parties',
  'progress.mission.long_games_25': 'Joue 25 parties',
  'progress.mission.long_friends_games_20': 'Joue 20 parties entre amis',
  'progress.mission.long_ranked_games_20': 'Joue 20 parties classées',
  'progress.mission.long_saves_5': 'Sauve 5 vies en Docteur',
  'progress.mission.long_survived_25': 'Sois en vie à la fin de 25 parties',
  'progress.mission.long_neutral_wins_3': 'Gagne 3 fois en neutre',
  'progress.mission': 'Objectif : {target}',
  'progress.achievement.wins_10': 'Veinard',
  'progress.achievement': 'Gagne 10 parties',
  'progress.achievement.wins_50': 'Homme d’honneur',
  'progress.achievement.winGames': 'Gagne 50 parties',
  'progress.achievement.wins_200': 'Légende',
  'progress.achievement.winGames.2': 'Gagne 200 parties',
  'progress.achievement.games_25': 'Habitué',
  'progress.achievement.playGames': 'Joue 25 parties',
  'progress.achievement.games_100': 'Fait partie des meubles',
  'progress.achievement.playGames.2': 'Joue 100 parties',
  'progress.achievement.games_500': 'Vétéran',
  'progress.achievement.playGames.3': 'Joue 500 parties',
  'progress.achievement.ranked_wins_10': 'Sur le tapis vert',
  'progress.achievement.winRankedGames': 'Gagne 10 parties classées',
  'progress.achievement.ranked_wins_50': 'Patron',
  'progress.achievement.winRankedGames.2': 'Gagne 50 parties classées',
  'progress.achievement.friends_wins_25': 'Entre amis',
  'progress.achievement.winGamesWith': 'Gagne 25 parties entre amis',
  'progress.achievement.town_wins_25': 'Citoyen modèle',
  'progress.achievement.winTimesWith': 'Gagne 25 fois avec la ville',
  'progress.achievement.mafia_wins_25': 'Affranchi',
  'progress.achievement.winTimesWith.2': 'Gagne 25 fois avec la Famille',
  'progress.achievement.neutral_wins_1': 'À mon compte',
  'progress.achievement.winAsA': 'Gagne en neutre',
  'progress.achievement.neutral_wins_10': 'Loup solitaire',
  'progress.achievement.winTimesAs': 'Gagne 10 fois en neutre',
  'progress.achievement.roles_won_5': 'Mille visages',
  'progress.achievement.winWithDifferent': 'Gagne avec 5 rôles différents',
  'progress.achievement.roles_won_12': 'Acteur chevronné',
  'progress.achievement.winWithDifferent.2': 'Gagne avec 12 rôles différents',
  'progress.achievement.roles_won_all': 'Caméléon',
  'progress.achievement.winWithEvery': 'Gagne avec chaque rôle',
  'progress.achievement.roles_town_all': 'Toute la ville',
  'progress.achievement.winWithEvery.2': 'Gagne avec chaque rôle de la ville',
  'progress.achievement.roles_mafia_all': 'Toute la Famille',
  'progress.achievement.winWithEvery.3': 'Gagne avec chaque rôle de la Famille',
  'progress.achievement.roles_lone_all': 'Tous les solitaires',
  'progress.achievement.winWithEvery.4': 'Gagne avec chaque rôle solitaire',
  'progress.achievement.winAGame': 'Gagne une partie avec ce rôle',
  'progress.achievement.wins_alive_25': 'Peau dure',
  'progress.achievement.winTimesStill': 'Gagne 25 fois encore en vie',
  'progress.achievement.lynch_hits_10': 'Bon flair',
  'progress.achievement.voteCondemnedMafiosi': 'Vote contre 10 mafieux condamnés',
  'progress.achievement.lynch_hits_50': 'Limier',
  'progress.achievement.voteCondemnedMafiosi.2': 'Vote contre 50 mafieux condamnés',
  'progress.achievement.lynch_hits_200': 'Vengeur',
  'progress.achievement.voteCondemnedMafiosi.3': 'Vote contre 200 mafieux condamnés',
  'progress.achievement.nights_25': 'Insomniaque',
  'progress.achievement.surviveNights': 'Survis à 25 nuits',
  'progress.achievement.nights_100': 'Oiseau de nuit',
  'progress.achievement.surviveNights.2': 'Survis à 100 nuits',
  'progress.achievement.saves_1': 'Premiers secours',
  'progress.achievement.saveALife': 'Sauve une vie en Docteur',
  'progress.achievement.saves_10': 'Ange gardien',
  'progress.achievement.saveLivesAs': 'Sauve 10 vies en Docteur',
  'progress.achievement.countryDoctor': 'Médecin de campagne',
  'progress.achievement.asTheDoctor': 'En Docteur, sauve quelqu’un et tiens jusqu’à la fin',
  'progress.achievement.finds_10': 'Instinct de flic',
  'progress.achievement.unmaskMafiosiAs': 'Démasque 10 mafieux en Commissaire',
  'progress.achievement.theInspector': 'L’Inspecteur',
  'progress.achievement.asTheDetective': 'En Commissaire, envoie le Parrain à la potence',
  'progress.achievement.snipes_1': 'Tir propre',
  'progress.achievement.asTheSniper': 'En Tireur, abats un mafieux',
  'progress.achievement.kills_25': 'Main lourde',
  'progress.achievement.successfulHitsWith': '25 contrats réussis avec la Famille',
  'progress.achievement.framed_5': 'Manipulateur',
  'progress.achievement.asAMafioso': 'En mafieux, fais condamner 5 innocents',
  'progress.achievement.fool_win': 'Rira bien qui rira le dernier',
  'progress.achievement.winAsThe': 'Gagne en Bouffon',
  'progress.titleName.man_of_honor': 'Homme d’honneur',
  'progress.titleName.legend': 'Légende',
  'progress.titleName.veteran': 'Vétéran',
  'progress.titleName.boss': 'Patron',
  'progress.titleName.model_citizen': 'Citoyen modèle',
  'progress.titleName.made_man': 'Affranchi',
  'progress.titleName.lone_wolf': 'Loup solitaire',
  'progress.titleName.chameleon': 'Caméléon',
  'progress.titleName.bloodhound': 'Limier',
  'progress.titleName.night_owl': 'Oiseau de nuit',
  'progress.titleName.guardian_angel': 'Ange gardien',
  'progress.titleName.inspector': 'L’Inspecteur',
  'progress.titleName.schemer': 'Manipulateur',
  'progress.toClaim': '{n} à encaisser',
  // ---- recap
  'recap.open': 'LE RÉCIT COMPLET',
  'recap.masthead': 'Le Récit complet',
  'recap.dateLine': 'Édition spéciale · toutes les cartes sur la table',
  'recap.cast': 'Qui était qui',
  'recap.timeline': 'Nuit après nuit, jour après jour',
  'recap.night': 'Nuit {round}',
  'recap.day': 'Jour {round}',
  'recap.won': 'GAGNÉ',
  'recap.wonAlone': 'GAGNÉ EN SOLO',
  'recap.survived': 'debout',
  'recap.fell': 'à terre',
  'recap.left': 'a filé',
  'recap.close': 'FERMER',
  'recap.you': 'toi',
  'recap.quietNight': 'Une nuit sans un geste.',
  'recap.team.citizens': 'ville',
  'recap.team.mafia': 'Famille',
  'recap.team.neutral': 'en solo',
  'recap.winner.citizens': 'La ville gagne',
  'recap.winner.mafia': 'La Famille gagne',
  'recap.winner.neutral': 'Le Pyromane gagne',
  'recap.winner.null': 'Pas de vainqueur',
  'recap.familyAimed': 'La Famille a visé {target} ({voters}).',
  'recap.familyNobody': 'La Famille n’a pas réussi à se mettre d’accord.',
  'recap.move.silence': 'a cousu la bouche de {target}.',
  'recap.move.protect': 'a veillé sur {target}.',
  'recap.move.guard': 'a monté la garde pour {target}.',
  'recap.move.snipe': 'a tiré sur {target}.',
  'recap.move.scoop': 'a sorti le scoop sur {target}.',
  'recap.move.douse': 'a arrosé {target} d’essence.',
  'recap.move.ignite': 'a craqué l’allumette.',
  'recap.move.resurrect': 'a rappelé {target} à la vie.',
  'recap.move.lend': 'a prêté de l’argent à {target}.',
  'recap.move.stab': 'a planté {target}.',
  'recap.move.jail': 'a bouclé {target}.',
  'recap.move.block': 'a passé la nuit avec {target}.',
  'recap.move.link': 'a lié le cœur de {target}.',
  'recap.move.convert': 'a appelé {target} dans la secte.',
  'recap.move.aim': 'a mis {target} en joue.',
  'recap.attack.family': 'par la Famille',
  'recap.attack.sniper': 'par le Tireur',
  'recap.attack.fire': 'par le feu',
  'recap.attack.assassin': 'par le Tueur à gages',
  'recap.attack.shrugged': '{target} encaisse le coup {by}, et survit.',
  'recap.attack.escorted': 'L’escorte a repoussé l’attentat {by} contre {target}.',
  'recap.scoopOut.mafia': 'Le journal est sorti : {target} est de la Famille.',
  'recap.scoopOut.citizens': 'Le journal est sorti : {target} est réglo.',
  'recap.scoopOut.neutral': 'Le journal est sorti : {target} joue en solo.',
  'recap.mayor': '{name} se révèle Maire : son vote compte double.',
  'recap.votes': 'Le scrutin',
  'recap.abstained': 's’abstient',
  'recap.noCondemned': 'La place ne condamne personne.',
  'recap.foolWins': '{name} ne voulait que ça : victoire en solo.',
  'recap.bounty': '{hunter} empoche la prime.',
  'recap.exit': '{name} a quitté la ville.',
  'recap.leftTown': '{name} a quitté la scène.',
  'recap.wentAway': '{name} a quitté la table un moment.',
  'recap.cameBack': '{name} est de retour à table.',
  'recap.calledOut': '{name} t’interpelle.',
  'recap.move.investigate': 'a enquêté sur {target} : {seen, select, mafia{de la Famille} other{réglo}}.',
  'recap.move.dig': 'a déterré {target} : c’était {role}.',
  'recap.move.watch': 'a surveillé la porte de {target} : {visited, select, yes{quelqu’un est passé} other{personne n’est passé}}.',
  'recap.attack.killed': '{gender, select, masculine{{target} a été tué {by}.} feminine{{target} a été tuée {by}.} other{{target} n’y survit pas : le coup vient {by}.}}',
  'recap.attack.healed': '{gender, select, masculine{{target}, touché {by}, a été sauvé.} feminine{{target}, touchée {by}, a été sauvée.} other{Le coup vient {by}, mais {target} s’en sort.}}',
  'recap.risen': '{gender, select, masculine{{target} est revenu parmi les vivants.} feminine{{target} est revenue parmi les vivants.} other{{target} revient parmi les vivants.}}',
  'recap.condemned': 'La place condamne {name}. C’était {role}.',
  // ---- rolesSheet
  'rolesSheet.button': 'RÔLES',
  'rolesSheet.title': 'Rôles en jeu',
  'rolesSheet.subtitle': 'Les cartes de cette partie. Qui les tient reste un secret.',
  'rolesSheet.deckEmpty': 'Le paquet n’est pas encore connu.',
  'rolesSheet.legendTitle': 'Ce que veulent dire les symboles',
  'rolesSheet.revealedBy': 'révélé : {name}',
  'rolesSheet.silenced': 'bouche cousue',
  'rolesSheet.silencedLegend': 'bouche cousue par le Tailleur : n’écrit pas aujourd’hui, mais vote encore',
  'rolesSheet.offline': 'hors ligne',
  'rolesSheet.offlineLegend': 'point gris : le joueur s’est déconnecté',
  'rolesSheet.dead': 'décès',
  'rolesSheet.deadLegend': 'œillet ou poignard : le joueur est mort',
  'rolesSheet.accused': 'accusé',
  'rolesSheet.accusedLegend': 'ruban ACCUSÉ : le plus visé en ce moment',
  'rolesSheet.votes': 'votes reçus',
  'rolesSheet.votesLegend': 'cercle rouge avec un chiffre : votes reçus',
  'rolesSheet.voteNote': 'a voté pour',
  'rolesSheet.voteNoteLegend': 'note « → nom » : le vote de cette place',
  'rolesSheet.revealedRole': 'rôle révélé',
  'rolesSheet.revealedRoleLegend': 'icône ou nom de rôle sur une place : un rôle que tu connais',
  'rolesSheet.selected': 'choisi',
  'rolesSheet.meLegend': 'plaque dorée : c’est toi',
  'rolesSheet.teamLabel': 'Camp',
  'rolesSheet.nightLabel': 'La nuit',
  'rolesSheet.winLabel': 'Tu gagnes si',
  'rolesSheet.twistLabel': 'Attention',
  'rolesSheet.teamFamily': 'la Famille',
  'rolesSheet.teamTown': 'la ville',
  'rolesSheet.teamAlone': 'en solo',
  // ---- safety
  'safety.report': 'Signaler',
  'safety.block': 'Bloquer',
  'safety.unblock': 'Débloquer',
  'safety.cancel': 'Annuler',
  'safety.send': 'Envoyer',
  'safety.reportTitle': 'Signaler {name}',
  'safety.reportWhy': 'Que s’est-il passé ?',
  'safety.reason.language': 'Langage insultant',
  'safety.reason.cheating': 'Triche ou abandon de parties',
  'safety.reason.identity': 'Pseudo ou look inapproprié',
  'safety.reason.spam': 'Spam',
  'safety.reason.other': 'Autre',
  'safety.noteHint': 'Détails (facultatif)',
  'safety.reportPrivate': 'Ça reste entre nous : personne ne saura que c’était toi.',
  'safety.reportSent': 'Signalement reçu. On s’en occupe.',
  'safety.reportedMessage': 'Message signalé',
  'safety.blockTitle': 'Bloquer {name} ?',
  'safety.blockBody': 'Hors de ta vue : pas de messages, pas d’amitié, pas de place dans tes salles. En classé, vous serez à des tables différentes. Tu peux annuler dans les Réglages.',
  'safety.muteChat': 'Couper le chat',
  'safety.unmuteChat': 'Rétablir le chat',
  'safety.chatMuted': 'Tu ne vois plus les messages de {name} (ici seulement).',
  'safety.chatUnmuted': 'Tu vois de nouveau les messages de {name}.',
  'safety.seat': 'Place {number}',
  'safety.atTable': 'À table',
  'safety.outOfGame': 'Hors jeu',
  'safety.inRoom': 'Dans la salle',
  'safety.blocked': 'Tu as bloqué {name}.',
  'safety.unblocked': 'Tu as débloqué {name}.',
  'safety.blockedPlayers': 'Joueurs bloqués',
  'safety.blockedHint': 'Qui tu as bloqué, et comment débloquer.',
  'safety.noneBlocked': 'Tu n’as bloqué personne.',
  'safety.rulesTitle': 'Règles de la communauté',
  'safety.rulesHint': 'Comment on se tient à table.',
  'safety.rulesEnforcement': 'Tu peux signaler un joueur en touchant son visage à table ou en gardant le doigt sur un de ses messages. Chaque signalement est examiné : qui enfreint les règles peut perdre le chat, le classé ou son compte. Les messages et les noms insultants sont bloqués automatiquement.',
  'safety.rulesContact': 'Pour les signalements urgents, écris à',
  'safety.rules.1': 'Mens dans le jeu, pas aux gens. Le bluff fait partie d’Obertà ; les insultes, les menaces et le harcèlement, non.',
  'safety.rules.2': 'Pas de discours de haine, d’injures, de contenu sexuel ni d’attaques sur l’origine, la religion, le genre, l’orientation ou le handicap de quiconque.',
  'safety.rules.3': 'Pseudos et looks corrects : pas de noms insultants, pas question de se faire passer pour l’équipe ou un autre joueur.',
  'safety.rules.4': 'Joue ta partie jusqu’au bout. Abandonner, perdre exprès ou s’allier hors du jeu, ça gâche tout pour tout le monde.',
  'safety.rules.5': 'Pas de spam, de pub, de liens ni de données personnelles : ne partage jamais de numéro, d’adresse ou de réseau social.',
  'safety.rules.6': 'Sois sympa avec les nouveaux. Tout le monde a débuté un jour.',
  // ---- stats
  'stats.tabFile': 'DOSSIER',
  'stats.tabStats': 'STATS',
  'stats.title': 'STATS PERSONNELLES',
  'stats.includeTests': 'Inclure les parties de test',
  'stats.games': 'Parties',
  'stats.wins': 'Gagnées',
  'stats.losses': 'Perdues',
  'stats.winRate': 'Taux de victoire',
  'stats.atTheTable': 'À TABLE',
  'stats.timePlayed': 'Temps passé à table',
  'stats.timeMeasured': 'mesuré sur {timed} parties sur {games}',
  'stats.favouriteRole': 'Rôle préféré',
  'stats.longestStreak': 'Plus longue série de victoires',
  'stats.survived': 'En vie à la fin',
  'stats.byTable': 'PAR TABLE',
  'stats.friends': 'Entre amis',
  'stats.ranked': 'Classé',
  'stats.byFaction': 'PAR CAMP',
  'stats.family': 'Famille',
  'stats.town': 'Ville',
  'stats.alone': 'En solo',
  'stats.byRole': 'PAR RÔLE',
  'stats.neverPlayed': 'jamais joué',
  'stats.feats': 'EXPLOITS',
  'stats.featsHint': 'Depuis toujours, seulement les parties jouées jusqu’au bout.',
  'stats.counter.nights': 'Nuits survécues',
  'stats.counter.lynch_hits': 'Bons votes au lynchage',
  'stats.counter.saves': 'Sauvetages du Docteur',
  'stats.counter.finds': 'Coupables trouvés',
  'stats.counter.snipes': 'Tirs du Tireur',
  'stats.counter.kills': 'Contrats de la Famille',
  'stats.counter.framed': 'Honnêtes piégés',
  'stats.counter.godfather_lynch': 'Parrains lynchés',
  'stats.counter.wins_alive': 'Victoires en vie',
  'stats.private': 'RIEN QUE POUR TOI',
  'stats.privateHint': 'Personne d’autre ne voit ces chiffres.',
  'stats.abandoned': 'Abandonnées',
  'stats.afk': 'Absences (AFK)',
  'stats.reserved': 'CONFIDENTIEL',
  'stats.empty': 'Pas encore de partie en ligne. Les stats s’écrivent toutes seules en jouant.',
  'stats.loadFailed': 'Chargement impossible. Réessaie.',
  'stats.retry': 'Réessayer',
  'stats.profile': 'Profil',
  'stats.publicTitle': 'DOSSIER PUBLIC',
  'stats.onRecord': 'AU DOSSIER',
  'stats.featured': 'MÉDAILLES EN VITRINE',
  'stats.noMedals': 'Pas encore de médailles.',
  'stats.topRoles': 'RÔLES LES PLUS JOUÉS',
  'stats.closedFile': 'Dossier confidentiel : ces stats restent privées.',
  'stats.unavailable': 'Profil indisponible.',
  'stats.publicSwitch': 'Profil public',
  'stats.publicSwitchHint': 'Les autres voient tes stats, ton rang et tes médailles. Désactivé : seulement ton nom, ton niveau et ton portrait.',
  'stats.gamesWins': '{games, plural, one{# partie} other{# parties}} · {wins} gagnées',
  // ---- table
  'table.holdTheCard': 'Garde le doigt sur la carte pour la voir.',
  'table.picked': 'Tu as choisi {name}. Tu peux changer jusqu’à la fin du temps.',
  'table.passed': 'Tu as passé. Tu peux encore choisir quelqu’un.',
  'table.familyPicks': 'Famille : {picks}',
  'table.nightRunsOut': 'La nuit finit quand le temps est écoulé.',
  'table.investigate': 'Enquêter sur {name} ?',
  'table.dig': 'Déterrer {name} ?',
  'table.instantAnswer': 'La réponse arrive tout de suite, et ensuite tu ne peux plus changer.',
  'table.cancel': 'Annuler',
  'table.jail': 'Boucler {name} ?',
  'table.jailBody': 'La cellule se ferme tout de suite : cette nuit, pas d’action possible et personne ne peut y toucher. Tu ne peux plus changer.',
  'table.youAreJailed': 'Tu es en cellule. Tu ne sors pas cette nuit.',
  'table.jailerWantsYou': 'Le Geôlier veut te dire un mot.',
  'table.inYourCell': 'Dans ta cellule : {name}. Interroge dans le chat.',
  'table.lastOfFamily': 'Tu es la dernière de la Famille : maintenant, la nuit est à toi.',
  'table.mateInCell': 'Cette nuit, {name} est en cellule.',
  'table.jailChat': 'La cellule',
  'table.jailer': 'Le Geôlier',
  'table.converted': 'Tu as vu la lumière : te voilà dans la secte, et tu ne gagnes plus qu’avec elle.',
  'table.sectLine': 'Ta secte : {names}.',
  'table.doorClosed': 'Porte close : {name} n’a pas suivi.',
  'table.linkFirst': 'Touche le premier cœur.',
  'table.linkSecond': '{name} et qui ? Touche le second.',
  'table.link': 'Lier le cœur de {a} et de {b} ?',
  'table.linkBody': 'Les deux l’apprendront à l’aube, et ne gagnent que si aucun ne meurt. Ensuite, impossible de changer.',
  'table.loversLine': 'Cœurs liés : {a} et {b}.',
  'table.inLoveWith': 'Ton cœur bat pour {name}.',
  'table.loversChat': 'Les amants',
  'table.answerAtDawn': 'Quelqu’un à cette table bloque : la réponse arrive à l’aube.',
  'table.readTheNews': 'Lis les nouvelles, puis Prêt.',
  'table.votedFor': 'Tu as voté {name}. Tu peux changer d’avis.',
  'table.revealMayor': 'Se révéler',
  'table.revealMayorTitle': 'Te révéler comme Maire ?',
  'table.revealMayorBody': 'Tout le monde saura qui tu es, et ton vote comptera double dès aujourd’hui.',
  'table.shootTitle': 'Tirer sur {name} ?',
  'table.shotLine': 'Le coup est revenu en arrière : {name} était {role}.',
  'table.shotLine.aShotFrom': 'Un coup de feu du clocher : {name} était {role}.',
  'table.aimLine': 'En joue : {name}. Balles : {left}.',
  'table.truce': 'Trêve',
  'table.truceHint': 'Touche qui révéler à tout le monde.',
  'table.truceTitle': 'Tout arrêter : révéler {name} ?',
  'table.truceBody': 'Tout le monde verra son rôle exact, et le tien. Pas de vote aujourd’hui. Une seule fois.',
  'table.truceLine': '{pacifist} a imposé une trêve : {name} est {role}.',
  'table.truceVerdict': 'Trêve : personne ne pend aujourd’hui.',
  'table.fire': 'Feu !',
  'table.fireHint': 'Touche ta cible.',
  'table.fireTitle': 'Feu sur {name} ?',
  'table.fireBody': 'La cible meurt sur le coup et son rôle devient public. Tout le monde entend le grondement : on saura que tu es l’Artilleur.',
  'table.shotsLeft': 'Il te reste un coup.',
  'table.shotsLeft.youHaveShots': 'Il te reste {count} coups.',
  'table.gunnerShotsLeft': 'L’Artilleur n’a plus de coups.',
  'table.gunnerShotsLeft.theGunnerHas': 'Il reste un coup à l’Artilleur.',
  'table.gunnerShotsLeft.theGunnerHas.2': 'Il reste {count} coups à l’Artilleur.',
  'table.cannonLine': 'Un grondement sur la place : l’Artilleur a touché {name}, qui était {role}.',
  'table.noLynch': 'Personne n’a été lynché.',
  'table.chatOpensLater': 'La place rouvre pour le débat.',
  'table.chatOver': 'La partie est finie.',
  'table.rejoin': 'Revenir',
  'table.leave': 'Quitter',
  'table.abstained': '{gender, select, masculine{Tu t’es abstenu. Tu peux encore voter.} feminine{Tu t’es abstenue. Tu peux encore voter.} other{Abstention enregistrée. Tu peux encore voter.}}',
  'table.silenced': '{gender, select, masculine{muselé} feminine{muselée} other{bouche cousue}}',
  'table.lynched': '{gender, select, masculine{Lynché} feminine{Lynchée} other{Lynchage}}',
  'table.lynchedLine': '{gender, select, masculine{{name} a été lynché.} feminine{{name} a été lynchée.} other{La place a lynché {name}.}}',
  'table.lynchedLine.role': '{gender, select, masculine{{name} a été lynché. C’était {role}.} feminine{{name} a été lynchée. C’était {role}.} other{La place a lynché {name}. C’était {role}.}}',
  'table.abstainedVotes': '{n, plural, one{# abstention} other{# abstentions}}',
  'table.shootBody': 'Tout le monde l’entend, personne ne sait qui a tiré. Si c’est quelqu’un de la ville, le coup revient et c’est toi qui meurs. {left, plural, one{C’est ta dernière balle.} other{Il te reste # balles.}}',
  // ---- tutorial
  'tutorial.you': 'Toi',
  'tutorial.skip': 'Passer',
  'tutorial.exit': 'Quitter',
  'tutorial.exitTitle': 'Quitter la main d’essai ?',
  'tutorial.exitBody': 'Elle ne comptera pas comme faite : tu peux la rejouer quand tu veux.',
  'tutorial.stay': 'Rester',
  'tutorial.hint': 'Première fois ? Trois mains d’essai, une par couleur.',
  'tutorial.hintGo': 'Essayer',
  'tutorial.replay': 'Tutoriel',
  'tutorial.replayHint': 'Trois mains d’essai contre les bots.',
  'tutorial.deskButton': 'Tutoriel',
  'tutorial.choose': 'Choisis un camp à apprendre',
  'tutorial.chooseSub': 'Une main contre cinq bots, sur la vraie table.',
  'tutorial.faction.family': 'Famille',
  'tutorial.faction.city': 'Ville',
  'tutorial.faction.solo': 'En solo',
  'tutorial.pitch.family': 'Tue la nuit, mens le jour.',
  'tutorial.pitch.city': 'Enquête, démasque la Famille.',
  'tutorial.pitch.solo': 'Fais-toi lyncher et gagne en solo.',
  'tutorial.done': 'Fait',
  'tutorial.ready': 'Maintenant, à toi de jouer',
  'tutorial.toTheTable': 'À la table',
  'tutorial.nextHand': 'Une autre main',
  // ---- tutorialScript
  'tutorialScript.whenYouHave': 'Quand tu as lu, « Prêt ».',
  'tutorialScript.atDawnYou': 'À l’aube, tu vois comment s’est passée la nuit.',
  'tutorialScript.theTownWins.city': 'La ville gagne quand il ne reste plus personne de la Famille. Les preuves valent mieux que les bavardages.',
  'tutorialScript.youAreThe.city': 'Tu es le Commissaire. Garde le doigt sur la carte, puis « Prêt ».',
  'tutorialScript.atNightYou.city': 'La nuit, tu enquêtes. Touche Vito, place 2, et confirme.',
  'tutorialScript.vitoIsFamily.city': 'Vito est de la Famille. Il n’y a que toi qui le sais, pour l’instant.',
  'tutorialScript.brunoNeverHurt.city': 'Bruno n’a jamais fait de mal à personne. Qui voulait sa peau ?',
  'tutorialScript.iWasAt.city': 'J’étais au bar toute la nuit. Demandez au 4.',
  'tutorialScript.trueLookAt.city': 'C’est vrai. Regardez plutôt le 6 : bien trop calme.',
  'tutorialScript.meDetectiveWhat.city': 'Moi ?? Commissaire, qu’est-ce que tu sais ?',
  'tutorialScript.iCheckedVito.city': 'J’ai vérifié Vito : Famille.',
  'tutorialScript.isLyingI.city': 'Le 2 ment. Je l’ai vu cette nuit.',
  'tutorialScript.liarHeJust.city': 'Menteur ! Il veut juste vous embrouiller.',
  'tutorialScript.ifTheDetective.city': 'Si le Commissaire le dit, je suis partant.',
  'tutorialScript.meTooWe.city': 'Moi aussi. On vote le 2.',
  'tutorialScript.theSquareTalks.city': 'La place discute. Dis ce que tu sais sur Vito.',
  'tutorialScript.theyBelieveYou.city': 'Ils te croient. « Prêt », et on vote.',
  'tutorialScript.onSecondThought.city': 'À la réflexion… le 2.',
  'tutorialScript.watchTheHands.city': 'Regarde les mains : les avis changent. Désigne Vito.',
  'tutorialScript.theLynchedShows.city': 'Le lynché montre sa carte. La place a vu juste.',
  'tutorialScript.anotherNightCheck.city': 'Encore une nuit. Vérifie Carmela, place 4.',
  'tutorialScript.carmelaIsFamily.city': 'Carmela est de la Famille, elle aussi.',
  'tutorialScript.tonightTheyCame.city': 'Cette nuit, ils sont venus pour toi…',
  'tutorialScript.theDoctorSaved.city': 'Le Docteur t’a sauvé la vie. À toi de jouer.',
  'tutorialScript.iWatchedOver.city': 'J’ai veillé sur le Commissaire cette nuit. Ils ont essayé.',
  'tutorialScript.luckyYouBut.city': 'Quelle veine… mais Vito a agi seul.',
  'tutorialScript.detectiveWhoDid.city': 'Commissaire, qui as-tu vérifié cette nuit ?',
  'tutorialScript.carmelaFamily.city': 'Carmela : Famille.',
  'tutorialScript.isTheLast.city': 'La 4 est la dernière. Votez contre elle.',
  'tutorialScript.ohPleaseIs.city': 'Oh, je t’en prie ! Le 1 délire.',
  'tutorialScript.iSavedYou.city': 'Je t’ai sauvé la vie : je te fais confiance.',
  'tutorialScript.weVote.city': 'On vote la 4.',
  'tutorialScript.lastDayTell.city': 'Dernier jour. Parle de Carmela à la place.',
  'tutorialScript.goodReadyAnd.city': 'Bien. « Prêt », et on vote.',
  'tutorialScript.noWait.city': 'Non, attendez : la 4.',
  'tutorialScript.voteCarmela.city': 'Vote Carmela.',
  'tutorialScript.noFamilyLeft.city': 'Plus personne de la Famille : la ville gagne.',
  'tutorialScript.theFamilyWins.family': 'La Famille gagne dès qu’elle est aussi nombreuse que la ville. Le jour, mens bien.',
  'tutorialScript.thisTimeYou.family': 'Cette fois, tu es de la Famille. Garde le doigt sur la carte, puis « Prêt ».',
  'tutorialScript.justTheTwo.family': 'Rien que nous deux. Personne ne doit savoir.',
  'tutorialScript.iSayEnzo.family': 'Moi, je dis le 6, Enzo : trop de questions. Et toi ?',
  'tutorialScript.ok.family': 'OK, le 6.',
  'tutorialScript.fineEnzoTonight.family': 'Va pour Enzo cette nuit.',
  'tutorialScript.perfectTap.family': 'Parfait. Touche le 6.',
  'tutorialScript.atNightThe.family': 'La nuit, la Famille parle en secret. Réponds à Vito.',
  'tutorialScript.nowTapEnzo.family': 'Maintenant touche Enzo, place 6 : c’est ton vote.',
  'tutorialScript.twoVotesOn.family': 'Deux votes sur Enzo : la Famille est d’accord.',
  'tutorialScript.enzoLivesThe.family': 'Enzo vit : le Docteur l’a sauvé. Réessaie plus tard.',
  'tutorialScript.someoneWentTo.family': 'Quelqu’un est allé chez Enzo cette nuit.',
  'tutorialScript.aliveByA.family': 'Vivant par miracle. Qui c’était ?',
  'tutorialScript.wasOutOn.family': 'Le 1 traînait dans la rue cette nuit. Je l’ai vu.',
  'tutorialScript.wellTalk.family': 'Alors, le 1 ? Parle.',
  'tutorialScript.easyWasAt.family': 'Doucement, le 1 était au bar avec moi.',
  'tutorialScript.brunoAccusesFirst.family': 'Bruno accuse le premier : qui accuse le premier cache quelque chose.',
  'tutorialScript.iWasAsleep.family': 'Je dormais. Mais le 3 en sait long, non ?',
  'tutorialScript.brunoIsIn.family': 'Bruno est bien pressé, c’est vrai.',
  'tutorialScript.toldYouIs.family': 'Je vous l’avais dit. Le 3 est bizarre.',
  'tutorialScript.whatIAm.family': 'Quoi ?! Je suis réglo, moi !',
  'tutorialScript.theyAccuseYou.family': 'On t’accuse. Ne te défends pas : renvoie la balle sur Bruno, place 3.',
  'tutorialScript.itWorkedReady.family': 'Ça a marché. « Prêt », et on vote.',
  'tutorialScript.changedMyMind.family': 'J’ai changé d’avis : le 3.',
  'tutorialScript.handsAreMoving.family': 'Les mains bougent. Vote Bruno, place 3, avec eux.',
  'tutorialScript.brunoWasInnocent.family': 'Bruno était innocent. Tu es tranquille, pour aujourd’hui.',
  'tutorialScript.theDoctorSaved.family': 'Le Docteur a sauvé Enzo. Je parie que c’est la 4.',
  'tutorialScript.herTonightYou.family': 'Elle, cette nuit. Ça te va ?',
  'tutorialScript.iAmIn.family': 'Partant : la 4.',
  'tutorialScript.fineCarmela.family': 'Va pour Carmela.',
  'tutorialScript.letSGo.family': 'On y va.',
  'tutorialScript.vitoHasAn.family': 'Vito a une idée. Réponds-lui.',
  'tutorialScript.tapCarmelaSeat.family': 'Touche Carmela, place 4.',
  'tutorialScript.twoAgainstTwo.family': 'Deux contre deux : la ville ne peut plus gagner.',
  'tutorialScript.soloPlayersHave.solo': 'Les solitaires ont leur propre but : le Bouffon gagne s’il est lynché, et la partie continue sans lui.',
  'tutorialScript.youPlayAlone.solo': 'Tu joues en solo : le Bouffon gagne s’il est lynché. Garde le doigt sur la carte.',
  'tutorialScript.theFoolHas.solo': 'Le Bouffon n’a aucun pouvoir : touche n’importe qui pour faire semblant.',
  'tutorialScript.atNightYou.solo': 'La nuit, tu ne fais rien. Ton boulot, c’est le jour.',
  'tutorialScript.brunoIsGone.solo': 'Bruno n’est plus là. Maintenant, on parle.',
  'tutorialScript.brunoIsDead.solo': 'Bruno est mort. Quelqu’un a vu quelque chose ?',
  'tutorialScript.iWasAsleep.solo': 'Je dormais. Mais le 1 a veillé toute la nuit.',
  'tutorialScript.yeahDoesNot.solo': 'Ouais, le 1 ne me convainc pas.',
  'tutorialScript.giveHimA.solo': 'Laissez-lui une chance. Alors, le 1 ?',
  'tutorialScript.brunoOneLess.solo': 'Bruno ? Un de moins. Je ne vais pas pleurer.',
  'tutorialScript.iSayNothing.solo': 'Je ne dis rien. Votez contre moi, si vous l’osez.',
  'tutorialScript.youHeardThat.solo': 'Vous avez entendu ? Presque des aveux !',
  'tutorialScript.isSeriouslyWeird.solo': 'Le 1 est vraiment bizarre. Je vote contre lui.',
  'tutorialScript.sorryYouDid.solo': 'Désolé, le 1 : tu l’as bien cherché.',
  'tutorialScript.actShadySay.solo': 'Joue le louche : dis un truc qu’aucun innocent ne dirait.',
  'tutorialScript.theyFellFor.solo': 'Ils sont tombés dans le panneau. « Prêt », et on vote.',
  'tutorialScript.fineMeToo.solo': 'Bon, moi aussi : le 1.',
  'tutorialScript.everyonePointsAt.solo': 'Tout le monde te montre du doigt. Vote n’importe qui : ça ne change rien.',
  'tutorialScript.theyLynchedYou.solo': 'La corde est pour toi : exactement ce que tu voulais.',
  // ---- voice
  'voice.title': 'Voix',
  'voice.mode.off': 'Coupée',
  'voice.mode.listen': 'Écoute seule',
  'voice.mode.mic': 'Micro',
  'voice.modeFull': 'Micro (appuyer pour parler)',
  'voice.pushToTalk': 'Appuyer pour parler',
  'voice.pushToTalkPhone': 'Garde le doigt sur le micro pour parler.',
  'voice.pushToTalkDesk': 'Maintiens V (ou le micro) pour parler.',
  'voice.holdToTalk': 'Maintiens pour parler',
  'voice.holdV': 'Maintiens V',
  'voice.offline': 'Voix hors ligne, nouvelle tentative',
  'voice.nightFamily': 'La nuit, seule la Famille parle',
  'voice.deadListen': 'Les morts ne font qu’écouter',
  'voice.sewn': 'Le Tailleur t’a cousu la bouche',
  'voice.jailed': 'On ne parle pas en cellule',
  'voice.voteSilence': 'On ne parle pas pendant le vote',
  'voice.nobodyNow': 'Personne ne parle en ce moment',
  'voice.opensSoon': 'La voix ouvre dans un instant',
  'voice.muteVoice': 'Couper la voix',
  'voice.unmuteVoice': 'Rétablir la voix',
  'voice.mutedHere': 'Coupé : ici, et pour toi seulement.',
  'voice.micDeniedTitle': 'Micro refusé',
  'voice.micDenied': 'Sans accès au micro, tu peux seulement écouter. Tu peux l’autoriser dans les réglages du système, puis choisir de nouveau « Micro ».',
  'voice.openSettings': 'Ouvrir les réglages',
  'voice.notNow': 'Pas maintenant',
  'voice.settings': 'Voix à table',
  'voice.settingsHint': 'Dans les salles entre amis. Le jour, les vivants parlent ; la nuit, seulement la Famille. En direct seulement : rien n’est enregistré.',
  'voice.people': 'À table',
  'voice.nobody': 'Personne d’autre n’écoute.',
  'voice.mute': 'Couper',
  'voice.reportOrBlock': 'Signaler ou bloquer',
  'voice.unmute': 'Rétablir',
  'voice.blocked': 'Blocage : vous ne vous entendez pas.',
  'voice.closed': 'La voix est fermée en ce moment.',
  'voice.listening': 'Écoute seule.',
  'voice.silencedNow': 'Tu ne peux pas parler en ce moment.',
  'voice.connecting': 'Connexion…',
  'voice.live': 'On t’entend',
  'voice.button': 'Voix',
  'voice.micAskTitle': 'Le micro',
  'voice.micAsk': 'Pour parler à table, Obertà utilise le micro, seulement quand le jeu te donne la parole. Ta voix part en direct et n’est jamais enregistrée ni transcrite.',
  'voice.micAllow': 'Utiliser le micro',
  'voice.cancel': 'Annuler',
  // ---- results
  'results.familyWins': 'LA FAMILLE GAGNE',
  'results.townWins': 'LA VILLE GAGNE',
  'results.loneWolfWins': 'UN LOUP SOLITAIRE GAGNE',
  'results.youLost': 'PERDU',
  'results.bountyPaid': 'LA PRIME EST PAYÉE',
  'results.loanSharkCashesIn': 'L’USURIER ENCAISSE',
  'results.foolLastLaugh': 'LE BOUFFON RIT LE DERNIER',
  'results.hitmanStandsAlone': 'LE TUEUR À GAGES RESTE SEUL',
  'results.cityBurns': 'LA VILLE BRÛLE',
  'results.back': 'RETOUR',
  'results.backToRoom': 'RETOUR À LA SALLE',
  'results.playAgain': 'REJOUER',
  'results.keysPlayAgainOrBack': 'ENTRÉE  rejouer   ·   ÉCHAP  retour',
  'results.keysBackToRoom': 'ENTRÉE ou ÉCHAP  retour à la salle',
  'results.level': 'NIVEAU {level}',

  // ---- mirror
  'mirror.takeHatOff': 'Enlever le chapeau',
  'mirror.putHatOn': 'Mettre le chapeau',
  'mirror.hatOff': 'Sans chapeau',
  'mirror.hatOn': 'Avec chapeau',
  'mirror.title': 'Le miroir du barbier',
  'mirror.later': 'Plus tard',
  'mirror.whoSits': 'Qui s’assoit dans le fauteuil ?',
  'mirror.presentationHint': 'Le barbier propose coupes, maquillage et vêtements assortis. Tu peux toujours tout choisir avec « Tout montrer ».',
  'mirror.man': 'Homme',
  'mirror.woman': 'Femme',
  'mirror.other': 'Autre',
  'mirror.preferNotToSay': 'Je préfère ne pas le dire',
  'mirror.showAll': 'Tout montrer',
  'mirror.saveFace': 'Garder ce visage',
  'mirror.backToBefore': 'Revenir comme avant',
  'mirror.randomFace': 'Visage au hasard',
  'mirror.readyMadeFaces': 'Visages tout faits',
  'mirror.freeClothes': 'Vêtements gratuits',
  'mirror.randomShort': 'Au hasard',
  'mirror.asItWas': 'Comme avant',
  'mirror.cancel': 'Annuler',
  'mirror.tab.skin': 'Peau',
  'mirror.tab.hair': 'Cheveux',
  'mirror.tab.colour': 'Couleur',
  'mirror.tab.eyes': 'Yeux',
  'mirror.tab.eyeSize': 'Taille des yeux',
  'mirror.tab.iris': 'Iris',
  'mirror.tab.brows': 'Sourcils',
  'mirror.tab.nose': 'Nez',
  'mirror.tab.mouth': 'Bouche',
  'mirror.tab.lipstick': 'Rouge à lèvres',
  'mirror.tab.makeUp': 'Maquillage',
  'mirror.tab.marks': 'Marques',
  'mirror.tab.age': 'Âge',
  'mirror.tab.head': 'Tête',

  // ---- chronicle
  'chronicle.deadJoiner': ' ET ',
  'chronicle.listJoiner': ' et ',
  'chronicle.fire': 'Incendie dans la nuit : {burned}',
  'chronicle.fireWithOthers': 'Incendie dans la nuit : {burned}. {gender, select, masculine{{n, plural, one{Mort} other{Morts}}} feminine{{n, plural, one{Morte} other{Mortes}}} other{Parmi les morts}} aussi : {others}',
  'chronicle.risen': '{name} revient de la tombe',
  'chronicle.foundDead': '{gender, select, masculine{{n, plural, one{Retrouvé mort : {names}} other{Retrouvés morts : {names}}}} feminine{{n, plural, one{Retrouvée morte : {names}} other{Retrouvées mortes : {names}}}} other{Du sang dans la nuit : {names}}}',
  'chronicle.squareUndecided': 'La place n’arrive pas à se décider',
  'chronicle.lynched': 'Lynchage de {name}',
  'chronicle.lynchedFool': 'Lynchage de {name} : le Bouffon gagne',
  'chronicle.lynchedBounty': 'Lynchage de {name} : {hunter} empoche la prime',
  'chronicle.lynchedNeutral': 'Lynchage de {name} : {role}',
  'chronicle.lynchedFamily': 'Lynchage de {name} : un de la Famille',
  'chronicle.lynchedInnocent': 'Lynchage de {name} : un innocent',

  // ---- courier
  'courier.masthead': 'Le Courrier de {city}',
  'courier.dateLine': 'An XIX  ·  Jour {round}  ·  {edition}',
  'courier.dawnEdition': 'Édition de l’aube',

  // ---- gesture
  'gesture.title': 'Un geste pour {name}',
  'gesture.hint': 'Toute la table le voit.',
  'gesture.locked': 'En boutique',
  'gesture.wait': 'Le prochain dans {seconds} s',
  'gesture.report': 'Signaler ou bloquer',
  'gesture.settingTitle': 'Gestes à table',
  'gesture.settingHint': 'Désactivés, personne ne peut te lancer de cigares, de roses ou de poissons.',
  'gesture.button': 'Gestes',
  'gesture.pickTarget': 'Qui reçoit un geste ?',
  'gesture.pickHint': 'Ou garde le doigt sur une place.',
  'gesture.firstHint': 'Lance un geste à quelqu’un : touche « Gestes ».',
  // ---- collection
  'collection.title': 'Les rôles',
  'collection.settingsHint': 'La collection : chaque carte se retourne en gagnant avec elle.',
  'collection.count': '{n} cartes sur {of}',
  'collection.hint': 'Chaque carte reste face cachée tant que tu n’as pas gagné une partie avec ce rôle.',
  'collection.signedOut': 'Connecte-toi pour retourner les cartes et tenir le compte de tes parties.',
  'collection.signIn': 'Se connecter',
  'collection.team.citizens': 'Ville',
  'collection.team.mafia': 'Famille',
  'collection.team.neutral': 'Solitaires',
  'collection.locked': 'Face cachée',
  'collection.lockedBody': 'Carte face cachée. Gagne une partie avec ce rôle pour savoir ce qu’il fait et voir tes chiffres.',
  'collection.playedNoWin': 'Jouée une fois, jamais gagnée.',
  'collection.playedNoWin.playedTimesNever': 'Jouée {n} fois, jamais gagnée.',
  'collection.neverPlayed': 'Jamais jouée.',
  'collection.played': 'Parties',
  'collection.wins': 'Gagnées',
  'collection.losses': 'Perdues',
  'collection.winRate': '% de victoires',
  'collection.bestStreak': 'Meilleure série',
  'collection.lastPlayed': 'Dernière partie',
  'collection.short': '{wins} V · {played} P',
  'collection.close': 'Fermer',
  'collection.publicCount': 'Rôles retournés',
  // ---- localRole
  'localRole.wasBusy': 'La nuit dernière, quelqu’un t’a occupé : ton coup est perdu.',
  'localRole.wasJailed': 'La nuit dernière, tu étais en cellule : ton coup est perdu.',
  'localRole.jailerAsked': 'Le Geôlier demandait : « {question} »',
  'localRole.prisonerAnswered': 'Depuis la cellule, {name} a répondu : « {answer} »',
  'localRole.foundFamily': 'À l’aube : {name} est de la Famille.',
  'localRole.foundClean': 'À l’aube : {name} est réglo.',
  'localRole.foundRole': 'À l’aube : {name} était {role}.',
  'localRole.jailedTitle': 'Tu es en cellule',
  'localRole.jailedBody': 'Cette nuit, tu ne sors pas, et personne ne te touche.',
  'localRole.jailerAsks': 'Le Geôlier te demande :',
  'localRole.answerHint': 'Ta réponse (seul le Geôlier la lit)',
  'localRole.questionHint': 'Une question pour le prisonnier (facultatif)',
  'localRole.jailed': '{name} est dans ta cellule.',
  'localRole.converted': 'Tu as vu la lumière : te voilà dans la secte, et tu ne gagnes plus qu’avec elle.',
  'localRole.sect': 'Ta secte : {names}.',
  'localRole.doorClosed': 'La nuit dernière, porte close : {name}.',
  'localRole.sectWins': 'La secte gagne',
  'localRole.linkSecond': 'Et qui d’autre ? Touche le second cœur.',
  'localRole.linked': 'Tu as lié {a} et {b}.',
  'localRole.inLoveWith': 'Ton cœur bat pour {name} : vous ne gagnez que si aucun de vous deux ne meurt.',
  'localRole.fateCannon': 'Au canon, jour {round}',
  'localRole.fateDay': 'De jour, jour {round}',
  'localRole.truce': 'Trêve du Pacifiste',
  'localRole.whoAreYou': 'Que le Pacifiste touche son propre visage.',
  'localRole.notYou': 'Seul le Pacifiste peut imposer la trêve.',
  'localRole.whoToReveal': 'Qui révèles-tu à tous ?',
  'localRole.cannon': 'Feu de l’Artilleur',
  'localRole.gunnerWhoAreYou': 'Que l’Artilleur touche son propre visage.',
  'localRole.notTheGunner': 'Seul l’Artilleur peut tirer.',
  'localRole.whoToHit': 'Qui frappes-tu ?',
  'localRole.marksman': 'Tir du Tireur d’élite',
  'localRole.whoIsMarksman': 'Que le Tireur d’élite touche son propre visage.',
  'localRole.notMarksman': 'Seul le Tireur d’élite peut tirer.',
  'localRole.aimed': 'En joue : {name}. Balles restantes : {left}.',
  'localRole.noAim': 'Personne en joue : choisis cette nuit.',
  'localRole.fire': 'Feu !',
  'localRole.carryOn': 'Continuer',
  'localRole.cancel': 'Annuler',
  'localRole.confirm': 'Confirmer',
  // ---- localTable
  'localTable.pickedConfirm': 'Tu as choisi {name}. Confirme, ou touche une autre place.',
  'localTable.familyNote': 'famille',
  'localTable.cleanNote': 'réglo',
  'localTable.discuss': 'Discutez à voix haute. Ensuite, on vote.',
  'localTable.openVote': 'Le téléphone reste au milieu : on vote un par un, à visage découvert.',
  'localTable.votedLine': '{voter} vote {target}.',
  'localTable.abstainedLine': '{voter} s’abstient.',
  'localTable.undo': 'Retour',
  'localTable.notTheMayor': 'Seul le Maire peut se révéler.',
  // ---- rules
  'rules.sign': 'Règles',
  'rules.title': 'Règles du jeu',
  'rules.banner': 'À lire à voix haute',
  'rules.pitch': 'Lis cette page à voix haute : en une minute, tes amis savent jouer.',
  'rules.style.quick': 'Express',
  'rules.style.stage': 'Théâtrale',
  'rules.styleHint.quick': 'Tout le jeu en une minute.',
  'rules.styleHint.stage': 'Un conte noir, à jouer.',
  'rules.readToMe': 'Lis-la-moi',
  'rules.stopReading': 'Ça suffit',
  'rules.commonRoles': 'Les rôles les plus courants',
  'rules.commonRolesHint': 'Une ligne chacun, pour les curieux.',
  'rules.playLocal': 'On joue sur un téléphone',
  'rules.playLocalHint': 'Un seul téléphone, passé de main en main.',
  'rules.playFriends': 'Jouer entre amis',
  'rules.playFriendsHint': 'Sur un seul téléphone, on joue sur place : d’ici, une salle en ligne.',
  'rules.back': 'Retour',
  'rules.team.citizens': 'Ville',
  'rules.team.mafia': 'Famille',
  'rules.team.neutral': 'En solo',
  // ---- chat
  'chat.fresh': '{n, plural, one{# nouveau} other{# nouveaux}}',
  // ---- nightNotes
  'nightNotes.spendTheNight': 'Passer la nuit',
  // ---- ranked
  'ranked.yourTable': 'Ta langue',
};

// The rules read aloud, quick and theatrical (rules_strings.dart has the
// Italian and English ones). Stage cues (RulesBeat.cue) are not spoken.
const _quickFr = [
  RulesStep('Deux camps', [
    RulesBeat('Imagine une grande ville dans les années quarante. Presque tout le monde y est honnête : c’est la ville.'),
    RulesBeat('Pas tous. Eux, c’est la Famille, et ce soir, ils ont du travail.'),
    RulesBeat('Les mafieux se connaissent entre eux. Les honnêtes gens ne connaissent personne. Tout le problème est là.'),
  ]),
  RulesStep('Ta carte est secrète', [
    RulesBeat('Le téléphone fait le tour. Chacun regarde son rôle, seul, et ne le dit à personne.'),
    RulesBeat('Le jour, tu peux dire ce que tu veux sur qui tu es. Même des mensonges. Surtout des mensonges.'),
  ]),
  RulesStep('La nuit', [
    RulesBeat('La nuit, le téléphone passe de main en main. Qui le tient joue son coup en secret ; les autres regardent ailleurs.'),
    RulesBeat('La Famille choisit qui descendre. Le Commissaire enquête, le Docteur sauve.'),
    RulesBeat('Pas de pouvoir ? Touche JE PASSE, avec la même tête que les autres. Personne ne doit savoir qui a fait quoi.'),
  ]),
  RulesStep('Le jour', [
    RulesBeat('À l’aube, on découvre qui n’a pas tenu le coup. Qui meurt la nuit emporte son rôle dans la tombe.'),
    RulesBeat('Puis on discute : accusations, alibis, regards en coin.'),
    RulesBeat('À la fin, on vote. Qui a le plus de voix est lynché, et sa carte est retournée. Égalité ? Personne ne pend aujourd’hui.'),
  ]),
  RulesStep('Qui gagne', [
    RulesBeat('La ville gagne quand toute la Famille est dehors.'),
    RulesBeat('La Famille gagne quand elle est aussi nombreuse que tous les autres.'),
    RulesBeat('Quelques drôles de types jouent pour leur compte : leur carte leur dit comment gagner.'),
  ]),
  RulesStep('Les règles d’or', [
    RulesBeat('Ne regarde pas le téléphone des autres.'),
    RulesBeat('Ne montre ton écran à personne.'),
    RulesBeat('Les morts ne parlent pas. Même pas avec les yeux.'),
    RulesBeat('Et personne ne se vexe : ce n’est qu’un jeu. Plus ou moins.'),
  ]),
];

const _stageFr = [
  RulesStep('Il était une fois', [
    RulesBeat.cue('Baisse les lumières. Attends le silence.'),
    RulesBeat('Il était une fois, dans une cité qui ne dort jamais, une place pleine de braves gens. On les appelait la ville.'),
    RulesBeat('Mais parmi ces braves gens se cachait la Famille. Peu nombreux, élégants, armés. Ils se connaissaient tous… et personne ne les connaissait.'),
    RulesBeat.cue('Regarde chaque visage, lentement.'),
    RulesBeat('Peut-être que l’un d’eux est assis à cette table. Peut-être deux.'),
  ]),
  RulesStep('L’enveloppe scellée', [
    RulesBeat('Chacun de vous recevra une enveloppe scellée : dedans, il y a qui vous êtes vraiment.'),
    RulesBeat.cue('Passe le téléphone à ta droite, comme une enveloppe.'),
    RulesBeat('Lisez-la en secret. Puis gardez-la au fond du cœur, et ne la dites à personne.'),
    RulesBeat('Dès demain, vous pourrez raconter ce que vous voulez sur vous. La vérité… ou pas.'),
  ]),
  RulesStep('Quand tombe la nuit', [
    RulesBeat.cue('Baisse la voix.'),
    RulesBeat('Quand tombe la nuit, le téléphone passe de main en main, comme un secret qui brûle les doigts.'),
    RulesBeat('Qui le tient joue son coup sans être vu. Les autres fixent le mur, le plafond, leurs chaussures.'),
    RulesBeat('La Famille choisit qui ne verra pas l’aube. Le Commissaire fouille dans les affaires des autres. Le Docteur veille sur quelqu’un.'),
    RulesBeat('Et ceux qui n’ont pas de pouvoir ? Ils jouent la comédie. Ils touchent l’écran avec un air de conspirateur, pour que personne ne soupçonne personne.'),
  ]),
  RulesStep('À l’aube, la place', [
    RulesBeat.cue('Élève la voix, comme un crieur public.'),
    RulesBeat('À l’aube, la ville se réveille et compte ses morts. Qui tombe la nuit s’en va avec son secret.'),
    RulesBeat('Alors la place se rassemble : on accuse, on jure, on ment.'),
    RulesBeat.cue('Montre quelqu’un du doigt, d’un coup.'),
    RulesBeat('Toi ! Où étais-tu cette nuit ?'),
    RulesBeat('Quand les voix se taisent, on vote. Qui récolte le plus de voix est condamné, et sa carte se retourne aux yeux de tous.'),
    RulesBeat('Si les voix sont à égalité, la place s’arrête : aujourd’hui, pas de condamnation.'),
  ]),
  RulesStep('Comment finit l’histoire', [
    RulesBeat('L’histoire finit bien pour la ville quand le dernier de la Famille a quitté la place.'),
    RulesBeat('Elle finit bien pour la Famille quand ses hommes sont aussi nombreux que tous les autres : dès lors, la ville est à eux.'),
    RulesBeat('Et quelques âmes solitaires jouent une partie bien à elles : leur enveloppe leur dira comment gagner.'),
  ]),
  RulesStep('Les trois lois de la rue', [
    RulesBeat.cue('Lentement, en comptant sur tes doigts.'),
    RulesBeat('Première loi : on ne regarde pas dans le téléphone des autres.'),
    RulesBeat('Deuxième loi : on ne montre son écran à personne.'),
    RulesBeat('Troisième loi : les morts ne parlent pas. Ni avec la bouche, ni avec les yeux.'),
    RulesBeat.cue('Une pause. Puis, à voix basse.'),
    RulesBeat('Et maintenant… que la nuit commence.'),
  ]),
];

// The same rules as the Italian and English scripts:
// - court : une ligne ou deux par réplique ;
// - jamais le genre d'un joueur : le nom, ou on retourne la phrase ;
// - villes et lieux vrais ; personnes et faits, non ;
// - personne ne ferme les yeux : on se passe le téléphone ;
// - les factions s'appellent toujours « la Famille » et « la ville ».

/// The narrator's script, read on screen (no recorded voice yet).
const frenchPack = NarrationPack(
  roles: {
    Role.mafioso: RoleText(
      'Le Porte-flingue',
      '« Rien de personnel. »',
      'Tu es de la Famille. Chaque nuit, avec la Famille, tu choisis qui meurt. Vous gagnez quand la Famille égale en nombre tous les autres.',
    ),
    Role.padrino: RoleText(
      'Le Parrain',
      '« Je ne rends que des services. »',
      'Tu diriges la Famille : chaque nuit, tu choisis avec elle qui meurt. Attention : pour le Commissaire, tu es réglo. Tu gagnes avec la Famille.',
    ),
    Role.sarto: RoleText(
      'Le Tailleur',
      '« Des costumes le jour. Des bouches la nuit. »',
      'Tu es de la Famille et tu tues avec elle la nuit. Une fois par partie, tu peux priver quelqu’un de parole pour une journée. Tu gagnes avec la Famille.',
    ),
    Role.compare: RoleText(
      'Le Complice',
      '« Moi, je ne faisais que passer. »',
      'Tu es de la Famille et tu tues avec elle la nuit. Tant que tu vis, la Famille peut aussi parler en secret le jour.',
    ),
    Role.cittadino: RoleText(
      'L’Honnête Citoyen',
      '« Je n’ai rien vu. Hélas, c’est vrai. »',
      'Tu n’as aucun pouvoir. Le jour, écoute, accuse et vote pour trouver les tueurs. Tu gagnes avec la ville quand ils sont tous dehors.',
    ),
    Role.detective: RoleText(
      'Le Commissaire',
      '« Tout le monde ment. Certains mieux. »',
      'Chaque nuit, choisis quelqu’un et apprends s’il est de la Famille. Attention : certaines cartes trompent, le Parrain te paraît innocent.',
    ),
    Role.medico: RoleText(
      'Le Docteur',
      '« Je recouds ce que d’autres déchirent. »',
      'Chaque nuit, choisis quelqu’un, toi compris : si on l’attaque, tu le sauves. Jamais la même personne deux nuits de suite.',
    ),
    Role.cecchino: RoleText(
      'Le Tireur',
      '« Une balle. Pas deux. »',
      'Tu as une seule balle pour toute la partie : une nuit, choisis qui meurt. Vise bien, tu peux te tromper. Tu gagnes avec la ville.',
    ),
    Role.giornalista: RoleText(
      'Le Reporter',
      '« La vérité sort en kiosque à six heures. »',
      'Une fois par partie, la nuit, choisis quelqu’un : à l’aube, tous apprennent son camp. Si tu meurs cette nuit-là, l’article ne sort pas.',
    ),
    Role.becchino: RoleText(
      'Le Fossoyeur',
      '« Mes clients ne mentent jamais. »',
      'Chaque nuit, tu peux choisir un mort de la nuit et apprendre son rôle. Ça reste entre toi et la tombe. Tu gagnes avec la ville.',
    ),
    Role.guardaspalle: RoleText(
      'Le Garde du corps',
      '« Il faudra d’abord passer sur moi. »',
      'Chaque nuit, protège quelqu’un : si on l’attaque, tu meurs à sa place. Tu gagnes avec la ville.',
    ),
    Role.reduce: RoleText(
      'Le Vétéran',
      '« On m’a déjà tiré dessus. Des meilleurs. »',
      'Tu ne fais rien la nuit, mais tu as la peau dure : la première attaque nocturne contre toi échoue. Tu gagnes avec la ville.',
    ),
    Role.pregiudicato: RoleText(
      'Le Repris de justice',
      '« J’ai payé. Mon casier, non. »',
      'Tu es avec la ville, mais attention : le Commissaire te voit de la Famille. Il faudra convaincre les autres que tu es réglo.',
    ),
    Role.messia: RoleText(
      'Le Messie',
      '« Lève-toi. Tu n’as pas fini. »',
      'Une fois par partie, la nuit, tu peux ramener n’importe quel mort à la vie. Tu gagnes avec la ville.',
    ),
    Role.sindaco: RoleText(
      'Le Maire',
      '« Je n’ai pas été élu pour me taire. »',
      'Une fois par partie, pendant le vote, tu peux te révéler : dès lors ton vote compte double. Tu gagnes avec la ville.',
    ),
    Role.portinaio: RoleText(
      'Le Concierge',
      '« Je ne demande pas qui. Je vois la porte. »',
      'Chaque nuit, surveille la porte de quelqu’un : à l’aube, tu sais si quelqu’un est passé, mais pas qui. Tu gagnes avec la ville.',
    ),
    Role.fesso: RoleText(
      'Le Bouffon',
      '« Coupable, moi ? Mais bien sûr. »',
      'Tu joues en solo et tu gagnes si la place te lynche : aie l’air louche ! Mourir la nuit ne compte pas.',
    ),
    Role.piromane: RoleText(
      'Le Pyromane',
      '« Qui n’aime pas un bon feu de joie ? »',
      'Tu joues en solo. Chaque nuit, arrose quelqu’un d’essence, ou mets le feu à tous les arrosés d’un coup. Tu gagnes si tu survis à tous.',
    ),
    Role.cacciatore: RoleText(
      'Le Chasseur de primes',
      '« Rien de personnel. C’est le métier. »',
      'Tu joues en solo, avec une prime sur un joueur de la ville dont tu vois le nom. Si la place le lynche, tu gagnes et la partie s’arrête.',
    ),
    Role.strozzino: RoleText(
      'L’Usurier',
      '« Un débiteur mort ne paie pas. »',
      'Tu joues en solo. Chaque nuit, protège quelqu’un, jamais le même deux nuits de suite. Tu gagnes si tu es en vie à la fin, quel que soit le vainqueur.',
    ),
    Role.sicario: RoleText(
      'Le Tueur à gages',
      '« Je travaille seul. Le café, c’est pour moi. »',
      'Tu joues en solo et tu tues quelqu’un chaque nuit. Attention : le Commissaire te voit de la Famille. Tu gagnes seulement si tu survis à tous.',
    ),
    Role.prostituta: RoleText(
      'L’Entraîneuse',
      '« Une chanson, un verre, et la nuit s’envole. »',
      'Tu joues pour la Famille, sans la connaître ni être connue. Chaque nuit, tu bloques le coup de quelqu’un, jamais le même deux fois de suite. Dernière en lice, tu votes.',
    ),
    Role.carceriere: RoleText(
      'Le Geôlier',
      '« Ici, on parle. Dehors, on meurt. »',
      'Chaque nuit, tu enfermes quelqu’un, jamais le même deux fois de suite : il n’agit pas et personne ne le tue. Interroge-le dans le chat, incognito.',
    ),
    Role.cupido: RoleText(
      'Cupidon',
      '« Deux cœurs, une dot, aucune issue. »',
      'La première nuit, tu lies deux personnes, toi aussi si tu veux. Elles ne gagnent que si les deux vivent ; si l’une meurt, l’autre suit. Tu gagnes avec la ville.',
    ),
    Role.presidente: RoleText(
      'Le Président',
      '« L’État ne négocie pas. »',
      'Tous savent qui tu es, et nul ne peut voter contre toi. Ton escorte te sauve des deux premières attaques ; à la troisième, tu meurs. Si tu meurs, la ville perd.',
    ),
    Role.capoSetta: RoleText(
      'Le Gourou',
      '« Je ne demande pas la foi. Juste de suivre. »',
      'Tu joues en solo : chaque nuit, tu convertis quelqu’un, qui ne gagne plus qu’avec toi sans savoir qui d’autre en est. Tu gagnes quand tous les vivants sont de la secte.',
    ),
    Role.artigliere: RoleText(
      'L’Artilleur',
      '« Je ne chuchote pas. Je tonne. »',
      'Deux coups, un par jour, dès le deuxième jour : pendant le débat, ta cible meurt sur-le-champ. Dès ton premier tir, tous savent qui tu es. Tu gagnes avec la ville.',
    ),
    Role.tiratoreScelto: RoleText(
      'Le Tireur d’élite',
      '« Un souffle, un coup, un nom. »',
      'La nuit, tu mets quelqu’un en joue ; le jour, tu peux lui tirer dessus. Deux balles. Si c’est quelqu’un de la ville, le coup revient et c’est toi qui meurs.',
    ),
    Role.pacifista: RoleText(
      'Le Pacifiste',
      '« Le sang appelle le sang. Moi, la trêve. »',
      'Une fois par partie, le jour, révèle à tous le rôle exact de quelqu’un, et le tien : ce jour-là, pas de vote. Tu gagnes avec la ville.',
    ),
  },
  cities: [
    CitySetting(
      id: 'chicago',
      name: 'Chicago',
      title: 'Chicago, 1929',
      openings: [
        'Chicago, 1929. La Prohibition a fermé les bars et ouvert tout le reste.',
        'Chicago, 1929. La ville du vent. Il emporte ton chapeau, et parfois ce qu’il y a dessous.',
      ],
      scenes: [
        StoryPiece('chicago-loop', 'Extérieur, nuit. Sous le métro aérien du Loop. Un train gronde au-dessus.'),
        StoryPiece('chicago-station', 'Intérieur, nuit. Union Station. La salle d’attente est vide.'),
        StoryPiece('chicago-pier', 'Extérieur, nuit. Navy Pier. Brouillard sur le lac Michigan.'),
        StoryPiece('chicago-jazz', 'Intérieur, nuit. Le Green Mill : de la fumée, et un saxophone.'),
        StoryPiece('chicago-bridge', 'Extérieur, nuit. Un pont basculant sur la Chicago River.'),
        StoryPiece('chicago-market', 'Extérieur, nuit. Le marché de Maxwell Street, tous les étals fermés.'),
        StoryPiece('chicago-speakeasy', 'Intérieur, nuit. Un bar clandestin du South Side.'),
        StoryPiece('chicago-hotel', 'Intérieur, nuit. Le hall du Lexington Hotel. Personne à la réception.'),
      ],
    ),
    CitySetting(
      id: 'new-york',
      name: 'New York',
      title: 'New York, 1947',
      openings: [
        'New York, 1947. Huit millions d’habitants, et pas un seul n’a rien vu.',
        'New York, 1947. La ville qui ne dort jamais. Ce soir, elle devrait essayer.',
      ],
      scenes: [
        StoryPiece('ny-mulberry', 'Extérieur, nuit. Mulberry Street, Little Italy, sous les néons.'),
        StoryPiece('ny-bridge', 'Extérieur, nuit. Sous le pont de Brooklyn. Brouillard sur l’East River.'),
        StoryPiece('ny-station', 'Intérieur, nuit. Grand Central. L’horloge indique trois heures.'),
        StoryPiece('ny-market', 'Extérieur, nuit. Le marché aux poissons de Fulton, entre les caisses.'),
        StoryPiece('ny-coney', 'Extérieur, nuit. Coney Island, hors saison. La grande roue ne tourne plus.'),
        StoryPiece('ny-pier', 'Extérieur, nuit. Un quai sur l’Hudson. Un cargo sans nom.'),
        StoryPiece('ny-diner', 'Intérieur, nuit. Un diner à une rue de Times Square.'),
        StoryPiece('ny-park', 'Extérieur, nuit. Central Park. Un seul réverbère encore allumé.'),
      ],
    ),
    CitySetting(
      id: 'palermo',
      name: 'Palerme',
      title: 'Palerme, 1955',
      openings: [
        'Palerme, 1955. Le plus beau soleil du monde, et des ombres très longues.',
        'Palerme, 1955. Ici, tout le monde sait tout. C’est pour ça que personne ne dit rien.',
      ],
      scenes: [
        StoryPiece('palermo-vucciria', 'Extérieur, nuit. Le marché de la Vucciria, rideaux baissés.'),
        StoryPiece('palermo-teatro', 'Extérieur, nuit. Les marches du Teatro Massimo, entre les deux lions.'),
        StoryPiece('palermo-canti', 'Extérieur, nuit. Les Quattro Canti, déserts. Personne, à part les statues.'),
        StoryPiece('palermo-cala', 'Extérieur, nuit. La Cala, le vieux port. Les barques se balancent.'),
        StoryPiece('palermo-ballaro', 'Extérieur, nuit. Une ruelle de Ballarò, du linge aux fenêtres.'),
        StoryPiece('palermo-mondello', 'Extérieur, nuit. La plage de Mondello, hors saison.'),
        StoryPiece('palermo-foro', 'Extérieur, nuit. Le Foro Italico, sur le front de mer, entre les palmiers.'),
        StoryPiece('palermo-pasticceria', 'Intérieur, nuit. Une pâtisserie du centre historique, rideau baissé.'),
      ],
    ),
    CitySetting(
      id: 'napoli',
      name: 'Naples',
      title: 'Naples, 1950',
      openings: [
        'Naples, 1950. Le Vésuve fume, le café brûle, et quelqu’un ne dormira pas ce soir.',
        'Naples, 1950. Ici, tout le monde chante. Jamais pour la police.',
      ],
      scenes: [
        StoryPiece('napoli-quartieri', 'Extérieur, nuit. Une ruelle des Quartiers espagnols.'),
        StoryPiece('napoli-galleria', 'Intérieur, nuit. La galerie Umberto, vide. Chaque pas résonne.'),
        StoryPiece('napoli-molo', 'Extérieur, nuit. Le quai Beverello. Les ferries ne partent plus.'),
        StoryPiece('napoli-spaccanapoli', 'Extérieur, nuit. Spaccanapoli, droite comme une lame.'),
        StoryPiece('napoli-sancarlo', 'Intérieur, nuit. Le Teatro San Carlo, tous les fauteuils vides.'),
        StoryPiece('napoli-lungomare', 'Extérieur, nuit. Le front de mer, sous le Castel dell’Ovo.'),
        StoryPiece('napoli-funicolare', 'Intérieur, nuit. Le funiculaire de Chiaia, dernière montée de la nuit.'),
        StoryPiece('napoli-pizzeria', 'Intérieur, nuit. Une pizzeria de la Via dei Tribunali, le four éteint.'),
      ],
    ),
    CitySetting(
      id: 'las-vegas',
      name: 'Las Vegas',
      title: 'Las Vegas, 1955',
      openings: [
        'Las Vegas, 1955. Un million d’ampoules dans le désert, pour cacher tout le reste.',
        'Las Vegas, 1955. La maison gagne toujours. Ce soir, tu sauras qui est la maison.',
      ],
      scenes: [
        StoryPiece('vegas-fremont', 'Extérieur, nuit. Fremont Street : mille lumières, pas un témoin.'),
        StoryPiece('vegas-flamingo', 'Intérieur, nuit. La salle de jeu du Flamingo, au petit matin.'),
        StoryPiece('vegas-desert', 'Extérieur, nuit. Le désert des Mojaves. Deux phares, une pelle.'),
        StoryPiece('vegas-nugget', 'Intérieur, nuit. L’arrière-salle du Golden Nugget. Une table de poker.'),
        StoryPiece('vegas-motel', 'Extérieur, nuit. Le parking d’un motel sur le Strip.'),
        StoryPiece('vegas-dam', 'Extérieur, nuit. Le barrage Hoover. En dessous, deux cents mètres de vide.'),
        StoryPiece('vegas-dressing', 'Intérieur, nuit. La loge d’une chanteuse, après le spectacle.'),
        StoryPiece('vegas-chapel', 'Intérieur, nuit. Une chapelle de mariage ouverte toute la nuit.'),
      ],
    ),
  ],
  howToPlay:
      'La nuit, la Famille élimine quelqu’un. Le jour, tout le monde vote pour éliminer quelqu’un. '
      'La ville gagne en éliminant toute la Famille ; la Famille gagne dès qu’elle n’est plus en minorité.',
  firstNights: [
    'La première nuit tombe sur {city}.',
    'L’obscurité s’installe sur {city}. C’est la première nuit.',
    'Première nuit. Dormez bien, si votre conscience vous laisse.',
  ],
  nights: [
    'La nuit retombe sur {city}.',
    'Les réverbères s’éteignent. Quelqu’un a du travail.',
    'C’est la nuit. Quelqu’un a un rendez-vous. Les fleurs, ce sera pour après.',
    'Encore une nuit. À {city}, on commence à dormir avec ses chaussures.',
    'L’obscurité tombe. Même les chiens ont cessé d’aboyer.',
    'Pleine nuit. Les pompes funèbres font des heures sup.',
  ],
  nightInstruction: 'Faites tourner le téléphone. Chacun joue son coup en secret, puis le passe.',
  nobodyDied: 'Personne n’est mort cette nuit.',
  quietDawns: [
    'Les pompes funèbres font part de leur vive inquiétude.',
    'Regardez autour de la table : quelqu’un ici est déçu.',
    'Ne vous installez pas trop. C’est comme ça que ça commence, d’habitude.',
    'Le gardien du cimetière a dormi huit heures d’affilée, et ça ne lui dit rien qui vaille.',
  ],
  secondVictims: ['Et ce n’est pas tout.', 'Changement de décor.', 'Mais la nuit a été longue.'],
  victimFact: 'Parmi les morts de la nuit : {name}. Son rôle reste secret.',
  sniperShots: {
    DeathStory.sniperId: [
      'Une seule détonation, d’une fenêtre lointaine. {name} n’a rien entendu.',
      'Un reflet sur un toit, puis un coup de feu. {name} s’effondre avant l’écho.',
      'Quelqu’un, au loin, a pris son temps pour viser. {name} reste sur le trottoir.',
      'Personne au coin de la rue, cette fois. Juste un viseur, avec {name} en plein centre.',
    ],
    DeathStory.belfryId: [
      'Un reflet en haut du clocher. Puis un coup de cloche, et {name} ne se relève pas.',
      'La cloche sonne l’heure et avale la détonation. {name} reste sur les pavés.',
      'Une nuée de pigeons jaillit du clocher. {name} est déjà à terre.',
    ],
    DeathStory.phoneBoothId: [
      'La cabine sonne. {name} décroche. La vitre éclate en étoile.',
      'Un trou dans la vitre de la cabine, une toile de fissures. {name} glisse au sol.',
      '{name} décroche le combiné. Au bout du fil, personne : seulement la détonation.',
    ],
    DeathStory.carDoorId: [
      '{name} ouvre la portière. Un coup de feu au loin : la voiture ne démarrera pas.',
      'Les clés à la main, un pied sur le marchepied. Puis la détonation, et {name} s’écroule.',
      '{name} allait partir. Le moteur reste froid, la portière grande ouverte.',
    ],
  },
  rescues: {
    DeathStory.rescueId: [
      'Le coup porte, et {name} est à terre. Puis des pas qui courent : le Doc.',
      'On était venu solder le compte de {name}. Le Doc est arrivé avant le curé.',
      '{name} était déjà à terre. Mais le Doc passait justement par là.',
      '{name} s’écroule. Puis une sacoche de cuir s’ouvre d’un coup sec : ce n’est pas fini.',
    ],
    DeathStory.defibrillatorId: [
      '{name} à terre, le cœur arrêté. Le Doc frotte les palettes : on dégage !',
      'Une décharge, rien. Une autre décharge : le cœur de {name} repart.',
      'Le Doc ouvre une boîte pleine de fils. Une étincelle, et {name} respire de nouveau.',
    ],
    DeathStory.pliersId: [
      'Le Doc fouille la blessure de {name} avec une pince. Le plomb sort.',
      'Une balle dans la pince, un bandage sur la poitrine. {name} respire encore.',
      '{name} à terre, le Doc à genoux. « Ding » : la balle tombe dans le plateau.',
    ],
    DeathStory.ambulanceId: [
      'Une sirène au bout de la rue. L’ambulance pile : {name} part sur une civière.',
      '{name} à terre, puis les sirènes. Civière, couverture, et ça file.',
      'L’ambulance s’arrête, gyrophare allumé. Depuis la civière, {name} fait un signe de la main.',
    ],
    DeathStory.stitchesId: [
      'Sous le réverbère, du fil et une aiguille. Le Doc recoud {name}, point par point.',
      'Trois points, un nœud, un coup de ciseaux. {name} se relève.',
      'Le Doc enfile l’aiguille à la lueur du réverbère. {name} ne sent rien.',
    ],
  },
  someone: 'quelqu’un',
  savedFact: 'Cette nuit, quelqu’un a failli mourir, mais quelqu’un est intervenu à temps. Qui ? Ça reste un secret.',
  shrugs: {
    DeathStory.luckyId: [
      '{name} titube, puis tâte sa poche de poitrine : une flasque, bien cabossée.',
      'Le coup porte, et fait « ding ». {name} sort une flasque cabossée.',
      '{name} tient debout : le coup s’est arrêté sur la flasque.',
      '{name} sent un choc dans la poitrine. Sous la veste, une flasque pliée en deux.',
    ],
    DeathStory.bibleId: [
      '{name} sort une Bible de sa poche de poitrine : le coup s’est arrêté là.',
      'Le coup s’arrête dans une Bible de poche. {name} lève les yeux au ciel et dit merci.',
      '{name} sent un choc dans la poitrine. Dans la poche, une Bible trouée à moitié.',
    ],
    DeathStory.jamId: [
      'L’arme vise {name}. « Clic. » Encore « clic. » Le tueur détale.',
      'La détente claque dans le vide : l’arme est enrayée. {name} se retourne, le tueur file.',
      '« Clic, clic. » {name} retrousse ses manches, et la ruelle se vide.',
    ],
    DeathStory.bananaId: [
      'Le tueur marche sur une peau de banane et s’envole en arrière. {name} s’en va.',
      'Une peau de banane, un salto. Le tueur atterrit à plat sur la chaussée : {name} rigole.',
      'Le tueur fonce sur {name}, puis rencontre une peau de banane. La suite, c’est du burlesque.',
    ],
    DeathStory.blackCatId: [
      'Un chat noir saute sur le bras du tueur. Le coup part à côté, {name} reste debout.',
      'Le tueur met {name} en joue. Un chat noir fait voler l’arme.',
      'Ça porte malheur, paraît-il. Mais cette nuit, un chat noir a sauvé {name}.',
    ],
  },
  shruggedFact: 'Cette nuit, quelqu’un a failli mourir, mais le coup a raté. Qui ? Ça reste un secret.',
  methods: [
    StoryPiece('auto', 'Deux phares dans le noir. Une berline noire ne freine pas. {name} se retourne : trop tard.'),
    StoryPiece('pianoforte', 'Une corde lâche. Un piano à queue tombe. {name} lève les yeux.'),
    StoryPiece('veleno', '{name} boit la dernière gorgée de café. Une grimace. Du poison.'),
    StoryPiece('pugnale', 'Une ombre derrière {name}. Une lame. Une fois suffit.'),
    StoryPiece('cemento', 'Deux gorilles tiennent {name}. Un troisième remue le béton.'),
    StoryPiece('cappio', 'Un nœud coulant tombe du noir, derrière {name}. Il se resserre.'),
    StoryPiece('silenziatore', 'Un « pop » étouffé, comme un bouchon de champagne. {name} glisse au sol.'),
    StoryPiece('pacco', '{name} déballe un cadeau. Dedans, quelque chose fait tic-tac. Puis boum.'),
    StoryPiece('lampadario', 'Un craquement. Un lustre en cristal se décroche, juste au-dessus de {name}.'),
    StoryPiece('violino', 'Un étui à violon s’ouvre. Pas de violon dedans. {name} s’écroule.'),
    StoryPiece('cassaforte', 'D’en haut, un coffre-fort. {name} a juste le temps de lire la marque.'),
    StoryPiece('sigaro', '{name} allume un cigare reçu en cadeau. Le cigare fait « boum ».'),
    StoryPiece('mazza', 'Au coin de la rue, une batte de base-ball. Un seul coup. {name} voit des étoiles, puis plus rien.'),
    StoryPiece('lupara', 'Deux canons sciés sortent du noir. Un fracas. {name} vole en arrière.'),
    StoryPiece('raffica', 'Une voiture ralentit. À la fenêtre, une mitraillette. {name} n’a pas le temps de se retourner.'),
    StoryPiece('garrota', 'Un fil d’acier, deux mains gantées. {name} se débat, puis plus rien.'),
    StoryPiece('vaso', 'Un pot de géraniums tombe du troisième. Pas un accident. {name} ne le voit pas venir.'),
    StoryPiece('tombino', 'Une bouche d’égout s’ouvre sous les pieds de {name}. Puis se referme, soigneusement.'),
    StoryPiece('buio', 'Le réverbère s’éteint. Un bruit sourd. Quand la lumière revient, {name} est à terre.'),
    StoryPiece('bacio', 'Un inconnu, un baiser, un rouge à lèvres à tomber. {name} sourit, et tombe.'),
    StoryPiece('boccia', 'Une boule de bowling roule hors du noir. {name} vole comme une quille. Strike.'),
    StoryPiece(
      'pescespada',
      'Un espadon surgit au coin de la rue. En garde, fente. {name} dort avec les poissons, désormais.',
    ),
    StoryPiece(
      'arpione',
      'Un harpon siffle dans le noir et la corde se tend. {name} disparaît au coin de la rue.',
    ),
    StoryPiece('torta', 'Une tarte à la crème, en pleine figure de {name}. Tout le monde rit. Dans la crème, une grenade.'),
    StoryPiece('trombone', 'Un trombone joue dans la ruelle. Le pavillon crache une balle. {name} fait une fausse note.'),
    StoryPiece('tango', 'Un inconnu invite {name} pour un tango. Un tour, un renversé, un poignard.'),
    StoryPiece('rose', 'Un bouquet de roses rouges pour {name}. Parmi les roses, un canon. Des pétales partout.'),
    StoryPiece('lavanderia', 'Une camionnette de blanchisserie s’arrête. Une porte coulisse, deux bras. {name} ne revient pas.'),
  ],
  epilogues: [
    StoryPiece('gatto', 'Un chat a tout vu. Il ne parlera pas.'),
    StoryPiece('mambo', 'Quelque part, une radio joue un mambo.'),
    StoryPiece('tetti', '{city} dort. Ou fait semblant.'),
    StoryPiece('carta', 'Par terre, une carte à jouer. Générique.'),
    StoryPiece('finestra', 'Une fenêtre s’allume, puis s’éteint.'),
    StoryPiece('sipario', 'Le rideau tombe. Personne n’applaudit.'),
    StoryPiece('voce', 'Une voix hors champ : « Rien de personnel. »'),
    StoryPiece('sirene', 'Des sirènes au loin. Toujours en retard.'),
    StoryPiece('cappello', 'Un chapeau roule sur le sol. Coupez.'),
    StoryPiece('continua', 'À l’écran, trois mots : « À suivre… »'),
  ],
  scoops: [
    'Édition spéciale ! {name} fait la une.',
    'La queue au kiosque : le journal ne parle que de {name}.',
    'Les crieurs de journaux hurlent tous le même nom : {name}.',
  ],
  scoopMafia: 'Le journal l’écrit noir sur blanc : {name} est de la Famille.',
  scoopClean: 'Le journal l’écrit noir sur blanc : {name} est réglo.',
  silences: [
    'Aiguille, fil, travail soigné : ce matin, les lèvres de {name} sont cousues.',
    'Quelqu’un a rendu visite à {name} cette nuit. Avec une aiguille et un conseil.',
    'Sur l’oreiller de {name}, une bobine de fil noir. Message reçu.',
  ],
  silencedFact:
      'Aujourd’hui, {name} ne peut pas parler pendant le débat. {name} vote par gestes, et reste éliminable.',
  silencedFactOnline: 'Aujourd’hui, {name} ne peut pas écrire dans le chat de la ville. {name} vote quand même, et reste éliminable.',
  dayInstruction: 'Vous avez {minutes} pour discuter. Ensuite, votez pour qui éliminer.',
  oneMinute: 'une minute',
  manyMinutes: '{minutes} minutes',
  voteCalls: [
    'C’est l’heure. La foule veut un coupable.',
    'Assez parlé. {city} veut un nom.',
    'La foule s’agite. Le bourreau s’échauffe.',
    'Place au vote. Essayez de ne pas vous tromper. Encore.',
  ],
  voteInstruction: 'Décidez à voix haute qui éliminer. Vous pouvez aussi n’éliminer personne.',
  passPhone: 'Passe le téléphone à {name}.',
  curtainHint: 'Les autres regardent ailleurs. Touche seulement quand le téléphone est entre tes mains.',
  cardCurtainHint: 'Tu vas voir ta carte : personne d’autre ne doit regarder.',
  putPhoneDown: 'C’est fait. Pose le téléphone et passe-le.',
  voterTurn: '{name} vote : touche qui tu condamnes.',
  lynchScenes: [
    '{name} monte les marches de l’échafaud. La guillotine brille au soleil.',
    '{name} marche vers la corde, la tête haute. Roulement de tambour.',
    'Un train de marchandises, un aller simple. {name} quitte {city}.',
    'La trappe de l’hôtel de ville grince. {name} jette un dernier regard à la foule.',
    '{name} demande une dernière cigarette. Le bourreau tend du feu.',
    'Gros plan sur les mains liées de {name}. Tout {city} regarde.',
  ],
  cardTurns: 'La carte se retourne. {name} était… {role}.',
  wasMafia: 'Du côté de la Famille.',
  wasCitizen: 'Du côté de la ville.',
  wasNeutral: 'En solo, pour son propre compte.',
  lynchedInnocent: [
    'Beau travail, tout le monde. Vraiment.',
    'Quelqu’un à cette table se retient de sourire.',
    'La Famille vous remercie de votre coopération.',
    'Le bourreau s’excuse, et facture plein tarif quand même.',
  ],
  lynchedMafioso: [
    'Moins un. Mais il y a des amis derrière, et les amis ont la mémoire longue.',
    'Quelqu’un vient de perdre un associé, et ne peut même pas aller à l’enterrement.',
    'Joli coup. Cette nuit, la Famille sera de mauvaise humeur.',
  ],
  lynchedLastMafioso: [
    'La Famille, c’est fini. Toutes les cloches de la ville sonnent.',
    'Plus personne de la Famille. À {city}, enfin, quelqu’un a parlé.',
  ],
  noLynch: [
    'Pour une fois, le bourreau rentre tôt.',
    'Quelqu’un pousse un soupir de soulagement. On se demande qui.',
    'À {city}, ne s’entendre sur rien, c’est la routine.',
  ],
  noLynchFact: 'Personne n’est éliminé aujourd’hui.',
  truces: [
    'Halte, tout le monde. Personne ne pend aujourd’hui.',
    'La place range les cordes : trêve, pour aujourd’hui.',
  ],
  truceFact: 'Le Pacifiste a imposé une trêve : pas de vote aujourd’hui.',
  heartbreaks: [
    'Un cœur s’arrête sans un bruit. L’autre moitié est déjà partie.',
    'Il y a des gens qui ne savent pas rester seuls au monde.',
  ],
  heartbreakFact: 'Le cœur de {name} s’est brisé, sur les pas de l’être aimé.',
  loversWinFact: 'Les deux amants sont en vie : ils gagnent ensemble.',
  escorts: [
    'Un coup de feu dans le noir. Mais un homme en noir est déjà devant le Président, mallette levée.',
    'Un coup de feu, une étincelle, un claquement d’acier. L’escorte ne dort jamais.',
  ],
  escortFact: 'L’escorte a repoussé un attentat contre le Président.',
  presidentFallsFact: 'Le Président est tombé. La ville a perdu.',
  sectWins: [
    'Des bougies s’allument à chaque fenêtre. À {city}, il n’y a plus personne à convertir.',
    'Un chant sourd monte des rues de {city}. Tout le monde a vu la lumière.',
  ],
  sectWinsFact: 'La secte gagne : chaque âme encore en vie suit le Gourou.',
  cannonShots: [
    'Un grondement secoue la place. Les vitres tremblent, les pigeons s’envolent d’un coup.',
    'Le canon tonne une fois. Quand la fumée se dissipe, quelqu’un n’est plus debout.',
    'Feu ! Le sol tremble, les tasses sautent sur les tables du café. Puis, le silence.',
  ],
  cannonFact: 'Un grondement sur la place : l’Artilleur a touché {name}.',
  marksmanShots: [
    'Un coup de feu du clocher. {name} s’effondre au milieu de la place.',
    'Une détonation sèche, de très loin. {name} ne finira jamais sa phrase.',
  ],
  marksmanShotFact: 'Un coup de feu du clocher : {name} quitte la partie.',
  backfires: [
    'Le coup résonne, mais c’est le tireur qui tombe.',
    'Le fusil s’enraye et éclate. Du clocher ne descend que le silence.',
  ],
  backfireFact: 'Le coup est revenu en arrière : le Tireur d’élite visait la ville, et meurt à sa place.',
  citizensWin: [
    '{city} est libre. Dès demain, on dort fenêtres ouvertes. Générique.',
    'Dans la rue, les gens se regardent de nouveau dans les yeux. À l’écran : « Fin ».',
  ],
  citizensWinFact: 'La ville gagne : toute la Famille a été éliminée.',
  mafiaWins: [
    '{city} a de nouveaux patrons, et ils étaient assis à cette table. Générique.',
    'À {city}, personne n’a rien vu. Comme d’habitude. Fondu au noir.',
  ],
  mafiaWinsFact: 'La Famille gagne : la ville n’est plus en majorité.',
  fires: [
    'Une odeur d’essence, une allumette, et la nuit devient orange.',
    'Quelqu’un a craqué une allumette. Quand les pompiers sont arrivés, il ne restait rien.',
  ],
  burnedFact: '{name} a brûlé dans la nuit et quitte la partie.',
  resurrections: [
    'Une main soulève le couvercle du cercueil. La ville a oublié de le clouer.',
    'À l’aube, un fantôme entre au bar et commande un café. Ce n’est pas un fantôme.',
  ],
  resurrectedFact: '{name} revient dans la partie, avec la même carte qu’avant.',
  foolWins: [
    'La corde se balance, avec un sourire au bout. C’était le plan depuis le début.',
    'La foule applaudit, et le Bouffon salue.',
  ],
  foolWinsFact: '{name} était le Bouffon et gagne en solo. La partie continue.',
  arsonistWins: [
    '{city} n’est plus que cendres. Une silhouette s’éloigne en sifflotant, une boîte d’allumettes à la main. Générique.',
    'Plus rien à brûler à {city}. Fondu à l’orange.',
  ],
  arsonistWinsFact: 'Le Pyromane gagne en solo : plus personne pour l’arrêter.',
  bountyWins: [
    'Au fond de la place, quelqu’un compte des billets. La prime est payée.',
    'Un chapeau se soulève dans la foule, en guise de merci. Un plaisir de faire affaire.',
  ],
  loanSharkWinsFact: '{name} était l’Usurier : en vie à la fin, encaisse aussi.',
  bountyWinsFact: '{name} était le Chasseur de primes : encaisse et gagne en solo. La partie s’arrête ici.',
  assassinWins: [
    'Il ne reste que des chaises vides à {city}. Le Tueur à gages paie le café et s’en va.',
    'La dernière lumière s’éteint à {city}. Quelqu’un essuie une lame en sifflotant. Générique.',
  ],
  assassinWinsFact: 'Le Tueur à gages gagne en solo : table rase.',
  mayorRevealed: '{name} est le Maire : aujourd’hui, son vote compte double.',
  watchVisited: 'La nuit dernière, quelqu’un est venu à la porte de {name}.',
  watchQuiet: 'La nuit dernière, personne n’est venu à la porte de {name}.',
  taskPrompts: {
    NightTaskKind.kill: 'Qui la Famille élimine-t-elle cette nuit ?',
    NightTaskKind.silence: 'À qui couds-tu les lèvres cette nuit ?',
    NightTaskKind.protect: 'Qui protèges-tu cette nuit ?',
    NightTaskKind.guard: 'Pour qui fais-tu bouclier cette nuit ?',
    NightTaskKind.investigate: 'Sur qui veux-tu enquêter ?',
    NightTaskKind.dig: 'Quelle tombe ouvres-tu cette nuit ?',
    NightTaskKind.snipe: 'Tu veux tirer sur quelqu’un ?',
    NightTaskKind.scoop: 'Sur qui porte ton scoop ?',
    NightTaskKind.douse: 'Qui arroses-tu d’essence cette nuit ?',
    NightTaskKind.ignite: 'Tu craques l’allumette cette nuit ?',
    NightTaskKind.resurrect: 'Qui ramènes-tu cette nuit ?',
    NightTaskKind.watch: 'Quelle porte surveilles-tu cette nuit ?',
    NightTaskKind.lend: 'Qui protèges-tu cette nuit en lui prêtant de l’argent ?',
    NightTaskKind.stab: 'Qui élimines-tu cette nuit ?',
    NightTaskKind.jail: 'Qui enfermes-tu cette nuit ?',
    NightTaskKind.block: 'Pour qui chantes-tu cette nuit ?',
  },
  taskHints: {
    NightTaskKind.kill: 'Touche un nom : c’est ton vote pour qui meurt. La majorité de la Famille décide.',
    NightTaskKind.silence: 'Touche un nom : pas de parole demain. Une seule fois, à la place de ton vote.',
    NightTaskKind.protect: 'Touche un nom, même le tien : pas de mort cette nuit. Jamais deux nuits de suite.',
    NightTaskKind.guard: 'Touche un nom : si on l’attaque cette nuit, tu meurs à sa place.',
    NightTaskKind.investigate: 'Touche un nom : tu sais tout de suite si c’est la Famille ou la ville.',
    NightTaskKind.dig: 'Touche un mort : son rôle, rien que pour toi, tout de suite.',
    NightTaskKind.snipe: 'Touche un nom : tu tires, et c’est la mort. Une seule balle. Passe pour la garder.',
    NightTaskKind.scoop: 'Touche un nom : à l’aube, tous apprennent son camp. Un seul scoop. Passe pour le garder.',
    NightTaskKind.douse: 'Touche un nom pour l’arroser, en secret. Ou craque l’allumette : tous les arrosés brûlent.',
    NightTaskKind.ignite: 'Touche ton propre nom : tous ceux que tu as arrosés brûlent cette nuit.',
    NightTaskKind.resurrect: 'Touche un mort : retour à l’aube si tu vis. Une seule fois ; passer la garde.',
    NightTaskKind.watch: 'Touche un nom : à l’aube, tu sauras si quelqu’un est passé. Pas qui.',
    NightTaskKind.lend: 'Touche un nom : pas de mort cette nuit. Jamais le même deux fois de suite.',
    NightTaskKind.stab: 'Touche un nom : c’est la mort cette nuit, sauf si quelqu’un protège.',
    NightTaskKind.jail: 'Touche un nom : cette nuit, pas d’action et personne n’y touche. Ça ferme tout de suite.',
    NightTaskKind.block: 'Touche un nom : son coup de cette nuit est perdu. Jamais le même deux nuits de suite.',
    NightTaskKind.decoy: 'Pas de coup cette nuit : touche n’importe quel nom, rien ne se passe. Ça cache ton rôle.',
  },
  decoyPrompts: [
    'Qui te paraît le plus louche ?',
    'À qui ne ferais-tu jamais confiance ?',
    'Qui a la tête de quelqu’un qui cache quelque chose ?',
    'S’il fallait pointer du doigt, ce serait qui ?',
    'Qui joue la meilleure comédie à cette table ?',
  ],
);
