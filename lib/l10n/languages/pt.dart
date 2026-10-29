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

// The whole of the Portuguese translation: interface, keyed messages and the
// narrator's script. Brazilian Portuguese ("você").
//
// Each class extends the English one, so anything not overridden here stays
// in English; test/l10n/translations_test.dart lists what is missing.
//
// Same rules as the script: never a player's gender (the name, or turn the
// sentence around), nobody closes their eyes, the factions are always
// "a Família" and "a cidade".
//
// Stage names: Soldado, Padrinho, Alfaiate, Cúmplice, Cidadão Honesto,
// Detetive, Doutor, Atirador, Repórter, Coveiro, Guarda-Costas, Veterano,
// Ex-Presidiário, Messias, Prefeito, Porteiro, Bobo, Incendiário,
// Caçador de Recompensas, Agiota, Matador, Cortesã, Carcereiro, Cupido,
// Presidente, Líder da Seita, Artilheiro, Atirador de Elite, Pacifista.

final class PortugueseStrings extends EnglishStrings {
  const PortugueseStrings();

  @override
  AppLanguage get language => AppLanguage.pt;
  @override
  NarrationPack get pack => portuguesePack;
  @override
  OnlineStrings get online => const PortugueseOnlineStrings();
  @override
  ShopStrings get shop => const PortugueseShopStrings();
  @override
  Map<String, String> get messages => portugueseMessages;
  @override
  List<RulesStep>? rulesSteps(RulesStyle style) => style == RulesStyle.quick ? _quickPt : _stagePt;

  @override
  String get settings => 'Ajustes';
  @override
  String get alleyPlaque => 'BECO DO SILÊNCIO';
  @override
  String get tonight => 'SÓ HOJE À NOITE';
  @override
  String get sharedTitle => 'UM CELULAR PARA TODOS';
  @override
  String get sharedBlurb => 'Passe de mão em mão. Sem rede, sem testemunhas.';
  @override
  String get createRoom => 'CRIAR SALA';
  @override
  String get hostName => 'Você';
  @override
  String get soon => 'EM BREVE';
  @override
  String get rankedTitle => 'RANQUEADA';
  @override
  String get rankedBlurb => 'Desconhecidos, pontos e um ranking para escalar.';
  @override
  String get rankedTeaser => 'A ranqueada abre em breve. Enquanto isso, faça seu nome.';
  @override
  List<String> get homeCaptions => const [
    'Ninguém viu nada.',
    'Ninguém fala. Alguém morre.',
    'Você não estava lá. E se estava, dormia.',
    'Nesta cidade até as paredes ficam caladas.',
    'Confiar é bom. Calar é melhor.',
    'Quem sabe, cala. Quem fala não vê o sol nascer.',
    'Esta noite alguém não volta para casa.',
  ];

  @override
  String get settingsTitle => 'AJUSTES';
  @override
  String get sound => 'Música e efeitos sonoros';
  @override
  String get soundHint => 'Você vai ouvir mesmo com o celular no silencioso.';
  @override
  String get languageSetting => 'Idioma';
  @override
  String get languageAutomatic => 'Automático (celular)';

  @override
  String get narratorTitle => 'NARRADOR';
  @override
  String get whoPullsTheStrings => 'Quem mexe\nos pauzinhos?';
  @override
  String get narratorIntro => 'O narrador conduz a partida e conhece todos os papéis.';
  @override
  String get pickedByGroup => 'Escolhido pelo grupo';
  @override
  String get pickedByGroupHint => 'Vocês decidem quem conta a história. Quem narra não recebe papel.';
  @override
  String get drawnByCylinder => 'Sorteado no tambor';
  @override
  String get drawnByCylinderHint => 'Um giro do tambor. Quem sair narra e fica de fora.';
  @override
  String get automaticNarrator => 'Narrador automático';
  @override
  String get automaticNarratorHint => 'O celular conta a história: todo mundo joga.';
  @override
  String needAtLeast(int players) => 'São necessários pelo menos $players jogadores';
  @override
  String get whoNarrates => 'QUEM NARRA?';
  @override
  String get drawTitle => 'O SORTEIO';
  @override
  String get whoNarratesTonight => 'Quem narra\nesta noite?';
  @override
  String get theNarratorIs => 'QUEM NARRA É';
  @override
  String get continueLabel => 'CONTINUAR';

  @override
  String get cardsTitle => 'AS CARTAS';
  @override
  String get automatic => 'Automático';
  @override
  String get cardsDealt => 'As cartas estão dadas';
  @override
  String get shuffling => 'Embaralhando…';
  @override
  String get checkYourCards => 'OLHEM SUAS CARTAS';
  @override
  String cardOf(int card, int of) => 'CARTA $card DE $of';
  @override
  String get holdTheCardHint => 'Segure a carta para olhar.\nSolte e ela vira de volta.';
  @override
  String get gotIt => 'ENTENDI';
  @override
  String get pressAndHold => 'SEGURE';
  @override
  String get youAreFamily => 'VOCÊ É DA FAMÍLIA';
  @override
  String get youAreTown => 'VOCÊ É DA CIDADE';
  @override
  String get youActAlone => 'VOCÊ TRABALHA SEM SÓCIOS';
  @override
  String get yourAccomplices => 'SEUS CÚMPLICES';
  @override
  String get familyUnknown => 'VOCÊ TRABALHA PARA A FAMÍLIA, MAS NÃO SABE QUEM SÃO';
  @override
  String get familyBadge => 'FAMÍLIA';
  @override
  String get townBadge => 'HONESTOS';

  @override
  String get passThePhoneTo => 'PASSE O CELULAR PARA';
  @override
  String get nobodyElseLooks => 'Ninguém mais olha para a tela.';
  @override
  String get itsMe => 'SOU EU';
  @override
  String get youBadge => 'VOCÊ';
  @override
  String get innocentBadge => 'INOCENTE';
  @override
  String get neutralBadge => 'NEUTRO';
  @override
  String get youAreNeutral => 'VOCÊ JOGA POR CONTA PRÓPRIA';
  @override
  String get arsonistWins => 'Um lobo solitário\nvence';
  @override
  String get wonAlone => 'VITÓRIA SOLITÁRIA';
  @override
  String get revealAsMayor => 'Revele-se: Prefeito';
  @override
  String get lightTheMatch => 'Acender o fósforo';
  @override
  String get dousePick => 'Encharcar';
  @override
  String get dousedBadge => 'GASOLINA';
  @override
  String get bountyBadge => 'RECOMPENSA';
  @override
  String get bountyLine => 'Tem uma recompensa pela cabeça de {name}: faça a cidade linchar.';
  @override
  String get readAloud => 'LEIA EM VOZ ALTA';
  @override
  String readerReadsAloud(String reader) => '${reader.toUpperCase()} LÊ EM VOZ ALTA';
  @override
  String get narratorSpeaks => 'O NARRADOR FALA';
  @override
  String get narratorOnly => 'SÓ PARA O NARRADOR';
  @override
  String get holdToSeeRoles => 'Segure para ver todos os papéis';

  @override
  String nightTitle(int round) => 'NOITE $round';
  @override
  String get nightFalls => 'Cai a noite';
  @override
  String get startTheNight => 'COMEÇAR A NOITE';
  @override
  String get dawnTitle => 'AMANHECER';

  @override
  String get dayBreaks => 'O dia nasce';
  @override
  String get everyoneAlive => 'Todo mundo sobreviveu';
  @override
  String get crimePage => 'A página policial';
  @override
  String get finale => 'O FINAL';
  @override
  String get openTheFloor => 'ABRIR A DISCUSSÃO';
  @override
  String dayTitle(int round) => 'DIA $round';
  @override
  String get verdictTitle => 'O VEREDITO';
  @override
  String get noConviction => 'Ninguém condenado';
  @override
  String get endTitle => 'FIM';
  @override
  String get leaveQuestion => 'Abandonar a partida?';
  @override
  String get leaveWarning => 'A partida em andamento será perdida.';
  @override
  String get stay => 'FICAR';
  @override
  String get leave => 'SAIR';
  @override
  String get leaveTooltip => 'Sair da partida';
  @override
  String get rolesTooltip => 'Papéis, só para o narrador';
  @override
  String get phoneOnTheTable => 'Celular\nna mesa';
  @override
  String get phoneOnTheTableHint => 'Coloque no meio, onde todos possam ver.\nAlguma coisa aconteceu ontem à noite.';
  @override
  String get lightsDown => 'APAGAR AS LUZES';
  @override
  String get pass => 'PASSAR';
  @override
  String get voteTheHit => 'O SERVIÇO';
  @override
  String get sewAMouth => 'COSTURAR UMA BOCA';
  @override
  String get confirm => 'CONFIRMAR';
  @override
  String get doneTitle => 'Feito.';
  @override
  String get nobodyWillKnow => 'Ninguém vai saber o que você escolheu.';
  @override
  String get yourInvestigation => 'SUA INVESTIGAÇÃO';
  @override
  String get inTheGrave => 'NA COVA';
  @override
  String wasRole(String role) => 'ERA ${role.toUpperCase()}';
  @override
  String get isFamily => 'É DA FAMÍLIA';
  @override
  String get isInnocent => 'É INOCENTE';
  @override
  String get wasWithFamily => 'ERA DA FAMÍLIA';
  @override
  String get wasWithTown => 'ERA DA CIDADE';
  @override
  String get done => 'FEITO';
  @override
  String get nobody => 'NINGUÉM';
  @override
  String get condemn => 'CONDENAR';
  @override
  String fateNight(int round) => 'Noite $round';
  @override
  String fateGallows(int round) => 'Forca, dia $round';
  @override
  String get stillStanding => 'Ainda de pé';
  @override
  String get familyWins => 'A Família\nvence';
  @override
  String get townWins => 'A cidade\nvence';
  @override
  String get whoWasWho => 'QUEM ERA QUEM';
  @override
  String get mostSuspicious => 'A CARA MAIS SUSPEITA';
  @override
  String suspicion(String name, int fingers, {required bool rightly}) =>
      '$name, com $fingers ${fingers == 1 ? 'dedo apontado' : 'dedos apontados'} no escuro. '
      '${rightly ? 'Com razão.' : 'Sem razão, no fim das contas.'}';
  @override
  String get backHome => 'DE VOLTA AO BECO';
  @override
  String get keepReading => 'CONTINUAR LENDO';
  @override
  String get flipTheCard => 'VIRAR A CARTA';
  @override
  String get timeUp => 'ACABOU O TEMPO';
  @override
  String get floorIsOpen => 'A DISCUSSÃO ESTÁ ABERTA';
  @override
  String get plusMinute => '+1 MIN';
  @override
  String get callTheVote => 'CHAMAR A VOTAÇÃO';
  @override
  String get accusedStamp => 'SOB ACUSAÇÃO';
  @override
  String aliveCount(int alive, int total) => '$alive de $total ainda de pé';

  @override
  String get willSeeDawn => 'VAI VER O AMANHECER';
  @override
  String get wontSeeDawn => 'NÃO VAI VER O AMANHECER';
  @override
  String get next => 'PRÓXIMO';
  @override
  String get skip => 'PULAR';

  @override
  String verdictCaption(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'Pôr do sol, lá no cais.',
    VerdictTake.cartello => 'O limite da cidade. Estrada de terra, e nada de volta.',
    VerdictTake.treno => 'Estação Central. O último trem da noite.',
    VerdictTake.cannone => 'O circo chegou à cidade. Procura-se voluntário.',
    VerdictTake.assoluzione => 'A praça ao pôr do sol. Os ânimos esquentam.',
  };
  @override
  String verdictStamp(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'DORME COM OS PEIXES',
    VerdictTake.cartello => 'FORA DA CIDADE',
    VerdictTake.treno => 'SÓ IDA',
    VerdictTake.cannone => 'EM ÓRBITA',
    VerdictTake.assoluzione => '',
  };
  @override
  String get verdictLine => 'O POVO DECIDIU';
  @override
  String get acquittalTitle => 'NINGUÉM CONDENADO';
  @override
  String get acquittalLine => 'TODO MUNDO PRA CASA. POR HOJE.';
  @override
  String get townSign => 'CIDADE';
  @override
  String verdictWord(VerdictWord word) => switch (word) {
    VerdictWord.thud => 'TUM!',
    VerdictWord.byeBye => 'TCHAU TCHAU!',
    VerdictWord.glub => 'GLUB',
    VerdictWord.getOut => 'RUA!',
    VerdictWord.cough => 'COF!',
    VerdictWord.toot => 'PIUÍ!',
    VerdictWord.sniff => 'SNIF!',
    VerdictWord.ping => 'PLIM!',
    VerdictWord.bonk => 'POF!',
    VerdictWord.shrug => 'SEI LÁ!',
  };

  @override
  String get lobbyTitle => 'A MESA';

  @override
  String get lobbyDebugAdd => '+ TEST';

  @override
  String get lobbyClearTooltip => 'Remover todo mundo';

  @override
  String get lobbyEmptyTitle => 'QUEM JOGA ESTA NOITE?';

  @override
  String get lobbyEmptyBody => 'Passe o celular: cada um digita o nome e tira a foto de ficha.';

  @override
  String get lobbyEmptyPlaceholder => '???';

  @override
  String get lobbyTableEmpty => 'MESA VAZIA';

  @override
  String get lobbyReadyHint => 'Quando quiserem.';

  @override
  String get lobbyTableFull => 'Mesa cheia: no máximo $maxTablePlayers jogadores.';

  @override
  String get lobbyTableFullRefusal => 'A mesa está cheia: alguém precisa levantar antes.';

  @override
  String get lobbyRosterFull => 'A lista está cheia: remova alguém antes.';

  @override
  String get lobbyGestureHint => 'Toque num rosto para sentar ou levantar.\nSegure para mudar o nome ou a foto.';

  @override
  String get lobbyOut => 'FORA';

  @override
  String get lobbyPrivacy => 'Nomes e fotos ficam neste celular.';

  @override
  String get lobbyAdd => 'ADICIONAR';

  @override
  String get lobbyStart => 'COMEÇAR';

  @override
  String get lobbyClearTitle => 'Remover todo mundo?';

  @override
  String get lobbyClearBody => 'Isso apaga todos os nomes e fotos deste celular. Não tem volta.';

  @override
  String get lobbyClearCancel => 'CANCELAR';

  @override
  String get lobbyClearConfirm => 'APAGAR TUDO';

  @override
  String lobbySeated(int seated) => '$seated NA MESA';

  @override
  String lobbyMissing(int missing) =>
      missing == 1 ? 'Falta um jogador para começar.' : 'Faltam $missing jogadores para começar.';

  @override
  String get personTitleNew => 'NOVA FICHA';

  @override
  String get personTitleEdit => 'FICHA';

  @override
  String get personPlacardEmpty => 'SEU NOME';

  @override
  String get personNameHint => 'Qual é o seu nome?';

  @override
  String get personNameEmpty => 'Sem nome, sem ficha.';

  @override
  String get personNameTooLong => 'Comprido demais: no máximo $maxNameLength letras.';

  @override
  String get personNameTaken => 'Alguém já usa esse nome.';

  @override
  String get personShoot => 'FOTOGRAFAR';

  @override
  String get personReshoot => 'REFAZER';

  @override
  String get personGallery => 'GALERIA';

  @override
  String get personNoPhoto => 'SEM FOTO';

  @override
  String get personHintDrag => 'Arraste para centralizar o rosto';

  @override
  String get personSubmitNew => 'SENTAR À MESA';

  @override
  String get personSubmitEdit => 'SALVAR';

  @override
  String get personPrivacy => 'A foto fica neste celular: o jogo nunca a envia para lugar nenhum.';

  @override
  String get personCameraDenied => 'Sem permissão para a câmera. Você pode liberar nos Ajustes, ou jogar sem foto.';

  @override
  String get personCameraFailed => 'A foto não deu certo. Tente de novo, ou jogue sem foto.';

  @override
  String get personStamp => 'FICHADO';

  @override
  String get personBookedPass => 'Passe o celular para o próximo.';

  @override
  String get personNext => 'PRÓXIMO!';

  @override
  String get personDone => 'TERMINAMOS';

  @override
  String get personRemoveTooltip => 'Remover da lista';

  @override
  String get personRemoveCancel => 'CANCELAR';

  @override
  String get personRemoveConfirm => 'REMOVER';

  @override
  String get personRemoveBody => 'Isso apaga o nome e a foto do celular.';

  @override
  String personBookedSeated(String name) => '$name está na mesa.';

  @override
  String personBookedWatching(String name) => 'A mesa está cheia: por enquanto $name só assiste.';

  @override
  String personRemoveTitle(String name) => 'Remover $name?';

  @override
  String verdictName(VerdictTake take) => switch (take) {
        VerdictTake.molo => 'O cais',
        VerdictTake.cartello => 'O limite da cidade',
        VerdictTake.treno => 'O último trem',
        VerdictTake.cannone => 'O canhão do circo',
        VerdictTake.assoluzione => 'Ninguém condenado',
      };

  @override
  String get someoneSaved => 'ALGUÉM';

  @override
  String get musicVolumeLabel => 'Música';

  @override
  String get effectsVolumeLabel => 'Efeitos sonoros';

  @override
  String get memeMode => 'Modo meme';

  @override
  String get memeModeHint => 'Vine boom, FAAAH e companhia nos grandes momentos.';
}

final class PortugueseOnlineStrings extends EnglishOnlineStrings {
  const PortugueseOnlineStrings();

  @override
  String get rankedQueueTitle => 'RANQUEADA';
  @override
  String get rankedStart => 'Procurar partida';
  @override
  String get rankedSearching => 'Procurando caras novas na cidade…';
  @override
  String rankedWaiting(int people) => '$people na espera';
  @override
  String rankedEstimate(String time) => 'Espera estimada: $time';
  @override
  String get rankedCancel => 'Cancelar';
  @override
  String get rankedFound => 'Mesa encontrada!';
  @override
  String get rankedTestMatch => 'TESTE · SEM RANKING';
  @override
  String get rankedWarning => 'Quem abandona partidas acaba jogando com quem abandona.';
  @override
  String rankedCooldown(String time) => 'Partidas abandonadas demais: você volta à fila em $time.';
  @override
  String get rankedLobbyTitle => 'SALA DE ESPERA';
  @override
  String rankedSeats(int seated, int size) => '$seated/$size na mesa';
  @override
  String rankedMissing(int missing) => missing == 1 ? 'Falta um jogador' : 'Faltam $missing jogadores';
  @override
  String rankedStartsIn(int seconds) => 'Mesa cheia: começa em $seconds';
  @override
  String get rankedLeaveLobby => 'Sair da sala';
  @override
  String get rankedNoPenalty => 'Antes do início, você pode sair sem punição.';
  @override
  String get rankedTipsTitle => 'ENQUANTO ESPERA';
  @override
  String get rankedStrangers => 'Você descobre quem senta com você quando a partida começa.';
  @override
  String homeQueued(int n) => '$n esperando uma mesa';
  @override
  String get rankedSit => 'Sentar';
  @override
  String get rankedTutorialsTitle => 'Antes, as três mãos de treino';
  @override
  String get rankedTutorialsBody =>
      'Só senta numa mesa ranqueada quem terminou as três mãos de treino: a Família, a cidade e os solitários. Com amigos, dá para jogar na hora.';
  @override
  String rankedTutorialName(String faction) => switch (faction) {
        'family' => 'a Família',
        'town' => 'a cidade',
        _ => 'o solitário',
      };
  @override
  String rankedTutorialPlay(String name) => 'Jogar a mão: $name';
  @override
  String get rankedSkipTutorials => 'Já conheço o jogo';
  @override
  String get rankedSkipTitle => 'Tem certeza?';
  @override
  String get rankedSkipBody => 'Você pula todos os tutoriais e vai direto para a ranqueada.';
  @override
  String get rankedSkipConfirm => 'Sim, pular os tutoriais';
  @override
  String get rankedSkipCancel => 'Deixa pra lá';
  @override
  String get rankedPickTable => 'ESCOLHA SUA MESA';
  @override
  String get rankedRules => '12 jogadores · turnos cronometrados · quem sai paga';
  @override
  String get rankedYourRank => 'SEU POSTO';
  @override
  String rankedTowards(String tier) => 'rumo a $tier';
  @override
  String get rankedTopTier => 'no topo da família';
  @override
  String rankedTableQueued(int n) => '$n na fila';
  @override
  String get rankedTableIt => 'Fala-se italiano';
  @override
  String get rankedTableEn => 'Fala-se inglês';
  @override
  String homeOnline(int n) => '$n jogadores pela cidade';
  @override
  List<String> get rankedTips => const [
        'Fale durante o dia, mas não demais: quem fala mais alto acaba na mira.',
        'Um voto dado no último segundo diz muito sobre quem votou.',
        'A Família vence quando empata em número com a cidade: conte as cabeças.',
        'Abandonar uma partida deixa seu time desfalcado.',
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
  String get dossierTitle => 'FICHA PESSOAL';
  @override
  String get dossierHistory => 'CASOS RECENTES';
  @override
  String get dossierNoHistory => 'Ficha limpa: nenhuma partida ainda.';
  @override
  String get dossierSettings => 'Ajustes';
  @override
  String get dossierConfidential => 'CONFIDENCIAL';
  @override
  String get dossierName => 'NOME';
  @override
  String steamPersona(String persona) => 'Na Steam: $persona';
  @override
  String get pictureLabel => 'Foto do perfil';
  @override
  String get pictureGame => 'Avatar do jogo';
  @override
  String get pictureSteam => 'Foto da Steam';
  @override
  String handleFromSteam(String persona) =>
      'Tirado do seu nome na Steam, “$persona”. Gostou? Salve, ou troque.';
  @override
  String get handleSuggestions => 'Livres por perto:';
  @override
  String get dossierRank => 'POSTO';
  @override
  String get dossierExperience => 'EXPERIÊNCIA';
  @override
  String get resultsTitle => 'COMO FOI';
  @override
  String get resultsWon => 'Vitória';
  @override
  String get resultsLost => 'Derrota';
  @override
  String get resultsLeft => 'Você deixou a cidade';
  @override
  String resultsXp(int xp) => '+$xp XP';
  @override
  String resultsLevelUp(int level) => 'Nível $level!';
  @override
  String resultsCoins(int coins) => '+$coins moedas';
  @override
  String get resultsRatingUp => 'Seu posto sobe';
  @override
  String get resultsRatingDown => 'Seu posto cai';
  @override
  String get resultsContinue => 'Continuar';

  @override
  String get posterTitle => 'JOGAR COM\nAMIGOS';
  @override
  String get posterBlurb => 'Uma sala online: um código ou um QR, cada um no seu celular.';
  @override
  String get posterStrip => 'ONLINE';

  @override
  String get unavailableTitle => 'INDISPONÍVEL';
  @override
  String get unavailableBody => 'O jogo online não está disponível nesta versão. Um celular para todos funciona como sempre.';

  @override
  String get loginTitle => 'QUEM É VOCÊ?';
  @override
  String get loginBody => 'O jogo online precisa de uma conta: seu perfil e seus amigos seguem você em qualquer celular.';
  @override
  String get loginApple => 'Entrar com a Apple';
  @override
  String get loginGoogle => 'Entrar com o Google';
  @override
  String get loginNoProvider => 'Ainda não há como entrar neste celular.';
  @override
  String get loginPrivacy => 'A conta serve só para o seu perfil de jogo. Um celular para todos não precisa de conta.';

  @override
  String get signIn => 'ENTRAR';
  @override
  String get coachSignIn => 'Entre para jogar online';
  @override
  String roomLinkSignIn(String code) => 'Entre para participar da sala $code.';
  @override
  String get roomLinkInvalid => 'Este link não leva a sala nenhuma.';
  @override
  String get technicalReason => 'Motivo técnico';
  @override
  String get pickHandle => 'Escolha seu apelido';
  @override
  String levelShort(int level) => 'NV. $level';
  @override
  String get level => 'NÍVEL';
  @override
  String get coins => 'MOEDAS';
  @override
  String xpProgress(int xp, int next) => '$xp de $next pontos de experiência';

  @override
  String get testAccount => 'Conta de teste';
  @override
  String get testAccountBody =>
      'Só para testar o app em outro celular: entre com e-mail e senha, ou crie a conta se não existir.';
  @override
  String get emailLabel => 'Endereço de e-mail';
  @override
  String get passwordLabel => 'Senha (pelo menos 6 caracteres)';
  @override
  String get testAccountSubmit => 'ENTRAR OU CRIAR';

  @override
  String get setupTitle => 'SEU PERFIL';
  @override
  String get setupBody => 'Seu apelido é também o nome que todos veem: na sala, na mesa e entre amigos.';
  @override
  String get handleLabel => 'Apelido';
  @override
  String get handleHint => 'tipo joao.silva';
  @override
  String get save => 'SALVAR';
  @override
  String get handleInvalid => 'De 3 a 12 caracteres: letras minúsculas, números, ponto e sublinhado.';
  @override
  String get handleChecking => 'Vendo se está livre…';
  @override
  String get handleFree => 'Livre: é seu, se quiser.';
  @override
  String handleProblem(HandleProblem problem) => switch (problem) {
        HandleProblem.tooShort => 'Pelo menos 3 caracteres.',
        HandleProblem.tooLong => 'No máximo 12 caracteres.',
        HandleProblem.characters => 'Só letras minúsculas, números, ponto e sublinhado.',
        HandleProblem.start => 'Não pode começar com ponto ou sublinhado.',
        HandleProblem.endsWithDot => 'Não pode terminar com ponto.',
        HandleProblem.doubleDot => 'Nada de dois pontos seguidos.',
        HandleProblem.tooManySymbols => 'No máximo três símbolos seguidos.',
        HandleProblem.botName => 'Nomes que começam com "bot" são dos bots.',
        HandleProblem.notAllowed => 'Nome não permitido.',
      };

  @override
  String get hubTitle => 'JOGAR COM AMIGOS';
  @override
  String signedInAs(String name) => 'Na conta: $name';
  @override
  String get hubCreate => 'ABRIR UMA SALA';
  @override
  String get hubJoin => 'ENTRAR COM CÓDIGO';
  @override
  String get friends => 'AMIGOS';
  @override
  String get signOut => 'Sair da conta';

  @override
  String get joinTitle => 'ENTRAR NUMA SALA';
  @override
  String get codeLabel => 'Código da sala';
  @override
  String get joinSubmit => 'ENTRAR';
  @override
  String get scan => 'Ler o QR';
  @override
  String get codeInvalid => 'O código tem seis caracteres, sem 0, O, 1, I ou L.';
  @override
  String get scanTitle => 'LER O QR';
  @override
  String get scanHint => 'Aponte a câmera para o QR no celular de quem abriu a sala.';
  @override
  String get scanDenied => 'Sem a câmera não dá para ler o QR: digite o código.';

  @override
  String get roomTitle => 'A SALA';
  @override
  String get roomShareHint => 'Deixe lerem o QR, ou diga o código em voz alta.';
  @override
  String roomSeated(int seated, int max) => '$seated de $max na mesa';
  @override
  String get hostBadge => 'ANFITRIÃO';
  @override
  String get addFriend => 'Adicionar amigo';
  @override
  String friendRequestSent(String name) => 'Pedido de amizade enviado para $name.';
  @override
  String nowFriends(String name) => 'Agora você e $name são amigos.';
  @override
  String get leaveRoom => 'SAIR DA SALA';
  @override
  String get leaveConfirmTitle => 'Sair da sala?';
  @override
  String get leaveConfirmBody => 'Seu lugar na mesa fica livre.';
  @override
  String get leaveConfirm => 'SAIR';
  @override
  String get stay => 'FICAR';
  @override
  String get chooseHostTitle => 'Quem assume a sala?';
  @override
  String get chooseHostBody => 'A sala é sua: escolha quem fica no seu lugar, e depois saia.';
  @override
  String get botBadge => 'BOT DE TESTE';
  @override
  String get testBotsNote => 'Teste: bots ocupam os lugares vazios.';
  @override
  String get startGame => 'COMEÇAR A PARTIDA';
  @override
  String startNeeds(int players) => 'Pelo menos $players pessoas na mesa: deixe alguém entrar.';
  @override
  String get waitingForHost => 'Esperando quem abriu a sala dar as cartas.';
  @override
  String get rejoin => 'DE VOLTA À MESA';
  @override
  String get gameRunning => 'A partida está rolando.';
  @override
  String get reconnecting => 'Voltando para a mesa…';

  @override
  String get gameConnecting => 'Sentando à mesa…';
  @override
  String get yourCard => 'SUA CARTA';
  @override
  String get yourCardHint => 'Guarde para você: os outros só veem a deles.';
  @override
  String waitingForOthers(int pending) => pending == 1
      ? 'Esperando o último escolher.'
      : 'Esperando os outros: faltam $pending escolherem.';
  @override
  String get youAreOut => 'Você está fora da partida. Assista ao final, e de boca fechada.';
  @override
  String get voteTitle => 'A CIDADE VOTA';
  @override
  String get voteHint => 'Toque em quem você quer condenar. Dá para mudar de ideia enquanto a votação está aberta.';
  @override
  String get abstain => 'ME ABSTENHO';
  @override
  String votedFor(String name) => 'Você votou em $name';
  @override
  String get abstained => 'Você se absteve';
  @override
  String votesCast(int votes, int alive) => '$votes votos de $alive';
  @override
  String closesIn(String time) => 'A votação fecha em $time';
  @override
  String get rejected => 'Essa jogada não é permitida: tente de novo.';
  @override
  String get serverSilent => 'O servidor não responde: verifique sua conexão.';
  @override
  String get syncLost => 'Conexão perdida, tentando de novo…';
  @override
  String get backToRoom => 'DE VOLTA À SALA';
  @override
  String timeLeft(String time) => 'faltam $time';
  @override
  String get startingSoon => 'Começando todos juntos…';
  @override
  String get ready => 'PRONTO';
  @override
  String get readyWaiting => 'Esperando os outros…';
  @override
  String get moveRegistered => 'Feito. A cidade dorme…';
  @override
  String get voteRegistered => 'registrado ✓';
  @override
  String get sending => 'Enviando…';
  @override
  String get offlineBadge => 'offline';
  @override
  String get leaveAbandonWarning =>
      'Sair agora conta como abandono: sem pontos e sem moedas, mesmo que seu lado vença depois.';
  @override
  String get leaveDeadWarning => 'Você pode sair sem punição, mas se seu lado vencer depois, não leva recompensa.';
  @override
  String get resultsAfk => 'Você estava ausente: sem recompensa';
  @override
  String get gameClosed => 'A partida foi encerrada: ninguém mais estava jogando.';
  @override
  String get fateLeft => 'Deixou a cidade';
  @override
  String get youLeftTown => 'Você ficou ausente tempo demais e deixou a cidade. Assista ao final.';
  @override
  String get youLookOffline => 'O servidor não ouve você: para os outros, você está offline.';
  @override
  String get connectionLost => 'Conexão perdida.';
  @override
  String get abstainTag => 'se abstém';
  @override
  String votesFor(int votes) => votes == 1 ? '1 voto' : '$votes votos';
  @override
  String get nightTitleOnline => 'A NOITE';
  @override
  String get discussionTitle => 'A CIDADE DISCUTE';
  @override
  String get discussionHint => 'Dê sua opinião no chat. Depois, vote.';
  @override
  String get accusedTag => 'SOB ACUSAÇÃO';
  @override
  String get verdictWaiting => 'A cidade decidiu.';
  @override
  String get chatHint => 'Escreva…';
  @override
  String get chatLobby => 'SALA';
  @override
  String get chatTown => 'CIDADE';
  @override
  String get chatFamily => 'FAMÍLIA';
  @override
  String get chatEmpty => 'Nenhuma mensagem ainda.';
  @override
  String get chatNightClosed => 'À noite a cidade fica em silêncio.';
  @override
  String get chatDead => 'Do além, só dá para ler.';
  @override
  String get chatSilenced => 'O Alfaiate costurou sua boca: hoje você lê e vota, mas não escreve.';
  @override
  String get chatSend => 'Enviar';

  @override
  String get searchHint => 'Buscar por apelido';
  @override
  String get requests => 'PEDIDOS';
  @override
  String get yourFriends => 'SEUS AMIGOS';
  @override
  String get waiting => 'AGUARDANDO';
  @override
  String get friendsEmpty => 'Nenhum amigo ainda. Busque por apelido ou adicione a partir de uma sala.';
  @override
  String get noResults => 'Ninguém com esse apelido.';
  @override
  String get accept => 'Aceitar';
  @override
  String get decline => 'Recusar';
  @override
  String get add => 'Adicionar';
  @override
  String get remove => 'Remover';
  @override
  String get withdraw => 'Cancelar pedido';

  @override
  String get deviceOneAtATime => 'Você só pode jogar em um aparelho por vez';
  @override
  String deviceContested(String other) => 'Sua conta também está aberta em: $other. Onde você quer jogar?';
  @override
  String get deviceDisplacedTitle => 'Sua conta está ativa em outro aparelho';
  @override
  String deviceDisplaced(String other) => 'Agora você está jogando em: $other. Se quiser, retome daqui.';
  @override
  String get devicePlayHere => 'JOGAR AQUI';

  @override
  String get updateTitle => 'Atualização necessária';
  @override
  String updateNewRelease(String latest, String current) =>
      'Saiu a versão $latest e esta é a $current. Atualize para continuar jogando.';
  @override
  String get updateServer => 'Esta versão não é mais aceita na mesa. Atualize para continuar jogando.';
  @override
  String get updateButton => 'ATUALIZAR';

  @override
  String failure(OnlineFailure failure) => switch (failure) {
        OnlineFailure.notSignedIn => 'Entre com uma conta primeiro.',
        OnlineFailure.appleDisabled => 'O login com a Apple não está ativado no servidor.',
        OnlineFailure.googleDisabled => 'O login com o Google não está ativado no servidor.',
        OnlineFailure.emailDisabled => 'O login por e-mail não está ativado no servidor.',
        OnlineFailure.wrongPassword => 'Senha errada para este e-mail.',
        OnlineFailure.weakPassword => 'Senha fraca demais: pelo menos 6 caracteres.',
        OnlineFailure.invalidEmail => 'Esse e-mail não parece válido.',
        OnlineFailure.emailNotConfirmed => 'O servidor quer o e-mail confirmado: desative isso para os testes.',
        OnlineFailure.profileIncomplete => 'Termine seu perfil primeiro.',
        OnlineFailure.handleTaken => 'Esse apelido já tem dono.',
        OnlineFailure.invalidHandle => 'Nome inválido.',
        OnlineFailure.handleNotAllowed => 'Nome não permitido.',
        OnlineFailure.roomNotFound => 'Nenhuma sala com esse código.',
        OnlineFailure.roomClosed => 'Essa sala já está jogando.',
        OnlineFailure.roomFull => 'A sala está cheia.',
        OnlineFailure.hostMustChoose => 'Primeiro escolha quem assume a sala.',
        OnlineFailure.playerNotFound => 'Jogador não encontrado.',
        OnlineFailure.notAllowed => 'Não permitido.',
        OnlineFailure.requestNotFound => 'Esse pedido não existe mais.',
        OnlineFailure.messageBlocked => 'Essa mensagem não pode ser enviada.',
        OnlineFailure.tooManyMessages => 'Calma: mensagens demais seguidas.',
        OnlineFailure.tooManyReports => 'Você já enviou muitas denúncias. Tente mais tarde.',
        OnlineFailure.chatClosed => 'Você não pode escrever aqui agora.',
        OnlineFailure.reactionClosed => 'Sem gestos agora: só de dia, e só entre os vivos.',
        OnlineFailure.reactionCooldown => 'Calma com os gestos: espere alguns segundos.',
        OnlineFailure.reactionCap => 'Chega de gestos nesta partida.',
        OnlineFailure.notEnoughCoins => 'Você não tem moedas suficientes.',
        OnlineFailure.alreadyOwned => 'Isso já é seu.',
        OnlineFailure.notOwned => 'Compre primeiro.',
        OnlineFailure.itemNotFound => 'Este item não está mais na loja.',
        OnlineFailure.cancelled => 'Login cancelado.',
        OnlineFailure.rankedCooldown => 'Partidas abandonadas demais: espere um pouco antes de entrar na fila.',
        OnlineFailure.alreadyInGame => 'Você já está numa partida.',
        OnlineFailure.tutorialsRequired => 'Termine as três mãos de treino para jogar a ranqueada.',
        OnlineFailure.otherDevice => 'Sua conta está ativa em outro aparelho.',
        OnlineFailure.updateRequired => 'Atualização necessária: baixe a nova versão.',
        OnlineFailure.linkSameAccount => 'Esta conta já está vinculada.',
        OnlineFailure.linkConflict => 'Essas duas contas não podem ser unidas: já usam o mesmo tipo de login.',
        OnlineFailure.network => 'Sem conexão. Tente de novo daqui a pouco.',
        OnlineFailure.unknown => 'Algo deu errado. Tente de novo.',
      };
}

final class PortugueseShopStrings extends EnglishShopStrings {
  const PortugueseShopStrings();

  @override
  String get title => 'O ALFAIATE';
  @override
  String get subtitle => 'Alfaiataria e chapelaria · desde 1946';
  @override
  String get greeting => 'Pode experimentar. O espelho nunca mente.';
  @override
  String get coinsHint => 'As moedas vêm com cada nível, e os níveis vêm das vitórias.';
  @override
  String get featured => 'NA VITRINE';
  @override
  String endsIn(int days) => days <= 1 ? 'Último dia' : 'Faltam $days dias';
  @override
  String get counterTab => 'BALCÃO';
  @override
  String get wardrobeTab => 'GUARDA-ROUPA';
  @override
  String slot(String slot) => switch (slot) {
    'hat' => 'Chapéus',
    'face' => 'Bigodes',
    'glasses' => 'Óculos',
    'outfit' => 'Ternos',
    'hairdo' => 'Penteados',
    'tattoo' => 'Tatuagens',
    'border' => 'Molduras',
    'nameStyle' => 'Nomes',
    'gesture' => 'Gestos',
    _ => 'Acessórios',
  };
  @override
  String rarity(ShopRarity rarity) => switch (rarity) {
    ShopRarity.base => 'Da casa',
    ShopRarity.comune => 'Comum',
    ShopRarity.raro => 'Raro',
    ShopRarity.epico => 'Épico',
    ShopRarity.leggendario => 'Lendário',
  };
  @override
  String get owned => 'SEU';
  @override
  String get worn => 'VESTINDO';
  @override
  String get free => 'GRÁTIS';
  @override
  String get buy => 'COMPRAR';
  @override
  String get wear => 'VESTIR';
  @override
  String get takeOff => 'TIRAR';
  @override
  String get tryingOn => 'Provando';
  @override
  String confirmTitle(String item) => 'Comprar: $item?';
  @override
  String confirmBody(int price, int left) => 'Custa $price moedas. Vão sobrar $left.';
  @override
  String get confirmYes => 'Fechado';
  @override
  String get notNow => 'Agora não';
  @override
  String bought(String item) => '$item agora é seu.';
  @override
  String missing(int coins) => 'Faltam $coins moedas.';
  @override
  String get emptyWardrobe => 'Aqui só fica pendurado o que já é seu.';
  @override
  String get unavailable => 'A loja está fechada: entre com sua conta.';
  @override
  String get brands => 'Grifes';
  @override
  String get allBrands => 'Todas';
  @override
  String get oddities => 'Curiosidades';
  @override
  String get calcioHint => 'As velhas arquibancadas: escolha seu time.';
  @override
  String brandTagline(ShopBrand brand) => switch (brand) {
    ShopBrand.vaugirard => 'Baús e malas · Paris',
    ShopBrand.arminio => 'Alfaiataria leve · Milão',
    ShopBrand.cuccioli => 'Couro · Florença',
    ShopBrand.versalli => 'Ouro e barroco · Reggio',
    ShopBrand.chanterelle => 'Alta-costura · Paris',
    ShopBrand.nikea => 'Corrida e atletismo',
    ShopBrand.adelphi => 'O atletismo de dois irmãos',
  };
  @override
  String dept(ShopDept dept) => switch (dept) {
    ShopDept.window => 'Vitrine',
    ShopDept.hats => 'Chapéus',
    ShopDept.face => 'Rosto',
    ShopDept.outfit => 'Ternos',
    ShopDept.vice => 'Vícios',
    ShopDept.scene => 'Cenário',
    ShopDept.back => 'Ombros',
    ShopDept.hands => 'Mãos',
    ShopDept.frames => 'Molduras',
    ShopDept.gestures => 'Gestos',
  };
  @override
  String ownership(ShopOwnership ownership) => switch (ownership) {
    ShopOwnership.all => 'Tudo',
    ShopOwnership.mine => 'Meus',
    ShopOwnership.toBuy => 'Para comprar',
  };
  @override
  String get filters => 'Filtros';
  @override
  String get rarityFilter => 'Classe';
  @override
  String get collectionFilter => 'Coleção';
  @override
  String get clearFilters => 'Limpar';
  @override
  String get search => 'Buscar uma peça';
  @override
  String count(int shown, int total) => shown == total ? pieces(total) : '$shown de $total';
  @override
  String timeLeft(Duration left) => left.inDays >= 1
      ? '${left.inDays}d ${left.inHours % 24}h'
      : left.inHours >= 1
      ? '${left.inHours}h'
      : '${max(1, left.inMinutes)}min';

  @override
  String get homeSign => 'ALFAIATE';
  @override
  String get fresh => 'NOVO';
  @override
  String get allRarities => 'Todas';
  @override
  String get allSlots => 'Todos';
  @override
  String get affordable => 'Cabe no bolso';
  @override
  String get cheapFirst => 'Preço ↑';
  @override
  String get dearFirst => 'Preço ↓';
  @override
  String pieces(int count) => count == 1 ? '1 peça' : '$count peças';
  @override
  String get emptyShelf => 'Nada nesta prateleira.';
  @override
  String get changeFace => 'Mudar o rosto';
  @override
  String get viewBust => 'Personagem';
  @override
  String get viewCard => 'Cartão da mesa';
  @override
  String hand(Hand hand) => hand == Hand.left ? 'Esquerda' : 'Direita';
  @override
  String get changeFaceHint => 'Rosto, pele, bigode: fale com o barbeiro.';
  @override
  String get back => 'Voltar';
  @override
  String save(int pct) => 'ECONOMIZE $pct%';
  @override
  String get bundlesHeading => 'VISUAIS COMPLETOS';
  @override
  String get bundlesHint => 'Junto sai mais barato que peça por peça.';
  @override
  String get premiumHeading => 'GRANDE LUXO';
  @override
  String get premium => 'GRANDE LUXO';
  @override
  String get complete => 'COMPLETO';
  @override
  String get buyBundle => 'COMPRAR TUDO';
  @override
  String get bundleContents => 'NO PACOTE';
  @override
  String get singlesLabel => 'Peça por peça';
  @override
  String ownedPart(int owned, int total) => 'Você tem $owned de $total: só paga o resto.';
  @override
  String bundleConfirmTitle(String bundle) => 'Comprar $bundle?';
  @override
  String bundleConfirmBody(int price, int saved, int left) =>
      'Custa $price moedas, $saved a menos que peça por peça. Vão sobrar $left.';
  @override
  String bundleBought(String bundle) => '$bundle agora é todo seu.';
  @override
  String get seeAll => 'Todos os pacotes';
}

/// The keyed messages (the keys and placeholders of lib/l10n/messages_en.dart).
const portugueseMessages = <String, String>{
  // ---- settings
  'settings.audio': 'ÁUDIO',
  'settings.languageSection': 'IDIOMA',
  'settings.game': 'JOGO',
  'settings.account': 'CONTA',
  'settings.privacy': 'PRIVACIDADE E DADOS',
  'settings.about': 'SOBRE',
  'settings.signedInAs': 'Na conta: @{handle}',
  'settings.signedInNoHandle': 'Conta ativa, ainda sem apelido',
  'settings.notSignedIn': 'Você não entrou na conta online.',
  'settings.privacyPolicy': 'Política de privacidade',
  'settings.terms': 'Termos de uso',
  'settings.openOnWeb': 'Abrir na web',
  'settings.exportData': 'Baixar meus dados',
  'settings.exportHint': 'Tudo o que o servidor guarda sobre você, num arquivo JSON.',
  'settings.exportFailed': 'Não deu para baixar seus dados. Tente de novo.',
  'settings.deleteAccount': 'Excluir conta',
  'settings.deleteHint': 'Para sempre: perfil, amigos, guarda-roupa e moedas.',
  'settings.deleteTitle': 'Excluir sua conta?',
  'settings.deleteBody': 'Perfil, visual, amigos, guarda-roupa, moedas, missões, salas e mensagens: tudo some, para sempre.',
  'settings.deleteContinue': 'Continuar',
  'settings.cancel': 'Cancelar',
  'settings.deleteTypePrompt': 'Última palavra: digite "{word}" para confirmar.',
  'settings.deleteConfirmWord': 'EXCLUIR',
  'settings.deleteForever': 'Excluir para sempre',
  'settings.deleteDone': 'Conta excluída. Adeus, e obrigado.',
  'settings.deleteFailed': 'Não deu para excluir a conta. Tente de novo.',
  'settings.version': 'Versão',
  'settings.credits': 'Créditos',
  'settings.creditsBody': 'Sons e gráficos de Kenney (kenney.nl) e Freesound (freesound.org), sob licença CC0. Obrigado!',
  'settings.yourLook': 'SEU VISUAL',
  'settings.barberSign': 'BARBEIRO',
  'settings.changeLook': 'Mudar o visual',
  'settings.lobbyHint': 'Suas mesas: italiano, inglês e {language}.',
  'settings.lobbyHintShared': 'Suas mesas: italiano e inglês.',
  // ---- desktop
  'desktop.loginSteam': 'Entrar com a Steam',
  'desktop.steamWaiting': 'Termine o login no navegador e depois volte.',
  'desktop.screen': 'TELA',
  'desktop.windowMode': 'Janela',
  'desktop.windowed': 'Em janela',
  'desktop.fullscreen': 'Tela cheia',
  'desktop.borderless': 'Sem bordas',
  'desktop.resolution': 'Resolução',
  'desktop.resolutionHint': 'Telas mais largas jogam em 16:9, com faixas nas laterais.',
  'desktop.orientation': 'Orientação',
  'desktop.landscape': 'Paisagem',
  'desktop.portrait': 'Retrato',
  'desktop.linkAccount': 'Vincular conta',
  'desktop.linkHint': 'Jogue com o mesmo perfil no celular e no PC.',
  'desktop.linkBody': 'Entre com sua outra conta: os dois perfis viram um só.',
  'desktop.linkWith': 'Vincular {provider}',
  'desktop.linkRule': 'O perfil mais antigo vence: fica com nome, moedas, experiência, guarda-roupa e pontuação. O outro fecha para sempre.',
  'desktop.linkWaiting': 'Termine o login no navegador e depois volte.',
  'desktop.linkDone': 'Contas vinculadas.',
  'desktop.linkSwitched': 'Contas vinculadas: agora você está no perfil mais antigo.',
  'desktop.linkAlready': 'Esta conta já está vinculada.',
  'desktop.close': 'Fechar',
  'desktop.quit': 'Sair',
  'desktop.quitTitle': 'Vai deixar o beco?',
  'desktop.quitBody': 'O jogo vai fechar. Ninguém viu nada.',
  'desktop.quitConfirm': 'Sair do jogo',
  'desktop.stay': 'Ficar',
  'desktop.enterHint': 'ENTER para confirmar',
  'desktop.posterEnter': 'Entrar',
  // ---- desktopOnline
  'desktopOnline.hubCreateBody': 'Abra sua própria mesa e sente seus amigos com o código.',
  'desktopOnline.hubJoinBody': 'Alguém te passou um código? Digite e pronto, você está dentro.',
  'desktopOnline.hubFriendsBody': 'Busque por apelido, responda aos pedidos de amizade.',
  'desktopOnline.hubDoors': 'Para onde',
  'desktopOnline.profile': 'Seu perfil',
  'desktopOnline.joinHint': 'Digite o código e aperte ENTER.',
  'desktopOnline.invite': 'Convidar para a mesa',
  'desktopOnline.table': 'Na mesa',
  'desktopOnline.search': 'Buscar',
  'desktopOnline.results': 'Encontrados',
  'desktopOnline.searchEmpty': 'Digite um apelido para achar alguém.',
  'desktopOnline.rankedHow': 'Como funciona',
  'desktopOnline.freeSeat': 'Lugar vazio',
  // ---- desktopGame
  'desktopGame.menu': 'Menu',
  'desktopGame.menuTitle': 'A mesa não espera',
  'desktopGame.menuBody': 'A partida continua com este menu aberto: o relógio corre para todos.',
  'desktopGame.resume': 'De volta à mesa',
  'desktopGame.roles': 'Papéis em jogo',
  'desktopGame.settings': 'Ajustes',
  'desktopGame.leave': 'Sair da partida',
  'desktopGame.stay': 'Ficar na mesa',
  'desktopGame.leaveConfirm': 'Sair',
  'desktopGame.keyEnter': 'Enter',
  'desktopGame.chatKeys': 'ENTER para o chat',
  'desktopGame.rightClick': 'Clique direito num jogador: denunciar ou bloquear',
  'desktopGame.timeLeft': 'Tempo',
  'desktopGame.table': 'A mesa',
  'desktopGame.you': 'Você',
  // ---- gameEvent
  'gameEvent.onlyYou': 'SÓ VOCÊ',
  'gameEvent._team.mafia': 'da Família',
  'gameEvent._team.neutral': 'um lobo solitário',
  'gameEvent._team': 'de ficha limpa',
  'gameEvent._winner.citizens': 'a cidade vence',
  'gameEvent._winner.mafia': 'a Família vence',
  'gameEvent._winner.neutral': 'um solitário vence',
  'gameEvent._winner': 'ninguém vence',
  'gameEvent.text.night': 'Cai a noite {round}. A cidade dorme.',
  'gameEvent.text.dawn': 'Nasce o dia {round}.',
  'gameEvent.text.dawn.nobodyDiedTonight': 'Ninguém morreu esta noite.',
  'gameEvent.text.dawn.foundDead': 'Vítimas da noite: {names}.',
  'gameEvent.text.dawn.theEscortFended': 'A escolta rechaçou um atentado contra o Presidente.',
  'gameEvent.text.dawn.someoneWasSaved': 'Alguém foi salvo.',
  'gameEvent.text.dawn.attacksFoiled': '{saved} ataques frustrados.',
  'gameEvent.text.dawn.diedOfA': 'O coração de {broken} se partiu.',
  'gameEvent.text.scoop': 'O furo do jornal: {name} é {role}.',
  'gameEvent.text.scoop.thePaperS': 'O furo do jornal: {name} é {team}.',
  'gameEvent.text.silenced': 'O Alfaiate costurou a boca de {name}: hoje, silêncio.',
  'gameEvent.text.lynch': 'abstenções {abstained}',
  'gameEvent.text.lynch.theSquareCondemns': 'A praça não condena ninguém.',
  'gameEvent.text.lynch.theSquareCondemns.2': 'A praça condena {name}: {role}.',
  'gameEvent.text.lynch.collectsTheBounty': ' {bountyHunter} recebe a recompensa.',
  'gameEvent.text.lynch.diedOfA': ' O coração de {heartbroken} se partiu.',
  'gameEvent.text.mayor': '{name} se revela Prefeito: o voto conta em dobro.',
  'gameEvent.text.truce': '{name}, o Pacifista, pede trégua: {target} é {role}. Hoje não tem votação.',
  'gameEvent.text.cannon': ' O coração de {heartbroken} se partiu.',
  'gameEvent.text.cannon.aRoarIn': 'Um estrondo na praça: {name}, o Artilheiro, acertou {target}, que era {role}.',
  'gameEvent.text.shot': ' O coração de {heartbroken} se partiu.',
  'gameEvent.text.shot.aShotFrom': 'Um tiro do campanário volta para trás: {name}, {role}, mirava em alguém da cidade.',
  'gameEvent.text.shot.aShotFrom.2': 'Um tiro do campanário: {name} está no chão. Era {role}.',
  'gameEvent.text.aim': 'Você tem {name} na mira.',
  'gameEvent.text.cell': 'Você está numa cela. Esta noite você não sai.',
  'gameEvent.text.cell.tonightIsIn': 'Esta noite {name} está numa cela.',
  'gameEvent.text.converted': 'Você viu a luz: agora é da seita, e só vence com ela.',
  'gameEvent.text.door': '{name} agora é dos seus.',
  'gameEvent.text.door.doorShutDid': 'Porta fechada: {name} não se converteu.',
  'gameEvent.text.busy': 'Ontem à noite alguém tomou o seu tempo.',
  'gameEvent.text.left': '{name} deixou a cidade.',
  'gameEvent.text.end': 'Partida encerrada: ninguém estava jogando.',
  'gameEvent.text.end.thePresidentHas': ' O Presidente caiu.',
  'gameEvent.text.end.gameOver': 'Fim de jogo: {winner}.',
  'gameEvent.text.end.wonAlone': ' Vitória solitária: {alone}.',
  'gameEvent.text.found': '{name} era {role}.',
  'gameEvent.text.found.comesUp': '{name} aparece: {team}.',
  'gameEvent.text.watch': 'Alguém bateu à porta de {name}.',
  'gameEvent.text.watch.nobodyCameTo': 'Ninguém bateu à porta de {name}.',
  'gameEvent.text.bounty': 'Sua recompensa: faça a cidade linchar {name}.',
  'gameEvent.text.doused': 'Encharcados de gasolina: {names}.',
  'gameEvent.text.familyTarget': 'A Família não chegou a um acordo.',
  'gameEvent.text.familyTarget.theFamilyChose': 'A Família escolheu {name}.',
  'gameEvent.text.guard': 'Esta noite você fez a guarda de {name}.',
  'gameEvent.text.lend': 'Esta noite você emprestou dinheiro a {name}.',
  'gameEvent.text.protected': 'Esta noite você cuidou de {name}.',
  'gameEvent.text.dawn.foundOne': '{gender, select, masculine{Encontrado morto: {name}.} feminine{Encontrada morta: {name}.} other{Vítima da noite: {name}.}}',
  'gameEvent.text.dawn.backAmongLiving': '{gender, select, masculine{{name} voltou dos mortos.} feminine{{name} voltou dos mortos.} other{{name} volta ao mundo dos vivos.}}',
  'gameEvent.text.lovers.bound': 'Você uniu {first} e {second}.',
  'gameEvent.text.lovers.self': 'O coração escolheu: {first} e {second} se amam. Vocês só vencem se os dois viverem.',
  // ---- progress
  'progress.missions': 'Missões',
  'progress.achievements': 'Conquistas',
  'progress.leaderboard': 'Ranking',
  'progress.daily': 'DIÁRIAS',
  'progress.weekly': 'SEMANAIS',
  'progress.goals': 'OBJETIVOS',
  'progress.tabDaily': 'HOJE',
  'progress.tabWeekly': 'SEMANA',
  'progress.tabGoals': 'OBJETIVOS',
  'progress.missionsHint': 'Elas se completam enquanto você joga; depois, é só resgatar. Moedas só se ganham assim: nada se compra com dinheiro de verdade. Partidas abandonadas ou paradas nunca contam.',
  'progress.goalsHint': 'Os objetivos ficam até você alcançar. Alguns dão peças que a loja nunca vende.',
  'progress.claim': 'RESGATAR',
  'progress.claimed': 'RESGATADO',
  'progress.late': 'DE ONTEM',
  'progress.reputation': 'RESPEITO',
  'progress.reputationGain': '+{n} de respeito',
  'progress.claimDone': 'Resgatado: {coins} moedas, +{reputation} de respeito',
  'progress.itemWon': 'Agora é seu: {name}',
  'progress.reward': 'Prêmio: {name}',
  'progress.unlocksWith': 'Libera com: {mission}',
  'progress.missionOnly': 'Só com missões',
  'progress.done': 'FEITO',
  'progress.endsIn': 'termina em {inDays} dias',
  'progress.endsIn.endsInH': 'termina em {h}h',
  'progress.endsIn.endsInMin': 'termina em {d} min',
  'progress.loadFailed': 'Não deu para carregar. Tente de novo.',
  'progress.retry': 'Tentar de novo',
  'progress.unlockedCount': '{n} de {of}',
  'progress.locked': 'Bloqueada',
  'progress.rewardTitle': 'Título: "{title}"',
  'progress.rewardFrame': 'Moldura grátis',
  'progress.title': 'TÍTULO',
  'progress.leaderboardEmpty': 'Ninguém no ranking ainda.',
  'progress.leaderboardHint': 'Os cem melhores da ranqueada, por idioma.',
  'progress.yourPlace': 'Sua posição: nº {rank}',
  'progress.notRanked': 'Jogue uma ranqueada para entrar no ranking.',
  'progress.missionDone': 'Missão cumprida: {name}. Vá resgatar!',
  'progress.achievementDone': 'Conquista: {name}',
  'progress.mission.daily_play_3': 'Jogue 3 partidas',
  'progress.mission.daily_win_1': 'Vença uma partida',
  'progress.mission.daily_friends_win_2': 'Vença 2 partidas com amigos',
  'progress.mission.daily_lynch_hits_3': 'Vote no mafioso certo 3 vezes',
  'progress.mission.daily_nights_2': 'Sobreviva a 2 noites',
  'progress.mission.daily_ranked_1': 'Jogue 1 ranqueada',
  'progress.mission.daily_survive_1': 'Esteja de pé no fim de uma partida',
  'progress.mission.daily_town_win_1': 'Vença com a cidade',
  'progress.mission.daily_mafia_win_1': 'Vença com a Família',
  'progress.mission.weekly_neutral_win_1': 'Vença como neutro',
  'progress.mission.weekly_wins_7': 'Vença 7 partidas',
  'progress.mission.weekly_play_15': 'Jogue 15 partidas',
  'progress.mission.weekly_lynch_hits_10': 'Vote no mafioso certo 10 vezes',
  'progress.mission.weekly_ranked_5': 'Jogue 5 ranqueadas',
  'progress.mission.weekly_ranked_wins_3': 'Vença 3 ranqueadas',
  'progress.mission.weekly_saves_2': 'Salve 2 vidas como Doutor',
  'progress.mission.weekly_finds_3': 'Desmascare 3 mafiosos como Detetive',
  'progress.mission.weekly_kills_5': 'Faça 5 serviços com a Família',
  'progress.mission.weekly_nights_12': 'Sobreviva a 12 noites',
  'progress.mission.daily_friends_play_2': 'Jogue 2 partidas com amigos',
  'progress.mission.daily_win_alive_1': 'Vença e esteja de pé no fim',
  'progress.mission.daily_survive_2': 'Esteja de pé no fim de 2 partidas',
  'progress.mission.weekly_play_10': 'Jogue 10 partidas',
  'progress.mission.weekly_wins_4': 'Vença 4 partidas',
  'progress.mission.weekly_town_wins_3': 'Vença 3 vezes com a cidade',
  'progress.mission.weekly_mafia_wins_2': 'Vença 2 vezes com a Família',
  'progress.mission.weekly_detective_win_1': 'Vença uma partida como Detetive',
  'progress.mission.weekly_doctor_win_1': 'Vença uma partida como Doutor',
  'progress.mission.long_nights_10': 'Sobreviva a 10 noites',
  'progress.mission.long_lynch_hits_3': 'Mande 3 soldados para a forca',
  'progress.mission.long_detective_wins_5': 'Vença 5 partidas como Detetive',
  'progress.mission.long_finds_5': 'Desmascare 5 mafiosos como Detetive',
  'progress.mission.long_mafia_wins_10': 'Vença 10 vezes com a Família',
  'progress.mission.long_town_wins_10': 'Vença 10 vezes com a cidade',
  'progress.mission.long_wins_50': 'Vença 50 partidas',
  'progress.mission.long_games_25': 'Jogue 25 partidas',
  'progress.mission.long_friends_games_20': 'Jogue 20 partidas com amigos',
  'progress.mission.long_ranked_games_20': 'Jogue 20 ranqueadas',
  'progress.mission.long_saves_5': 'Salve 5 vidas como Doutor',
  'progress.mission.long_survived_25': 'Esteja de pé no fim de 25 partidas',
  'progress.mission.long_neutral_wins_3': 'Vença 3 vezes como neutro',
  'progress.mission': 'Meta: {target}',
  'progress.achievement.wins_10': 'Sortudo',
  'progress.achievement': 'Vença 10 partidas',
  'progress.achievement.wins_50': 'Homem de honra',
  'progress.achievement.winGames': 'Vença 50 partidas',
  'progress.achievement.wins_200': 'Lenda',
  'progress.achievement.winGames.2': 'Vença 200 partidas',
  'progress.achievement.games_25': 'Freguês',
  'progress.achievement.playGames': 'Jogue 25 partidas',
  'progress.achievement.games_100': 'Parte da mobília',
  'progress.achievement.playGames.2': 'Jogue 100 partidas',
  'progress.achievement.games_500': 'Veterano',
  'progress.achievement.playGames.3': 'Jogue 500 partidas',
  'progress.achievement.ranked_wins_10': 'No pano verde',
  'progress.achievement.winRankedGames': 'Vença 10 ranqueadas',
  'progress.achievement.ranked_wins_50': 'Chefão',
  'progress.achievement.winRankedGames.2': 'Vença 50 ranqueadas',
  'progress.achievement.friends_wins_25': 'Entre amigos',
  'progress.achievement.winGamesWith': 'Vença 25 partidas com amigos',
  'progress.achievement.town_wins_25': 'Cidadão modelo',
  'progress.achievement.winTimesWith': 'Vença 25 vezes com a cidade',
  'progress.achievement.mafia_wins_25': 'Homem feito',
  'progress.achievement.winTimesWith.2': 'Vença 25 vezes com a Família',
  'progress.achievement.neutral_wins_1': 'Por conta própria',
  'progress.achievement.winAsA': 'Vença como neutro',
  'progress.achievement.neutral_wins_10': 'Lobo solitário',
  'progress.achievement.winTimesAs': 'Vença 10 vezes como neutro',
  'progress.achievement.roles_won_5': 'Muitas caras',
  'progress.achievement.winWithDifferent': 'Vença com 5 papéis diferentes',
  'progress.achievement.roles_won_12': 'Ator de carreira',
  'progress.achievement.winWithDifferent.2': 'Vença com 12 papéis diferentes',
  'progress.achievement.roles_won_all': 'Camaleão',
  'progress.achievement.winWithEvery': 'Vença com todos os papéis',
  'progress.achievement.roles_town_all': 'A cidade inteira',
  'progress.achievement.winWithEvery.2': 'Vença com todos os papéis da cidade',
  'progress.achievement.roles_mafia_all': 'A Família inteira',
  'progress.achievement.winWithEvery.3': 'Vença com todos os papéis da Família',
  'progress.achievement.roles_lone_all': 'Todos os solitários',
  'progress.achievement.winWithEvery.4': 'Vença com todos os papéis solitários',
  'progress.achievement.winAGame': 'Vença uma partida com este papel',
  'progress.achievement.wins_alive_25': 'Couro grosso',
  'progress.achievement.winTimesStill': 'Vença 25 vezes ainda de pé',
  'progress.achievement.lynch_hits_10': 'Bom faro',
  'progress.achievement.voteCondemnedMafiosi': 'Vote em 10 mafiosos condenados',
  'progress.achievement.lynch_hits_50': 'Cão farejador',
  'progress.achievement.voteCondemnedMafiosi.2': 'Vote em 50 mafiosos condenados',
  'progress.achievement.lynch_hits_200': 'Vingador',
  'progress.achievement.voteCondemnedMafiosi.3': 'Vote em 200 mafiosos condenados',
  'progress.achievement.nights_25': 'Insone',
  'progress.achievement.surviveNights': 'Sobreviva a 25 noites',
  'progress.achievement.nights_100': 'Coruja',
  'progress.achievement.surviveNights.2': 'Sobreviva a 100 noites',
  'progress.achievement.saves_1': 'Primeiros socorros',
  'progress.achievement.saveALife': 'Salve uma vida como Doutor',
  'progress.achievement.saves_10': 'Anjo da guarda',
  'progress.achievement.saveLivesAs': 'Salve 10 vidas como Doutor',
  'progress.achievement.countryDoctor': 'Médico do interior',
  'progress.achievement.asTheDoctor': 'Como Doutor, salve alguém e esteja de pé no fim',
  'progress.achievement.finds_10': 'Faro de tira',
  'progress.achievement.unmaskMafiosiAs': 'Desmascare 10 mafiosos como Detetive',
  'progress.achievement.theInspector': 'O Inspetor',
  'progress.achievement.asTheDetective': 'Como Detetive, mande o Padrinho para a forca',
  'progress.achievement.snipes_1': 'Tiro limpo',
  'progress.achievement.asTheSniper': 'Como Atirador, derrube um mafioso',
  'progress.achievement.kills_25': 'Mão pesada',
  'progress.achievement.successfulHitsWith': '25 serviços bem-feitos com a Família',
  'progress.achievement.framed_5': 'Armador',
  'progress.achievement.asAMafioso': 'Como mafioso, faça condenar 5 inocentes',
  'progress.achievement.fool_win': 'Último a rir',
  'progress.achievement.winAsThe': 'Vença como Bobo',
  'progress.titleName.man_of_honor': 'Homem de honra',
  'progress.titleName.legend': 'Lenda',
  'progress.titleName.veteran': 'Veterano',
  'progress.titleName.boss': 'Chefão',
  'progress.titleName.model_citizen': 'Cidadão modelo',
  'progress.titleName.made_man': 'Homem feito',
  'progress.titleName.lone_wolf': 'Lobo solitário',
  'progress.titleName.chameleon': 'Camaleão',
  'progress.titleName.bloodhound': 'Cão farejador',
  'progress.titleName.night_owl': 'Coruja',
  'progress.titleName.guardian_angel': 'Anjo da guarda',
  'progress.titleName.inspector': 'O Inspetor',
  'progress.titleName.schemer': 'Armador',
  'progress.toClaim': '{n} para resgatar',
  // ---- recap
  'recap.open': 'O RELATO COMPLETO',
  'recap.masthead': 'O Relato Completo',
  'recap.dateLine': 'Edição especial · todas as cartas na mesa',
  'recap.cast': 'Quem era quem',
  'recap.timeline': 'Noite após noite, dia após dia',
  'recap.night': 'Noite {round}',
  'recap.day': 'Dia {round}',
  'recap.won': 'VENCEU',
  'recap.wonAlone': 'VITÓRIA SOLITÁRIA',
  'recap.survived': 'de pé',
  'recap.fell': 'caiu',
  'recap.left': 'saiu',
  'recap.close': 'FECHAR',
  'recap.you': 'você',
  'recap.quietNight': 'Uma noite sem jogadas.',
  'recap.team.citizens': 'cidade',
  'recap.team.mafia': 'Família',
  'recap.team.neutral': 'por conta própria',
  'recap.winner.citizens': 'A cidade vence',
  'recap.winner.mafia': 'A Família vence',
  'recap.winner.neutral': 'O Incendiário vence',
  'recap.winner.null': 'Ninguém vence',
  'recap.familyAimed': 'A Família foi atrás de {target} ({voters}).',
  'recap.familyNobody': 'A Família não chegou a um acordo.',
  'recap.move.silence': 'costurou a boca de {target}.',
  'recap.move.protect': 'cuidou de {target}.',
  'recap.move.guard': 'fez a guarda de {target}.',
  'recap.move.snipe': 'atirou em {target}.',
  'recap.move.scoop': 'deu o furo sobre {target}.',
  'recap.move.douse': 'encharcou {target} de gasolina.',
  'recap.move.ignite': 'riscou o fósforo.',
  'recap.move.resurrect': 'trouxe {target} de volta à vida.',
  'recap.move.lend': 'emprestou dinheiro a {target}.',
  'recap.move.stab': 'esfaqueou {target}.',
  'recap.move.jail': 'trancou {target} na cela.',
  'recap.move.block': 'passou a noite com {target}.',
  'recap.move.link': 'fez {target} se apaixonar.',
  'recap.move.convert': 'chamou {target} para a seita.',
  'recap.move.aim': 'pôs {target} na mira.',
  'recap.attack.family': 'pela Família',
  'recap.attack.sniper': 'pelo Atirador',
  'recap.attack.fire': 'pelo fogo',
  'recap.attack.assassin': 'pelo Matador',
  'recap.attack.shrugged': '{target} levou o golpe {by} e sobreviveu.',
  'recap.attack.escorted': 'A escolta rechaçou o atentado {by} contra {target}.',
  'recap.scoopOut.mafia': 'O jornal saiu: {target} é da Família.',
  'recap.scoopOut.citizens': 'O jornal saiu: {target} tem ficha limpa.',
  'recap.scoopOut.neutral': 'O jornal saiu: {target} joga por conta própria.',
  'recap.mayor': '{name} se revela Prefeito: o voto conta em dobro.',
  'recap.votes': 'A votação',
  'recap.abstained': 'se abstém',
  'recap.noCondemned': 'A praça não condena ninguém.',
  'recap.foolWins': '{name} queria exatamente isso: vitória solitária.',
  'recap.bounty': '{hunter} recebe a recompensa.',
  'recap.exit': '{name} deixou a cidade.',
  'recap.leftTown': '{name} saiu de cena.',
  'recap.wentAway': '{name} se afastou da mesa.',
  'recap.cameBack': '{name} está de volta à mesa.',
  'recap.calledOut': '{name} está chamando você.',
  'recap.move.investigate': 'investigou {target}: deu {seen, select, mafia{Família} other{ficha limpa}}.',
  'recap.move.dig': 'desenterrou {target}: era {role}.',
  'recap.move.watch': 'vigiou a porta de {target}: {visited, select, yes{alguém passou por lá} other{ninguém passou por lá}}.',
  'recap.attack.killed': '{gender, select, masculine{{target} foi morto {by}.} feminine{{target} foi morta {by}.} other{{target} não resiste: o golpe vem {by}.}}',
  'recap.attack.healed': '{gender, select, masculine{{target}, atingido {by}, foi salvo.} feminine{{target}, atingida {by}, foi salva.} other{O golpe vem {by}, mas {target} se salva.}}',
  'recap.risen': '{gender, select, masculine{{target} voltou dos mortos.} feminine{{target} voltou dos mortos.} other{{target} volta ao mundo dos vivos.}}',
  'recap.condemned': 'A praça condena {name}. Era {role}.',
  // ---- rolesSheet
  'rolesSheet.button': 'PAPÉIS',
  'rolesSheet.title': 'Papéis em jogo',
  'rolesSheet.subtitle': 'As cartas desta partida. Quem tem cada uma continua segredo.',
  'rolesSheet.deckEmpty': 'O baralho ainda não é conhecido.',
  'rolesSheet.legendTitle': 'O que os símbolos querem dizer',
  'rolesSheet.revealedBy': 'revelado: {name}',
  'rolesSheet.silenced': 'em silêncio',
  'rolesSheet.silencedLegend': 'silenciado pelo Alfaiate: hoje não escreve, mas ainda vota',
  'rolesSheet.offline': 'ausente',
  'rolesSheet.offlineLegend': 'ponto cinza: o jogador caiu da conexão',
  'rolesSheet.dead': 'morto',
  'rolesSheet.deadLegend': 'cravo ou punhal: o jogador morreu',
  'rolesSheet.accused': 'sob acusação',
  'rolesSheet.accusedLegend': 'faixa SOB ACUSAÇÃO: o mais votado agora',
  'rolesSheet.votes': 'votos recebidos',
  'rolesSheet.votesLegend': 'círculo vermelho com número: votos recebidos',
  'rolesSheet.voteNote': 'votou em',
  'rolesSheet.voteNoteLegend': 'nota "→ nome": em quem votou',
  'rolesSheet.revealedRole': 'papel revelado',
  'rolesSheet.revealedRoleLegend': 'ícone ou nome de papel num lugar: um papel que você conhece',
  'rolesSheet.selected': 'escolhido',
  'rolesSheet.meLegend': 'plaquinha dourada: é você',
  'rolesSheet.teamLabel': 'Time',
  'rolesSheet.nightLabel': 'À noite',
  'rolesSheet.winLabel': 'Você vence se',
  'rolesSheet.twistLabel': 'Cuidado',
  'rolesSheet.teamFamily': 'a Família',
  'rolesSheet.teamTown': 'a cidade',
  'rolesSheet.teamAlone': 'por conta própria',
  // ---- safety
  'safety.report': 'Denunciar',
  'safety.block': 'Bloquear',
  'safety.unblock': 'Desbloquear',
  'safety.cancel': 'Cancelar',
  'safety.send': 'Enviar',
  'safety.reportTitle': 'Denunciar {name}',
  'safety.reportWhy': 'O que aconteceu?',
  'safety.reason.language': 'Linguagem ofensiva',
  'safety.reason.cheating': 'Trapaça ou abandono de partidas',
  'safety.reason.identity': 'Nome de usuário ou visual inadequado',
  'safety.reason.spam': 'Spam',
  'safety.reason.other': 'Outro',
  'safety.noteHint': 'Detalhes (opcional)',
  'safety.reportPrivate': 'Fica entre nós: ninguém vai saber quem denunciou.',
  'safety.reportSent': 'Denúncia recebida. A partir daqui é com a gente.',
  'safety.reportedMessage': 'Mensagem denunciada',
  'safety.blockTitle': 'Bloquear {name}?',
  'safety.blockBody': 'Some da sua vista: sem mensagens, sem amizade, sem lugar nas suas salas. Na ranqueada, vocês ficam em mesas diferentes. Dá para desfazer nos Ajustes.',
  'safety.muteChat': 'Silenciar chat',
  'safety.unmuteChat': 'Reativar chat',
  'safety.chatMuted': 'Você não vê mais as mensagens de {name} (só aqui).',
  'safety.chatUnmuted': 'Você voltou a ver as mensagens de {name}.',
  'safety.seat': 'Lugar {number}',
  'safety.atTable': 'Na mesa',
  'safety.outOfGame': 'Fora da partida',
  'safety.inRoom': 'Na sala',
  'safety.blocked': 'Você bloqueou {name}.',
  'safety.unblocked': 'Você desbloqueou {name}.',
  'safety.blockedPlayers': 'Jogadores bloqueados',
  'safety.blockedHint': 'Quem você bloqueou, e como desbloquear.',
  'safety.noneBlocked': 'Você não bloqueou ninguém.',
  'safety.rulesTitle': 'Regras da comunidade',
  'safety.rulesHint': 'Como a gente se comporta na mesa.',
  'safety.rulesEnforcement': 'Você pode denunciar um jogador tocando no rosto dele na mesa ou segurando uma das mensagens. Toda denúncia é analisada: quem quebra as regras pode perder o chat, a ranqueada ou a conta. Mensagens e nomes ofensivos são bloqueados automaticamente.',
  'safety.rulesContact': 'Para denúncias urgentes, escreva para',
  'safety.rules.1': 'Minta no jogo, não para as pessoas. Blefar faz parte de Obertà; insultos, ameaças e assédio, não.',
  'safety.rules.2': 'Nada de discurso de ódio, ofensas, conteúdo sexual ou ataques à origem, religião, gênero, orientação ou deficiência de ninguém.',
  'safety.rules.3': 'Nomes de usuário e visuais precisam ser decentes: nada de nomes ofensivos, nada de se passar pela equipe ou por outro jogador.',
  'safety.rules.4': 'Jogue sua partida até o fim. Abandonar, entregar de propósito ou combinar fora do jogo estraga a diversão de todos.',
  'safety.rules.5': 'Nada de spam, anúncios, links ou dados pessoais: nunca compartilhe telefone, endereço ou redes sociais.',
  'safety.rules.6': 'Seja gentil com quem está começando. Todo mundo já foi novato.',
  // ---- stats
  'stats.tabFile': 'FICHA',
  'stats.tabStats': 'NÚMEROS',
  'stats.title': 'ESTATÍSTICAS PESSOAIS',
  'stats.includeTests': 'Incluir partidas de teste',
  'stats.games': 'Partidas',
  'stats.wins': 'Vitórias',
  'stats.losses': 'Derrotas',
  'stats.winRate': 'Aproveitamento',
  'stats.atTheTable': 'NA MESA',
  'stats.timePlayed': 'Tempo na mesa',
  'stats.timeMeasured': 'medido em {timed} de {games} partidas',
  'stats.favouriteRole': 'Papel favorito',
  'stats.longestStreak': 'Maior sequência de vitórias',
  'stats.survived': 'De pé no fim',
  'stats.byTable': 'POR MESA',
  'stats.friends': 'Com amigos',
  'stats.ranked': 'Ranqueada',
  'stats.byFaction': 'POR FACÇÃO',
  'stats.family': 'Família',
  'stats.town': 'Cidade',
  'stats.alone': 'Por conta própria',
  'stats.byRole': 'POR PAPEL',
  'stats.neverPlayed': 'nunca jogado',
  'stats.feats': 'FAÇANHAS',
  'stats.featsHint': 'De todos os tempos, só de partidas jogadas até o fim.',
  'stats.counter.nights': 'Noites sobrevividas',
  'stats.counter.lynch_hits': 'Votos certeiros no linchamento',
  'stats.counter.saves': 'Salvamentos do Doutor',
  'stats.counter.finds': 'Culpados encontrados',
  'stats.counter.snipes': 'Tiros do Atirador',
  'stats.counter.kills': 'Serviços da Família',
  'stats.counter.framed': 'Honestos incriminados',
  'stats.counter.godfather_lynch': 'Padrinhos linchados',
  'stats.counter.wins_alive': 'Vitórias de pé',
  'stats.private': 'SÓ PARA VOCÊ',
  'stats.privateHint': 'Ninguém mais vê esses números.',
  'stats.abandoned': 'Abandonadas',
  'stats.afk': 'Ausente (AFK)',
  'stats.reserved': 'RESTRITO',
  'stats.empty': 'Nenhuma partida online ainda. Os números se escrevem enquanto você joga.',
  'stats.loadFailed': 'Não deu para carregar. Tente de novo.',
  'stats.retry': 'Tentar de novo',
  'stats.profile': 'Perfil',
  'stats.publicTitle': 'FICHA PÚBLICA',
  'stats.onRecord': 'NA FICHA',
  'stats.featured': 'MEDALHAS EM DESTAQUE',
  'stats.noMedals': 'Nenhuma medalha ainda.',
  'stats.topRoles': 'PAPÉIS MAIS JOGADOS',
  'stats.closedFile': 'Ficha restrita: este jogador guarda os números para si.',
  'stats.unavailable': 'Perfil indisponível.',
  'stats.publicSwitch': 'Perfil público',
  'stats.publicSwitchHint': 'Os outros veem seus números, posto e medalhas. Desligado: só nome, nível e retrato.',
  'stats.gamesWins': '{games, plural, one{# partida} other{# partidas}} · {wins} vitórias',
  // ---- table
  'table.holdTheCard': 'Segure a carta para olhar.',
  'table.picked': 'Você escolheu {name}. Dá para mudar até o tempo acabar.',
  'table.passed': 'Você passou. Ainda dá para escolher alguém.',
  'table.familyPicks': 'Família: {picks}',
  'table.nightRunsOut': 'A noite termina quando o tempo acaba.',
  'table.investigate': 'Investigar {name}?',
  'table.dig': 'Desenterrar {name}?',
  'table.instantAnswer': 'A resposta vem na hora, e depois não dá para mudar.',
  'table.cancel': 'Cancelar',
  'table.jail': 'Trancar {name} na cela?',
  'table.jailBody': 'A cela fecha na hora: esta noite a pessoa não age e ninguém pode tocá-la. Não dá para mudar.',
  'table.youAreJailed': 'Você está numa cela. Esta noite você não sai.',
  'table.jailerWantsYou': 'O Carcereiro quer dar uma palavrinha.',
  'table.inYourCell': 'Na sua cela: {name}. Interrogue pelo chat.',
  'table.lastOfFamily': 'Da Família, só sobrou você: agora a noite é sua.',
  'table.mateInCell': 'Esta noite {name} está numa cela.',
  'table.jailChat': 'A cela',
  'table.jailer': 'O Carcereiro',
  'table.converted': 'Você viu a luz: agora é da seita, e só vence com ela.',
  'table.sectLine': 'Sua seita: {names}.',
  'table.doorClosed': 'Porta fechada: {name} não se converteu.',
  'table.linkFirst': 'Toque no primeiro apaixonado.',
  'table.linkSecond': '{name} e quem mais? Toque no segundo.',
  'table.link': 'Fazer {a} e {b} se apaixonarem?',
  'table.linkBody': 'Ficam sabendo ao amanhecer e só vencem se os dois viverem. Depois não dá para mudar.',
  'table.loversLine': 'Apaixonados: {a} e {b}.',
  'table.inLoveWith': 'Seu coração bate por {name}.',
  'table.loversChat': 'Os apaixonados',
  'table.answerAtDawn': 'Alguém nesta mesa bloqueia: a resposta vem ao amanhecer.',
  'table.readTheNews': 'Leia as notícias, depois Pronto.',
  'table.votedFor': 'Você votou em {name}. Dá para mudar de ideia.',
  'table.revealMayor': 'Revelar',
  'table.revealMayorTitle': 'Revelar-se como Prefeito?',
  'table.revealMayorBody': 'Todos vão saber quem você é, e seu voto conta em dobro a partir de hoje.',
  'table.shootTitle': 'Atirar em {name}?',
  'table.shotLine': 'O tiro voltou: {name} era {role}.',
  'table.shotLine.aShotFrom': 'Um tiro do campanário: {name} era {role}.',
  'table.aimLine': 'Na mira: {name}. Tiros: {left}.',
  'table.truce': 'Trégua',
  'table.truceHint': 'Toque em quem revelar para todos.',
  'table.truceTitle': 'Parar tudo: revelar {name}?',
  'table.truceBody': 'Todos vão ver o papel exato da pessoa, e o seu. Hoje não tem votação. Só uma vez.',
  'table.truceLine': '{pacifist} pediu trégua: {name} é {role}.',
  'table.truceVerdict': 'Trégua: hoje ninguém vai para a forca.',
  'table.fire': 'Fogo!',
  'table.fireHint': 'Toque em quem acertar.',
  'table.fireTitle': 'Fogo em {name}?',
  'table.fireBody': 'Morre na hora e o papel fica público. Todos ouvem o estrondo: vão saber que você é o Artilheiro.',
  'table.shotsLeft': 'Resta um tiro.',
  'table.shotsLeft.youHaveShots': 'Restam {count} tiros.',
  'table.gunnerShotsLeft': 'O Artilheiro não tem mais tiros.',
  'table.gunnerShotsLeft.theGunnerHas': 'O Artilheiro tem um último tiro.',
  'table.gunnerShotsLeft.theGunnerHas.2': 'O Artilheiro tem {count} tiros.',
  'table.cannonLine': 'Um estrondo na praça: o Artilheiro acertou {name}, que era {role}.',
  'table.noLynch': 'Ninguém foi linchado.',
  'table.chatOpensLater': 'A praça reabre para a discussão.',
  'table.chatOver': 'A partida acabou.',
  'table.rejoin': 'Voltar',
  'table.leave': 'Sair',
  'table.abstained': '{gender, select, masculine{Você se absteve. Ainda dá para votar.} feminine{Você se absteve. Ainda dá para votar.} other{Abstenção registrada. Ainda dá para votar.}}',
  'table.silenced': '{gender, select, masculine{silenciado} feminine{silenciada} other{em silêncio}}',
  'table.lynched': '{gender, select, masculine{Linchado} feminine{Linchada} other{Na forca}}',
  'table.lynchedLine': '{gender, select, masculine{{name} foi linchado.} feminine{{name} foi linchada.} other{A praça linchou {name}.}}',
  'table.lynchedLine.role': '{gender, select, masculine{{name} foi linchado. Era {role}.} feminine{{name} foi linchada. Era {role}.} other{A praça linchou {name}. Era {role}.}}',
  'table.abstainedVotes': '{n, plural, one{# abstenção} other{# abstenções}}',
  'table.shootBody': 'Todos ouvem, ninguém sabe quem atirou. Se for da cidade, o tiro volta e quem morre é você. {left, plural, one{É o seu último tiro.} other{Restam # tiros.}}',
  // ---- tutorial
  'tutorial.you': 'Você',
  'tutorial.skip': 'Pular',
  'tutorial.exit': 'Sair',
  'tutorial.exitTitle': 'Sair da mão de treino?',
  'tutorial.exitBody': 'Não vai contar como feita: dá para jogar de novo quando quiser.',
  'tutorial.stay': 'Ficar',
  'tutorial.hint': 'Primeira vez? Três mãos de treino, uma por cor.',
  'tutorial.hintGo': 'Tentar',
  'tutorial.replay': 'Tutorial',
  'tutorial.replayHint': 'Três mãos de treino contra os bots.',
  'tutorial.deskButton': 'Tutorial',
  'tutorial.choose': 'Escolha um lado para aprender',
  'tutorial.chooseSub': 'Uma mão contra cinco bots, na mesa de verdade.',
  'tutorial.faction.family': 'Família',
  'tutorial.faction.city': 'Cidade',
  'tutorial.faction.solo': 'Por conta própria',
  'tutorial.pitch.family': 'Mate de noite, minta de dia.',
  'tutorial.pitch.city': 'Investigue, desmascare a Família.',
  'tutorial.pitch.solo': 'Vá para a forca e vença por conta própria.',
  'tutorial.done': 'Feito',
  'tutorial.ready': 'Agora é com você',
  'tutorial.toTheTable': 'Para a mesa',
  'tutorial.nextHand': 'Outra mão',
  // ---- tutorialScript
  'tutorialScript.whenYouHave': 'Leu? Então, «Pronto».',
  'tutorialScript.atDawnYou': 'Ao amanhecer você vê como foi a noite.',
  'tutorialScript.theTownWins.city': 'A cidade vence quando não sobra ninguém da Família. Prova vale mais que conversa.',
  'tutorialScript.youAreThe.city': 'Você é o Detetive. Segure a carta, depois «Pronto».',
  'tutorialScript.atNightYou.city': 'À noite você investiga. Toque em Vito, lugar 2, e confirme.',
  'tutorialScript.vitoIsFamily.city': 'Vito é da Família. Por enquanto, só você sabe.',
  'tutorialScript.brunoNeverHurt.city': 'Bruno nunca fez mal a ninguém. Quem queria ele morto?',
  'tutorialScript.iWasAt.city': 'Passei a noite toda no bar. Pergunta pro 4.',
  'tutorialScript.trueLookAt.city': 'Verdade. Olhem o 6: calmo demais.',
  'tutorialScript.meDetectiveWhat.city': 'Eu?? Detetive, o que você sabe?',
  'tutorialScript.iCheckedVito.city': 'Investiguei o Vito: Família.',
  'tutorialScript.isLyingI.city': 'O 2 está mentindo. Eu vi ele esta noite.',
  'tutorialScript.liarHeJust.city': 'Mentira! Ele só quer confundir vocês.',
  'tutorialScript.ifTheDetective.city': 'Se o Detetive diz, eu topo.',
  'tutorialScript.meTooWe.city': 'Eu também. Votamos no 2.',
  'tutorialScript.theSquareTalks.city': 'A praça discute. Conte o que você sabe sobre o Vito.',
  'tutorialScript.theyBelieveYou.city': 'Acreditaram em você. «Pronto», e vamos votar.',
  'tutorialScript.onSecondThought.city': 'Pensando melhor... o 2.',
  'tutorialScript.watchTheHands.city': 'Olho nas mãos: as opiniões mudam. Aponte para o Vito.',
  'tutorialScript.theLynchedShows.city': 'O linchado mostra a carta. A praça acertou.',
  'tutorialScript.anotherNightCheck.city': 'Outra noite. Investigue a Carmela, lugar 4.',
  'tutorialScript.carmelaIsFamily.city': 'Carmela também é da Família.',
  'tutorialScript.tonightTheyCame.city': 'Esta noite vieram atrás de você...',
  'tutorialScript.theDoctorSaved.city': 'O Doutor salvou você. Agora é sua vez.',
  'tutorialScript.iWatchedOver.city': 'Cuidei do Detetive esta noite. Eles tentaram.',
  'tutorialScript.luckyYouBut.city': 'Sorte sua... mas o Vito agiu sozinho.',
  'tutorialScript.detectiveWhoDid.city': 'Detetive, quem você investigou esta noite?',
  'tutorialScript.carmelaFamily.city': 'Carmela: Família.',
  'tutorialScript.isTheLast.city': 'A 4 é a última. Votem nela.',
  'tutorialScript.ohPleaseIs.city': 'Ah, por favor! O 1 está delirando.',
  'tutorialScript.iSavedYou.city': 'Eu salvei você: confio em você.',
  'tutorialScript.weVote.city': 'Votamos na 4.',
  'tutorialScript.lastDayTell.city': 'Último dia. Conte à praça sobre a Carmela.',
  'tutorialScript.goodReadyAnd.city': 'Muito bem. «Pronto», e vamos votar.',
  'tutorialScript.noWait.city': 'Não, espera: a 4.',
  'tutorialScript.voteCarmela.city': 'Vote na Carmela.',
  'tutorialScript.noFamilyLeft.city': 'Não sobrou ninguém da Família: a cidade vence.',
  'tutorialScript.theFamilyWins.family': 'A Família vence quando empata em número com a cidade. De dia, minta bem.',
  'tutorialScript.thisTimeYou.family': 'Desta vez você é da Família. Segure a carta, depois «Pronto».',
  'tutorialScript.justTheTwo.family': 'Só nós dois. Ninguém pode saber.',
  'tutorialScript.iSayEnzo.family': 'Eu digo o 6, Enzo: pergunta demais. E você?',
  'tutorialScript.ok.family': 'Ok, o 6.',
  'tutorialScript.fineEnzoTonight.family': 'Fechado, Enzo esta noite.',
  'tutorialScript.perfectTap.family': 'Perfeito. Toque no 6.',
  'tutorialScript.atNightThe.family': 'À noite a Família conversa em segredo. Responda ao Vito.',
  'tutorialScript.nowTapEnzo.family': 'Agora toque no Enzo, lugar 6: esse é o seu voto.',
  'tutorialScript.twoVotesOn.family': 'Dois votos no Enzo: a Família está de acordo.',
  'tutorialScript.enzoLivesThe.family': 'Enzo vive: o Doutor salvou ele. Tentem de novo depois.',
  'tutorialScript.someoneWentTo.family': 'Alguém foi até a casa do Enzo esta noite.',
  'tutorialScript.aliveByA.family': 'Vivo por milagre. Quem foi?',
  'tutorialScript.wasOutOn.family': 'O 1 estava na rua ontem à noite. Eu vi ele.',
  'tutorialScript.wellTalk.family': 'E aí, 1? Fala.',
  'tutorialScript.easyWasAt.family': 'Calma, o 1 estava no bar comigo.',
  'tutorialScript.brunoAccusesFirst.family': 'Bruno acusa primeiro: quem acusa primeiro esconde alguma coisa.',
  'tutorialScript.iWasAsleep.family': 'Eu estava dormindo. Mas o 3 sabe muita coisa, né?',
  'tutorialScript.brunoIsIn.family': 'Bruno está com pressa, é verdade.',
  'tutorialScript.toldYouIs.family': 'Eu disse. O 3 é estranho.',
  'tutorialScript.whatIAm.family': 'O quê?! Eu sou limpo!',
  'tutorialScript.theyAccuseYou.family': 'Estão acusando você. Não se defenda: jogue a culpa no Bruno, lugar 3.',
  'tutorialScript.itWorkedReady.family': 'Funcionou. «Pronto», e vamos votar.',
  'tutorialScript.changedMyMind.family': 'Mudei de ideia: o 3.',
  'tutorialScript.handsAreMoving.family': 'As mãos estão mudando. Vote no Bruno, lugar 3, junto com eles.',
  'tutorialScript.brunoWasInnocent.family': 'Bruno era inocente. Você está a salvo, por hoje.',
  'tutorialScript.theDoctorSaved.family': 'O Doutor salvou o Enzo. Aposto que é a 4.',
  'tutorialScript.herTonightYou.family': 'Ela esta noite. Topa?',
  'tutorialScript.iAmIn.family': 'Topo: a 4.',
  'tutorialScript.fineCarmela.family': 'Fechado, Carmela.',
  'tutorialScript.letSGo.family': 'Vamos nessa.',
  'tutorialScript.vitoHasAn.family': 'Vito tem uma ideia. Responda.',
  'tutorialScript.tapCarmelaSeat.family': 'Toque na Carmela, lugar 4.',
  'tutorialScript.twoAgainstTwo.family': 'Dois contra dois: a cidade não pode mais vencer.',
  'tutorialScript.soloPlayersHave.solo': 'Os solitários têm um objetivo próprio: o Bobo vence se for linchado, e a partida segue sem ele.',
  'tutorialScript.youPlayAlone.solo': 'Você joga por conta própria: o Bobo vence se for linchado. Segure a carta.',
  'tutorialScript.theFoolHas.solo': 'O Bobo não tem poder: toque em qualquer um para disfarçar.',
  'tutorialScript.atNightYou.solo': 'À noite você não faz nada. Seu trabalho é de dia.',
  'tutorialScript.brunoIsGone.solo': 'Bruno se foi. Agora a gente conversa.',
  'tutorialScript.brunoIsDead.solo': 'Bruno morreu. Alguém viu alguma coisa?',
  'tutorialScript.iWasAsleep.solo': 'Eu estava dormindo. Mas o 1 passou a noite acordado.',
  'tutorialScript.yeahDoesNot.solo': 'É, o 1 não me convence.',
  'tutorialScript.giveHimA.solo': 'Deem uma chance. E então, 1?',
  'tutorialScript.brunoOneLess.solo': 'Bruno? Um a menos. Não vou chorar.',
  'tutorialScript.iSayNothing.solo': 'Não digo nada. Votem em mim, se tiverem coragem.',
  'tutorialScript.youHeardThat.solo': 'Ouviram isso? Quase uma confissão!',
  'tutorialScript.isSeriouslyWeird.solo': 'O 1 é muito estranho. Voto nele.',
  'tutorialScript.sorryYouDid.solo': 'Desculpa, 1: você fez tudo sozinho.',
  'tutorialScript.actShadySay.solo': 'Faça cara de quem tem culpa: diga algo que nenhum inocente diria.',
  'tutorialScript.theyFellFor.solo': 'Caíram direitinho. «Pronto», e vamos votar.',
  'tutorialScript.fineMeToo.solo': 'Tá, eu também: o 1.',
  'tutorialScript.everyonePointsAt.solo': 'Todo mundo aponta para você. Vote em qualquer um: tanto faz.',
  'tutorialScript.theyLynchedYou.solo': 'Lincharam você: exatamente o que você queria.',
  // ---- voice
  'voice.title': 'Voz',
  'voice.mode.off': 'Desligada',
  'voice.mode.listen': 'Só ouvir',
  'voice.mode.mic': 'Microfone',
  'voice.modeFull': 'Microfone (aperte para falar)',
  'voice.pushToTalk': 'Aperte para falar',
  'voice.pushToTalkPhone': 'Segure o microfone para falar.',
  'voice.pushToTalkDesk': 'Segure V (ou o microfone) para falar.',
  'voice.holdToTalk': 'Segure para falar',
  'voice.holdV': 'Segure V',
  'voice.offline': 'Voz offline, tentando de novo',
  'voice.nightFamily': 'À noite só a Família fala',
  'voice.deadListen': 'Os mortos só escutam',
  'voice.sewn': 'O Alfaiate costurou sua boca',
  'voice.jailed': 'Na cela não se fala',
  'voice.voteSilence': 'Ninguém fala durante a votação',
  'voice.nobodyNow': 'Ninguém fala agora',
  'voice.opensSoon': 'A voz abre num instante',
  'voice.muteVoice': 'Silenciar voz',
  'voice.unmuteVoice': 'Reativar voz',
  'voice.mutedHere': 'Silenciado: só você não ouve.',
  'voice.micDeniedTitle': 'Microfone negado',
  'voice.micDenied': 'Sem acesso ao microfone você só pode ouvir. Dá para liberar nos ajustes do sistema e depois escolher "Microfone" de novo.',
  'voice.openSettings': 'Abrir ajustes',
  'voice.notNow': 'Agora não',
  'voice.settings': 'Voz na mesa',
  'voice.settingsHint': 'Nas salas de amigos. De dia falam os vivos, à noite só a Família. Só ao vivo: nada é gravado.',
  'voice.people': 'Na mesa',
  'voice.nobody': 'Ninguém mais está ouvindo.',
  'voice.mute': 'Silenciar',
  'voice.reportOrBlock': 'Denunciar ou bloquear',
  'voice.unmute': 'Reativar',
  'voice.blocked': 'Bloqueado: vocês não se ouvem.',
  'voice.closed': 'A voz está fechada agora.',
  'voice.listening': 'Só ouvindo.',
  'voice.silencedNow': 'Você não pode falar agora.',
  'voice.connecting': 'Conectando…',
  'voice.live': 'Estão ouvindo você',
  'voice.button': 'Voz',
  'voice.micAskTitle': 'O microfone',
  'voice.micAsk': 'Para falar na mesa, Obertà usa o microfone, só quando o jogo dá a palavra a você. Sua voz sai ao vivo e nunca é gravada nem transcrita.',
  'voice.micAllow': 'Usar o microfone',
  'voice.cancel': 'Cancelar',
  // ---- results
  'results.familyWins': 'A FAMÍLIA VENCE',
  'results.townWins': 'A CIDADE VENCE',
  'results.loneWolfWins': 'UM LOBO SOLITÁRIO VENCE',
  'results.youLost': 'VOCÊ PERDEU',
  'results.bountyPaid': 'A RECOMPENSA FOI PAGA',
  'results.loanSharkCashesIn': 'O AGIOTA COBRA A CONTA',
  'results.foolLastLaugh': 'O BOBO RIU POR ÚLTIMO',
  'results.hitmanStandsAlone': 'O MATADOR FICA SOZINHO DE PÉ',
  'results.cityBurns': 'A CIDADE ARDE',
  'results.back': 'VOLTAR',
  'results.backToRoom': 'DE VOLTA À SALA',
  'results.playAgain': 'JOGAR DE NOVO',
  'results.keysPlayAgainOrBack': 'ENTER  jogar de novo   ·   ESC  voltar',
  'results.keysBackToRoom': 'ENTER ou ESC  de volta à sala',
  'results.level': 'NÍVEL {level}',

  // ---- mirror
  'mirror.takeHatOff': 'Tirar o chapéu',
  'mirror.putHatOn': 'Pôr o chapéu',
  'mirror.hatOff': 'Sem chapéu',
  'mirror.hatOn': 'Com chapéu',
  'mirror.title': 'O espelho do barbeiro',
  'mirror.later': 'Depois',
  'mirror.whoSits': 'Quem senta na cadeira?',
  'mirror.presentationHint': 'O barbeiro sugere cortes, maquiagem e roupas que combinam. Você ainda pode escolher qualquer coisa com "Mostrar tudo".',
  'mirror.man': 'Homem',
  'mirror.woman': 'Mulher',
  'mirror.other': 'Outro',
  'mirror.preferNotToSay': 'Prefiro não dizer',
  'mirror.showAll': 'Mostrar tudo',
  'mirror.saveFace': 'Salvar este rosto',
  'mirror.backToBefore': 'Voltar ao que era',
  'mirror.randomFace': 'Rosto aleatório',
  'mirror.readyMadeFaces': 'Rostos prontos',
  'mirror.freeClothes': 'Roupas grátis',
  'mirror.randomShort': 'Aleatório',
  'mirror.asItWas': 'Como era',
  'mirror.cancel': 'Cancelar',
  'mirror.tab.skin': 'Pele',
  'mirror.tab.hair': 'Cabelo',
  'mirror.tab.colour': 'Cor',
  'mirror.tab.eyes': 'Olhos',
  'mirror.tab.eyeSize': 'Tamanho dos olhos',
  'mirror.tab.iris': 'Íris',
  'mirror.tab.brows': 'Sobrancelhas',
  'mirror.tab.nose': 'Nariz',
  'mirror.tab.mouth': 'Boca',
  'mirror.tab.lipstick': 'Batom',
  'mirror.tab.makeUp': 'Maquiagem',
  'mirror.tab.marks': 'Marcas',
  'mirror.tab.age': 'Idade',
  'mirror.tab.head': 'Cabeça',

  // ---- chronicle
  'chronicle.deadJoiner': ' E ',
  'chronicle.listJoiner': ' e ',
  'chronicle.fire': 'Incêndio na noite: o fogo levou {burned}',
  'chronicle.fireWithOthers': 'Incêndio na noite: {burned}. {gender, select, masculine{{n, plural, one{Morto} other{Mortos}}} feminine{{n, plural, one{Morta} other{Mortas}}} other{Entre os mortos}} também {others}',
  'chronicle.risen': '{name} volta da cova',
  'chronicle.foundDead': '{gender, select, masculine{{n, plural, one{Encontrado morto: {names}} other{Encontrados mortos: {names}}}} feminine{{n, plural, one{Encontrada morta: {names}} other{Encontradas mortas: {names}}}} other{Sangue na noite: {names}}}',
  'chronicle.squareUndecided': 'A praça não se decide',
  'chronicle.lynched': '{name} na forca',
  'chronicle.lynchedFool': '{name} na forca: o Bobo vence',
  'chronicle.lynchedBounty': '{name} na forca: {hunter} recebe a recompensa',
  'chronicle.lynchedNeutral': '{name} na forca: {role}',
  'chronicle.lynchedFamily': '{name} na forca: era da Família',
  'chronicle.lynchedInnocent': '{name} na forca: um inocente',

  // ---- courier
  'courier.masthead': 'O Correio de {city}',
  'courier.dateLine': 'Ano XIX  ·  Dia {round}  ·  {edition}',
  'courier.dawnEdition': 'Edição da madrugada',

  // ---- gesture
  'gesture.title': 'Um gesto para {name}',
  'gesture.hint': 'A mesa inteira vê.',
  'gesture.locked': 'Na loja',
  'gesture.wait': 'Próximo em {seconds} s',
  'gesture.report': 'Denunciar ou bloquear',
  'gesture.settingTitle': 'Gestos na mesa',
  'gesture.settingHint': 'Desligado, ninguém pode jogar charutos, rosas ou peixes em você.',
  'gesture.button': 'Gestos',
  'gesture.pickTarget': 'Quem leva um gesto?',
  'gesture.pickHint': 'Ou segure num lugar.',
  'gesture.firstHint': 'Jogue um gesto em alguém: toque em «Gestos».',
  // ---- collection
  'collection.title': 'Os papéis',
  'collection.settingsHint': 'A coleção: cada carta se revela quando você vence com ela.',
  'collection.count': '{n} de {of} cartas',
  'collection.hint': 'Cada carta fica virada para baixo até você vencer uma partida com esse papel.',
  'collection.signedOut': 'Entre na conta para virar as cartas e acompanhar suas partidas.',
  'collection.signIn': 'Entrar',
  'collection.team.citizens': 'Cidade',
  'collection.team.mafia': 'Família',
  'collection.team.neutral': 'Solitários',
  'collection.locked': 'Virada',
  'collection.lockedBody': 'Carta virada para baixo. Vença uma partida com este papel para saber o que ele faz e ver seus números.',
  'collection.playedNoWin': 'Jogada uma vez, nunca vencida.',
  'collection.playedNoWin.playedTimesNever': 'Jogada {n} vezes, nunca vencida.',
  'collection.neverPlayed': 'Nunca jogada.',
  'collection.played': 'Partidas',
  'collection.wins': 'Vitórias',
  'collection.losses': 'Derrotas',
  'collection.winRate': '% de vitórias',
  'collection.bestStreak': 'Melhor sequência',
  'collection.lastPlayed': 'Última partida',
  'collection.short': '{wins} V · {played} P',
  'collection.close': 'Fechar',
  'collection.publicCount': 'Papéis revelados',
  // ---- localRole
  'localRole.wasBusy': 'Ontem à noite alguém te manteve ocupado: sua jogada se perdeu.',
  'localRole.wasJailed': 'Ontem à noite você estava na cela: sua jogada se perdeu.',
  'localRole.jailerAsked': 'O Carcereiro perguntou: “{question}”',
  'localRole.prisonerAnswered': 'Da cela, {name} respondeu: “{answer}”',
  'localRole.foundFamily': 'Ao amanhecer: {name} é da Família.',
  'localRole.foundClean': 'Ao amanhecer: {name} tem ficha limpa.',
  'localRole.foundRole': 'Ao amanhecer: {name} era {role}.',
  'localRole.jailedTitle': 'Você está na cela',
  'localRole.jailedBody': 'Hoje à noite você não sai, e ninguém encosta em você.',
  'localRole.jailerAsks': 'O Carcereiro te pergunta:',
  'localRole.answerHint': 'Sua resposta (só o Carcereiro lê)',
  'localRole.questionHint': 'Uma pergunta para o prisioneiro (opcional)',
  'localRole.jailed': '{name} está na sua cela.',
  'localRole.converted': 'Você viu a luz: agora é da seita, e só vence com ela.',
  'localRole.sect': 'Sua seita: {names}.',
  'localRole.doorClosed': 'Ontem à noite, porta fechada: {name}.',
  'localRole.sectWins': 'A seita vence',
  'localRole.linkSecond': 'E quem mais? Toque no segundo apaixonado.',
  'localRole.linked': 'Você uniu {a} e {b}.',
  'localRole.inLoveWith': 'Seu coração bate por {name}: vocês só vencem se os dois viverem.',
  'localRole.fateCannon': 'Canhonaço, dia {round}',
  'localRole.fateDay': 'De dia, dia {round}',
  'localRole.whoToReveal': 'Quem você revela para todos?',
  'localRole.whoToHit': 'Em quem você atira?',
  'localRole.aimed': 'Na mira: {name}. Tiros restantes: {left}.',
  'localRole.noAim': 'Ninguém na mira: escolha alguém hoje à noite.',
  'localRole.fire': 'Fogo!',
  'localRole.carryOn': 'Seguir',
  'localRole.cancel': 'Cancelar',
  'localRole.confirm': 'Confirmar',
  'localRole.usePower': 'Usar um poder',
  'localRole.powerWho': 'Quem é você? Toque no seu próprio rosto.',
  'localRole.noPower': 'Agora você não tem nada para usar.',
  'localRole.truceHow': 'Uma vez por partida: você revela a todos o papel exato de alguém, e o seu. Hoje não tem votação.',
  'localRole.cannonHow': 'Quem você acerta morre na hora, na frente de todos. Um tiro por dia; desde o primeiro, todos sabem quem você é.',
  'localRole.marksmanHow': 'Você atira em quem está na sua mira. Se for da cidade, o tiro volta contra você.',
  'localRole.mayorHow': 'Uma vez por partida: você se revela a todos, e hoje seu voto vale dobrado.',
  'localRole.shotsLeft': 'Tiros restantes: {left}.',
  'localRole.askTruce': 'Trégua',
  'localRole.dayPowerHint': 'De dia: pegue o celular e toque em “Usar um poder”.',
  // ---- localTable
  'localTable.pickedConfirm': 'Você escolheu {name}. Confirme, ou toque em outro lugar.',
  'localTable.familyNote': 'família',
  'localTable.cleanNote': 'ficha limpa',
  'localTable.discuss': 'Discutam em voz alta. Depois, votação.',
  'localTable.undo': 'Voltar',
  'localTable.voteTitle': 'A votação',
  'localTable.voteHeadline': 'Como a praça vota?',
  'localTable.voteIntro': 'De dia, terminada a discussão, a praça condena alguém. Escolham como, para esta partida.',
  'localTable.secretVote': 'Voto secreto no celular',
  'localTable.voiceVoteHint': 'Vota-se em voz alta, todos juntos: cada um diz quem acusa, na frente de todos. Depois alguém toca no celular em quem vocês condenam, ou “Empate · ninguém”: com empate ninguém sobe ao patíbulo e a noite volta. Fala-se mais, e todos se expõem.',
  'localTable.secretVoteHint': 'O celular passa de mão em mão e cada um vota sozinho, uma vez, sem ser visto. No fim só se descobre quem foi condenado e quantos votos cada um recebeu, nunca quem votou em quem. Mais lento, e é mais fácil se esconder.',
  'localTable.voteNext': 'Avançar',
  'localTable.voiceVoteTitle': 'Votem em voz alta',
  'localTable.voiceVote': 'Votem em voz alta. Depois toquem em quem vocês condenam.',
  'localTable.tieRule': 'Empate: ninguém sobe ao patíbulo, a noite volta.',
  'localTable.condemnConfirm': 'Condenar {name}? Confirme, ou toque em outro lugar.',
  'localTable.tieNobody': 'Empate · ninguém',
  'localTable.condemn': 'Condenar {name}',
  'localTable.backToTalk': 'Voltar à discussão',
  'localTable.mustVote': '{name} precisa votar',
  'localTable.secretBallot': 'Voto secreto: ninguém mais olha. Toque em quem você quer eliminar, uma vez só.',
  'localTable.votePicked': 'Você vota em {name}. Confirme, ou toque em outro lugar.',
  'localTable.castVote': 'Votar',
  // ---- rules
  'rules.sign': 'Regras',
  'rules.title': 'Como jogar',
  'rules.banner': 'Para ler em voz alta',
  'rules.pitch': 'Leia esta página em voz alta: em um minuto seus amigos sabem jogar.',
  'rules.style.quick': 'Rápida',
  'rules.style.stage': 'Teatral',
  'rules.styleHint.quick': 'O jogo inteiro em um minuto.',
  'rules.styleHint.stage': 'Uma fábula sombria, para encenar.',
  'rules.readToMe': 'Leia para mim',
  'rules.stopReading': 'Chega',
  'rules.commonRoles': 'Os papéis mais comuns',
  'rules.commonRolesHint': 'Uma linha cada, para os curiosos.',
  'rules.playLocal': 'Vamos jogar num celular só',
  'rules.playLocalHint': 'Um celular só, passado de mão em mão.',
  'rules.playFriends': 'Jogar com amigos',
  'rules.playFriendsHint': 'Num celular só, se joga no celular: daqui, uma sala online.',
  'rules.back': 'Voltar',
  'rules.team.citizens': 'Cidade',
  'rules.team.mafia': 'Família',
  'rules.team.neutral': 'Por conta própria',
  // ---- chat
  'chat.fresh': '{n, plural, one{# nova} other{# novas}}',
  // ---- nightNotes
  'nightNotes.spendTheNight': 'Passar a noite',
  // ---- ranked
  'ranked.yourTable': 'Seu idioma',
};

/// The narrator's script, read on screen (no recorded voice yet).
// Same rules as the English script: short lines, never a player's gender
// (the name, or turn the sentence around), real cities and places, nobody
// closes their eyes, the factions are always "a Família" and "a cidade".
const portuguesePack = NarrationPack(
  roles: {
    Role.mafioso: RoleText(
      'Soldado',
      '“Nada pessoal.”',
      'Você é da Família. Toda noite você e a Família escolhem quem morre. Vocês vencem quando forem tantos quanto todo o resto.',
    ),
    Role.padrino: RoleText(
      'Padrinho',
      '“Eu só faço favores. Pergunte por aí.”',
      'Você comanda a Família: toda noite escolhe com ela quem morre. Cuidado: o Detetive vê você como inocente. Você vence com a Família.',
    ),
    Role.sarto: RoleText(
      'Alfaiate',
      '“De dia, ternos. De noite, bocas.”',
      'Você é da Família e mata com ela à noite. Uma vez por partida, pode calar alguém por um dia inteiro. Você vence com a Família.',
    ),
    Role.compare: RoleText(
      'Cúmplice',
      '“Eu só estava de passagem.”',
      'Você é da Família e mata com ela à noite. Enquanto você viver, a Família também pode conversar em segredo durante o dia.',
    ),
    Role.cittadino: RoleText(
      'Cidadão Honesto',
      '“Não vi nada. Infelizmente, é verdade.”',
      'Você não tem poderes. De dia, escute, acuse e vote para achar os assassinos. Você vence com a cidade quando não sobrar nenhum.',
    ),
    Role.detective: RoleText(
      'Detetive',
      '“Todo mundo mente. Uns mentem melhor.”',
      'Toda noite escolha alguém e descubra se é da Família. Cuidado: algumas cartas mentem, o Padrinho por exemplo parece inocente.',
    ),
    Role.medico: RoleText(
      'Doutor',
      '“Eu costuro o que os outros rasgam.”',
      'Toda noite escolha alguém, até você: se essa pessoa sofrer um ataque, você salva. Nunca a mesma pessoa duas noites seguidas.',
    ),
    Role.cecchino: RoleText(
      'Atirador',
      '“Um tiro. Não dois.”',
      'Você tem uma bala para a partida inteira: numa noite, escolha quem morre. Use bem, dá para errar o alvo. Você vence com a cidade.',
    ),
    Role.giornalista: RoleText(
      'Repórter',
      '“A verdade chega às bancas às seis.”',
      'Uma vez por partida, à noite, escolha alguém: ao amanhecer todos sabem o lado dessa pessoa. Se você morrer nessa noite, a matéria não sai.',
    ),
    Role.becchino: RoleText(
      'Coveiro',
      '“Meus clientes nunca mentem.”',
      'Toda noite você pode escolher alguém que morreu à noite e descobrir o papel. Só você fica sabendo. Você vence com a cidade.',
    ),
    Role.guardaspalle: RoleText(
      'Guarda-Costas',
      '“Vão ter que passar por mim.”',
      'Toda noite proteja alguém: se essa pessoa for atacada, você morre no lugar dela. Você vence com a cidade.',
    ),
    Role.reduce: RoleText(
      'Veterano',
      '“Já levei tiro. De gente com melhor mira.”',
      'Você não faz nada à noite, mas tem couro grosso: o primeiro ataque noturno contra você falha. Você vence com a cidade.',
    ),
    Role.pregiudicato: RoleText(
      'Ex-Presidiário',
      '“Cumpri minha pena. Minha ficha, não.”',
      'Você é da cidade, mas cuidado: o Detetive vê você como da Família. Vai ter que convencer todo mundo de que tem ficha limpa.',
    ),
    Role.messia: RoleText(
      'Messias',
      '“Levanta. Você ainda não terminou.”',
      'Uma vez por partida, à noite, você pode trazer de volta qualquer um dos mortos. Você vence com a cidade.',
    ),
    Role.sindaco: RoleText(
      'Prefeito',
      '“Não ganhei a eleição para ficar quieto.”',
      'Uma vez por partida, na votação, você pode se revelar: a partir daí seu voto vale em dobro. Você vence com a cidade.',
    ),
    Role.portinaio: RoleText(
      'Porteiro',
      '“Não pergunto quem. Só vejo a porta.”',
      'Toda noite vigie a porta de alguém: ao amanhecer você sabe se alguém passou por lá, mas não quem. Você vence com a cidade.',
    ),
    Role.fesso: RoleText(
      'Bobo',
      '“Eu? Culpa minha? Ah, com certeza.”',
      'Você joga por conta própria e vence se a praça linchar você: faça cara de culpa! Morrer à noite não conta.',
    ),
    Role.piromane: RoleText(
      'Incendiário',
      '“Todo mundo adora uma fogueira.”',
      'Você joga por conta própria. Toda noite encharque alguém de gasolina, ou ponha fogo em todos os encharcados de uma vez. Vence se for a última pessoa viva.',
    ),
    Role.cacciatore: RoleText(
      'Caçador de Recompensas',
      '“Nada pessoal. São negócios.”',
      'Você joga por conta própria, com uma recompensa por alguém da cidade, mostrado pelo nome. Se a praça linchar essa pessoa, você vence e a partida acaba.',
    ),
    Role.strozzino: RoleText(
      'Agiota',
      '“Devedor morto não paga.”',
      'Você joga por conta própria. Toda noite proteja alguém, nunca a mesma pessoa duas vezes seguidas. Você vence se estiver de pé no fim, ganhe quem ganhar.',
    ),
    Role.sicario: RoleText(
      'Matador',
      '“Trabalho sozinho. O café é por minha conta.”',
      'Você joga por conta própria e mata alguém toda noite. Cuidado: o Detetive vê você como da Família. Só vence se for a última pessoa de pé.',
    ),
    Role.prostituta: RoleText(
      'Cortesã',
      '“Uma canção, um drinque, e lá se foi a noite.”',
      'Você joga pela Família, mas ninguém se conhece. Toda noite bloqueia a jogada de alguém, nunca a mesma pessoa duas vezes seguidas. Se sobrar só você, vota.',
    ),
    Role.carceriere: RoleText(
      'Carcereiro',
      '“Aqui dentro a gente conversa. Lá fora, morre.”',
      'Toda noite você tranca alguém, nunca a mesma pessoa duas vezes seguidas: não age e ninguém pode matar. Interrogue pelo chat, sem se revelar.',
    ),
    Role.cupido: RoleText(
      'Cupido',
      '“Dois corações, um dote, nenhuma saída.”',
      'Na primeira noite você une duas pessoas, e pode ser uma delas. Só vencem se as duas viverem; se uma morre, a outra vai junto. Você vence com a cidade.',
    ),
    Role.presidente: RoleText(
      'Presidente',
      '“O Estado não negocia.”',
      'Todos sabem quem você é, e ninguém pode votar em você. A escolta salva você nos dois primeiros ataques; no terceiro, você morre. Se morrer, a cidade perde.',
    ),
    Role.capoSetta: RoleText(
      'Líder da Seita',
      '“Não peço que acredite. Só que me siga.”',
      'Você joga por conta própria: toda noite converte alguém, que daí em diante só vence com você. Você vence quando todos os vivos forem da seita.',
    ),
    Role.artigliere: RoleText(
      'Artilheiro',
      '“Eu não sussurro. Eu trovejo.”',
      'Dois tiros, um por dia, a partir do segundo dia: quem você acertar morre na hora. Do primeiro tiro em diante, todos sabem quem você é. Vence com a cidade.',
    ),
    Role.tiratoreScelto: RoleText(
      'Atirador de Elite',
      '“Um fôlego, um tiro, um nome.”',
      'À noite você põe alguém na mira; de dia, pode atirar. Dois tiros. Se for da cidade, o tiro volta e quem morre é você.',
    ),
    Role.pacifista: RoleText(
      'Pacifista',
      '“Sangue pede sangue. Eu peço trégua.”',
      'Uma vez por partida, de dia, revele a todos o papel exato de alguém, e o seu: nesse dia não tem votação. Você vence com a cidade.',
    ),
  },
  cities: [
    CitySetting(
      id: 'chicago',
      name: 'Chicago',
      title: 'Chicago, 1929',
      openings: [
        'Chicago, 1929. A Lei Seca fechou os bares e abriu todo o resto.',
        'Chicago, 1929. A Cidade dos Ventos. Leva o seu chapéu, e às vezes quem está embaixo dele.',
      ],
      scenes: [
        StoryPiece('chicago-loop', 'Externa, noite. Sob os trilhos do L, no Loop. Um trem chacoalha lá em cima.'),
        StoryPiece('chicago-station', 'Interna, noite. Union Station. A sala de espera está vazia.'),
        StoryPiece('chicago-pier', 'Externa, noite. Navy Pier. Neblina sobre o lago Michigan.'),
        StoryPiece('chicago-jazz', 'Interna, noite. O Green Mill: fumaça, e um saxofone.'),
        StoryPiece('chicago-bridge', 'Externa, noite. Uma ponte levadiça sobre o rio Chicago.'),
        StoryPiece('chicago-market', 'Externa, noite. O mercado da Maxwell Street, todas as barracas fechadas.'),
        StoryPiece('chicago-speakeasy', 'Interna, noite. Um bar clandestino no South Side.'),
        StoryPiece('chicago-hotel', 'Interna, noite. O saguão do Lexington Hotel. Ninguém na recepção.'),
      ],
    ),
    CitySetting(
      id: 'new-york',
      name: 'Nova York',
      title: 'Nova York, 1947',
      openings: [
        'Nova York, 1947. Oito milhões de pessoas, e nenhuma viu nada.',
        'Nova York, 1947. A cidade que nunca dorme. Esta noite, bem que devia tentar.',
      ],
      scenes: [
        StoryPiece('ny-mulberry', 'Externa, noite. Mulberry Street, Little Italy, sob os letreiros de neon.'),
        StoryPiece('ny-bridge', 'Externa, noite. Sob a ponte do Brooklyn. Neblina no East River.'),
        StoryPiece('ny-station', 'Interna, noite. Grand Central. O relógio marca três horas.'),
        StoryPiece('ny-market', 'Externa, noite. O mercado de peixe da Fulton, entre os caixotes.'),
        StoryPiece('ny-coney', 'Externa, noite. Coney Island, fora de temporada. A roda-gigante está parada.'),
        StoryPiece('ny-pier', 'Externa, noite. Um píer no rio Hudson. Um cargueiro sem nome.'),
        StoryPiece('ny-diner', 'Interna, noite. Uma lanchonete a uma quadra da Times Square.'),
        StoryPiece('ny-park', 'Externa, noite. Central Park. Só um poste ainda aceso.'),
      ],
    ),
    CitySetting(
      id: 'palermo',
      name: 'Palermo',
      title: 'Palermo, 1955',
      openings: [
        'Palermo, 1955. O sol mais bonito do mundo, e umas sombras bem compridas.',
        'Palermo, 1955. Aqui todo mundo sabe de tudo. Por isso ninguém fala nada.',
      ],
      scenes: [
        StoryPiece('palermo-vucciria', 'Externa, noite. O mercado da Vucciria, fechado para a noite.'),
        StoryPiece('palermo-teatro', 'Externa, noite. A escadaria do Teatro Massimo, entre os dois leões.'),
        StoryPiece('palermo-canti', 'Externa, noite. Os Quattro Canti, desertos. Só as estátuas.'),
        StoryPiece('palermo-cala', 'Externa, noite. La Cala, o porto velho. Barcos balançando.'),
        StoryPiece('palermo-ballaro', 'Externa, noite. Um beco em Ballarò, roupa no varal.'),
        StoryPiece('palermo-mondello', 'Externa, noite. A praia de Mondello, fora de temporada.'),
        StoryPiece('palermo-foro', 'Externa, noite. O Foro Italico, à beira-mar, entre as palmeiras.'),
        StoryPiece('palermo-pasticceria', 'Interna, noite. Uma confeitaria no centro histórico, portas fechadas.'),
      ],
    ),
    CitySetting(
      id: 'napoli',
      name: 'Nápoles',
      title: 'Nápoles, 1950',
      openings: [
        'Nápoles, 1950. O Vesúvio fumega, o café queima, e alguém não dorme esta noite.',
        'Nápoles, 1950. Aqui todo mundo canta. Só não canta para a polícia.',
      ],
      scenes: [
        StoryPiece('napoli-quartieri', 'Externa, noite. Um beco nos Quartieri Spagnoli.'),
        StoryPiece('napoli-galleria', 'Interna, noite. A Galleria Umberto, vazia. Cada passo ecoa.'),
        StoryPiece('napoli-molo', 'Externa, noite. O cais Beverello. As balsas não estão saindo.'),
        StoryPiece('napoli-spaccanapoli', 'Externa, noite. Spaccanapoli, reta como uma lâmina.'),
        StoryPiece('napoli-sancarlo', 'Interna, noite. O Teatro San Carlo, todas as poltronas vazias.'),
        StoryPiece('napoli-lungomare', 'Externa, noite. A orla, abaixo do Castel dell\'Ovo.'),
        StoryPiece('napoli-funicolare', 'Interna, noite. O funicular de Chiaia, última viagem da noite.'),
        StoryPiece('napoli-pizzeria', 'Interna, noite. Uma pizzaria na Via dei Tribunali, o forno já frio.'),
      ],
    ),
    CitySetting(
      id: 'las-vegas',
      name: 'Las Vegas',
      title: 'Las Vegas, 1955',
      openings: [
        'Las Vegas, 1955. Um milhão de lâmpadas no deserto, para esconder todo o resto.',
        'Las Vegas, 1955. A casa sempre ganha. Esta noite você descobre quem é a casa.',
      ],
      scenes: [
        StoryPiece('vegas-fremont', 'Externa, noite. Fremont Street: mil luzes, nenhuma testemunha.'),
        StoryPiece('vegas-flamingo', 'Interna, noite. O salão do cassino Flamingo, de madrugada.'),
        StoryPiece('vegas-desert', 'Externa, noite. O deserto de Mojave. Dois faróis, uma pá.'),
        StoryPiece('vegas-nugget', 'Interna, noite. Os fundos do Golden Nugget. Uma mesa de pôquer.'),
        StoryPiece('vegas-motel', 'Externa, noite. O estacionamento de um motel na Strip.'),
        StoryPiece('vegas-dam', 'Externa, noite. A represa Hoover. Lá embaixo, duzentos metros de nada.'),
        StoryPiece('vegas-dressing', 'Interna, noite. O camarim de uma cantora, depois do show.'),
        StoryPiece('vegas-chapel', 'Interna, noite. Uma capela de casamentos aberta a noite toda.'),
      ],
    ),
  ],
  howToPlay:
      'À noite a Família elimina uma pessoa. De dia todos votam em quem eliminar. '
      'A cidade vence eliminando a Família inteira; a Família vence quando deixa de ser minoria.',
  firstNights: [
    'Cai a primeira noite sobre {city}.',
    'A escuridão desce sobre {city}. É a primeira noite.',
    'Primeira noite. Durma bem, se a consciência deixar.',
  ],
  nights: [
    'Cai a noite sobre {city}, mais uma vez.',
    'Os postes se apagam. Alguém tem trabalho a fazer.',
    'É noite. Alguém tem um encontro. As flores vêm depois.',
    'Mais uma noite. Em {city}, o pessoal já dorme de sapato.',
    'Cai a escuridão. Até os cachorros pararam de latir.',
    'Calada da noite. A funerária está fazendo hora extra.',
  ],
  nightInstruction: 'Passem o celular. Cada um faz sua jogada em segredo, depois passa adiante.',
  nobodyDied: 'Ninguém morreu esta noite.',
  quietDawns: [
    'A funerária expressa sua profunda preocupação.',
    'Olhem em volta da mesa: alguém aqui está decepcionado.',
    'Não se acomodem. Geralmente é assim que começa.',
    'O vigia do cemitério dormiu oito horas seguidas, e não confia nisso.',
  ],
  secondVictims: ['E não acabou.', 'Mudança de cena.', 'Mas a noite foi longa.'],
  victimFact: 'Entre os mortos desta noite: {name}. O papel continua em segredo.',
  sniperShots: {
    DeathStory.sniperId: [
      'Um único tiro, de uma janela distante. {name} não ouviu nada.',
      'Um reflexo num telhado, depois um tiro. {name} cai antes do eco.',
      'Alguém lá longe mirou sem pressa. {name} fica na calçada.',
      'Ninguém na esquina desta vez. Só uma mira, com {name} bem no centro.',
    ],
    DeathStory.belfryId: [
      'Um reflexo lá no campanário. Depois um badalo, e {name} não levanta mais.',
      'O sino bate a hora e engole o tiro. {name} fica nas pedras da rua.',
      'Uma revoada de pombos sai do campanário. {name} já está no chão.',
    ],
    DeathStory.phoneBoothId: [
      'O telefone da cabine toca. {name} atende. O vidro racha em estrela.',
      'Um furo no vidro da cabine, uma teia de rachaduras. {name} escorrega.',
      '{name} tira o fone do gancho. Ninguém fala do outro lado: só o tiro.',
    ],
    DeathStory.carDoorId: [
      '{name} abre a porta do carro. Um tiro de longe: essa viagem nunca começa.',
      'Chave na mão, um pé no estribo. Depois o tiro, e {name} cai.',
      '{name} ia partir. O motor fica frio, a porta fica aberta.',
    ],
  },
  rescues: {
    DeathStory.rescueId: [
      'O golpe acerta, e {name} vai ao chão. Depois, passos apressados: o Doutor.',
      'Vieram fechar a conta de {name}. O Doutor chegou antes do padre.',
      '{name} já estava no chão. Mas o Doutor, por acaso, ia passando.',
      '{name} cai. Então uma maleta de couro se abre: ainda não acabou.',
    ],
    DeathStory.defibrillatorId: [
      '{name} no chão, coração parado. O Doutor esfrega as pás: afastem!',
      'Um choque, nada. Outro choque: o coração de {name} volta a bater.',
      'O Doutor abre uma caixa cheia de fios. Uma faísca, e {name} respira de novo.',
    ],
    DeathStory.pliersId: [
      'O Doutor cava a ferida de {name} com um alicate. Sai o chumbo.',
      'Uma bala no alicate, um curativo no peito. {name} ainda respira.',
      '{name} no chão, o Doutor de joelhos. “Plim”: a bala cai na bandeja.',
    ],
    DeathStory.ambulanceId: [
      'Uma sirene no fim da rua. A ambulância freia: {name} vai para a maca.',
      '{name} no chão, depois as sirenes. Maca, cobertor, e lá vão eles a toda.',
      'A ambulância encosta, luzes piscando. Da maca, {name} dá tchau.',
    ],
    DeathStory.stitchesId: [
      'Sob o poste, agulha e linha. O Doutor costura {name}, ponto por ponto.',
      'Três pontos, um nó, um corte de tesoura. {name} se levanta.',
      'O Doutor passa a linha na agulha à luz do poste. {name} não sente nada.',
    ],
  },
  someone: 'alguém',
  savedFact: 'Esta noite alguém quase morreu, mas foi salvo a tempo. Quem foi continua em segredo.',
  shrugs: {
    DeathStory.luckyId: [
      '{name} cambaleia, depois apalpa o bolso do peito: um cantil, todo amassado.',
      'O golpe acerta, e faz “dim”. {name} tira do bolso um cantil amassado.',
      '{name} continua de pé: o golpe parou no cantil.',
      '{name} sente uma pancada no peito. Sob o paletó, um cantil dobrado ao meio.',
    ],
    DeathStory.bibleId: [
      '{name} tira uma Bíblia do bolso do peito: o golpe parou bem ali.',
      'O golpe para numa Bíblia de bolso. {name} olha para o céu e agradece.',
      '{name} sente uma pancada no peito. No bolso, uma Bíblia furada até a metade.',
    ],
    DeathStory.jamId: [
      'A arma aponta para {name}. “Clique.” Outro “clique.” O assassino sai correndo.',
      'O gatilho estala no vazio: a arma engasgou. {name} se vira, o assassino foge.',
      '“Clique, clique.” {name} arregaça as mangas, e o beco se esvazia.',
    ],
    DeathStory.bananaId: [
      'O assassino pisa numa casca de banana e voa para trás. {name} vai embora.',
      'Uma casca de banana, um mortal para trás. O assassino se estatela na rua: {name} ri.',
      'O assassino parte para cima de {name}, e encontra uma casca de banana. O resto é pastelão.',
    ],
    DeathStory.blackCatId: [
      'Um gato preto pula no braço do assassino. O tiro sai torto, {name} continua de pé.',
      'O assassino mira em {name}. Um gato preto faz a arma voar.',
      'Dá azar, dizem. Mas esta noite um gato preto salvou {name}.',
    ],
  },
  shruggedFact: 'Esta noite alguém quase morreu, mas o golpe falhou. Quem foi continua em segredo.',
  methods: [
    StoryPiece('auto', 'Dois faróis no escuro. Um sedã preto que não freia. {name} se vira: tarde demais.'),
    StoryPiece('pianoforte', 'Uma corda arrebenta. Um piano de cauda despenca. {name} olha para cima.'),
    StoryPiece('veleno', '{name} toma o último gole de café. Faz uma careta. Veneno.'),
    StoryPiece('pugnale', 'Uma sombra atrás de {name}. Uma lâmina. Uma vez basta.'),
    StoryPiece('cemento', 'Dois capangas seguram {name}. Um terceiro mexe o cimento.'),
    StoryPiece('cappio', 'Um laço desce do escuro atrás de {name}. E aperta.'),
    StoryPiece('silenziatore', 'Um estalo abafado, como rolha de champanhe. {name} escorrega até o chão.'),
    StoryPiece('pacco', '{name} abre um presente. Lá dentro, algo faz tique-taque. Depois, algo faz bum.'),
    StoryPiece('lampadario', 'Um rangido. Um lustre de cristal se solta, bem em cima de {name}.'),
    StoryPiece('violino', 'Um estojo de violino se abre. Não tem violino dentro. {name} cai.'),
    StoryPiece('cassaforte', 'Lá de cima, um cofre. {name} só tem tempo de ler a marca.'),
    StoryPiece('sigaro', '{name} acende um charuto que veio de presente. O charuto faz “bum”.'),
    StoryPiece('mazza', 'Na esquina, um taco de beisebol. Um golpe. {name} vê estrelas, depois mais nada.'),
    StoryPiece('lupara', 'Dois canos serrados surgem do escuro. Um estrondo. {name} voa para trás.'),
    StoryPiece('raffica', 'Um carro desacelera. Na janela, uma metralhadora. {name} não se vira a tempo.'),
    StoryPiece('garrota', 'Um fio de aço, duas mãos de luva. {name} se debate, depois para.'),
    StoryPiece('vaso', 'Um vaso de gerânios cai do terceiro andar. Não foi acidente. {name} nem vê.'),
    StoryPiece('tombino', 'Um bueiro se abre sob os pés de {name}. Depois se fecha de novo, com cuidado.'),
    StoryPiece('buio', 'O poste se apaga. Um baque. Quando a luz volta, {name} está no chão.'),
    StoryPiece('bacio', 'Um desconhecido, um beijo, um batom de matar. {name} sorri, e é o fim.'),
    StoryPiece('boccia', 'Uma bola de boliche rola do escuro. {name} voa como um pino. Strike.'),
    StoryPiece(
      'pescespada',
      'Um peixe-espada aparece na esquina. Em guarda, estocada. Agora {name} dorme com os peixes.',
    ),
    StoryPiece(
      'arpione',
      'Um arpão assobia no escuro e a corda estica. {name} some na esquina.',
    ),
    StoryPiece('torta', 'Uma torta de creme bem na cara de {name}. Todos riem. Dentro do creme, uma granada.'),
    StoryPiece('trombone', 'Um trombone toca no beco. Da campana sai um tiro. {name} desafina de vez.'),
    StoryPiece('tango', 'Um desconhecido tira {name} para um tango. Um giro, uma inclinação, um punhal.'),
    StoryPiece('rose', 'Um buquê de rosas vermelhas para {name}. Entre as rosas, um cano. Pétalas para todo lado.'),
    StoryPiece('lavanderia', 'Uma van de lavanderia encosta. A porta corre, dois braços. {name} nunca mais volta.'),
  ],
  epilogues: [
    StoryPiece('gatto', 'Um gato viu tudo. Não vai abrir o bico.'),
    StoryPiece('mambo', 'Em algum lugar, um rádio toca um mambo.'),
    StoryPiece('tetti', '{city} dorme. Ou finge.'),
    StoryPiece('carta', 'No chão, uma carta de baralho. Sobem os créditos.'),
    StoryPiece('finestra', 'Uma janela se acende, depois se apaga.'),
    StoryPiece('sipario', 'Cai o pano. Ninguém aplaude.'),
    StoryPiece('voce', 'Uma voz fora de cena: “Nada pessoal.”'),
    StoryPiece('sirene', 'Sirenes ao longe. Sempre chegam atrasadas.'),
    StoryPiece('cappello', 'Um chapéu rola pelo chão. Corta.'),
    StoryPiece('continua', 'Na tela, três palavras: “Continua no próximo.”'),
  ],
  scoops: [
    'Extra! Extra! {name} está na primeira página.',
    'Tem fila na banca: o jornal só fala de {name}.',
    'Os jornaleiros gritam um nome só: {name}.',
  ],
  scoopMafia: 'O jornal não deixa dúvida: {name} é da Família.',
  scoopClean: 'O jornal não deixa dúvida: {name} é inocente.',
  silences: [
    'Agulha, linha, trabalho fino: esta manhã os lábios de {name} estão costurados.',
    'Alguém visitou {name} ontem à noite. Trouxe uma agulha e um conselho.',
    'No travesseiro de {name}, um carretel de linha preta. Recado dado.',
  ],
  silencedFact: 'Hoje {name} não pode falar na discussão. {name} vota por gestos e continua na mira da votação.',
  silencedFactOnline: 'Hoje {name} não pode escrever no chat da cidade. {name} ainda vota e continua na mira da votação.',
  dayInstruction: 'Vocês têm {minutes} para discutir. Depois, votem em quem eliminar.',
  oneMinute: 'um minuto',
  manyMinutes: '{minutes} minutos',
  voteCalls: [
    'Acabou o tempo. A multidão quer um culpado.',
    'Chega de conversa. {city} quer um nome.',
    'A multidão está inquieta. O carrasco está se aquecendo.',
    'Hora de votar. Tentem não errar. De novo.',
  ],
  voteInstruction: 'Votem em voz alta, todos juntos. Depois alguém toca no condenado. Empate: ninguém.',
  secretVoteInstruction: 'Voto secreto: o celular passa de mão em mão, cada um vota sozinho, os outros não olham.',
  tieFact: 'Empate: ninguém é condenado hoje. De volta à noite.',
  powerCurtainHint: 'Pegue o celular na mão e não deixe ninguém ver.',
  dayPowersHint: 'Quem tem um poder de dia usa com o botão “Usar um poder”.',
  passPhone: 'Passe o celular para {name}.',
  curtainHint: 'Os outros olham para o lado. Toque só quando o celular estiver na sua mão.',
  cardCurtainHint: 'Você vai ver sua carta: mais ninguém pode olhar.',
  putPhoneDown: 'Pronto. Largue o celular e passe adiante.',
  voterTurn: '{name} precisa votar. O voto é secreto.',
  lynchScenes: [
    '{name} sobe os degraus do cadafalso. A guilhotina brilha ao sol.',
    '{name} caminha até a forca, de cabeça erguida. Rufam os tambores.',
    'Um trem de carga, uma passagem só de ida. {name} está deixando {city}.',
    'O alçapão da prefeitura range. {name} dá uma última olhada na multidão.',
    '{name} pede um último cigarro. O carrasco oferece o fogo.',
    'Close nas mãos amarradas de {name}. {city} inteira está olhando.',
  ],
  cardTurns: 'A carta vira. {name} era… {role}.',
  wasMafia: 'Do lado da Família.',
  wasCitizen: 'Do lado da cidade.',
  wasNeutral: 'Jogando por conta própria.',
  lynchedInnocent: [
    'Belo trabalho, pessoal. Sério.',
    'Alguém nesta mesa está segurando o riso.',
    'A Família agradece a colaboração.',
    'O carrasco pede desculpas, e cobra o preço cheio mesmo assim.',
  ],
  lynchedMafioso: [
    'Menos um. Mas esse tinha amigos, e amigos têm boa memória.',
    'Alguém acabou de perder um sócio, e nem pode ir ao enterro.',
    'Belo tiro. Esta noite a Família vai estar de péssimo humor.',
  ],
  lynchedLastMafioso: [
    'E esse era o último. Todos os sinos da cidade estão tocando.',
    'Era o último. Em {city}, finalmente, alguém falou.',
  ],
  noLynch: [
    'O carrasco chega cedo em casa, para variar.',
    'Alguém respira aliviado. Quem será?',
    'Em {city}, não concordar com nada é o de sempre.',
  ],
  noLynchFact: 'Ninguém é eliminado hoje.',
  truces: [
    'Parem todos. Hoje ninguém vai para a forca.',
    'A praça baixa as cordas: trégua, por hoje.',
  ],
  truceFact: 'O Pacifista pediu trégua: hoje não tem votação.',
  heartbreaks: [
    'Um coração para sem fazer barulho. Quem ele amava já se foi.',
    'Tem gente que não consegue ficar sozinha no mundo.',
  ],
  heartbreakFact: '{name} morreu de coração partido, atrás de quem amava.',
  loversWinFact: 'Os apaixonados estão vivos: vencem juntos.',
  escorts: [
    'Um tiro no escuro. Mas um homem de preto já está na frente do Presidente, maleta erguida.',
    'Um tiro, uma faísca, um tinido de aço. A escolta nunca dorme.',
  ],
  escortFact: 'A escolta rechaçou um atentado contra o Presidente.',
  presidentFallsFact: 'O Presidente caiu. A cidade está perdida.',
  sectWins: [
    'Velas se acendem em todas as janelas. Em {city} não sobrou ninguém para converter.',
    'Um canto baixo sobe das ruas de {city}. Todos viram a luz.',
  ],
  sectWinsFact: 'A seita vence: cada alma viva segue o Líder.',
  cannonShots: [
    'Um estrondo sacode a praça. As janelas tremem, os pombos levantam voo todos de uma vez.',
    'O canhão troveja uma vez. Quando a fumaça baixa, alguém não está mais de pé.',
    'Fogo! O chão treme, as xícaras pulam nas mesas do café. Depois, silêncio.',
  ],
  cannonFact: 'Um estrondo na praça: o Artilheiro acertou {name}.',
  marksmanShots: [
    'Um tiro do campanário. {name} cai no meio da praça.',
    'Um estalo seco, lá de longe. {name} não termina a frase.',
  ],
  marksmanShotFact: 'Um tiro do campanário: {name} está fora do jogo.',
  backfires: [
    'O tiro ecoa, mas quem cai é quem puxou o gatilho.',
    'O fuzil engasga e explode. Do campanário, só desce o silêncio.',
  ],
  backfireFact: 'O tiro voltou: o Atirador de Elite mirava na cidade, e morre no lugar.',
  citizensWin: [
    '{city} está livre. A partir de amanhã, o pessoal dorme de janela aberta. Sobem os créditos.',
    'Na rua, as pessoas voltam a se olhar nos olhos. Na tela: “Fim.”',
  ],
  citizensWinFact: 'A cidade vence: a Família inteira foi eliminada.',
  mafiaWins: [
    '{city} tem novos chefes, e eles estavam sentados nesta mesa. Sobem os créditos.',
    'Em {city}, ninguém viu nada. Como sempre. A tela escurece.',
  ],
  mafiaWinsFact: 'A Família vence: a cidade não é mais maioria.',
  fires: [
    'Cheiro de gasolina, um fósforo, e a noite fica laranja.',
    'Alguém riscou um fósforo. Quando os bombeiros chegaram, não sobrava nada.',
  ],
  burnedFact: '{name} queimou durante a noite e está fora da partida.',
  resurrections: [
    'Uma mão empurra a tampa do caixão. A cidade esqueceu de pregar.',
    'Ao amanhecer um fantasma entra no bar e pede um café. Não é um fantasma.',
  ],
  resurrectedFact: '{name} está de volta à partida, com a mesma carta de antes.',
  foolWins: [
    'A corda balança, e na forca há um sorriso. Esse era o plano desde o começo.',
    'A multidão aplaude, e o Bobo agradece com uma reverência.',
  ],
  foolWinsFact: '{name} era o Bobo e vence por conta própria. A partida continua.',
  arsonistWins: [
    '{city} virou cinzas. Uma silhueta vai embora assobiando, caixa de fósforos na mão. Sobem os créditos.',
    'Não sobrou nada para queimar em {city}. A tela fica laranja.',
  ],
  arsonistWinsFact: 'O Incendiário vence por conta própria: não sobrou ninguém para impedir.',
  bountyWins: [
    'No fundo da praça, alguém conta as notas. A recompensa foi paga.',
    'Um chapéu se ergue na multidão, em agradecimento. Bom fazer negócio.',
  ],
  loanSharkWinsFact: '{name} era o Agiota: de pé no fim, também leva a sua parte.',
  bountyWinsFact: '{name} era o Caçador de Recompensas: recebe e vence por conta própria. A partida acaba aqui.',
  assassinWins: [
    'Em {city} só sobraram cadeiras vazias. O Matador paga o café e vai embora.',
    'A última luz se apaga em {city}. Alguém limpa uma lâmina e assobia. Sobem os créditos.',
  ],
  assassinWinsFact: 'O Matador vence por conta própria: limpou a mesa.',
  mayorRevealed: '{name} é o Prefeito: hoje esse voto vale em dobro.',
  watchVisited: 'Ontem à noite alguém bateu à porta de {name}.',
  watchQuiet: 'Ontem à noite ninguém bateu à porta de {name}.',
  taskPrompts: {
    NightTaskKind.kill: 'Quem a Família elimina esta noite?',
    NightTaskKind.silence: 'De quem você costura a boca esta noite?',
    NightTaskKind.protect: 'Quem você protege esta noite?',
    NightTaskKind.guard: 'Por quem você se põe na frente esta noite?',
    NightTaskKind.investigate: 'Quem você quer investigar?',
    NightTaskKind.dig: 'Que cova você abre esta noite?',
    NightTaskKind.snipe: 'Quer atirar em alguém?',
    NightTaskKind.scoop: 'Sobre quem é o seu furo?',
    NightTaskKind.douse: 'Quem você encharca de gasolina esta noite?',
    NightTaskKind.ignite: 'Você acende o fósforo esta noite?',
    NightTaskKind.resurrect: 'Quem você traz de volta esta noite?',
    NightTaskKind.watch: 'Que porta você vigia esta noite?',
    NightTaskKind.lend: 'Quem você protege esta noite emprestando dinheiro?',
    NightTaskKind.stab: 'Quem você elimina esta noite?',
    NightTaskKind.jail: 'Quem você tranca esta noite?',
    NightTaskKind.block: 'Para quem você canta esta noite?',
  },
  taskHints: {
    NightTaskKind.kill: 'Toque num nome: é o seu voto em quem morre. A maioria da Família decide.',
    NightTaskKind.silence: 'Toque num nome: amanhã essa pessoa não fala. Só uma vez, no lugar do seu voto.',
    NightTaskKind.protect: 'Toque num nome, até o seu: essa pessoa não morre esta noite. Nunca duas noites seguidas.',
    NightTaskKind.guard: 'Toque num nome: se essa pessoa for atacada esta noite, você morre no lugar.',
    NightTaskKind.investigate: 'Toque num nome: descubra na hora se é da Família ou da cidade.',
    NightTaskKind.dig: 'Toque num morto: você, e só você, descobre o papel na hora.',
    NightTaskKind.snipe: 'Toque num nome: você atira e essa pessoa morre. Só uma bala. Passe para guardar.',
    NightTaskKind.scoop: 'Toque num nome: ao amanhecer todos sabem o lado. Só um furo. Passe para guardar.',
    NightTaskKind.douse: 'Toque num nome para encharcar, em segredo. Ou acenda o fósforo: todos os encharcados queimam.',
    NightTaskKind.ignite: 'Toque no seu próprio nome: todos que você encharcou queimam esta noite.',
    NightTaskKind.resurrect: 'Toque num morto: volta ao amanhecer, se você viver. Só uma vez; passar guarda.',
    NightTaskKind.watch: 'Toque num nome: ao amanhecer você sabe se alguém passou por lá. Não quem.',
    NightTaskKind.lend: 'Toque num nome: essa pessoa não morre esta noite. Nunca a mesma duas vezes seguidas.',
    NightTaskKind.stab: 'Toque num nome: morre esta noite, a não ser que alguém proteja.',
    NightTaskKind.jail: 'Toque num nome: esta noite não age e ninguém pode tocar. A cela fecha na hora.',
    NightTaskKind.block: 'Toque num nome: a jogada dessa pessoa se perde. Nunca a mesma duas noites seguidas.',
    NightTaskKind.decoy: 'Nenhuma jogada esta noite: toque em qualquer nome, nada acontece. Mantém seu papel escondido.',
  },
  decoyPrompts: [
    'Quem parece mais suspeito para você?',
    'Em quem você nunca confiaria?',
    'Quem tem cara de quem esconde alguma coisa?',
    'Se tivesse que apontar o dedo, para quem seria?',
    'Quem está fazendo o melhor teatro nesta mesa?',
  ],
);

// The rules read aloud before a one-phone game: quick and theatrical.
const _quickPt = [
  RulesStep('Dois lados', [
    RulesBeat('Imagine uma cidade grande nos anos quarenta. Quase todo mundo é gente direita: a cidade.'),
    RulesBeat('Alguns não são. São a Família, e hoje à noite eles têm serviço.'),
    RulesBeat('Os mafiosos se conhecem. A gente honesta não conhece ninguém. Esse é o problema.'),
  ]),
  RulesStep('Sua carta é segredo', [
    RulesBeat('O celular dá a volta. Cada um olha seu papel, sozinho, e não conta para ninguém.'),
    RulesBeat('De dia você pode dizer o que quiser sobre quem é. Até mentiras. Principalmente mentiras.'),
  ]),
  RulesStep('A noite', [
    RulesBeat(
      'À noite o celular passa de mão em mão. Quem está com ele faz sua jogada em segredo; os outros olham para o lado.',
    ),
    RulesBeat('A Família escolhe quem apagar. O Detetive investiga, o Doutor salva.'),
    RulesBeat('Sem poderes? Toque em PASSAR, com a mesma cara de pôquer dos outros. Ninguém pode saber quem fez o quê.'),
  ]),
  RulesStep('O dia', [
    RulesBeat('Ao amanhecer vocês descobrem quem não sobreviveu. Quem morre à noite leva o papel para o túmulo.'),
    RulesBeat('Depois, conversa: acusações, álibis, olhares tortos.'),
    RulesBeat(
      'Quem tem um poder de dia toca em “Usar um poder”, depois no próprio rosto, e usa o poder com o celular na mão.',
    ),
    RulesBeat(
      'No fim, votação em voz alta, todos juntos, e alguém toca no celular em quem vocês condenam. A carta dele é virada. Empate? Hoje ninguém vai para a forca.',
    ),
    RulesBeat('Preferem o voto secreto? Escolham antes das cartas: o celular passa de mão em mão e cada um vota sozinho.'),
  ]),
  RulesStep('Quem vence', [
    RulesBeat('A cidade vence quando a Família inteira estiver fora.'),
    RulesBeat('A Família vence quando forem tantos quanto todo o resto.'),
    RulesBeat('Alguns tipos esquisitos jogam por conta própria: a carta diz como vencer.'),
  ]),
  RulesStep('As regras de ouro', [
    RulesBeat('Não espie o celular dos outros.'),
    RulesBeat('Nunca mostre sua tela para ninguém.'),
    RulesBeat('Morto não fala. Nem com os olhos.'),
    RulesBeat('E ninguém leva para o lado pessoal: é só um jogo. Mais ou menos.'),
  ]),
];

const _stagePt = [
  RulesStep('Era uma vez', [
    RulesBeat.cue('Diminua as luzes. Espere o silêncio.'),
    RulesBeat(
      'Era uma vez, numa cidade que nunca dorme, uma praça cheia de gente de bem. Chamavam aquilo de cidade.',
    ),
    RulesBeat(
      'Mas escondida entre aquela gente de bem estava a Família. Poucos, elegantes, armados. Todos se conheciam… e ninguém os conhecia.',
    ),
    RulesBeat.cue('Olhe cada rosto, devagar.'),
    RulesBeat('Talvez um deles esteja sentado nesta mesa. Talvez dois.'),
  ]),
  RulesStep('O envelope lacrado', [
    RulesBeat('Cada um de vocês vai receber um envelope lacrado: dentro está quem vocês são de verdade.'),
    RulesBeat.cue('Passe o celular para quem está à sua direita, como se fosse um envelope.'),
    RulesBeat('Leiam sozinhos. Depois guardem no peito, e não contem para ninguém.'),
    RulesBeat('A partir de amanhã, cada um pode dizer o que quiser sobre si. A verdade… ou não.'),
  ]),
  RulesStep('Quando cai a noite', [
    RulesBeat.cue('Abaixe a voz.'),
    RulesBeat('Quando cai a noite, o celular passa de mão em mão, como um segredo quente demais para segurar.'),
    RulesBeat('Quem está com ele faz sua jogada sem ser visto. Os outros encaram a parede, o teto, os próprios sapatos.'),
    RulesBeat(
      'A Família escolhe quem não vai ver o amanhecer. O Detetive fuça os negócios alheios. O Doutor vela por alguém.',
    ),
    RulesBeat(
      'E quem não tem poderes? Atua. Toca a tela com cara de quem trama, para que ninguém desconfie de ninguém.',
    ),
  ]),
  RulesStep('Ao amanhecer, a praça', [
    RulesBeat.cue('Levante a voz, como um pregoeiro.'),
    RulesBeat('Ao amanhecer a cidade acorda e conta seus mortos. Quem cai à noite vai embora com seu segredo.'),
    RulesBeat('Então a praça se reúne: acusa, jura, mente.'),
    RulesBeat.cue('Aponte para alguém, de repente.'),
    RulesBeat('Você! Onde estava ontem à noite?'),
    RulesBeat(
      'Quando as vozes se calam, vocês votam: em voz alta, de dedo apontado. Quem tiver mais votos é condenado, e a carta é virada diante de todos.',
    ),
    RulesBeat('Se der empate, a praça para: hoje ninguém é condenado.'),
  ]),
  RulesStep('Como a história termina', [
    RulesBeat('A história termina bem para a cidade quando o último da Família deixar a praça.'),
    RulesBeat(
      'Termina bem para a Família quando seus homens forem tantos quanto todo o resto: daí em diante, a cidade é deles.',
    ),
    RulesBeat('E algumas almas solitárias jogam uma partida só delas: o envelope vai dizer como vencer.'),
  ]),
  RulesStep('As três leis da rua', [
    RulesBeat.cue('Devagar, contando nos dedos.'),
    RulesBeat('Primeira lei: não se espia o celular dos outros.'),
    RulesBeat('Segunda lei: a própria tela não se mostra a ninguém.'),
    RulesBeat('Terceira lei: morto não fala. Nem com a boca, nem com os olhos.'),
    RulesBeat.cue('Uma pausa. Depois, num sussurro.'),
    RulesBeat('E agora… que comece a noite.'),
  ]),
];
