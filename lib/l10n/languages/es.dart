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
import '../shop_strings.dart';
import '../strings_en.dart';

// The whole of the Spanish translation: interface, keyed messages and the
// narrator's script. Spanish, neutral enough for Spain and Latin America ("ustedes", no "vosotros").
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.
//
// Stage names, the same everywhere: el Soldado, el Padrino, el Sastre, el
// Compadre, el Honrado, el Comisario, el Doctor, el Francotirador, el
// Cronista, el Sepulturero, el Guardaespaldas, el Veterano, el Exconvicto,
// el Mesías, el Alcalde, el Portero, el Tonto, el Pirómano, el
// Cazarrecompensas, el Usurero, el Sicario, la Cortesana, el Carcelero, el
// Pacifista. The factions are always "la Familia" and "el pueblo".

final class SpanishStrings extends EnglishStrings {
  const SpanishStrings();

  @override
  AppLanguage get language => AppLanguage.es;
  @override
  NarrationPack get pack => spanishPack;
  @override
  OnlineStrings get online => const SpanishOnlineStrings();
  @override
  ShopStrings get shop => const SpanishShopStrings();
  @override
  Map<String, String> get messages => spanishMessages;

  @override
  String get settings => 'Ajustes';
  @override
  String get alleyPlaque => 'CALLEJÓN DEL SILENCIO';
  @override
  String get tonight => 'SOLO ESTA NOCHE';
  @override
  String get sharedTitle => 'UN TELÉFONO PARA TODOS';
  @override
  String get sharedBlurb => 'Pásalo de mano en mano. Sin red, sin testigos.';
  @override
  String get createRoom => 'CREAR SALA';
  @override
  String get hostName => 'Tú';
  @override
  String get soon => 'MUY PRONTO';
  @override
  String get rankedTitle => 'CLASIFICATORIA';
  @override
  String get rankedBlurb => 'Desconocidos, puntos y una tabla que escalar.';
  @override
  String get rankedTeaser => 'La clasificatoria abre pronto. Mientras tanto, hazte un nombre.';
  @override
  List<String> get homeCaptions => const [
    'Nadie vio nada.',
    'Nadie habla. Alguien muere.',
    'Tú no estabas. Y si estabas, dormías.',
    'En esta ciudad hasta las paredes se callan.',
    'Fiarse está bien. Callarse está mejor.',
    'Quien sabe, calla. Quien habla, no ve el amanecer.',
    'Esta noche alguien no vuelve a casa.',
  ];

  @override
  String get settingsTitle => 'AJUSTES';
  @override
  String get sound => 'Música y efectos';
  @override
  String get soundHint => 'Se oyen incluso con el teléfono en silencio.';
  @override
  String get languageSetting => 'Idioma';
  @override
  String get languageAutomatic => 'Automático (teléfono)';

  @override
  String get narratorTitle => 'NARRADOR';
  @override
  String get whoPullsTheStrings => '¿Quién mueve\nlos hilos?';
  @override
  String get narratorIntro => 'El narrador dirige la partida y conoce todos los roles.';
  @override
  String get pickedByGroup => 'Lo elige el grupo';
  @override
  String get pickedByGroupHint => 'Ustedes deciden quién cuenta la historia. No recibe rol.';
  @override
  String get drawnByCylinder => 'Lo decide el tambor';
  @override
  String get drawnByCylinderHint => 'Un giro del tambor. A quien le toque, narra y no juega.';
  @override
  String get automaticNarrator => 'Narrador automático';
  @override
  String get automaticNarratorHint => 'El teléfono cuenta la historia: juegan todos.';
  @override
  String needAtLeast(int players) => 'Hacen falta al menos $players jugadores';
  @override
  String get whoNarrates => '¿QUIÉN NARRA?';
  @override
  String get drawTitle => 'EL SORTEO';
  @override
  String get whoNarratesTonight => '¿Quién narra\nesta noche?';
  @override
  String get theNarratorIs => 'NARRA';
  @override
  String get continueLabel => 'CONTINUAR';

  @override
  String get cardsTitle => 'LAS CARTAS';
  @override
  String get automatic => 'Automático';
  @override
  String get cardsDealt => 'Las cartas están repartidas';
  @override
  String get shuffling => 'Barajando…';
  @override
  String get checkYourCards => 'MIREN SUS CARTAS';
  @override
  String cardOf(int card, int of) => 'CARTA $card DE $of';
  @override
  String get holdTheCardHint => 'Mantén pulsada la carta para mirarla.\nSuéltala y se da la vuelta.';
  @override
  String get gotIt => 'ENTENDIDO';
  @override
  String get pressAndHold => 'MANTÉN PULSADO';
  @override
  String get youAreFamily => 'ERES DE LA FAMILIA';
  @override
  String get youAreTown => 'ERES DEL PUEBLO';
  @override
  String get youActAlone => 'VAS POR LIBRE';
  @override
  String get yourAccomplices => 'TUS CÓMPLICES';
  @override
  String get familyBadge => 'FAMILIA';
  @override
  String get townBadge => 'PUEBLO';

  @override
  String get passThePhoneTo => 'PASA EL TELÉFONO A';
  @override
  String get nobodyElseLooks => 'Que nadie más mire la pantalla.';
  @override
  String get itsMe => 'SOY YO';
  @override
  String get youBadge => 'TÚ';
  @override
  String get innocentBadge => 'INOCENTE';
  @override
  String get neutralBadge => 'NEUTRAL';
  @override
  String get youAreNeutral => 'JUEGAS POR TU CUENTA';
  @override
  String get arsonistWins => 'Gana un\nlobo solitario';
  @override
  String get wonAlone => 'GANA EN SOLITARIO';
  @override
  String get revealAsMayor => 'Revélate: Alcalde';
  @override
  String get lightTheMatch => 'Enciende la cerilla';
  @override
  String get dousePick => 'Rociar';
  @override
  String get dousedBadge => 'GASOLINA';
  @override
  String get bountyBadge => 'RECOMPENSA';
  @override
  String get bountyLine => 'Hay una recompensa por {name}: consigue que acabe en la horca.';
  @override
  String get readAloud => 'LÉANLO EN VOZ ALTA';
  @override
  String readerReadsAloud(String reader) => '${reader.toUpperCase()} LO LEE EN VOZ ALTA';
  @override
  String get narratorSpeaks => 'HABLA EL NARRADOR';
  @override
  String get narratorOnly => 'SOLO EL NARRADOR';
  @override
  String get holdToSeeRoles => 'Mantén pulsado para ver todos los roles';

  @override
  String nightTitle(int round) => 'NOCHE $round';
  @override
  String get nightFalls => 'Cae la noche';
  @override
  String get startTheNight => 'EMPIEZA LA NOCHE';
  @override
  String get dawnTitle => 'AMANECER';

  @override
  String get dayBreaks => 'Amanece';
  @override
  String get everyoneAlive => 'Siguen todos vivos';
  @override
  String get crimePage => 'La página de sucesos';
  @override
  String get finale => 'EL FINAL';
  @override
  String get openTheFloor => 'QUE HABLE LA PLAZA';
  @override
  String dayTitle(int round) => 'DÍA $round';
  @override
  String get verdictTitle => 'EL VEREDICTO';
  @override
  String get noConviction => 'Sin condena';
  @override
  String get endTitle => 'FIN';
  @override
  String get leaveQuestion => '¿Abandonar la partida?';
  @override
  String get leaveWarning => 'La partida en curso se perderá.';
  @override
  String get stay => 'ME QUEDO';
  @override
  String get leave => 'SALIR';
  @override
  String get leaveTooltip => 'Salir de la partida';
  @override
  String get rolesTooltip => 'Roles, solo para el narrador';
  @override
  String get phoneOnTheTable => 'El teléfono\nen la mesa';
  @override
  String get phoneOnTheTableHint => 'Déjenlo en el centro, donde todos lo vean.\nAnoche pasó algo.';
  @override
  String get lightsDown => 'APAGUEN LAS LUCES';
  @override
  String get pass => 'PASO';
  @override
  String get voteTheHit => 'EL GOLPE';
  @override
  String get sewAMouth => 'COSER UNA BOCA';
  @override
  String get confirm => 'CONFIRMAR';
  @override
  String get doneTitle => 'Hecho.';
  @override
  String get nobodyWillKnow => 'Nadie sabrá lo que elegiste.';
  @override
  String get yourInvestigation => 'TU INVESTIGACIÓN';
  @override
  String get inTheGrave => 'EN LA TUMBA';
  @override
  String wasRole(String role) => 'ERA ${role.toUpperCase()}';
  @override
  String get isFamily => 'ES DE LA FAMILIA';
  @override
  String get isInnocent => 'ES INOCENTE';
  @override
  String get wasWithFamily => 'ERA DE LA FAMILIA';
  @override
  String get wasWithTown => 'ERA DEL PUEBLO';
  @override
  String get done => 'LISTO';
  @override
  String get nobody => 'NADIE';
  @override
  String get condemn => 'CONDENAR';
  @override
  String fateNight(int round) => 'Noche $round';
  @override
  String fateGallows(int round) => 'Horca, día $round';
  @override
  String get stillStanding => 'Sigue en pie';
  @override
  String get familyWins => 'Gana\nla Familia';
  @override
  String get townWins => 'Gana\nel pueblo';
  @override
  String get whoWasWho => 'QUIÉN ERA QUIÉN';
  @override
  String get mostSuspicious => 'LA CARA MÁS TURBIA';
  @override
  String suspicion(String name, int fingers, {required bool rightly}) =>
      '$name, con $fingers ${fingers == 1 ? 'dedo' : 'dedos'} apuntándole desde la oscuridad. '
      '${rightly ? 'Con razón.' : 'Sin razón, al final.'}';
  @override
  String get backHome => 'VOLVER AL CALLEJÓN';
  @override
  String get keepReading => 'SIGUE LEYENDO';
  @override
  String get flipTheCard => 'DA LA VUELTA A LA CARTA';
  @override
  String get timeUp => 'SE ACABÓ EL TIEMPO';
  @override
  String get floorIsOpen => 'LA PLAZA TIENE LA PALABRA';
  @override
  String get plusMinute => '+1 MIN';
  @override
  String get callTheVote => 'A VOTAR';
  @override
  String get accusedStamp => 'ACUSACIÓN';
  @override
  String aliveCount(int alive, int total) => '$alive de $total siguen en pie';

  @override
  String get willSeeDawn => 'VERÁ EL AMANECER';
  @override
  String get wontSeeDawn => 'NO VERÁ EL AMANECER';
  @override
  String get next => 'SIGUIENTE';
  @override
  String get skip => 'SALTAR';

  @override
  String verdictCaption(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'Atardecer, en el muelle.',
    VerdictTake.cartello => 'Las afueras. Un camino de polvo, y nadie que te traiga de vuelta.',
    VerdictTake.treno => 'Estación Central. El último tren de la noche.',
    VerdictTake.cannone => 'Ha llegado el circo a la ciudad. Se busca voluntario.',
    VerdictTake.assoluzione => 'La plaza al caer el sol. Los ánimos se calientan.',
  };
  @override
  String verdictStamp(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'DUERME CON LOS PECES',
    VerdictTake.cartello => 'FUERA DE LA CIUDAD',
    VerdictTake.treno => 'BILLETE SOLO DE IDA',
    VerdictTake.cannone => 'EN ÓRBITA',
    VerdictTake.assoluzione => '',
  };
  @override
  String get verdictLine => 'LA PLAZA HA HABLADO';
  @override
  String get acquittalTitle => 'SIN CONDENA';
  @override
  String get acquittalLine => 'TODOS A CASA. POR ESTA NOCHE.';
  @override
  String get townSign => 'CIUDAD';
  @override
  String verdictWord(VerdictWord word) => switch (word) {
    VerdictWord.thud => '¡PUM!',
    VerdictWord.byeBye => '¡CHAO, CHAO!',
    VerdictWord.glub => 'GLUB',
    VerdictWord.getOut => '¡FUERA!',
    VerdictWord.cough => '¡COF!',
    VerdictWord.toot => '¡CHU-CHU!',
    VerdictWord.sniff => '¡SNIF!',
    VerdictWord.ping => '¡TILÍN!',
    VerdictWord.bonk => '¡BONK!',
    VerdictWord.shrug => '¡BAH!',
  };

  @override
  String get lobbyTitle => 'LA MESA';

  @override
  String get lobbyDebugAdd => '+ PRUEBA';

  @override
  String get lobbyClearTooltip => 'Borrar a todos';

  @override
  String get lobbyEmptyTitle => '¿QUIÉN JUEGA ESTA NOCHE?';

  @override
  String get lobbyEmptyBody => 'Pasen el teléfono: cada uno escribe su nombre y se hace la foto de ficha.';

  @override
  String get lobbyEmptyPlaceholder => '???';

  @override
  String get lobbyTableEmpty => 'MESA VACÍA';

  @override
  String get lobbyReadyHint => 'Cuando quieran.';

  @override
  String get lobbyTableFull => 'Mesa llena: no más de $maxTablePlayers jugadores.';

  @override
  String get lobbyTableFullRefusal => 'La mesa está llena: primero alguien tiene que levantarse.';

  @override
  String get lobbyRosterFull => 'La lista está llena: primero quita a alguien.';

  @override
  String get lobbyGestureHint => 'Toca una cara para sentarla o levantarla.\nMantén pulsado para cambiar el nombre o la foto.';

  @override
  String get lobbyOut => 'FUERA';

  @override
  String get lobbyPrivacy => 'Los nombres y las fotos se quedan en este teléfono.';

  @override
  String get lobbyAdd => 'AÑADIR';

  @override
  String get lobbyStart => 'EMPEZAR';

  @override
  String get lobbyClearTitle => '¿Borrar a todos?';

  @override
  String get lobbyClearBody => 'Se borran todos los nombres y fotos de este teléfono. No se puede deshacer.';

  @override
  String get lobbyClearCancel => 'CANCELAR';

  @override
  String get lobbyClearConfirm => 'BORRAR TODO';

  @override
  String lobbySeated(int seated) => '$seated EN LA MESA';

  @override
  String lobbyMissing(int missing) =>
      missing == 1 ? 'Falta un jugador para empezar.' : 'Faltan $missing jugadores para empezar.';

  @override
  String get personTitleNew => 'FICHA NUEVA';

  @override
  String get personTitleEdit => 'FICHA';

  @override
  String get personPlacardEmpty => 'TU NOMBRE';

  @override
  String get personNameHint => '¿Cómo te llamas?';

  @override
  String get personNameEmpty => 'Sin nombre no hay ficha.';

  @override
  String get personNameTooLong => 'Demasiado largo: $maxNameLength letras como máximo.';

  @override
  String get personNameTaken => 'Alguien ya se llama así.';

  @override
  String get personShoot => 'DISPARAR';

  @override
  String get personReshoot => 'REPETIR';

  @override
  String get personGallery => 'GALERÍA';

  @override
  String get personNoPhoto => 'SIN FOTO';

  @override
  String get personHintDrag => 'Arrastra para centrar la cara';

  @override
  String get personSubmitNew => 'A LA MESA';

  @override
  String get personSubmitEdit => 'GUARDAR';

  @override
  String get personPrivacy => 'La foto se queda en este teléfono: el juego no la envía a ninguna parte.';

  @override
  String get personCameraDenied => 'Sin permiso de cámara. Puedes darlo en Ajustes, o jugar sin foto.';

  @override
  String get personCameraFailed => 'La foto no salió. Inténtalo otra vez, o juega sin ella.';

  @override
  String get personStamp => 'EN ARCHIVO';

  @override
  String get personBookedPass => 'Pasa el teléfono al siguiente.';

  @override
  String get personNext => '¡EL SIGUIENTE!';

  @override
  String get personDone => 'YA ESTAMOS';

  @override
  String get personRemoveTooltip => 'Quitar de la lista';

  @override
  String get personRemoveCancel => 'CANCELAR';

  @override
  String get personRemoveConfirm => 'QUITAR';

  @override
  String get personRemoveBody => 'Se borran el nombre y la foto del teléfono.';

  @override
  String personBookedSeated(String name) => '$name está en la mesa.';

  @override
  String personBookedWatching(String name) => 'La mesa está llena: $name mira por ahora.';

  @override
  String personRemoveTitle(String name) => '¿Quitar a $name?';

  @override
  String verdictName(VerdictTake take) => switch (take) {
        VerdictTake.molo => 'El muelle',
        VerdictTake.cartello => 'Las afueras',
        VerdictTake.treno => 'El último tren',
        VerdictTake.cannone => 'El cañón del circo',
        VerdictTake.assoluzione => 'Sin condena',
      };

  @override
  String get someoneSaved => 'ALGUIEN';

  @override
  String get musicVolumeLabel => 'Música';

  @override
  String get effectsVolumeLabel => 'Efectos de sonido';

  @override
  String get memeMode => 'Modo meme';

  @override
  String get memeModeHint => 'Vine booms, FAAAH y compañía en los grandes momentos.';
}

final class SpanishOnlineStrings extends EnglishOnlineStrings {
  const SpanishOnlineStrings();

  @override
  String get rankedQueueTitle => 'CLASIFICATORIA';
  @override
  String get rankedStart => 'Buscar partida';
  @override
  String get rankedSearching => 'Buscando caras nuevas en la ciudad…';
  @override
  String rankedWaiting(int people) => '$people en espera';
  @override
  String rankedEstimate(String time) => 'Espera estimada: $time';
  @override
  String get rankedCancel => 'Cancelar';
  @override
  String get rankedFound => '¡Mesa encontrada!';
  @override
  String get rankedTestMatch => 'PRUEBA · SIN PUNTOS';
  @override
  String get rankedWarning => 'Quien abandona partidas acaba jugando con quien abandona partidas.';
  @override
  String rankedCooldown(String time) => 'Demasiadas partidas abandonadas: podrás volver a la cola en $time.';
  @override
  String get rankedLobbyTitle => 'SALA DE ESPERA';
  @override
  String rankedSeats(int seated, int size) => '$seated/$size en la mesa';
  @override
  String rankedMissing(int missing) => missing == 1 ? 'Falta un jugador' : 'Faltan $missing jugadores';
  @override
  String rankedStartsIn(int seconds) => 'Mesa llena: empieza en $seconds';
  @override
  String get rankedLeaveLobby => 'Salir de la sala';
  @override
  String get rankedNoPenalty => 'Antes de empezar puedes salir sin penalización.';
  @override
  String get rankedTipsTitle => 'MIENTRAS ESPERAS';
  @override
  String get rankedStrangers => 'Sabrás quién se sienta contigo cuando empiece la partida.';
  @override
  String homeQueued(int n) => '$n esperando mesa';
  @override
  String get rankedSit => 'Siéntate';
  @override
  String get rankedTutorialsTitle => 'Primero, las tres manos de práctica';
  @override
  String get rankedTutorialsBody =>
      'En una mesa clasificatoria solo se sienta quien ha terminado las tres manos de práctica: la Familia, el pueblo y los solitarios. Con amigos puedes jugar ya.';
  @override
  String rankedTutorialName(String faction) => switch (faction) {
        'family' => 'la Familia',
        'town' => 'el pueblo',
        _ => 'el solitario',
      };
  @override
  String rankedTutorialPlay(String name) => 'Juega la mano: $name';
  @override
  String get rankedSkipTutorials => 'Ya conozco el juego';
  @override
  String get rankedSkipTitle => '¿Seguro?';
  @override
  String get rankedSkipBody => 'Te saltas todos los tutoriales y vas directo a la clasificatoria.';
  @override
  String get rankedSkipConfirm => 'Sí, saltar los tutoriales';
  @override
  String get rankedSkipCancel => 'Mejor no';
  @override
  String get rankedPickTable => 'ELIGE TU MESA';
  @override
  String get rankedRules => '12 jugadores · turnos con tiempo · quien abandona paga';
  @override
  String get rankedYourRank => 'TU RANGO';
  @override
  String rankedTowards(String tier) => 'hacia $tier';
  @override
  String get rankedTopTier => 'la cima de la familia';
  @override
  String rankedTableQueued(int n) => '$n en cola';
  @override
  String get rankedTableIt => 'Se habla italiano';
  @override
  String get rankedTableEn => 'Se habla inglés';
  @override
  String homeOnline(int n) => '$n jugadores por la ciudad';
  @override
  List<String> get rankedTips => const [
        'Habla de día, pero no demasiado: los que más gritan acaban en el punto de mira.',
        'Un voto en el último segundo dice mucho de quien lo emite.',
        'La Familia gana cuando iguala en número al pueblo: cuenta cabezas.',
        'Abandonar una partida deja a tu equipo con una pieza menos.',
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
  String get dossierTitle => 'EXPEDIENTE PERSONAL';
  @override
  String get dossierHistory => 'CASOS RECIENTES';
  @override
  String get dossierNoHistory => 'Expediente limpio: todavía ninguna partida.';
  @override
  String get dossierSettings => 'Ajustes';
  @override
  String get dossierConfidential => 'CONFIDENCIAL';
  @override
  String get dossierName => 'NOMBRE';
  @override
  String steamPersona(String persona) => 'En Steam: $persona';
  @override
  String get pictureLabel => 'Foto de perfil';
  @override
  String get pictureGame => 'Avatar del juego';
  @override
  String get pictureSteam => 'Foto de Steam';
  @override
  String handleFromSteam(String persona) => 'Sacado de tu nombre de Steam, “$persona”. ¿Te gusta? Guárdalo o cámbialo.';
  @override
  String get handleSuggestions => 'Libres, parecidos:';
  @override
  String get dossierRank => 'RANGO';
  @override
  String get dossierExperience => 'EXPERIENCIA';
  @override
  String get resultsTitle => 'CÓMO FUE';
  @override
  String get resultsWon => 'Victoria';
  @override
  String get resultsLost => 'Derrota';
  @override
  String get resultsLeft => 'Te fuiste de la ciudad';
  @override
  String resultsXp(int xp) => '+$xp XP';
  @override
  String resultsLevelUp(int level) => '¡Nivel $level!';
  @override
  String resultsCoins(int coins) => '+$coins monedas';
  @override
  String get resultsRatingUp => 'Tu rango sube';
  @override
  String get resultsRatingDown => 'Tu rango baja';
  @override
  String get resultsContinue => 'Continuar';

  @override
  String get posterTitle => 'JUEGA CON\nAMIGOS';
  @override
  String get posterBlurb => 'Una sala en línea: un código o un QR, cada uno con su teléfono.';
  @override
  String get posterStrip => 'ONLINE';

  @override
  String get unavailableTitle => 'NO DISPONIBLE';
  @override
  String get unavailableBody => 'El juego en línea no está disponible en esta versión. Un teléfono para todos funciona como siempre.';

  @override
  String get loginTitle => '¿QUIÉN ERES?';
  @override
  String get loginBody => 'Para jugar en línea hace falta una cuenta: tu perfil y tus amigos te siguen a cualquier teléfono.';
  @override
  String get loginApple => 'Iniciar sesión con Apple';
  @override
  String get loginGoogle => 'Iniciar sesión con Google';
  @override
  String get loginNoProvider => 'En este teléfono todavía no hay forma de iniciar sesión.';
  @override
  String get loginPrivacy => 'La cuenta solo sirve para tu perfil de juego. Un teléfono para todos no necesita cuenta.';

  @override
  String get signIn => 'ENTRAR';
  @override
  String get coachSignIn => 'Inicia sesión para jugar en línea';
  @override
  String roomLinkSignIn(String code) => 'Inicia sesión para entrar en la sala $code.';
  @override
  String get roomLinkInvalid => 'Este enlace no lleva a ninguna sala.';
  @override
  String get technicalReason => 'Motivo técnico';
  @override
  String get pickHandle => 'Elige tu alias';
  @override
  String levelShort(int level) => 'NV. $level';
  @override
  String get level => 'NIVEL';
  @override
  String get coins => 'MONEDAS';
  @override
  String xpProgress(int xp, int next) => '$xp de $next puntos de experiencia';

  @override
  String get testAccount => 'Cuenta de prueba';
  @override
  String get testAccountBody =>
      'Solo para probar la app desde otro teléfono: entra con correo y contraseña, o crea la cuenta si no existe.';
  @override
  String get emailLabel => 'Correo electrónico';
  @override
  String get passwordLabel => 'Contraseña (al menos 6 caracteres)';
  @override
  String get testAccountSubmit => 'ENTRAR O CREAR';

  @override
  String get setupTitle => 'TU PERFIL';
  @override
  String get setupBody => 'Tu alias es también el nombre que ven todos: en la sala, en la mesa y entre amigos.';
  @override
  String get handleLabel => 'Alias';
  @override
  String get handleHint => 'como juan.perez';
  @override
  String get save => 'GUARDAR';
  @override
  String get handleInvalid => 'De 3 a 12 caracteres: minúsculas, números, punto y guion bajo.';
  @override
  String get handleChecking => 'Comprobando si está libre…';
  @override
  String get handleFree => 'Libre: es tuyo si lo quieres.';
  @override
  String handleProblem(HandleProblem problem) => switch (problem) {
        HandleProblem.tooShort => 'Al menos 3 caracteres.',
        HandleProblem.tooLong => '12 caracteres como máximo.',
        HandleProblem.characters => 'Solo minúsculas, números, punto y guion bajo.',
        HandleProblem.start => 'No puede empezar con punto ni guion bajo.',
        HandleProblem.endsWithDot => 'No puede terminar en punto.',
        HandleProblem.doubleDot => 'Nada de dos puntos seguidos.',
        HandleProblem.tooManySymbols => 'Como mucho tres símbolos seguidos.',
        HandleProblem.botName => 'Los nombres que empiezan por "bot" son de los bots.',
        HandleProblem.notAllowed => 'Nombre no permitido.',
      };

  @override
  String get hubTitle => 'JUEGA CON AMIGOS';
  @override
  String signedInAs(String name) => 'Sesión iniciada como $name';
  @override
  String get hubCreate => 'ABRIR UNA SALA';
  @override
  String get hubJoin => 'ENTRAR CON CÓDIGO';
  @override
  String get friends => 'AMIGOS';
  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get joinTitle => 'ENTRAR EN UNA SALA';
  @override
  String get codeLabel => 'Código de la sala';
  @override
  String get joinSubmit => 'ENTRAR';
  @override
  String get scan => 'Escanear el QR';
  @override
  String get codeInvalid => 'El código tiene seis caracteres, sin 0, O, 1, I ni L.';
  @override
  String get scanTitle => 'ESCANEA EL QR';
  @override
  String get scanHint => 'Apunta la cámara al QR del teléfono de quien abrió la sala.';
  @override
  String get scanDenied => 'Sin cámara no se puede leer el QR: escribe el código.';

  @override
  String get roomTitle => 'LA SALA';
  @override
  String get roomShareHint => 'Que escaneen el QR, o léeles el código.';
  @override
  String roomSeated(int seated, int max) => '$seated de $max en la mesa';
  @override
  String get hostBadge => 'ANFITRIÓN';
  @override
  String get addFriend => 'Añadir amigo';
  @override
  String friendRequestSent(String name) => 'Solicitud de amistad enviada a $name.';
  @override
  String nowFriends(String name) => 'Ahora $name y tú son amigos.';
  @override
  String get leaveRoom => 'SALIR DE LA SALA';
  @override
  String get leaveConfirmTitle => '¿Salir de la sala?';
  @override
  String get leaveConfirmBody => 'Tu asiento en la mesa queda libre.';
  @override
  String get leaveConfirm => 'SALIR';
  @override
  String get stay => 'ME QUEDO';
  @override
  String get chooseHostTitle => '¿Quién se queda con la sala?';
  @override
  String get chooseHostBody => 'La sala es tuya: elige quién ocupa tu lugar, y luego sal.';
  @override
  String get botBadge => 'BOT DE PRUEBA';
  @override
  String get testBotsNote => 'Pruebas: los bots ocupan los asientos vacíos.';
  @override
  String get startGame => 'EMPEZAR LA PARTIDA';
  @override
  String startNeeds(int players) => 'Al menos $players personas en la mesa: deja entrar a alguien.';
  @override
  String get waitingForHost => 'Esperando a que se repartan las cartas.';
  @override
  String get rejoin => 'VOLVER A LA MESA';
  @override
  String get gameRunning => 'La partida está en marcha.';
  @override
  String get reconnecting => 'Volviendo a la mesa…';

  @override
  String get gameConnecting => 'Tomando asiento…';
  @override
  String get yourCard => 'TU CARTA';
  @override
  String get yourCardHint => 'Guárdatela: los demás solo ven la suya.';
  @override
  String waitingForOthers(int pending) =>
      pending == 1 ? 'Falta que elija una persona.' : 'Esperando a los demás: faltan $pending por elegir.';
  @override
  String get youAreOut => 'Estás fuera de la partida. Mira cómo termina, y en silencio.';
  @override
  String get voteTitle => 'EL PUEBLO VOTA';
  @override
  String get voteHint => 'Toca a quien quieras condenar. Puedes cambiar de idea mientras la votación siga abierta.';
  @override
  String get abstain => 'ME ABSTENGO';
  @override
  String votedFor(String name) => 'Votaste a $name';
  @override
  String get abstained => 'Te abstuviste';
  @override
  String votesCast(int votes, int alive) => '$votes votos de $alive';
  @override
  String closesIn(String time) => 'La votación cierra en $time';
  @override
  String get rejected => 'Esa jugada no está permitida: inténtalo otra vez.';
  @override
  String get serverSilent => 'El servidor no responde: revisa tu conexión.';
  @override
  String get backToRoom => 'VOLVER A LA SALA';
  @override
  String timeLeft(String time) => 'Quedan $time';
  @override
  String get startingSoon => 'Empezamos juntos…';
  @override
  String get ready => 'LISTO';
  @override
  String get readyWaiting => 'Esperando a los demás…';
  @override
  String get moveRegistered => 'Hecho. La ciudad duerme…';
  @override
  String get voteRegistered => 'registrado ✓';
  @override
  String get sending => 'Enviando…';
  @override
  String get offlineBadge => 'sin conexión';
  @override
  String get leaveAbandonWarning =>
      'Salir ahora cuenta como abandono: ni puntos ni monedas, aunque tu bando gane después.';
  @override
  String get leaveDeadWarning => 'Puedes salir sin penalización, pero si tu bando gana después no recibes premios.';
  @override
  String get resultsAfk => 'Estabas ausente: sin premios';
  @override
  String get gameClosed => 'Se cerró la partida: ya no jugaba nadie.';
  @override
  String get fateLeft => 'Se fue de la ciudad';
  @override
  String get youLeftTown => 'Estuviste fuera demasiado tiempo y te fuiste de la ciudad. Mira cómo termina.';
  @override
  String get youLookOffline => 'El servidor no te oye: los demás te ven sin conexión.';
  @override
  String get connectionLost => 'Conexión perdida.';
  @override
  String get abstainTag => 'se abstiene';
  @override
  String votesFor(int votes) => votes == 1 ? '1 voto' : '$votes votos';
  @override
  String get nightTitleOnline => 'LA NOCHE';
  @override
  String get discussionTitle => 'EL PUEBLO HABLA';
  @override
  String get discussionHint => 'Di lo tuyo en el chat. Luego se vota.';
  @override
  String get accusedTag => 'ACUSACIÓN';
  @override
  String get verdictWaiting => 'El pueblo ha decidido.';
  @override
  String get chatHint => 'Escribe…';
  @override
  String get chatLobby => 'SALA';
  @override
  String get chatTown => 'PUEBLO';
  @override
  String get chatFamily => 'FAMILIA';
  @override
  String get chatEmpty => 'Todavía no hay mensajes.';
  @override
  String get chatNightClosed => 'De noche el pueblo calla.';
  @override
  String get chatDead => 'Desde el más allá solo se lee.';
  @override
  String get chatSilenced => 'El Sastre te cosió la boca: hoy lees y votas, pero no puedes escribir.';
  @override
  String get chatSend => 'Enviar';

  @override
  String get searchHint => 'Buscar por alias';
  @override
  String get requests => 'SOLICITUDES';
  @override
  String get yourFriends => 'TUS AMIGOS';
  @override
  String get waiting => 'PENDIENTES';
  @override
  String get friendsEmpty => 'Todavía no tienes amigos. Busca por alias o añádelos desde una sala.';
  @override
  String get noResults => 'Nadie con ese alias.';
  @override
  String get accept => 'Aceptar';
  @override
  String get decline => 'Rechazar';
  @override
  String get add => 'Añadir';
  @override
  String get remove => 'Quitar';
  @override
  String get withdraw => 'Retirar';

  @override
  String get deviceOneAtATime => 'Puedes jugar en un solo dispositivo a la vez';
  @override
  String deviceContested(String other) => 'Tu cuenta también está abierta en: $other. ¿Dónde quieres jugar?';
  @override
  String get deviceDisplacedTitle => 'Tu cuenta está abierta en otro dispositivo';
  @override
  String deviceDisplaced(String other) => 'Ahora juegas en: $other. Recupéralo desde aquí si quieres.';
  @override
  String get devicePlayHere => 'JUGAR AQUÍ';

  @override
  String get updateTitle => 'Hace falta actualizar';
  @override
  String updateNewRelease(String latest, String current) =>
      'Ha salido la versión $latest y esta es la $current. Actualiza para seguir jugando.';
  @override
  String get updateServer => 'Esta versión ya no puede sentarse a la mesa. Actualiza para seguir jugando.';
  @override
  String get updateButton => 'ACTUALIZAR';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Primero inicia sesión con una cuenta.',
        OnlineFailure.appleDisabled => 'El inicio de sesión con Apple no está activado en el servidor.',
        OnlineFailure.googleDisabled => 'El inicio de sesión con Google no está activado en el servidor.',
        OnlineFailure.emailDisabled => 'El inicio de sesión con correo no está activado en el servidor.',
        OnlineFailure.wrongPassword => 'Contraseña incorrecta para este correo.',
        OnlineFailure.weakPassword => 'Contraseña demasiado débil: al menos 6 caracteres.',
        OnlineFailure.invalidEmail => 'Ese correo no parece válido.',
        OnlineFailure.emailNotConfirmed => 'El servidor pide confirmar el correo: desactívalo para las pruebas.',
        OnlineFailure.profileIncomplete => 'Primero completa tu perfil.',
        OnlineFailure.handleTaken => 'Ese alias ya está ocupado.',
        OnlineFailure.invalidHandle => 'Nombre no válido.',
        OnlineFailure.handleNotAllowed => 'Nombre no permitido.',
        OnlineFailure.roomNotFound => 'No hay ninguna sala con ese código.',
        OnlineFailure.roomClosed => 'Esa sala ya está jugando.',
        OnlineFailure.roomFull => 'La sala está llena.',
        OnlineFailure.hostMustChoose => 'Primero elige quién se queda con la sala.',
        OnlineFailure.playerNotFound => 'Jugador no encontrado.',
        OnlineFailure.notAllowed => 'No permitido.',
        OnlineFailure.requestNotFound => 'Esa solicitud ya no existe.',
        OnlineFailure.messageBlocked => 'Ese mensaje no se puede enviar.',
        OnlineFailure.tooManyMessages => 'Calma: demasiados mensajes seguidos.',
        OnlineFailure.tooManyReports => 'Ya enviaste muchas denuncias. Inténtalo más tarde.',
        OnlineFailure.chatClosed => 'Ahora no puedes escribir aquí.',
        OnlineFailure.reactionClosed => 'Ahora no hay gestos: solo de día, y solo entre los vivos.',
        OnlineFailure.reactionCooldown => 'Calma con los gestos: espera unos segundos.',
        OnlineFailure.reactionCap => 'Ya basta de gestos en esta partida.',
        OnlineFailure.notEnoughCoins => 'No tienes monedas suficientes.',
        OnlineFailure.alreadyOwned => 'Ya lo tienes.',
        OnlineFailure.notOwned => 'Primero cómpralo.',
        OnlineFailure.itemNotFound => 'Esta pieza ya no está en la tienda.',
        OnlineFailure.cancelled => 'Inicio de sesión cancelado.',
        OnlineFailure.rankedCooldown => 'Demasiadas partidas abandonadas: espera un poco antes de volver a la cola.',
        OnlineFailure.alreadyInGame => 'Ya estás en una partida.',
        OnlineFailure.tutorialsRequired => 'Termina las tres manos de práctica para jugar la clasificatoria.',
        OnlineFailure.otherDevice => 'Tu cuenta está abierta en otro dispositivo.',
        OnlineFailure.updateRequired => 'Hace falta actualizar: descarga la nueva versión.',
        OnlineFailure.linkSameAccount => 'Esta cuenta ya está vinculada.',
        OnlineFailure.linkConflict => 'Estas dos cuentas no se pueden unir: ya usan el mismo tipo de inicio de sesión.',
        OnlineFailure.network => 'Sin conexión. Inténtalo dentro de un momento.',
        OnlineFailure.unknown => 'Algo salió mal. Inténtalo otra vez.',
      };
}

final class SpanishShopStrings extends EnglishShopStrings {
  const SpanishShopStrings();

  @override
  String get title => 'LA SASTRERÍA';
  @override
  String get subtitle => 'Sastre y sombrerero · desde 1946';
  @override
  String get greeting => 'Adelante, pruébatelo. El espejo nunca miente.';
  @override
  String get coinsHint => 'Las monedas llegan con cada nivel, y los niveles se ganan ganando.';
  @override
  String get featured => 'EN EL ESCAPARATE';
  @override
  String endsIn(int days) => days <= 1 ? 'Último día' : 'Quedan $days días';
  @override
  String get counterTab => 'MOSTRADOR';
  @override
  String get wardrobeTab => 'ARMARIO';
  @override
  String slot(String slot) => switch (slot) {
    'hat' => 'Sombreros',
    'face' => 'Bigotes',
    'glasses' => 'Gafas',
    'outfit' => 'Trajes',
    'hairdo' => 'Peinados',
    'tattoo' => 'Tatuajes',
    'border' => 'Marcos',
    'nameStyle' => 'Nombres',
    'gesture' => 'Gestos',
    _ => 'Accesorios',
  };
  @override
  String rarity(ShopRarity rarity) => switch (rarity) {
    ShopRarity.base => 'De la casa',
    ShopRarity.comune => 'Común',
    ShopRarity.raro => 'Rara',
    ShopRarity.epico => 'Épica',
    ShopRarity.leggendario => 'Legendaria',
  };
  @override
  String get owned => 'TUYO';
  @override
  String get worn => 'PUESTO';
  @override
  String get free => 'GRATIS';
  @override
  String get buy => 'COMPRAR';
  @override
  String get wear => 'PONÉRSELO';
  @override
  String get takeOff => 'QUITÁRSELO';
  @override
  String get tryingOn => 'Probándote';
  @override
  String confirmTitle(String item) => '¿Comprar: $item?';
  @override
  String confirmBody(int price, int left) => 'Cuesta $price monedas. Te quedarán $left.';
  @override
  String get confirmYes => 'Trato hecho';
  @override
  String get notNow => 'Ahora no';
  @override
  String bought(String item) => 'Ya es tuyo: $item.';
  @override
  String missing(int coins) => 'Te faltan $coins monedas.';
  @override
  String get emptyWardrobe => 'Aquí solo cuelga lo que ya tienes.';
  @override
  String get unavailable => 'La tienda está cerrada: inicia sesión con tu cuenta.';
  @override
  String get brands => 'Marcas';
  @override
  String get allBrands => 'Todas';
  @override
  String get oddities => 'Rarezas';
  @override
  String get calcioHint => 'Las viejas gradas: elige tu equipo.';
  @override
  String brandTagline(ShopBrand brand) => switch (brand) {
    ShopBrand.vaugirard => 'Baúles y maletas · París',
    ShopBrand.arminio => 'Sastrería suave · Milán',
    ShopBrand.cuccioli => 'Marroquinería · Florencia',
    ShopBrand.versalli => 'Oro y barroco · Reggio',
    ShopBrand.chanterelle => 'Alta costura · París',
    ShopBrand.nikea => 'Running y atletismo',
    ShopBrand.adelphi => 'El atletismo de dos hermanos',
  };
  @override
  String dept(ShopDept dept) => switch (dept) {
    ShopDept.window => 'Escaparate',
    ShopDept.hats => 'Sombreros',
    ShopDept.face => 'Cara',
    ShopDept.outfit => 'Trajes',
    ShopDept.vice => 'Vicios',
    ShopDept.scene => 'Escena',
    ShopDept.back => 'Hombros',
    ShopDept.hands => 'Manos',
    ShopDept.frames => 'Marcos',
    ShopDept.gestures => 'Gestos',
  };
  @override
  String ownership(ShopOwnership ownership) => switch (ownership) {
    ShopOwnership.all => 'Todo',
    ShopOwnership.mine => 'Lo mío',
    ShopOwnership.toBuy => 'Por comprar',
  };
  @override
  String get filters => 'Filtros';
  @override
  String get rarityFilter => 'Clase';
  @override
  String get collectionFilter => 'Colección';
  @override
  String get clearFilters => 'Limpiar';
  @override
  String get search => 'Busca una pieza';
  @override
  String count(int shown, int total) => shown == total ? pieces(total) : '$shown de $total';
  @override
  String timeLeft(Duration left) => left.inDays >= 1
      ? '${left.inDays} d ${left.inHours % 24} h'
      : left.inHours >= 1
      ? '${left.inHours} h'
      : '${max(1, left.inMinutes)} min';

  @override
  String get homeSign => 'SASTRE';
  @override
  String get fresh => 'NUEVO';
  @override
  String get allRarities => 'Todas';
  @override
  String get allSlots => 'Todo';
  @override
  String get affordable => 'Me lo puedo permitir';
  @override
  String get cheapFirst => 'Precio ↑';
  @override
  String get dearFirst => 'Precio ↓';
  @override
  String pieces(int count) => count == 1 ? '1 pieza' : '$count piezas';
  @override
  String get emptyShelf => 'No hay nada en este estante.';
  @override
  String get changeFace => 'Cambiar de cara';
  @override
  String get viewBust => 'Personaje';
  @override
  String get viewCard => 'Tarjeta de asiento';
  @override
  String hand(Hand hand) => hand == Hand.left ? 'Izquierda' : 'Derecha';
  @override
  String get changeFaceHint => 'Cara, piel, bigote: pásate por la barbería.';
  @override
  String get back => 'Atrás';
  @override
  String save(int pct) => 'AHORRA $pct%';
  @override
  String get bundlesHeading => 'LOOKS COMPLETOS';
  @override
  String get bundlesHint => 'Todo junto cuesta menos que pieza a pieza.';
  @override
  String get premiumHeading => 'GRAN LUJO';
  @override
  String get premium => 'GRAN LUJO';
  @override
  String get complete => 'COMPLETO';
  @override
  String get buyBundle => 'COMPRARLO TODO';
  @override
  String get bundleContents => 'EN EL LOTE';
  @override
  String get singlesLabel => 'Una a una';
  @override
  String ownedPart(int owned, int total) => 'Tienes $owned de $total: solo pagas el resto.';
  @override
  String bundleConfirmTitle(String bundle) => '¿Comprar $bundle?';
  @override
  String bundleConfirmBody(int price, int saved, int left) =>
      'Cuesta $price monedas, $saved menos que pieza a pieza. Te quedarán $left.';
  @override
  String bundleBought(String bundle) => '$bundle es todo tuyo.';
  @override
  String get seeAll => 'Todos los lotes';
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const spanishMessages = <String, String>{
  // ---- settings
  'settings.audio': 'AUDIO',
  'settings.languageSection': 'IDIOMA',
  'settings.game': 'JUEGO',
  'settings.account': 'CUENTA',
  'settings.privacy': 'PRIVACIDAD Y DATOS',
  'settings.about': 'ACERCA DE',
  'settings.signedInAs': 'Sesión iniciada como @{handle}',
  'settings.signedInNoHandle': 'Sesión iniciada, todavía sin alias',
  'settings.notSignedIn': 'No has iniciado sesión en línea.',
  'settings.privacyPolicy': 'Política de privacidad',
  'settings.terms': 'Condiciones de uso',
  'settings.openOnWeb': 'Abrir en la web',
  'settings.exportData': 'Descargar mis datos',
  'settings.exportHint': 'Todo lo que el servidor guarda de ti, en un archivo JSON.',
  'settings.exportFailed': 'No se pudieron descargar tus datos. Inténtalo otra vez.',
  'settings.deleteAccount': 'Eliminar cuenta',
  'settings.deleteHint': 'Para siempre: perfil, amigos, armario y monedas.',
  'settings.deleteTitle': '¿Eliminar tu cuenta?',
  'settings.deleteBody': 'Perfil, aspecto, amigos, armario, monedas, salas y mensajes: todo fuera, para siempre. De las compras con dinero real queda solo un recibo anónimo, por motivos fiscales.',
  'settings.deleteContinue': 'Continuar',
  'settings.cancel': 'Cancelar',
  'settings.deleteTypePrompt': 'Última palabra: escribe "{word}" para confirmar.',
  'settings.deleteConfirmWord': 'ELIMINAR',
  'settings.deleteForever': 'Eliminar para siempre',
  'settings.deleteDone': 'Cuenta eliminada. Adiós, y gracias.',
  'settings.deleteFailed': 'No se pudo eliminar la cuenta. Inténtalo otra vez.',
  'settings.version': 'Versión',
  'settings.credits': 'Créditos',
  'settings.creditsBody': 'Sonidos y gráficos de Kenney (kenney.nl) y Freesound (freesound.org), con licencia CC0. ¡Gracias!',
  'settings.yourLook': 'TU ASPECTO',
  'settings.barberSign': 'BARBERÍA',
  'settings.changeLook': 'Cambia tu aspecto',
  // ---- desktop
  'desktop.loginSteam': 'Iniciar sesión con Steam',
  'desktop.steamWaiting': 'Termina de iniciar sesión en el navegador y vuelve.',
  'desktop.screen': 'PANTALLA',
  'desktop.windowMode': 'Ventana',
  'desktop.windowed': 'En ventana',
  'desktop.fullscreen': 'Pantalla completa',
  'desktop.borderless': 'Sin bordes',
  'desktop.resolution': 'Resolución',
  'desktop.resolutionHint': 'Las pantallas más anchas juegan en 16:9, con bandas a los lados.',
  'desktop.orientation': 'Orientación',
  'desktop.landscape': 'Horizontal',
  'desktop.portrait': 'Vertical',
  'desktop.linkAccount': 'Vincular cuenta',
  'desktop.linkHint': 'Juega con el mismo perfil en el teléfono y en el PC.',
  'desktop.linkBody': 'Inicia sesión con tu otra cuenta: los dos perfiles se vuelven uno.',
  'desktop.linkWith': 'Vincular {provider}',
  'desktop.linkRule': 'Gana el perfil más antiguo: conserva nombre, monedas, experiencia, armario y puntuación. El otro se cierra para siempre.',
  'desktop.linkWaiting': 'Termina de iniciar sesión en el navegador y vuelve.',
  'desktop.linkDone': 'Cuentas vinculadas.',
  'desktop.linkSwitched': 'Cuentas vinculadas: ahora estás en el perfil más antiguo.',
  'desktop.linkAlready': 'Esta cuenta ya está vinculada.',
  'desktop.close': 'Cerrar',
  'desktop.quit': 'Salir',
  'desktop.quitTitle': '¿Te vas del callejón?',
  'desktop.quitBody': 'El juego se cerrará. Nadie vio nada.',
  'desktop.quitConfirm': 'Salir del juego',
  'desktop.stay': 'Me quedo',
  'desktop.enterHint': 'ENTER para confirmar',
  'desktop.posterEnter': 'Entrar',
  // ---- desktopOnline
  'desktopOnline.hubCreateBody': 'Abre tu propia mesa y sienta a tus amigos con el código.',
  'desktopOnline.hubJoinBody': '¿Alguien te pasó un código? Escríbelo y estás dentro.',
  'desktopOnline.hubFriendsBody': 'Busca por alias, responde a las solicitudes de amistad.',
  'desktopOnline.hubDoors': 'Adónde',
  'desktopOnline.profile': 'Tu perfil',
  'desktopOnline.joinHint': 'Escribe el código y pulsa ENTER.',
  'desktopOnline.invite': 'Invitar a la mesa',
  'desktopOnline.table': 'En la mesa',
  'desktopOnline.search': 'Buscar',
  'desktopOnline.results': 'Encontrados',
  'desktopOnline.searchEmpty': 'Escribe un alias para encontrar a alguien.',
  'desktopOnline.rankedHow': 'Cómo funciona',
  'desktopOnline.freeSeat': 'Asiento libre',
  // ---- desktopGame
  'desktopGame.menu': 'Menú',
  'desktopGame.menuTitle': 'La mesa no espera',
  'desktopGame.menuBody': 'La partida sigue con este menú abierto: el reloj corre para todos.',
  'desktopGame.resume': 'Volver a la mesa',
  'desktopGame.roles': 'Roles en juego',
  'desktopGame.settings': 'Ajustes',
  'desktopGame.leave': 'Salir de la partida',
  'desktopGame.stay': 'Seguir en la mesa',
  'desktopGame.leaveConfirm': 'Salir',
  'desktopGame.keyEnter': 'Enter',
  'desktopGame.chatKeys': 'ENTER para el chat',
  'desktopGame.rightClick': 'Clic derecho en un jugador: denunciar o bloquear',
  'desktopGame.timeLeft': 'Tiempo',
  'desktopGame.table': 'La mesa',
  'desktopGame.you': 'Tú',
  // ---- gameEvent
  'gameEvent.onlyYou': 'SOLO TÚ',
  'gameEvent._team.mafia': 'de la Familia',
  'gameEvent._team.neutral': 'por su cuenta',
  'gameEvent._team': 'inocente',
  'gameEvent._winner.citizens': 'gana el pueblo',
  'gameEvent._winner.mafia': 'gana la Familia',
  'gameEvent._winner.neutral': 'gana un solitario',
  'gameEvent._winner': 'sin ganador',
  'gameEvent.text.night': 'Cae la noche {round}. El pueblo duerme.',
  'gameEvent.text.dawn': 'Amanece el día {round}.',
  'gameEvent.text.dawn.nobodyDiedTonight': 'Esta noche no murió nadie.',
  'gameEvent.text.dawn.foundDead': 'Hallazgo de la noche: {names}.',
  'gameEvent.text.dawn.someoneWasSaved': 'Alguien se salvó.',
  'gameEvent.text.dawn.attacksFoiled': '{saved} ataques frustrados.',
  'gameEvent.text.scoop': 'La exclusiva del periódico: {name} es {role}.',
  'gameEvent.text.scoop.thePaperS': 'La exclusiva del periódico: {name} es {team}.',
  'gameEvent.text.silenced': 'El Sastre le cosió la boca a {name}: hoy, silencio.',
  'gameEvent.text.lynch': 'abstenciones: {abstained}',
  'gameEvent.text.lynch.theSquareCondemns': 'La plaza no condena a nadie.',
  'gameEvent.text.lynch.theSquareCondemns.2': 'La plaza condena a {name}: era {role}.',
  'gameEvent.text.lynch.collectsTheBounty': ' {bountyHunter} cobra la recompensa.',
  'gameEvent.text.mayor': '{name} se revela Alcalde: su voto vale doble.',
  'gameEvent.text.truce': '{name}, el Pacifista, pide una tregua: {target} es {role}. Hoy no se vota.',
  'gameEvent.text.cell': 'Estás en una celda. Esta noche no sales.',
  'gameEvent.text.cell.tonightIsIn': 'Esta noche {name} está en una celda.',
  'gameEvent.text.busy': 'Anoche alguien te entretuvo.',
  'gameEvent.text.left': '{name} se ha ido de la ciudad.',
  'gameEvent.text.end': 'Partida cerrada: no jugaba nadie.',
  'gameEvent.text.end.gameOver': 'Fin de la partida: {winner}.',
  'gameEvent.text.end.wonAlone': ' Gana en solitario: {alone}.',
  'gameEvent.text.found': '{name} era {role}.',
  'gameEvent.text.found.comesUp': '{name} resulta {team}.',
  'gameEvent.text.watch': 'Alguien llamó a la puerta de {name}.',
  'gameEvent.text.watch.nobodyCameTo': 'Nadie llamó a la puerta de {name}.',
  'gameEvent.text.bounty': 'Tu recompensa: que {name} acabe en la horca.',
  'gameEvent.text.doused': 'Rociados de gasolina: {names}.',
  'gameEvent.text.familyTarget': 'La Familia no se puso de acuerdo.',
  'gameEvent.text.familyTarget.theFamilyChose': 'La Familia eligió a {name}.',
  'gameEvent.text.guard': 'Esta noche hiciste guardia por {name}.',
  'gameEvent.text.lend': 'Esta noche le prestaste dinero a {name}.',
  'gameEvent.text.protected': 'Esta noche velaste por {name}.',
  'gameEvent.text.dawn.foundOne': '{gender, select, masculine{Hallado muerto: {name}.} feminine{Hallada muerta: {name}.} other{Víctima de la noche: {name}.}}',
  'gameEvent.text.dawn.backAmongLiving': '{name} vuelve al mundo de los vivos.',
  // ---- progress
  'progress.missions': 'Misiones',
  'progress.achievements': 'Logros',
  'progress.leaderboard': 'Clasificación',
  'progress.daily': 'DIARIAS',
  'progress.weekly': 'SEMANALES',
  'progress.missionsHint': 'Se completan jugando: el premio llega solo. Las partidas abandonadas o inactivas no cuentan.',
  'progress.done': 'HECHA',
  'progress.endsIn': 'acaba en {inDays} días',
  'progress.endsIn.endsInH': 'acaba en {h} h',
  'progress.endsIn.endsInMin': 'acaba en {d} min',
  'progress.loadFailed': 'No se pudo cargar. Inténtalo otra vez.',
  'progress.retry': 'Reintentar',
  'progress.unlockedCount': '{n} de {of}',
  'progress.locked': 'Bloqueado',
  'progress.rewardTitle': 'Título: "{title}"',
  'progress.rewardFrame': 'Marco gratis',
  'progress.title': 'TÍTULO',
  'progress.leaderboardEmpty': 'Todavía no hay nadie en la tabla.',
  'progress.leaderboardHint': 'Los cien mejores de la clasificatoria, por idioma.',
  'progress.yourPlace': 'Estás en el puesto {rank}',
  'progress.notRanked': 'Juega una partida clasificatoria para entrar en la tabla.',
  'progress.missionDone': 'Misión cumplida: {name}',
  'progress.achievementDone': 'Logro: {name}',
  'progress.mission.daily_play_3': 'Juega 3 partidas',
  'progress.mission.daily_win_1': 'Gana una partida',
  'progress.mission.daily_friends_win_2': 'Gana 2 partidas con amigos',
  'progress.mission.daily_lynch_hits_3': 'Vota 3 veces al mafioso correcto',
  'progress.mission.daily_nights_2': 'Sobrevive a 2 noches',
  'progress.mission.daily_ranked_1': 'Juega 1 partida clasificatoria',
  'progress.mission.daily_survive_1': 'Llega con vida al final de una partida',
  'progress.mission.daily_town_win_1': 'Gana con el pueblo',
  'progress.mission.daily_mafia_win_1': 'Gana con la Familia',
  'progress.mission.weekly_neutral_win_1': 'Gana como neutral',
  'progress.mission.weekly_wins_7': 'Gana 7 partidas',
  'progress.mission.weekly_play_15': 'Juega 15 partidas',
  'progress.mission.weekly_lynch_hits_10': 'Vota 10 veces al mafioso correcto',
  'progress.mission.weekly_ranked_5': 'Juega 5 partidas clasificatorias',
  'progress.mission.weekly_ranked_wins_3': 'Gana 3 partidas clasificatorias',
  'progress.mission.weekly_saves_2': 'Salva 2 vidas como el Doctor',
  'progress.mission.weekly_finds_3': 'Desenmascara a 3 mafiosos como el Comisario',
  'progress.mission.weekly_kills_5': 'Da 5 golpes con la Familia',
  'progress.mission.weekly_nights_12': 'Sobrevive a 12 noches',
  'progress.mission': 'Objetivo: {target}',
  'progress.achievement.wins_10': 'Con suerte',
  'progress.achievement': 'Gana 10 partidas',
  'progress.achievement.wins_50': 'Hombre de honor',
  'progress.achievement.winGames': 'Gana 50 partidas',
  'progress.achievement.wins_200': 'Leyenda',
  'progress.achievement.winGames.2': 'Gana 200 partidas',
  'progress.achievement.games_25': 'Habitual',
  'progress.achievement.playGames': 'Juega 25 partidas',
  'progress.achievement.games_100': 'Parte del mobiliario',
  'progress.achievement.playGames.2': 'Juega 100 partidas',
  'progress.achievement.games_500': 'Veterano',
  'progress.achievement.playGames.3': 'Juega 500 partidas',
  'progress.achievement.ranked_wins_10': 'En el tapete verde',
  'progress.achievement.winRankedGames': 'Gana 10 partidas clasificatorias',
  'progress.achievement.ranked_wins_50': 'Jefe',
  'progress.achievement.winRankedGames.2': 'Gana 50 partidas clasificatorias',
  'progress.achievement.friends_wins_25': 'Entre amigos',
  'progress.achievement.winGamesWith': 'Gana 25 partidas con amigos',
  'progress.achievement.town_wins_25': 'Ciudadano modelo',
  'progress.achievement.winTimesWith': 'Gana 25 veces con el pueblo',
  'progress.achievement.mafia_wins_25': 'Iniciado',
  'progress.achievement.winTimesWith.2': 'Gana 25 veces con la Familia',
  'progress.achievement.neutral_wins_1': 'A mi aire',
  'progress.achievement.winAsA': 'Gana como neutral',
  'progress.achievement.neutral_wins_10': 'Lobo solitario',
  'progress.achievement.winTimesAs': 'Gana 10 veces como neutral',
  'progress.achievement.roles_won_5': 'Muchas caras',
  'progress.achievement.winWithDifferent': 'Gana con 5 roles distintos',
  'progress.achievement.roles_won_12': 'Actor curtido',
  'progress.achievement.winWithDifferent.2': 'Gana con 12 roles distintos',
  'progress.achievement.roles_won_all': 'Camaleón',
  'progress.achievement.winWithEvery': 'Gana con todos los roles',
  'progress.achievement.roles_town_all': 'Todo el pueblo',
  'progress.achievement.roles_town_all.goal': 'Gana con todos los roles del pueblo',
  'progress.achievement.roles_mafia_all': 'Toda la Familia',
  'progress.achievement.roles_mafia_all.goal': 'Gana con todos los roles de la Familia',
  'progress.achievement.roles_lone_all': 'Todos los solitarios',
  'progress.achievement.roles_lone_all.goal': 'Gana con todos los roles solitarios',
  'progress.achievement.roleWin': 'Gana una partida con este rol',
  'progress.achievement.wins_alive_25': 'Piel dura',
  'progress.achievement.winTimesStill': 'Gana 25 veces sin morir',
  'progress.achievement.lynch_hits_10': 'Buen olfato',
  'progress.achievement.voteCondemnedMafiosi': 'Vota a 10 mafiosos condenados',
  'progress.achievement.lynch_hits_50': 'Sabueso',
  'progress.achievement.voteCondemnedMafiosi.2': 'Vota a 50 mafiosos condenados',
  'progress.achievement.lynch_hits_200': 'Vengador',
  'progress.achievement.voteCondemnedMafiosi.3': 'Vota a 200 mafiosos condenados',
  'progress.achievement.nights_25': 'Insomne',
  'progress.achievement.surviveNights': 'Sobrevive a 25 noches',
  'progress.achievement.nights_100': 'Ave nocturna',
  'progress.achievement.surviveNights.2': 'Sobrevive a 100 noches',
  'progress.achievement.saves_1': 'Primeros auxilios',
  'progress.achievement.saveALife': 'Salva una vida como el Doctor',
  'progress.achievement.saves_10': 'Ángel de la guarda',
  'progress.achievement.saveLivesAs': 'Salva 10 vidas como el Doctor',
  'progress.achievement.countryDoctor': 'Médico de pueblo',
  'progress.achievement.asTheDoctor': 'Como el Doctor, salva a alguien y llega con vida al final',
  'progress.achievement.finds_10': 'Instinto de policía',
  'progress.achievement.unmaskMafiosiAs': 'Desenmascara a 10 mafiosos como el Comisario',
  'progress.achievement.theInspector': 'El Inspector',
  'progress.achievement.asTheDetective': 'Como el Comisario, manda al Padrino a la horca',
  'progress.achievement.snipes_1': 'Tiro limpio',
  'progress.achievement.asTheSniper': 'Como el Francotirador, abate a un mafioso',
  'progress.achievement.kills_25': 'Mano dura',
  'progress.achievement.successfulHitsWith': '25 golpes logrados con la Familia',
  'progress.achievement.framed_5': 'Intrigante',
  'progress.achievement.asAMafioso': 'Como mafioso, haz condenar a 5 inocentes',
  'progress.achievement.fool_win': 'La última risa',
  'progress.achievement.winAsThe': 'Gana como el Tonto',
  'progress.titleName.man_of_honor': 'Hombre de honor',
  'progress.titleName.legend': 'Leyenda',
  'progress.titleName.veteran': 'Veterano',
  'progress.titleName.boss': 'Jefe',
  'progress.titleName.model_citizen': 'Ciudadano modelo',
  'progress.titleName.made_man': 'Iniciado',
  'progress.titleName.lone_wolf': 'Lobo solitario',
  'progress.titleName.chameleon': 'Camaleón',
  'progress.titleName.bloodhound': 'Sabueso',
  'progress.titleName.night_owl': 'Ave nocturna',
  'progress.titleName.guardian_angel': 'Ángel de la guarda',
  'progress.titleName.inspector': 'El Inspector',
  'progress.titleName.schemer': 'Intrigante',
  // ---- recap
  'recap.open': 'EL INFORME COMPLETO',
  'recap.masthead': 'El Informe Completo',
  'recap.dateLine': 'Edición especial · todas las cartas sobre la mesa',
  'recap.cast': 'Quién era quién',
  'recap.timeline': 'Noche a noche, día a día',
  'recap.night': 'Noche {round}',
  'recap.day': 'Día {round}',
  'recap.won': 'GANA',
  'recap.wonAlone': 'GANA EN SOLITARIO',
  'recap.survived': 'en pie',
  'recap.fell': 'sin vida',
  'recap.left': 'se fue',
  'recap.close': 'CERRAR',
  'recap.you': 'tú',
  'recap.quietNight': 'Una noche sin jugadas.',
  'recap.team.citizens': 'pueblo',
  'recap.team.mafia': 'Familia',
  'recap.team.neutral': 'por su cuenta',
  'recap.winner.citizens': 'Gana el pueblo',
  'recap.winner.mafia': 'Gana la Familia',
  'recap.winner.neutral': 'Gana el Pirómano',
  'recap.winner.null': 'Sin ganador',
  'recap.familyAimed': 'La Familia fue a por {target} ({voters}).',
  'recap.familyNobody': 'La Familia no se puso de acuerdo.',
  'recap.move.silence': 'le cosió la boca a {target}.',
  'recap.move.protect': 'veló por {target}.',
  'recap.move.guard': 'hizo guardia por {target}.',
  'recap.move.snipe': 'disparó a {target}.',
  'recap.move.scoop': 'publicó la exclusiva sobre {target}.',
  'recap.move.douse': 'roció de gasolina a {target}.',
  'recap.move.ignite': 'encendió la cerilla.',
  'recap.move.resurrect': 'devolvió la vida a {target}.',
  'recap.move.lend': 'le prestó dinero a {target}.',
  'recap.move.stab': 'apuñaló a {target}.',
  'recap.move.jail': 'encerró a {target}.',
  'recap.move.block': 'pasó la noche con {target}.',
  'recap.attack.family': 'de la Familia',
  'recap.attack.sniper': 'del Francotirador',
  'recap.attack.fire': 'del fuego',
  'recap.attack.assassin': 'del Sicario',
  'recap.attack.shrugged': '{target} recibió el golpe {by} y sobrevivió.',
  'recap.scoopOut.mafia': 'Sale el periódico: {target} es de la Familia.',
  'recap.scoopOut.citizens': 'Sale el periódico: {target} es inocente.',
  'recap.scoopOut.neutral': 'Sale el periódico: {target} juega por su cuenta.',
  'recap.mayor': '{name} se revela Alcalde: su voto vale doble.',
  'recap.votes': 'La votación',
  'recap.abstained': 'se abstiene',
  'recap.noCondemned': 'La plaza no condena a nadie.',
  'recap.foolWins': '{name} quería justo esto: gana en solitario.',
  'recap.bounty': '{hunter} cobra la recompensa.',
  'recap.exit': '{name} se fue de la ciudad.',
  'recap.leftTown': '{name} ha salido de escena.',
  'recap.wentAway': '{name} se levantó de la mesa.',
  'recap.cameBack': '{name} vuelve a la mesa.',
  'recap.calledOut': '{name} te señala.',
  'recap.move.investigate': 'investigó a {target}: {seen, select, mafia{de la Familia} other{inocente}}.',
  'recap.move.dig': 'desenterró a {target}: era {role}.',
  'recap.move.watch': 'vigiló la puerta de {target}: {visited, select, yes{alguien pasó} other{no pasó nadie}}.',
  'recap.attack.killed': '{target} no sobrevive al golpe {by}.',
  'recap.attack.healed': '{target} recibe el golpe {by}, pero se salva.',
  'recap.risen': '{target} vuelve al mundo de los vivos.',
  'recap.condemned': 'La plaza condena a {name}. Era {role}.',
  // ---- rolesSheet
  'rolesSheet.button': 'ROLES',
  'rolesSheet.title': 'Roles en juego',
  'rolesSheet.subtitle': 'Las cartas de esta partida. Quién las tiene sigue siendo un secreto.',
  'rolesSheet.deckEmpty': 'Todavía no se conoce la baraja.',
  'rolesSheet.legendTitle': 'Qué significan los símbolos',
  'rolesSheet.revealedBy': 'revelado: {name}',
  'rolesSheet.silenced': 'sin voz',
  'rolesSheet.silencedLegend': 'sin voz por el Sastre: hoy no puede escribir, pero sí votar',
  'rolesSheet.offline': 'ausente',
  'rolesSheet.offlineLegend': 'punto gris: el jugador se ha desconectado',
  'rolesSheet.dead': 'muerto',
  'rolesSheet.deadLegend': 'clavel o puñal: el jugador está muerto',
  'rolesSheet.accused': 'acusación',
  'rolesSheet.accusedLegend': 'cinta ACUSACIÓN: quien tiene más votos ahora mismo',
  'rolesSheet.votes': 'votos recibidos',
  'rolesSheet.votesLegend': 'círculo rojo con un número: votos recibidos',
  'rolesSheet.voteNote': 'votó a',
  'rolesSheet.voteNoteLegend': 'nota "→ nombre": a quién votó',
  'rolesSheet.revealedRole': 'rol revelado',
  'rolesSheet.revealedRoleLegend': 'icono o nombre de rol en un asiento: un rol que conoces',
  'rolesSheet.selected': 'tu elección',
  'rolesSheet.meLegend': 'placa dorada con el nombre: eres tú',
  'rolesSheet.teamLabel': 'Bando',
  'rolesSheet.nightLabel': 'De noche',
  'rolesSheet.winLabel': 'Ganas si',
  'rolesSheet.twistLabel': 'Ojo',
  'rolesSheet.teamFamily': 'la Familia',
  'rolesSheet.teamTown': 'el pueblo',
  'rolesSheet.teamAlone': 'por tu cuenta',
  // ---- safety
  'safety.report': 'Denunciar',
  'safety.block': 'Bloquear',
  'safety.unblock': 'Desbloquear',
  'safety.cancel': 'Cancelar',
  'safety.send': 'Enviar',
  'safety.reportTitle': 'Denunciar a {name}',
  'safety.reportWhy': '¿Qué pasó?',
  'safety.reason.language': 'Lenguaje ofensivo',
  'safety.reason.cheating': 'Trampas o abandono de partidas',
  'safety.reason.identity': 'Alias o aspecto inapropiado',
  'safety.reason.spam': 'Spam',
  'safety.reason.other': 'Otro',
  'safety.noteHint': 'Detalles (opcional)',
  'safety.reportPrivate': 'Queda entre nosotros: nunca sabrán quién fue.',
  'safety.reportSent': 'Denuncia recibida. Nosotros nos encargamos.',
  'safety.reportedMessage': 'Mensaje denunciado',
  'safety.blockTitle': '¿Bloquear a {name}?',
  'safety.blockBody': 'Fuera de tu vista: sin mensajes, sin amistad, sin asiento en tus salas. En la clasificatoria se sientan en mesas distintas. Puedes deshacerlo en Ajustes.',
  'safety.muteChat': 'Silenciar chat',
  'safety.unmuteChat': 'Activar chat',
  'safety.chatMuted': 'Ya no ves los mensajes de {name} (solo aquí).',
  'safety.chatUnmuted': 'Vuelves a ver los mensajes de {name}.',
  'safety.seat': 'Asiento {number}',
  'safety.atTable': 'En la mesa',
  'safety.outOfGame': 'Fuera de la partida',
  'safety.inRoom': 'En la sala',
  'safety.blocked': 'Bloqueaste a {name}.',
  'safety.unblocked': 'Desbloqueaste a {name}.',
  'safety.blockedPlayers': 'Jugadores bloqueados',
  'safety.blockedHint': 'A quién bloqueaste, y cómo quitar el bloqueo.',
  'safety.noneBlocked': 'No has bloqueado a nadie.',
  'safety.rulesTitle': 'Normas de la comunidad',
  'safety.rulesHint': 'Cómo nos portamos en la mesa.',
  'safety.rulesEnforcement': 'Puedes denunciar a un jugador tocando su cara en la mesa o manteniendo pulsado uno de sus mensajes. Revisamos cada denuncia: quien rompe las normas puede perder el chat, la clasificatoria o la cuenta. Los mensajes y nombres ofensivos se bloquean automáticamente.',
  'safety.rulesContact': 'Para denuncias urgentes, escribe a',
  'safety.rules.1': 'Miente en el juego, no a las personas. Farolear es parte de Obertà; los insultos, las amenazas y el acoso no.',
  'safety.rules.2': 'Nada de discursos de odio, insultos, contenido sexual ni ataques por origen, religión, género, orientación o discapacidad.',
  'safety.rules.3': 'Los alias y los aspectos deben ser decentes: sin nombres ofensivos, sin hacerse pasar por el equipo o por otro jugador.',
  'safety.rules.4': 'Juega tu partida hasta el final. Abandonar, perder a propósito o aliarse fuera del juego lo estropea para todos.',
  'safety.rules.5': 'Nada de spam, anuncios, enlaces ni datos personales: nunca compartas teléfonos, direcciones ni redes sociales.',
  'safety.rules.6': 'Sé amable con quien empieza. Todos fuimos nuevos alguna vez.',
  // ---- stats
  'stats.tabFile': 'FICHA',
  'stats.tabStats': 'ESTADÍSTICAS',
  'stats.title': 'ESTADÍSTICAS PERSONALES',
  'stats.includeTests': 'Incluir partidas de prueba',
  'stats.games': 'Partidas',
  'stats.wins': 'Ganadas',
  'stats.losses': 'Perdidas',
  'stats.winRate': 'Porcentaje de victorias',
  'stats.atTheTable': 'EN LA MESA',
  'stats.timePlayed': 'Tiempo en la mesa',
  'stats.timeMeasured': 'medido en {timed} de {games} partidas',
  'stats.favouriteRole': 'Rol favorito',
  'stats.longestStreak': 'Mejor racha de victorias',
  'stats.survived': 'Con vida al final',
  'stats.byTable': 'POR MESA',
  'stats.friends': 'Con amigos',
  'stats.ranked': 'Clasificatoria',
  'stats.byFaction': 'POR BANDO',
  'stats.family': 'Familia',
  'stats.town': 'Pueblo',
  'stats.alone': 'Por su cuenta',
  'stats.byRole': 'POR ROL',
  'stats.neverPlayed': 'nunca jugado',
  'stats.feats': 'HAZAÑAS',
  'stats.featsHint': 'De siempre, solo de partidas jugadas hasta el final.',
  'stats.counter.nights': 'Noches sobrevividas',
  'stats.counter.lynch_hits': 'Votos de linchamiento acertados',
  'stats.counter.saves': 'Vidas salvadas como Doctor',
  'stats.counter.finds': 'Culpables encontrados',
  'stats.counter.snipes': 'Disparos de Francotirador',
  'stats.counter.kills': 'Golpes de la Familia',
  'stats.counter.framed': 'Inocentes incriminados',
  'stats.counter.godfather_lynch': 'Padrinos linchados',
  'stats.counter.wins_alive': 'Victorias con vida',
  'stats.private': 'SOLO PARA TI',
  'stats.privateHint': 'Nadie más ve estos números.',
  'stats.abandoned': 'Abandonadas',
  'stats.afk': 'Ausente (AFK)',
  'stats.reserved': 'RESERVADO',
  'stats.empty': 'Todavía no hay partidas en línea. Las estadísticas se escriben solas mientras juegas.',
  'stats.loadFailed': 'No se pudo cargar. Inténtalo otra vez.',
  'stats.retry': 'Reintentar',
  'stats.profile': 'Perfil',
  'stats.publicTitle': 'FICHA PÚBLICA',
  'stats.onRecord': 'EN EL EXPEDIENTE',
  'stats.featured': 'MEDALLAS EN VITRINA',
  'stats.noMedals': 'Todavía no hay medallas.',
  'stats.topRoles': 'ROLES MÁS JUGADOS',
  'stats.closedFile': 'Ficha reservada: sus estadísticas son privadas.',
  'stats.unavailable': 'Perfil no disponible.',
  'stats.publicSwitch': 'Perfil público',
  'stats.publicSwitchHint': 'Los demás ven tus estadísticas, tu rango y tus medallas. Desactivado: solo tu nombre, nivel y retrato.',
  'stats.gamesWins': '{games, plural, one{# partida} other{# partidas}} · {wins} ganadas',
  // ---- table
  'table.holdTheCard': 'Mantén pulsada la carta para mirarla.',
  'table.picked': 'Elegiste a {name}. Puedes cambiar hasta que se acabe el tiempo.',
  'table.passed': 'Pasaste. Todavía puedes elegir a alguien.',
  'table.familyPicks': 'Familia: {picks}',
  'table.nightRunsOut': 'La noche termina cuando se acaba el tiempo.',
  'table.investigate': '¿Investigar a {name}?',
  'table.dig': '¿Desenterrar a {name}?',
  'table.instantAnswer': 'La respuesta llega enseguida, y después no puedes cambiarla.',
  'table.cancel': 'Cancelar',
  'table.jail': '¿Encerrar a {name}?',
  'table.jailBody': 'La celda se cierra al momento: esta noche no podrá actuar y nadie podrá tocarle. No se puede cambiar.',
  'table.youAreJailed': 'Estás en una celda. Esta noche no sales.',
  'table.jailerWantsYou': 'El Carcelero quiere hablar contigo.',
  'table.inYourCell': 'En tu celda: {name}. Interrógale en el chat.',
  'table.mateInCell': 'Esta noche {name} está en una celda.',
  'table.jailChat': 'La celda',
  'table.jailer': 'El Carcelero',
  'table.answerAtDawn': 'Alguien en esta mesa bloquea: la respuesta llega al amanecer.',
  'table.readTheNews': 'Lee las noticias, y luego Listo.',
  'table.votedFor': 'Votaste a {name}. Puedes cambiar de idea.',
  'table.revealMayor': 'Revelarse',
  'table.revealMayorTitle': '¿Revelarte como el Alcalde?',
  'table.revealMayorBody': 'Todos sabrán quién eres, y desde hoy tu voto vale doble.',
  'table.truce': 'Tregua',
  'table.truceHint': 'Toca a quién revelar a todos.',
  'table.truceTitle': 'Alto a todo: ¿revelar a {name}?',
  'table.truceBody': 'Todos verán su rol exacto, y el tuyo. Hoy no se vota. Solo una vez.',
  'table.truceLine': '{pacifist} pidió una tregua: {name} es {role}.',
  'table.truceVerdict': 'Tregua: hoy no se ahorca a nadie.',
  'table.noLynch': 'No se linchó a nadie.',
  'table.chatOpensLater': 'La plaza vuelve a abrir para la discusión.',
  'table.chatOver': 'La partida ha terminado.',
  'table.rejoin': 'Volver',
  'table.leave': 'Salir',
  'table.abstained': 'Te abstuviste. Todavía puedes votar.',
  'table.silenced': '{gender, select, masculine{silenciado} feminine{silenciada} other{sin voz}}',
  'table.lynched': '{gender, select, masculine{Linchado} feminine{Linchada} other{A la horca}}',
  'table.lynchedLine': '{gender, select, masculine{{name} fue linchado.} feminine{{name} fue linchada.} other{La plaza linchó a {name}.}}',
  'table.lynchedLine.role': '{gender, select, masculine{{name} fue linchado. Era {role}.} feminine{{name} fue linchada. Era {role}.} other{La plaza linchó a {name}. Era {role}.}}',
  'table.abstainedVotes': '{n, plural, one{# abstención} other{# abstenciones}}',
  // ---- tutorial
  'tutorial.you': 'Tú',
  'tutorial.skip': 'Saltar',
  'tutorial.exit': 'Salir',
  'tutorial.exitTitle': '¿Salir de la mano de práctica?',
  'tutorial.exitBody': 'No contará como hecha: puedes volver a jugarla cuando quieras.',
  'tutorial.stay': 'Me quedo',
  'tutorial.hint': '¿Primera vez? Tres manos de práctica, una por color.',
  'tutorial.hintGo': 'Probar',
  'tutorial.replay': 'Tutorial',
  'tutorial.replayHint': 'Tres manos de práctica contra los bots.',
  'tutorial.deskButton': 'Tutorial',
  'tutorial.choose': 'Elige un bando para aprender',
  'tutorial.chooseSub': 'Una mano contra cinco bots, en la mesa de verdad.',
  'tutorial.faction.family': 'Familia',
  'tutorial.faction.city': 'Pueblo',
  'tutorial.faction.solo': 'Por tu cuenta',
  'tutorial.pitch.family': 'Mata de noche, miente de día.',
  'tutorial.pitch.city': 'Investiga, desenmascara a la Familia.',
  'tutorial.pitch.solo': 'Haz que te linchen y gana en solitario.',
  'tutorial.done': 'Hecho',
  'tutorial.ready': 'Ya sabes jugar',
  'tutorial.toTheTable': 'A la mesa',
  'tutorial.nextHand': 'Otra mano',
  // ---- tutorialScript
  'tutorialScript.whenYouHave': 'Cuando lo hayas leído, «Listo».',
  'tutorialScript.atDawnYou': 'Al amanecer ves cómo fue la noche.',
  'tutorialScript.theTownWins.city': 'El pueblo gana cuando no queda nadie de la Familia. Las pruebas valen más que la charla.',
  'tutorialScript.youAreThe.city': 'Eres el Comisario. Mantén pulsada la carta, y luego «Listo».',
  'tutorialScript.atNightYou.city': 'De noche investigas. Toca a Vito, asiento 2, y confirma.',
  'tutorialScript.vitoIsFamily.city': 'Vito es de la Familia. Por ahora, solo tú lo sabes.',
  'tutorialScript.brunoNeverHurt.city': 'Bruno nunca hizo daño a nadie. ¿Quién lo quería muerto?',
  'tutorialScript.iWasAt.city': 'Yo estuve en el bar toda la noche. Pregúntenle a 4.',
  'tutorialScript.trueLookAt.city': 'Es verdad. Miren mejor a 6: demasiado tranquilo.',
  'tutorialScript.meDetectiveWhat.city': '¿¿Yo?? Comisario, ¿qué sabe usted?',
  'tutorialScript.iCheckedVito.city': 'Investigué a Vito: Familia.',
  'tutorialScript.isLyingI.city': '2 miente. Lo vi esta noche.',
  'tutorialScript.liarHeJust.city': '¡Mentiroso! Solo quiere confundirlos.',
  'tutorialScript.ifTheDetective.city': 'Si el Comisario lo dice, me apunto.',
  'tutorialScript.meTooWe.city': 'Yo también. Votamos a 2.',
  'tutorialScript.theSquareTalks.city': 'La plaza habla. Di lo que sabes de Vito.',
  'tutorialScript.theyBelieveYou.city': 'Te creen. «Listo», y votamos.',
  'tutorialScript.onSecondThought.city': 'Pensándolo mejor... 2.',
  'tutorialScript.watchTheHands.city': 'Mira las manos: las ideas cambian. Señala a Vito.',
  'tutorialScript.theLynchedShows.city': 'El linchado enseña la carta. La plaza acertó.',
  'tutorialScript.anotherNightCheck.city': 'Otra noche. Investiga a Carmela, asiento 4.',
  'tutorialScript.carmelaIsFamily.city': 'Carmela también es de la Familia.',
  'tutorialScript.tonightTheyCame.city': 'Esta noche vinieron a por ti...',
  'tutorialScript.theDoctorSaved.city': 'El Doctor te salvó. Ahora te toca a ti.',
  'tutorialScript.iWatchedOver.city': 'Esta noche velé por el Comisario. Lo intentaron.',
  'tutorialScript.luckyYouBut.city': 'Qué suerte... pero Vito actuó solo.',
  'tutorialScript.detectiveWhoDid.city': 'Comisario, ¿a quién investigó esta noche?',
  'tutorialScript.carmelaFamily.city': 'Carmela: Familia.',
  'tutorialScript.isTheLast.city': '4 es la última. A votarla.',
  'tutorialScript.ohPleaseIs.city': '¡Por favor! 1 está delirando.',
  'tutorialScript.iSavedYou.city': 'Te salvé: confío en ti.',
  'tutorialScript.weVote.city': 'Votamos a 4.',
  'tutorialScript.lastDayTell.city': 'Último día. Cuéntale a la plaza lo de Carmela.',
  'tutorialScript.goodReadyAnd.city': 'Bien. «Listo», y votamos.',
  'tutorialScript.noWait.city': 'No, espera: 4.',
  'tutorialScript.voteCarmela.city': 'Vota a Carmela.',
  'tutorialScript.noFamilyLeft.city': 'No queda nadie de la Familia: gana el pueblo.',
  'tutorialScript.theFamilyWins.family': 'La Familia gana cuando iguala en número al pueblo. De día, miente bien.',
  'tutorialScript.thisTimeYou.family': 'Esta vez eres de la Familia. Mantén pulsada la carta, y luego «Listo».',
  'tutorialScript.justTheTwo.family': 'Solo nosotros dos. Nadie puede saberlo.',
  'tutorialScript.iSayEnzo.family': 'Yo digo 6, Enzo: demasiadas preguntas. ¿Tú?',
  'tutorialScript.ok.family': 'Vale, 6.',
  'tutorialScript.fineEnzoTonight.family': 'Bien, Enzo esta noche.',
  'tutorialScript.perfectTap.family': 'Perfecto. Toca el 6.',
  'tutorialScript.atNightThe.family': 'De noche la Familia habla en secreto. Responde a Vito.',
  'tutorialScript.nowTapEnzo.family': 'Ahora toca a Enzo, asiento 6: ese es tu voto.',
  'tutorialScript.twoVotesOn.family': 'Dos votos para Enzo: la Familia está de acuerdo.',
  'tutorialScript.enzoLivesThe.family': 'Enzo vive: lo salvó el Doctor. Ya habrá otra ocasión.',
  'tutorialScript.someoneWentTo.family': 'Alguien fue a casa de Enzo esta noche.',
  'tutorialScript.aliveByA.family': 'Vivo de milagro. ¿Quién fue?',
  'tutorialScript.wasOutOn.family': '1 andaba anoche por la calle. Lo vi.',
  'tutorialScript.wellTalk.family': '¿Y bien, 1? Habla.',
  'tutorialScript.easyWasAt.family': 'Calma, 1 estaba en el bar conmigo.',
  'tutorialScript.brunoAccusesFirst.family': 'Bruno acusa primero: quien acusa primero esconde algo.',
  'tutorialScript.iWasAsleep.family': 'Yo dormía. Pero 3 sabe mucho, ¿no?',
  'tutorialScript.brunoIsIn.family': 'Bruno tiene mucha prisa, sí.',
  'tutorialScript.toldYouIs.family': 'Se los dije. 3 es raro.',
  'tutorialScript.whatIAm.family': '¡¿Qué?! ¡Yo estoy limpio!',
  'tutorialScript.theyAccuseYou.family': 'Te acusan. No te defiendas: échale la culpa a Bruno, asiento 3.',
  'tutorialScript.itWorkedReady.family': 'Funcionó. «Listo», y votamos.',
  'tutorialScript.changedMyMind.family': 'Cambié de idea: 3.',
  'tutorialScript.handsAreMoving.family': 'Las manos se mueven. Vota a Bruno, asiento 3, con ellos.',
  'tutorialScript.brunoWasInnocent.family': 'Bruno era inocente. Por hoy, estás a salvo.',
  'tutorialScript.theDoctorSaved.family': 'El Doctor salvó a Enzo. Apuesto a que es 4.',
  'tutorialScript.herTonightYou.family': 'Ella esta noche. ¿Te apuntas?',
  'tutorialScript.iAmIn.family': 'Me apunto: 4.',
  'tutorialScript.fineCarmela.family': 'Bien, Carmela.',
  'tutorialScript.letSGo.family': 'Vamos.',
  'tutorialScript.vitoHasAn.family': 'Vito tiene una idea. Respóndele.',
  'tutorialScript.tapCarmelaSeat.family': 'Toca a Carmela, asiento 4.',
  'tutorialScript.twoAgainstTwo.family': 'Dos contra dos: el pueblo ya no puede ganar.',
  'tutorialScript.soloPlayersHave.solo': 'Los solitarios tienen su propio objetivo: el Tonto gana si lo linchan, y la partida sigue sin él.',
  'tutorialScript.youPlayAlone.solo': 'Juegas por tu cuenta: el Tonto gana si lo linchan. Mantén pulsada la carta.',
  'tutorialScript.theFoolHas.solo': 'El Tonto no tiene poderes: toca a cualquiera para disimular.',
  'tutorialScript.atNightYou.solo': 'De noche no haces nada. Tu trabajo es de día.',
  'tutorialScript.brunoIsGone.solo': 'Bruno ya no está. Ahora hablamos.',
  'tutorialScript.brunoIsDead.solo': 'Bruno está muerto. ¿Alguien vio algo?',
  'tutorialScript.iWasAsleep.solo': 'Yo dormía. Pero 1 estuvo despierto toda la noche.',
  'tutorialScript.yeahDoesNot.solo': 'Sí, 1 no me convence.',
  'tutorialScript.giveHimA.solo': 'Denle una oportunidad. ¿Y bien, 1?',
  'tutorialScript.brunoOneLess.solo': '¿Bruno? Uno menos. No voy a llorar.',
  'tutorialScript.iSayNothing.solo': 'No digo nada. Vótenme, si se atreven.',
  'tutorialScript.youHeardThat.solo': '¿Lo oyeron? ¡Casi una confesión!',
  'tutorialScript.isSeriouslyWeird.solo': '1 es rarísimo. Lo voto.',
  'tutorialScript.sorryYouDid.solo': 'Lo siento, 1: te lo buscaste tú solito.',
  'tutorialScript.actShadySay.solo': 'Que sospechen de ti: di algo que ningún inocente diría.',
  'tutorialScript.theyFellFor.solo': 'Picaron. «Listo», y votamos.',
  'tutorialScript.fineMeToo.solo': 'Vale, yo también: 1.',
  'tutorialScript.everyonePointsAt.solo': 'Todos te señalan. Vota a quien sea: da igual.',
  'tutorialScript.theyLynchedYou.solo': 'Te lincharon: justo lo que querías.',
  // ---- voice
  'voice.title': 'Voz',
  'voice.mode.off': 'Apagada',
  'voice.mode.listen': 'Solo escuchar',
  'voice.mode.mic': 'Micrófono',
  'voice.modeFull': 'Micrófono (pulsa para hablar)',
  'voice.pushToTalk': 'Pulsa para hablar',
  'voice.pushToTalkPhone': 'Mantén pulsado el micrófono para hablar.',
  'voice.pushToTalkDesk': 'Mantén pulsada la V (o el micrófono) para hablar.',
  'voice.holdToTalk': 'Mantén para hablar',
  'voice.holdV': 'Mantén la V',
  'voice.offline': 'Voz sin conexión, reintentando',
  'voice.nightFamily': 'De noche solo habla la Familia',
  'voice.deadListen': 'Los muertos solo escuchan',
  'voice.sewn': 'El Sastre te cosió la boca',
  'voice.jailed': 'En la celda no se habla',
  'voice.voteSilence': 'Durante la votación no se habla',
  'voice.nobodyNow': 'Ahora no habla nadie',
  'voice.opensSoon': 'La voz se abre en un momento',
  'voice.muteVoice': 'Silenciar voz',
  'voice.unmuteVoice': 'Activar voz',
  'voice.mutedHere': 'Silenciado: solo tú dejas de oírle.',
  'voice.micDeniedTitle': 'Micrófono denegado',
  'voice.micDenied': 'Sin acceso al micrófono solo puedes escuchar. Puedes permitirlo en los ajustes del sistema y luego volver a elegir "Micrófono".',
  'voice.openSettings': 'Abrir ajustes',
  'voice.notNow': 'Ahora no',
  'voice.settings': 'Voz en la mesa',
  'voice.settingsHint': 'En las salas con amigos. De día hablan los vivos, de noche solo la Familia. Solo en directo: no se graba nada.',
  'voice.people': 'En la mesa',
  'voice.nobody': 'No escucha nadie más.',
  'voice.mute': 'Silenciar',
  'voice.reportOrBlock': 'Denunciar o bloquear',
  'voice.unmute': 'Activar',
  'voice.blocked': 'Bloqueo: no se oyen entre ustedes.',
  'voice.closed': 'La voz está cerrada ahora mismo.',
  'voice.listening': 'Solo escuchando.',
  'voice.silencedNow': 'Ahora no puedes hablar.',
  'voice.connecting': 'Conectando…',
  'voice.live': 'Te están oyendo',
  'voice.button': 'Voz',
  'voice.micAskTitle': 'El micrófono',
  'voice.micAsk': 'Para hablar en la mesa Obertà usa el micrófono, solo cuando el juego te da la palabra. Tu voz sale en directo y nunca se graba ni se transcribe.',
  'voice.micAllow': 'Usar el micrófono',
  'voice.cancel': 'Cancelar',
  // ---- results
  'results.familyWins': 'GANA LA FAMILIA',
  'results.townWins': 'GANA EL PUEBLO',
  'results.loneWolfWins': 'GANA UN LOBO SOLITARIO',
  'results.youLost': 'HAS PERDIDO',
  'results.bountyPaid': 'LA RECOMPENSA ESTÁ COBRADA',
  'results.loanSharkCashesIn': 'EL USURERO COBRA',
  'results.foolLastLaugh': 'EL TONTO RÍE EL ÚLTIMO',
  'results.hitmanStandsAlone': 'EL SICARIO QUEDA SOLO',
  'results.cityBurns': 'LA CIUDAD ARDE',
  'results.back': 'ATRÁS',
  'results.backToRoom': 'VOLVER A LA SALA',
  'results.playAgain': 'JUGAR OTRA VEZ',
  'results.keysPlayAgainOrBack': 'ENTER  otra partida   ·   ESC  atrás',
  'results.keysBackToRoom': 'ENTER o ESC  volver a la sala',
  'results.level': 'NIVEL {level}',

  // ---- mirror
  'mirror.takeHatOff': 'Quitarse el sombrero',
  'mirror.putHatOn': 'Ponerse el sombrero',
  'mirror.hatOff': 'Sin sombrero',
  'mirror.hatOn': 'Con sombrero',
  'mirror.title': 'El espejo del barbero',
  'mirror.later': 'Luego',
  'mirror.whoSits': '¿Quién se sienta en el sillón?',
  'mirror.presentationHint': 'El barbero sugiere cortes, maquillaje y ropa a juego. Con "Mostrar todo" puedes elegir lo que quieras.',
  'mirror.man': 'Hombre',
  'mirror.woman': 'Mujer',
  'mirror.other': 'Otro',
  'mirror.preferNotToSay': 'Prefiero no decirlo',
  'mirror.showAll': 'Mostrar todo',
  'mirror.saveFace': 'Guardar esta cara',
  'mirror.backToBefore': 'Volver a como estaba',
  'mirror.randomFace': 'Cara al azar',
  'mirror.readyMadeFaces': 'Caras listas',
  'mirror.freeClothes': 'Ropa gratis',
  'mirror.randomShort': 'Al azar',
  'mirror.asItWas': 'Como estaba',
  'mirror.cancel': 'Cancelar',
  'mirror.tab.skin': 'Piel',
  'mirror.tab.hair': 'Pelo',
  'mirror.tab.colour': 'Color',
  'mirror.tab.eyes': 'Ojos',
  'mirror.tab.eyeSize': 'Tamaño de ojos',
  'mirror.tab.iris': 'Iris',
  'mirror.tab.brows': 'Cejas',
  'mirror.tab.nose': 'Nariz',
  'mirror.tab.mouth': 'Boca',
  'mirror.tab.lipstick': 'Pintalabios',
  'mirror.tab.makeUp': 'Maquillaje',
  'mirror.tab.marks': 'Marcas',
  'mirror.tab.age': 'Edad',
  'mirror.tab.head': 'Cabeza',

  // ---- chronicle
  'chronicle.deadJoiner': ' Y ',
  'chronicle.listJoiner': ' y ',
  'chronicle.fire': 'Incendio nocturno: arde {burned}',
  'chronicle.fireWithOthers': 'Incendio nocturno: arde {burned}. También sin vida: {others}',
  'chronicle.risen': '{name} vuelve de la tumba',
  'chronicle.foundDead': 'Sangre en la noche: {names}',
  'chronicle.squareUndecided': 'La plaza no se decide',
  'chronicle.lynched': 'Linchamiento: {name}',
  'chronicle.lynchedFool': 'Linchamiento: {name}, el Tonto, gana',
  'chronicle.lynchedBounty': 'Linchamiento: {name}. {hunter} cobra la recompensa',
  'chronicle.lynchedNeutral': 'Linchamiento: {name}, era {role}',
  'chronicle.lynchedFamily': 'Linchamiento: {name}, uno de la Familia',
  'chronicle.lynchedInnocent': 'Linchamiento: {name}, un inocente',

  // ---- courier
  'courier.masthead': 'El Correo de {city}',
  'courier.dateLine': 'Vol. XIX  ·  Día {round}  ·  {edition}',
  'courier.dawnEdition': 'Edición del alba',

  // ---- gesture
  'gesture.title': 'Un gesto para {name}',
  'gesture.hint': 'Lo ve toda la mesa.',
  'gesture.locked': 'En la tienda',
  'gesture.wait': 'El siguiente en {seconds} s',
  'gesture.report': 'Denunciar o bloquear',
  'gesture.settingTitle': 'Gestos en la mesa',
  'gesture.settingHint': 'Desactivado, nadie puede tirarte puros, rosas ni pescados.',
  'gesture.button': 'Gestos',
  'gesture.pickTarget': '¿A quién le va un gesto?',
  'gesture.pickHint': 'O mantén pulsado un asiento.',
  'gesture.firstHint': 'Lánzale un gesto a alguien: toca «Gestos».',
  // ---- collection
  'collection.title': 'Los roles',
  'collection.settingsHint': 'La colección: cada carta se descubre ganando con ella.',
  'collection.count': '{n} de {of} cartas',
  'collection.hint': 'Cada carta queda boca abajo hasta que ganes una partida con ese rol.',
  'collection.signedOut': 'Inicia sesión para descubrir las cartas y llevar la cuenta de tus partidas.',
  'collection.signIn': 'Iniciar sesión',
  'collection.team.citizens': 'Pueblo',
  'collection.team.mafia': 'Familia',
  'collection.team.neutral': 'Solitarios',
  'collection.locked': 'Boca abajo',
  'collection.lockedBody': 'Carta boca abajo. Gana una partida con este rol para saber qué hace y ver tus números.',
  'collection.playedNoWin': 'Jugada una vez, nunca ganada.',
  'collection.playedNoWin.playedTimesNever': 'Jugada {n} veces, nunca ganada.',
  'collection.neverPlayed': 'Nunca jugada.',
  'collection.played': 'Partidas',
  'collection.wins': 'Ganadas',
  'collection.losses': 'Perdidas',
  'collection.winRate': '% victorias',
  'collection.bestStreak': 'Mejor racha',
  'collection.lastPlayed': 'Última partida',
  'collection.short': '{wins} G · {played} P',
  'collection.close': 'Cerrar',
  'collection.publicCount': 'Roles descubiertos',
  // ---- localRole
  'localRole.wasBusy': 'Anoche alguien te tuvo ocupado: tu jugada se perdió.',
  'localRole.wasJailed': 'Anoche estabas en una celda: tu jugada se perdió.',
  'localRole.jailerAsked': 'El Carcelero preguntaba: «{question}»',
  'localRole.prisonerAnswered': 'Desde la celda, {name} respondió: «{answer}»',
  'localRole.foundFamily': 'Al amanecer: {name} resulta ser de la Familia.',
  'localRole.foundClean': 'Al amanecer: {name} resulta inocente.',
  'localRole.foundRole': 'Al amanecer: {name} era {role}.',
  'localRole.jailedTitle': 'Estás en una celda',
  'localRole.jailedBody': 'Esta noche no sales, y nadie te toca.',
  'localRole.jailerAsks': 'El Carcelero te pregunta:',
  'localRole.answerHint': 'Tu respuesta (solo la lee el Carcelero)',
  'localRole.questionHint': 'Una pregunta para el preso (opcional)',
  'localRole.jailed': '{name} está en tu celda.',
  'localRole.truce': 'Tregua del Pacifista',
  'localRole.whoAreYou': 'Que el Pacifista toque su propia cara.',
  'localRole.notYou': 'Solo el Pacifista puede pedir la tregua.',
  'localRole.whoToReveal': '¿A quién revelas ante todos?',
  'localRole.cancel': 'Cancelar',
  'localRole.confirm': 'Confirmar',
  // ---- localTable
  'localTable.curtainHint': 'Los demás miran a otro lado. Toca solo cuando tengas el teléfono en la mano.',
  'localTable.roleCurtainHint': 'Vas a ver tu carta: nadie más puede mirar.',
  'localTable.backToTable': 'Teléfono al centro de la mesa',
  'localTable.pickedConfirm': 'Elegiste a {name}. Confirma, o toca otro asiento.',
  'localTable.familyNote': 'familia',
  'localTable.cleanNote': 'inocente',
  'localTable.putItDown': 'Listo. Deja el teléfono y pásalo.',
  'localTable.discuss': 'Hablen en voz alta. Luego se vota.',
  'localTable.openVote': 'El teléfono se queda en el centro: se vota de uno en uno, a cara descubierta.',
  'localTable.voterTurn': 'Vota {name}: toca a quién condenas.',
  'localTable.votedLine': '{voter} vota a {target}.',
  'localTable.abstainedLine': '{voter} se abstiene.',
  'localTable.undo': 'Atrás',
  'localTable.notTheMayor': 'Solo el Alcalde puede revelarse.',
};

// The narrator's script, read on screen (no recorded voice yet). The same
// rules as the other packs: short lines; never a player's gender (the name,
// "alguien", or turn the sentence); real cities and places, made-up people;
// nobody closes their eyes; the factions are always "la Familia" and "el
// pueblo". Translate the line, not the words.
const spanishPack = NarrationPack(
  roles: {
    Role.mafioso: RoleText(
      'El Soldado',
      '«Nada personal.»',
      'Eres de la Familia. Cada noche eliges con la Familia quién muere. Ganan cuando son tantos como todos los demás.',
    ),
    Role.padrino: RoleText(
      'El Padrino',
      '«Yo solo hago favores. Pregunten por ahí.»',
      'Mandas en la Familia: cada noche eliges con ellos quién muere. Ojo: el Comisario te ve inocente. Ganas con la Familia.',
    ),
    Role.sarto: RoleText(
      'El Sastre',
      '«De día coso trajes. De noche, bocas.»',
      'Eres de la Familia y de noche matas con ellos. Una vez por partida puedes dejar a alguien sin voz un día entero. Ganas con la Familia.',
    ),
    Role.compare: RoleText(
      'El Compadre',
      '«Yo solo pasaba por aquí.»',
      'Eres de la Familia y de noche matas con ellos. Mientras vivas, la Familia puede hablar en secreto también de día.',
    ),
    Role.cittadino: RoleText(
      'El Honrado',
      '«Yo no vi nada. Por desgracia, es verdad.»',
      'No tienes poderes. De día escucha, acusa y vota para dar con los asesinos. Ganas con el pueblo cuando no queda ninguno.',
    ),
    Role.detective: RoleText(
      'El Comisario',
      '«Todos mienten. Algunos, mejor.»',
      'Cada noche eliges a alguien y sabes si es de la Familia. Ojo: algunas cartas engañan, el Padrino por ejemplo te sale inocente.',
    ),
    Role.medico: RoleText(
      'El Doctor',
      '«Coso lo que otros rompen.»',
      'Cada noche eliges a alguien, incluso a ti: si lo atacan, se salva. Nunca la misma persona dos noches seguidas.',
    ),
    Role.cecchino: RoleText(
      'El Francotirador',
      '«Un disparo. No dos.»',
      'Tienes una sola bala en toda la partida: una noche eliges quién muere. Úsala bien, puedes fallar de persona. Ganas con el pueblo.',
    ),
    Role.giornalista: RoleText(
      'El Cronista',
      '«La verdad sale en el quiosco a las seis.»',
      'Una vez por partida, de noche, eliges a alguien: al amanecer todos sabrán de qué bando es. Si mueres esa noche, la noticia no sale.',
    ),
    Role.becchino: RoleText(
      'El Sepulturero',
      '«Mis clientes nunca mienten.»',
      'Cada noche puedes elegir a alguien muerto de noche y saber qué rol tenía. Solo lo sabes tú. Ganas con el pueblo.',
    ),
    Role.guardaspalle: RoleText(
      'El Guardaespaldas',
      '«Primero tendrán que pasar por mí.»',
      'Cada noche proteges a alguien: si lo atacan, mueres tú en su lugar. Ganas con el pueblo.',
    ),
    Role.reduce: RoleText(
      'El Veterano',
      '«Ya me dispararon. Gente con mejor puntería.»',
      'De noche no haces nada, pero cuesta matarte: el primer ataque nocturno contra ti falla. Ganas con el pueblo.',
    ),
    Role.pregiudicato: RoleText(
      'El Exconvicto',
      '«Ya pagué. Mis antecedentes, no.»',
      'Eres del pueblo, pero ojo: el Comisario te ve de la Familia. Tendrás que convencer a los demás de tu inocencia.',
    ),
    Role.messia: RoleText(
      'El Mesías',
      '«Levántate. Todavía no has terminado.»',
      'Una vez por partida, de noche, puedes devolver la vida a cualquiera de los muertos. Ganas con el pueblo.',
    ),
    Role.sindaco: RoleText(
      'El Alcalde',
      '«No gané las elecciones para callarme.»',
      'Una vez por partida, durante la votación, puedes revelarte: desde entonces tu voto vale doble. Ganas con el pueblo.',
    ),
    Role.portinaio: RoleText(
      'El Portero',
      '«No pregunto quién. Miro la puerta.»',
      'Cada noche vigilas la puerta de alguien: al amanecer sabes si alguien pasó por allí, pero no quién. Ganas con el pueblo.',
    ),
    Role.fesso: RoleText(
      'El Tonto',
      '«¿Culpable yo? Pues claro que sí.»',
      'Juegas por tu cuenta y ganas si la plaza te lincha: ¡haz que sospechen! Morir de noche no cuenta.',
    ),
    Role.piromane: RoleText(
      'El Pirómano',
      '«¿A quién no le gusta una buena hoguera?»',
      'Juegas por tu cuenta. Cada noche rocías de gasolina a alguien, o prendes fuego a todos los rociados a la vez. Ganas si quedas en pie al final.',
    ),
    Role.cacciatore: RoleText(
      'El Cazarrecompensas',
      '«Nada personal. Son negocios.»',
      'Juegas por tu cuenta y tienes una recompensa por alguien del pueblo, cuyo nombre ves. Si la plaza lo lincha, ganas y la partida acaba.',
    ),
    Role.strozzino: RoleText(
      'El Usurero',
      '«Un deudor muerto no paga.»',
      'Juegas por tu cuenta. Cada noche proteges a alguien, nunca dos noches seguidas. Ganas si sigues con vida al final, gane quien gane.',
    ),
    Role.sicario: RoleText(
      'El Sicario',
      '«Trabajo solo. El café lo pago yo.»',
      'Juegas por tu cuenta y cada noche matas a alguien. Ojo: el Comisario te ve de la Familia. Solo ganas si quedas en pie al final.',
    ),
    Role.prostituta: RoleText(
      'La Cortesana',
      '«Una canción, una copa, y la noche vuela.»',
      'Eres de la Familia pero no votas el golpe: cada noche bloqueas la jugada de alguien, nunca dos seguidas. Si nadie más puede votar, votas tú.',
    ),
    Role.carceriere: RoleText(
      'El Carcelero',
      '«Aquí dentro se habla. Ahí fuera se muere.»',
      'Cada noche encierras a alguien, nunca dos seguidas: no actúa y nadie puede matarlo. Lo interrogas en el chat, sin que sepa quién eres.',
    ),
    Role.pacifista: RoleText(
      'El Pacifista',
      '«La sangre llama a la sangre. Yo, a la tregua.»',
      'Una vez por partida, de día, revelas a todos el rol exacto de alguien, y el tuyo: ese día no se vota. Ganas con el pueblo.',
    ),
  },
  cities: [
    CitySetting(
      id: 'chicago',
      name: 'Chicago',
      title: 'Chicago, 1929',
      openings: [
        'Chicago, 1929. La Ley Seca cerró los bares y abrió todo lo demás.',
        'Chicago, 1929. La Ciudad del Viento. Se lleva tu sombrero, y a veces lo que va debajo.',
      ],
      scenes: [
        StoryPiece('chicago-loop', 'Exterior, noche. Bajo las vías del L, en el Loop. Un tren traquetea encima.'),
        StoryPiece('chicago-station', 'Interior, noche. Union Station. La sala de espera, vacía.'),
        StoryPiece('chicago-pier', 'Exterior, noche. Navy Pier. Niebla sobre el lago Michigan.'),
        StoryPiece('chicago-jazz', 'Interior, noche. El Green Mill: humo, y un saxofón.'),
        StoryPiece('chicago-bridge', 'Exterior, noche. Un puente levadizo sobre el río Chicago.'),
        StoryPiece('chicago-market', 'Exterior, noche. El mercado de Maxwell Street, con todos los puestos cerrados.'),
        StoryPiece('chicago-speakeasy', 'Interior, noche. Un bar clandestino en el South Side.'),
        StoryPiece('chicago-hotel', 'Interior, noche. El vestíbulo del Lexington Hotel. Nadie en recepción.'),
      ],
    ),
    CitySetting(
      id: 'new-york',
      name: 'Nueva York',
      title: 'Nueva York, 1947',
      openings: [
        'Nueva York, 1947. Ocho millones de personas, y ninguna vio nada.',
        'Nueva York, 1947. La ciudad que nunca duerme. Esta noche debería intentarlo.',
      ],
      scenes: [
        StoryPiece('ny-mulberry', 'Exterior, noche. Mulberry Street, Little Italy, bajo los neones.'),
        StoryPiece('ny-bridge', 'Exterior, noche. Bajo el puente de Brooklyn. Niebla sobre el East River.'),
        StoryPiece('ny-station', 'Interior, noche. Grand Central. El reloj marca las tres.'),
        StoryPiece('ny-market', 'Exterior, noche. El mercado de pescado de Fulton, entre las cajas.'),
        StoryPiece('ny-coney', 'Exterior, noche. Coney Island, fuera de temporada. La noria Wonder Wheel, quieta.'),
        StoryPiece('ny-pier', 'Exterior, noche. Un muelle del Hudson. Un carguero sin nombre.'),
        StoryPiece('ny-diner', 'Interior, noche. Una cafetería a una cuadra de Times Square.'),
        StoryPiece('ny-park', 'Exterior, noche. Central Park. Solo queda una farola encendida.'),
      ],
    ),
    CitySetting(
      id: 'palermo',
      name: 'Palermo',
      title: 'Palermo, 1955',
      openings: [
        'Palermo, 1955. El mejor sol del mundo, y unas sombras larguísimas.',
        'Palermo, 1955. Aquí todos lo saben todo. Por eso nadie dice nada.',
      ],
      scenes: [
        StoryPiece('palermo-vucciria', 'Exterior, noche. El mercado de la Vucciria, cerrado a cal y canto.'),
        StoryPiece('palermo-teatro', 'Exterior, noche. La escalinata del Teatro Massimo, entre los dos leones.'),
        StoryPiece('palermo-canti', 'Exterior, noche. Los Quattro Canti, desiertos. Solo las estatuas.'),
        StoryPiece('palermo-cala', 'Exterior, noche. La Cala, el puerto viejo. Las barcas se mecen.'),
        StoryPiece('palermo-ballaro', 'Exterior, noche. Un callejón de Ballarò, con la ropa tendida.'),
        StoryPiece('palermo-mondello', 'Exterior, noche. La playa de Mondello, fuera de temporada.'),
        StoryPiece('palermo-foro', 'Exterior, noche. El Foro Italico, frente al mar, entre las palmeras.'),
        StoryPiece('palermo-pasticceria', 'Interior, noche. Una pastelería del centro histórico, con la persiana bajada.'),
      ],
    ),
    CitySetting(
      id: 'napoli',
      name: 'Nápoles',
      title: 'Nápoles, 1950',
      openings: [
        'Nápoles, 1950. El Vesubio humea, el café quema, y alguien no duerme esta noche.',
        'Nápoles, 1950. Aquí todo el mundo canta. Pero nunca a la policía.',
      ],
      scenes: [
        StoryPiece('napoli-quartieri', 'Exterior, noche. Un callejón de los Quartieri Spagnoli.'),
        StoryPiece('napoli-galleria', 'Interior, noche. La Galleria Umberto, vacía. Cada paso retumba.'),
        StoryPiece('napoli-molo', 'Exterior, noche. El muelle Beverello. Los ferris no salen.'),
        StoryPiece('napoli-spaccanapoli', 'Exterior, noche. Spaccanapoli, recta como una navaja.'),
        StoryPiece('napoli-sancarlo', 'Interior, noche. El Teatro San Carlo, con todas las butacas vacías.'),
        StoryPiece('napoli-lungomare', 'Exterior, noche. El paseo marítimo, bajo el Castel dell\'Ovo.'),
        StoryPiece('napoli-funicolare', 'Interior, noche. El funicular de Chiaia, último viaje de la noche.'),
        StoryPiece('napoli-pizzeria', 'Interior, noche. Una pizzería de Via dei Tribunali, con el horno ya frío.'),
      ],
    ),
    CitySetting(
      id: 'las-vegas',
      name: 'Las Vegas',
      title: 'Las Vegas, 1955',
      openings: [
        'Las Vegas, 1955. Un millón de bombillas en el desierto, para esconder todo lo demás.',
        'Las Vegas, 1955. La casa siempre gana. Esta noche sabrás quién es la casa.',
      ],
      scenes: [
        StoryPiece('vegas-fremont', 'Exterior, noche. Fremont Street: mil luces, ni un testigo.'),
        StoryPiece('vegas-flamingo', 'Interior, noche. La sala de juego del Flamingo, de madrugada.'),
        StoryPiece('vegas-desert', 'Exterior, noche. El desierto de Mojave. Dos faros, una pala.'),
        StoryPiece('vegas-nugget', 'Interior, noche. La trastienda del Golden Nugget. Una mesa de póquer.'),
        StoryPiece('vegas-motel', 'Exterior, noche. El aparcamiento de un motel en el Strip.'),
        StoryPiece('vegas-dam', 'Exterior, noche. La presa Hoover. Abajo, doscientos metros de nada.'),
        StoryPiece('vegas-dressing', 'Interior, noche. El camerino de una cantante, después del show.'),
        StoryPiece('vegas-chapel', 'Interior, noche. Una capilla de bodas abierta toda la noche.'),
      ],
    ),
  ],
  howToPlay:
      'De noche la Familia elimina a una persona. De día todos votan a quién eliminar. '
      'El pueblo gana si elimina a toda la Familia; la Familia gana cuando el pueblo ya no la supera en número.',
  firstNights: [
    'Cae la primera noche sobre {city}.',
    'La oscuridad se posa sobre {city}. Es la primera noche.',
    'Primera noche. Que duerman bien, si la conciencia los deja.',
  ],
  nights: [
    'Cae otra vez la noche sobre {city}.',
    'Se apagan las farolas. Alguien tiene trabajo.',
    'Es de noche. Alguien tiene una cita. Las flores, después.',
    'Otra noche. En {city} la gente ya duerme con los zapatos puestos.',
    'Cae la oscuridad. Hasta los perros han dejado de ladrar.',
    'Noche cerrada. La funeraria hace horas extra.',
  ],
  nightInstruction: 'Pásense el teléfono. Cada uno hace su jugada en secreto, y lo pasa.',
  nobodyDied: 'Anoche no murió nadie.',
  quietDawns: [
    'La funeraria expresa su profunda preocupación.',
    'Miren alrededor de la mesa: aquí hay una decepción.',
    'No se confíen. Así suele empezar.',
    'El vigilante del cementerio durmió ocho horas seguidas, y no se fía.',
  ],
  secondVictims: ['Y eso no es todo.', 'Cambio de escena.', 'Pero fue una noche larga.'],
  victimFact: 'Entre los muertos de anoche: {name}. Su rol sigue en secreto.',
  sniperShots: {
    DeathStory.sniperId: [
      'Un solo disparo, desde una ventana lejana. {name} no oyó nada.',
      'Un destello en una azotea, y un disparo. {name} cae antes que el eco.',
      'Alguien, muy lejos, apuntó sin prisa. {name} se queda en la acera.',
      'Esta vez nadie en la esquina. Solo una mira, con {name} en el centro.',
    ],
    DeathStory.belfryId: [
      'Un destello en el campanario. Luego una campanada, y {name} no se levanta.',
      'La campana da la hora y se traga el disparo. {name} se queda en los adoquines.',
      'Una bandada de palomas sale del campanario. {name} ya está en el suelo.',
    ],
    DeathStory.phoneBoothId: [
      'Suena el teléfono de la cabina. {name} contesta. El cristal se astilla en estrella.',
      'Un agujero en el cristal de la cabina, una telaraña de grietas. {name} se desliza.',
      '{name} descuelga. Al otro lado nadie habla: solo el disparo.',
    ],
    DeathStory.carDoorId: [
      '{name} abre la puerta del coche. Un disparo lejano: ese viaje no empieza.',
      'Llaves en la mano, un pie en el estribo. Luego el disparo, y {name} cae.',
      '{name} estaba a punto de arrancar. El motor sigue frío, la puerta abierta.',
    ],
  },
  rescues: {
    DeathStory.rescueId: [
      'El golpe llega, y {name} está en el suelo. Luego, pasos a la carrera: el Doctor.',
      'Venían a cerrarle la cuenta a {name}. El Doctor llegó antes que el cura.',
      '{name} ya estaba en el suelo. Pero el Doctor pasaba justo por allí.',
      '{name} cae. Luego se abre un maletín de cuero: esto no ha terminado.',
    ],
    DeathStory.defibrillatorId: [
      '{name} en el suelo, el corazón parado. El Doctor frota las palas: ¡fuera!',
      'Una descarga, nada. Otra descarga: el corazón de {name} vuelve a latir.',
      'El Doctor abre una caja llena de cables. Una chispa, y {name} respira otra vez.',
    ],
    DeathStory.pliersId: [
      'El Doctor hurga en la herida de {name} con unas pinzas. Sale el plomo.',
      'Una bala en las pinzas, una venda en el pecho. {name} sigue respirando.',
      '{name} en el suelo, el Doctor de rodillas. «Clinc»: la bala cae en la bandeja.',
    ],
    DeathStory.ambulanceId: [
      'Una sirena calle abajo. La ambulancia frena en seco: {name} va a la camilla.',
      '{name} en el suelo, y luego las sirenas. Camilla, manta, y a toda prisa.',
      'Llega la ambulancia con las luces encendidas. Desde la camilla, {name} saluda.',
    ],
    DeathStory.stitchesId: [
      'Bajo la farola, aguja e hilo. El Doctor cose a {name}, punto a punto.',
      'Tres puntos, un nudo, un tijeretazo. {name} se levanta.',
      'El Doctor enhebra la aguja a la luz de la farola. {name} no siente nada.',
    ],
  },
  someone: 'alguien',
  savedFact: 'Anoche alguien estuvo a punto de morir, pero alguien llegó a tiempo. Quién era sigue en secreto.',
  shrugs: {
    DeathStory.luckyId: [
      '{name} se tambalea y se palpa el bolsillo del pecho: una petaca, muy abollada.',
      'El golpe llega, y suena «cling». {name} saca una petaca abollada.',
      '{name} sigue en pie: el golpe se quedó en la petaca.',
      '{name} nota un golpe en el pecho. Bajo la chaqueta, una petaca doblada en dos.',
    ],
    DeathStory.bibleId: [
      '{name} saca una Biblia del bolsillo del pecho: el golpe se quedó justo ahí.',
      'El golpe se detiene en una Biblia de bolsillo. {name} mira al cielo y da las gracias.',
      '{name} nota un golpe en el pecho. En el bolsillo, una Biblia agujereada hasta la mitad.',
    ],
    DeathStory.jamId: [
      'El arma apunta a {name}. «Clic». Otro «clic». El asesino sale corriendo.',
      'El gatillo no responde: el arma se ha encasquillado. {name} se gira, el asesino huye.',
      '«Clic, clic». {name} se arremanga, y el callejón se vacía.',
    ],
    DeathStory.bananaId: [
      'El asesino pisa una cáscara de plátano y sale volando hacia atrás. {name} se aleja.',
      'Una cáscara de plátano, una voltereta. El asesino acaba de espaldas en la calle: {name} se ríe.',
      'El asesino se lanza contra {name}, y se cruza con una cáscara de plátano. El resto es comedia.',
    ],
    DeathStory.blackCatId: [
      'Un gato negro salta al brazo del asesino. El disparo se desvía, {name} sigue en pie.',
      'El asesino apunta a {name}. Un gato negro le hace soltar el arma.',
      'Dicen que traen mala suerte. Pero esta noche un gato negro salvó a {name}.',
    ],
  },
  shruggedFact: 'Anoche alguien estuvo a punto de morir, pero el golpe falló. Quién era sigue en secreto.',
  methods: [
    StoryPiece('auto', 'Dos faros en la oscuridad. Un sedán negro no frena. {name} se gira: demasiado tarde.'),
    StoryPiece('pianoforte', 'Se rompe una cuerda. Cae un piano de cola. {name} levanta la vista.'),
    StoryPiece('veleno', '{name} toma el último sorbo de café. Una mueca. Veneno.'),
    StoryPiece('pugnale', 'Una sombra detrás de {name}. Una hoja. Con una vez basta.'),
    StoryPiece('cemento', 'Dos matones sujetan a {name}. Un tercero remueve el cemento.'),
    StoryPiece('cappio', 'Una soga cae de la oscuridad detrás de {name}. Se aprieta.'),
    StoryPiece('silenziatore', 'Un «plop» sordo, como un corcho de champán. {name} se desliza hasta el suelo.'),
    StoryPiece('pacco', '{name} abre un regalo. Dentro, algo hace tic tac. Luego algo hace bum.'),
    StoryPiece('lampadario', 'Un crujido. Una lámpara de cristal se suelta, justo encima de {name}.'),
    StoryPiece('violino', 'Se abre un estuche de violín. Dentro no hay ningún violín. {name} cae.'),
    StoryPiece('cassaforte', 'Desde arriba, una caja fuerte. A {name} le da tiempo justo de leer la marca.'),
    StoryPiece('sigaro', '{name} enciende un puro de regalo. El puro hace «bum».'),
    StoryPiece('mazza', 'A la vuelta de la esquina, un bate de béisbol. Un golpe. {name} ve estrellas, y luego nada.'),
    StoryPiece('lupara', 'Dos cañones recortados asoman de la oscuridad. Un estruendo. {name} sale despedido.'),
    StoryPiece('raffica', 'Un coche frena. Por la ventanilla, una metralleta. {name} no llega a girarse.'),
    StoryPiece('garrota', 'Un alambre de acero, dos manos enguantadas. {name} patalea, y luego para.'),
    StoryPiece('vaso', 'Una maceta de geranios cae del tercer piso. No es un accidente. {name} no la ve venir.'),
    StoryPiece('tombino', 'Se abre una alcantarilla bajo los pies de {name}. Luego se cierra otra vez, con cuidado.'),
    StoryPiece('buio', 'La farola se apaga. Un golpe sordo. Cuando vuelve la luz, {name} está en el suelo.'),
    StoryPiece('bacio', 'Un desconocido, un beso, un carmín de muerte. {name} sonríe, y se acabó.'),
    StoryPiece('boccia', 'Una bola de bolos rueda desde la oscuridad. {name} sale volando como un bolo. Pleno.'),
    StoryPiece(
      'pescespada',
      'Un pez espada asoma por la esquina. En guardia, estocada. {name} ya duerme con los peces.',
    ),
    StoryPiece(
      'arpione',
      'Un arpón silba en la oscuridad y la cuerda se tensa. {name} desaparece tras la esquina.',
    ),
    StoryPiece('torta', 'Una tarta de nata, en plena cara de {name}. Todos se ríen. Dentro de la nata, una granada.'),
    StoryPiece('trombone', 'Un trombón suena en el callejón. Por la campana sale un disparo. {name} da la nota final.'),
    StoryPiece('tango', 'Alguien saca a {name} a bailar un tango. Un giro, una caída, un puñal.'),
    StoryPiece('rose', 'Un ramo de rosas rojas para {name}. Entre las rosas, un cañón. Pétalos por todas partes.'),
    StoryPiece('lavanderia', 'Llega una furgoneta de lavandería. Se abre una puerta, dos brazos. {name} no vuelve.'),
  ],
  epilogues: [
    StoryPiece('gatto', 'Un gato lo vio todo. No piensa hablar.'),
    StoryPiece('mambo', 'En algún sitio, una radio toca un mambo.'),
    StoryPiece('tetti', '{city} duerme. O lo finge.'),
    StoryPiece('carta', 'En el suelo, un naipe. Créditos.'),
    StoryPiece('finestra', 'Una ventana se enciende, y luego se apaga.'),
    StoryPiece('sipario', 'Cae el telón. Nadie aplaude.'),
    StoryPiece('voce', 'Una voz en off: «Nada personal».'),
    StoryPiece('sirene', 'Sirenas a lo lejos. Siempre llegan tarde.'),
    StoryPiece('cappello', 'Un sombrero rueda por el suelo. Corten.'),
    StoryPiece('continua', 'En la pantalla, dos palabras: «Continuará…».'),
  ],
  scoops: [
    '¡Extra! ¡Extra! {name} sale en primera plana.',
    'Hay cola en el quiosco: el periódico solo habla de {name}.',
    'Todos los voceadores gritan un solo nombre: {name}.',
  ],
  scoopMafia: 'El periódico lo dice bien claro: {name} es de la Familia.',
  scoopClean: 'El periódico lo dice bien claro: {name} es inocente.',
  silences: [
    'Aguja, hilo, buen trabajo: esta mañana {name} tiene los labios cosidos.',
    'Anoche alguien visitó a {name}. Trajo una aguja y un consejo.',
    'En la almohada de {name}, un carrete de hilo negro. Mensaje recibido.',
  ],
  silencedFact:
      'Hoy {name} no puede hablar durante la discusión. {name} vota por gestos y aún se le puede eliminar.',
  silencedFactOnline: 'Hoy {name} no puede escribir en el chat del pueblo. {name} sigue votando y aún puede caer.',
  dayInstruction: 'Tienen {minutes} para discutir. Luego voten a quién eliminar.',
  oneMinute: 'un minuto',
  manyMinutes: '{minutes} minutos',
  voteCalls: [
    'Se acabó el tiempo. La multitud quiere un culpable.',
    'Basta de charla. {city} quiere un nombre.',
    'La multitud se impacienta. El verdugo calienta.',
    'Hora de votar. Intenten no equivocarse. Otra vez.',
  ],
  voteInstruction: 'Decidan en voz alta a quién eliminar. También pueden no eliminar a nadie.',
  lynchScenes: [
    '{name} sube los peldaños del cadalso. La guillotina brilla al sol.',
    '{name} camina hacia la soga, con la cabeza alta. Redoble de tambor.',
    'Un tren de mercancías, un billete solo de ida. {name} se va de {city}.',
    'Cruje la trampilla del ayuntamiento. {name} echa una última mirada a la multitud.',
    '{name} pide un último cigarrillo. El verdugo le ofrece fuego.',
    'Primer plano de las manos atadas de {name}. Todo {city} mira.',
  ],
  cardTurns: 'La carta se gira. {name} era… {role}.',
  wasMafia: 'Del lado de la Familia.',
  wasCitizen: 'Del lado del pueblo.',
  wasNeutral: 'Por su cuenta.',
  lynchedInnocent: [
    'Buen trabajo, todos. De verdad.',
    'Alguien en esta mesa intenta no sonreír.',
    'La Familia agradece su colaboración.',
    'El verdugo pide disculpas, y cobra la tarifa completa igual.',
  ],
  lynchedMafioso: [
    'Uno menos. Pero tenía amigos, y los amigos tienen buena memoria.',
    'Alguien acaba de perder un socio, y ni siquiera puede ir al funeral.',
    'Buen tiro. Esta noche la Familia estará de un humor de perros.',
  ],
  lynchedLastMafioso: [
    'Y no queda ni uno. Repican todas las campanas de la ciudad.',
    'No queda ninguno. En {city}, por fin, alguien habló.',
  ],
  noLynch: [
    'El verdugo vuelve pronto a casa, por una vez.',
    'Se oye un suspiro de alivio. ¿De quién será?',
    'En {city}, no ponerse de acuerdo en nada es lo normal.',
  ],
  noLynchFact: 'Hoy no se elimina a nadie.',
  truces: [
    'Alto, todos. Hoy no se ahorca a nadie.',
    'La plaza baja las sogas: tregua, por hoy.',
  ],
  truceFact: 'El Pacifista pidió una tregua: hoy no se vota.',
  citizensWin: [
    '{city} es libre. Desde mañana se duerme con las ventanas abiertas. Créditos.',
    'En la calle, la gente vuelve a mirarse a los ojos. En pantalla: «Fin».',
  ],
  citizensWinFact: 'Gana el pueblo: toda la Familia ha sido eliminada.',
  mafiaWins: [
    '{city} tiene nuevos jefes, y estaban sentados en esta mesa. Créditos.',
    'En {city}, nadie vio nada. Como siempre. Fundido a negro.',
  ],
  mafiaWinsFact: 'Gana la Familia: el pueblo ya no la supera en número.',
  fires: [
    'Olor a gasolina, una cerilla, y la noche se vuelve naranja.',
    'Alguien encendió una cerilla. Cuando llegaron los bomberos, no quedaba nada.',
  ],
  burnedFact: '{name} ardió en la noche y queda fuera de la partida.',
  resurrections: [
    'Una mano empuja la tapa del ataúd. El pueblo se olvidó de clavarla.',
    'Al amanecer un fantasma entra en el bar y pide un café. No es un fantasma.',
  ],
  resurrectedFact: '{name} vuelve a la partida, con la misma carta que antes.',
  foolWins: [
    'La soga se balancea, y arriba alguien sonríe. Ese era el plan desde el principio.',
    'La multitud aplaude, y el Tonto hace una reverencia.',
  ],
  foolWinsFact: '{name} era el Tonto y gana en solitario. La partida sigue.',
  arsonistWins: [
    '{city} es ceniza. Una silueta se aleja silbando, con una caja de cerillas en la mano. Créditos.',
    'En {city} ya no queda nada que quemar. Fundido a naranja.',
  ],
  arsonistWinsFact: 'El Pirómano gana en solitario: no queda nadie para detener el fuego.',
  bountyWins: [
    'Al fondo de la plaza alguien cuenta billetes. La recompensa está pagada.',
    'Un sombrero se inclina entre la multitud, a modo de gracias. Un placer hacer negocios.',
  ],
  bountyWinsFact: '{name} era el Cazarrecompensas: cobra y gana en solitario. La partida acaba aquí.',
  loanSharkWinsFact: '{name} era el Usurero: sigue con vida al final, y también cobra.',
  assassinWins: [
    'En {city} solo quedan sillas vacías. El Sicario paga los cafés y se va.',
    'Se apaga la última luz en {city}. Alguien limpia una hoja y silba. Créditos.',
  ],
  assassinWinsFact: 'El Sicario gana en solitario: barrida completa.',
  mayorRevealed: '{name} es el Alcalde: hoy su voto vale doble.',
  watchVisited: 'Anoche alguien llamó a la puerta de {name}.',
  watchQuiet: 'Anoche nadie llamó a la puerta de {name}.',
  taskPrompts: {
    NightTaskKind.kill: '¿A quién elimina la Familia esta noche?',
    NightTaskKind.silence: '¿A quién le coses los labios esta noche?',
    NightTaskKind.protect: '¿A quién proteges esta noche?',
    NightTaskKind.guard: '¿A quién cubres esta noche?',
    NightTaskKind.investigate: '¿A quién quieres investigar?',
    NightTaskKind.dig: '¿Qué tumba abres esta noche?',
    NightTaskKind.snipe: '¿Quieres disparar a alguien?',
    NightTaskKind.scoop: '¿Sobre quién es tu exclusiva?',
    NightTaskKind.douse: '¿A quién rocías de gasolina esta noche?',
    NightTaskKind.ignite: '¿Enciendes la cerilla esta noche?',
    NightTaskKind.resurrect: '¿A quién traes de vuelta esta noche?',
    NightTaskKind.watch: '¿Qué puerta vigilas esta noche?',
    NightTaskKind.lend: '¿A quién proteges esta noche con un préstamo?',
    NightTaskKind.stab: '¿A quién eliminas esta noche?',
    NightTaskKind.jail: '¿A quién encierras esta noche?',
    NightTaskKind.block: '¿Para quién cantas esta noche?',
  },
  taskHints: {
    NightTaskKind.kill: 'Toca un nombre: es tu voto para quién muere. Decide la mayoría de la Familia.',
    NightTaskKind.silence: 'Toca un nombre: mañana no podrá hablar. Solo una vez, en lugar de tu voto.',
    NightTaskKind.protect: 'Toca un nombre, incluso el tuyo: esta noche no puede morir. Nunca dos noches seguidas.',
    NightTaskKind.guard: 'Toca un nombre: si lo atacan esta noche, mueres tú en su lugar.',
    NightTaskKind.investigate: 'Toca un nombre: sabrás al momento si es de la Familia o del pueblo.',
    NightTaskKind.dig: 'Toca a alguien muerto: solo tú sabrás su rol, al momento.',
    NightTaskKind.snipe: 'Toca un nombre: disparas y muere. Tienes una bala. Pasa para guardarla.',
    NightTaskKind.scoop: 'Toca un nombre: al amanecer todos sabrán su bando. Una sola exclusiva. Pasa para guardarla.',
    NightTaskKind.douse: 'Toca un nombre para rociarlo, en secreto. O enciende la cerilla: arden todos los rociados.',
    NightTaskKind.ignite: 'Toca tu propio nombre: esta noche arden todos los que rociaste.',
    NightTaskKind.resurrect: 'Toca a alguien muerto: vuelve al amanecer si sigues con vida. Solo una vez; pasar la guarda.',
    NightTaskKind.watch: 'Toca un nombre: al amanecer sabrás si alguien pasó por su puerta. No quién.',
    NightTaskKind.lend: 'Toca un nombre: esta noche no puede morir. Nunca la misma persona dos veces seguidas.',
    NightTaskKind.stab: 'Toca un nombre: muere esta noche, salvo que alguien lo proteja.',
    NightTaskKind.jail: 'Toca un nombre: esta noche no actúa y nadie puede tocarlo. Se cierra al momento.',
    NightTaskKind.block: 'Toca un nombre: su jugada de esta noche se pierde. Nunca dos noches seguidas.',
    NightTaskKind.decoy: 'Esta noche no tienes jugada: toca cualquier nombre, no pasa nada. Así tu rol queda oculto.',
  },
  decoyPrompts: [
    '¿Quién te da más mala espina?',
    '¿De quién no te fiarías nunca?',
    '¿Quién tiene cara de esconder algo?',
    'Si tuvieras que señalar a alguien, ¿a quién?',
    '¿Quién está actuando mejor en esta mesa?',
  ],
);
